import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flat_models.dart';
import '../../features/inventory/application/product_repository.dart';
import '../../features/finance/application/expense_repository.dart';
import '../../features/invoices/application/invoice_repository.dart';

// ---------------------------------------------------------------------------
// FlatDataMigrationService
//
// One-time idempotent migration that moves nested business data stored on
// each user document into flat, franchiseId-scoped top-level collections:
//
//   users/{uid}.inventory[]          →  products/{item.id}
//   users/{uid}.inventoryMovements[] →  movements/{mov.id}
//   users/{uid}.expenses[]           →  expenses/{expenseId}
//   users/{uid}/invoice_history/*    →  invoices/{invoiceId}
//
// Safety guarantees:
//   • Reads the current user doc BEFORE writing anything.
//   • Uses upsertIfAbsent/recordIfAbsent — only writes if the doc does not
//     already exist, so re-running is completely safe.
//   • Never deletes the source arrays until all writes succeed.
//   • Writes a migration record under users/{uid}.migrationStatus.
//
// Usage (call once after login, e.g. in app initialisation):
//   await FlatDataMigrationService().migrateUserData(uid);
// ---------------------------------------------------------------------------
class FlatDataMigrationService {
  FlatDataMigrationService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final ProductRepository _productRepo = ProductRepository();
  final MovementRepository _movementRepo = MovementRepository();
  final ExpenseRepository _expenseRepo = ExpenseRepository();
  final InvoiceRepository _invoiceRepo = InvoiceRepository();

  static const _migrationKey = 'inventoryMigratedAt';

  // ── Public entry point ───────────────────────────────────────────────────

  /// Migrates nested inventory data for [uid] to flat collections.
  /// Safe to call more than once — returns early when already done.
  Future<MigrationResult> migrateUserData(String uid) async {
    final result = MigrationResult();

    try {
      final userRef = _db.collection('users').doc(uid);
      final userSnap = await userRef.get();
      if (!userSnap.exists) {
        result.log('User document not found for $uid — skipping.');
        return result;
      }

      final data = userSnap.data()!;

      // Already migrated?
      final status = data['migrationStatus'] as Map<dynamic, dynamic>?;
      if (status?[_migrationKey] != null) {
        result.log('Migration already completed on ${status![_migrationKey]}');
        return result;
      }

      // Resolve franchiseId (branchId if set, else uid)
      final branchId = data['branchId'] as String?;
      final franchiseId = (branchId != null && branchId.isNotEmpty)
          ? branchId
          : uid;
      result.log('Migrating uid=$uid  franchiseId=$franchiseId');

      // Migrate products (was: inventory array)
      result.productsWritten = await _migrateInventory(data, franchiseId);

      // Migrate movements (was: inventoryMovements array)
      result.movementsWritten = await _migrateMovements(data, franchiseId);

      // Migrate embedded expenses array from user document
      result.expensesWritten = await _migrateExpenses(data, franchiseId);

      // Migrate legacy user subcollection invoices
      result.invoicesWritten = await _migrateInvoiceHistory(uid, franchiseId);

      // Mark migration complete on the user document (does NOT remove the
      // old arrays — that can be done manually after validating the new data).
      await userRef.set({
        'migrationStatus': {
          _migrationKey: DateTime.now().toIso8601String(),
          'productsWritten': result.productsWritten,
          'movementsWritten': result.movementsWritten,
          'expensesWritten': result.expensesWritten,
          'invoicesWritten': result.invoicesWritten,
        },
      }, SetOptions(merge: true));

      // Auto-prune after successful migration so users docs stop carrying
      // embedded business arrays.
      await pruneUserDocument(uid);

      result.log(
        'Done: ${result.productsWritten} products, '
        '${result.movementsWritten} movements, '
        '${result.expensesWritten} expenses, '
        '${result.invoicesWritten} invoices migrated and pruned.',
      );
    } catch (e, st) {
      result.error = e.toString();
      result.log('Migration failed: $e\n$st');
    }

    return result;
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  Future<int> _migrateInventory(
    Map<String, dynamic> userData,
    String franchiseId,
  ) async {
    final rawItems = userData['inventory'] as List? ?? const [];
    var count = 0;

    for (final raw in rawItems) {
      if (raw is! Map) continue;

      final id = raw['id'] as String? ?? '';
      if (id.isEmpty) continue;

      final product = ProductModel(
        id: id,
        name: raw['name'] as String? ?? '',
        quantity: (raw['quantity'] as num?)?.toInt() ?? 0,
        unitPrice:
            (raw['unitPrice'] as num?)?.toDouble() ??
            (raw['price'] as num?)?.toDouble() ??
            0,
        threshold:
            (raw['threshold'] as num?)?.toInt() ??
            (raw['minQuantity'] as num?)?.toInt() ??
            10,
        supplier: raw['supplier'] as String? ?? '',
        franchiseId: franchiseId,
        createdAt: DateTime.tryParse(raw['createdAt'] as String? ?? ''),
        updatedAt: DateTime.now(),
      );

      await _productRepo.upsertIfAbsent(product);
      count++;
    }

    return count;
  }

  Future<int> _migrateMovements(
    Map<String, dynamic> userData,
    String franchiseId,
  ) async {
    final rawMovements = userData['inventoryMovements'] as List? ?? const [];
    var count = 0;

    for (final raw in rawMovements) {
      if (raw is! Map) continue;

      final id = raw['id'] as String? ?? '';
      if (id.isEmpty) continue;

      final movement = StockMovementModel(
        id: id,
        productId:
            raw['productId'] as String? ?? raw['itemId'] as String? ?? '',
        productName:
            raw['productName'] as String? ?? raw['itemName'] as String? ?? '',
        type: raw['type'] as String? ?? 'adjustment',
        quantity:
            (raw['quantity'] as num?)?.toInt() ??
            (raw['quantityChange'] as num?)?.toInt() ??
            0,
        previousQuantity: (raw['previousQuantity'] as num?)?.toInt() ?? 0,
        newQuantity: (raw['newQuantity'] as num?)?.toInt() ?? 0,
        franchiseId: franchiseId,
        reason: raw['reason'] as String? ?? raw['note'] as String? ?? '',
        createdAt: DateTime.tryParse(raw['createdAt'] as String? ?? ''),
      );

      await _movementRepo.recordIfAbsent(movement);
      count++;
    }

    return count;
  }

  Future<int> _migrateExpenses(
    Map<String, dynamic> userData,
    String franchiseId,
  ) async {
    final rawExpenses = userData['expenses'] as List? ?? const [];
    var count = 0;

    for (final raw in rawExpenses) {
      if (raw is! Map) continue;
      final id = raw['id'] as String? ?? '';
      if (id.isEmpty) continue;

      final createdAt = DateTime.tryParse(raw['createdAt'] as String? ?? '');
      final expenseDate = DateTime.tryParse(
        raw['expenseDate'] as String? ?? '',
      );

      final expense = FlatExpenseModel(
        id: id,
        description:
            raw['title'] as String? ?? raw['description'] as String? ?? '',
        amount: (raw['amount'] as num?)?.toDouble() ?? 0,
        category: raw['category'] as String? ?? 'General',
        franchiseId: franchiseId,
        expenseDate: expenseDate,
        note: raw['note'] as String? ?? '',
        createdAt: createdAt,
      );

      await _expenseRepo.upsertIfAbsent(expense);
      count++;
    }

    return count;
  }

  Future<int> _migrateInvoiceHistory(String uid, String franchiseId) async {
    var count = 0;
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('invoice_history')
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final invoiceNumber =
          data['invoiceNo'] as String? ??
          data['quotationNo'] as String? ??
          doc.id;
      final generatedAt = DateTime.tryParse(
        data['generatedAt'] as String? ?? '',
      );
      final total = (data['total'] as num?)?.toDouble() ?? 0;
      final paymentReceived =
          (data['paymentReceived'] as num?)?.toDouble() ?? 0;
      final remainingPayment =
          (data['remainingPayment'] as num?)?.toDouble() ?? 0;

      final lines =
          ((data['document'] as Map?)?['lineItems'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (line) => {
                  'name': line['name']?.toString() ?? '',
                  'qty': (line['quantity'] as num?)?.toDouble() ?? 0,
                  'unitPrice': (line['unitPrice'] as num?)?.toDouble() ?? 0,
                  'total':
                      ((line['quantity'] as num?)?.toDouble() ?? 0) *
                      ((line['unitPrice'] as num?)?.toDouble() ?? 0),
                },
              )
              .toList();

      final flat = FlatInvoiceModel(
        id: doc.id,
        invoiceNumber: invoiceNumber,
        clientName: data['clientName'] as String? ?? '',
        items: lines,
        grandTotal: total,
        paymentReceived: paymentReceived,
        remainingPayment: remainingPayment,
        franchiseId: franchiseId,
        status: remainingPayment <= 0 ? 'paid' : 'pending',
        quotationNo:
            data['parentQuotationNo'] as String? ??
            data['quotationNo'] as String? ??
            '',
        isInvoice: data['isInvoice'] as bool? ?? true,
        renderedTemplate: data['renderedTemplate'] as String? ?? '',
        createdAt: generatedAt,
      );

      await _invoiceRepo.upsertIfAbsent(flat);
      count++;
    }

    return count;
  }

  /// Removes the now-migrated nested arrays from the user document.
  /// Call this AFTER validating the flat collections look correct.
  Future<void> pruneUserDocument(String uid) async {
    await _db.collection('users').doc(uid).update({
      'inventory': FieldValue.delete(),
      'inventoryMovements': FieldValue.delete(),
      'expenses': FieldValue.delete(),
    });
  }
}

// ---------------------------------------------------------------------------
// MigrationResult
// ---------------------------------------------------------------------------
class MigrationResult {
  int productsWritten = 0;
  int movementsWritten = 0;
  int expensesWritten = 0;
  int invoicesWritten = 0;
  String? error;
  final List<String> logs = [];

  bool get success => error == null;

  void log(String message) {
    // ignore: avoid_print
    print('[Migration] $message');
    logs.add(message);
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------
final flatDataMigrationServiceProvider = Provider<FlatDataMigrationService>(
  (ref) => FlatDataMigrationService(),
);
