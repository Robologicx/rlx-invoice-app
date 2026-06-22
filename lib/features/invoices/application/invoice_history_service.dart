import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/models/erp_models.dart';
import '../../../core/models/flat_models.dart';
import '../../../core/services/app_mode_service.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../database/local_database.dart';
import 'invoice_repository.dart';

const _invoiceHistorySyncPendingKey = 'invoice_history_sync_pending';
const _invoiceHistoryDeletedIdsKey = 'invoice_history_deleted_ids';
const _invoiceHistoryCleanupCompletedKey = 'invoice_history_cleanup_completed';

class InvoiceHistoryService {
  final FirebaseFirestore _firestore;
  final InvoiceRepository _invoiceRepository;
  final bool useLocalStorage;
  final Connectivity _connectivity = Connectivity();

  InvoiceHistoryService({
    FirebaseFirestore? firestore,
    required this.useLocalStorage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _invoiceRepository = InvoiceRepository(firestore: firestore);

  String? _activeUserId() => FirebaseAuth.instance.currentUser?.uid;

  Future<String?> _activeFranchiseId() async {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return null;
    }
    try {
      final profile = await _firestore.collection('users').doc(userId).get();
      final branchId = profile.data()?['branchId'] as String?;
      return (branchId != null && branchId.isNotEmpty) ? branchId : userId;
    } catch (_) {
      return userId;
    }
  }

  Future<void> save(GeneratedQuotation quotation) async {
    if (useLocalStorage) {
      await _saveLocal(quotation);
      unawaited(syncPendingToCloud());
      return;
    }

    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final recordId = _recordIdFor(quotation);
    final record = InvoiceRecord(
      id: recordId,
      quotationNo: quotation.quotationNo,
      parentQuotationNo: quotation.quotationNo,
      isInvoice: quotation.isInvoice,
      invoiceNo: quotation.invoiceNo,
      clientName: quotation.clientName,
      category: quotation.category,
      packageName: quotation.packageName,
      total: quotation.grandTotal,
      paymentReceived: quotation.paymentReceived,
      remainingPayment: quotation.remainingPayment,
      generatedAt: now,
      renderedTemplate: quotation.renderedTemplate,
      document: quotation,
    );
    final franchiseId = await _activeFranchiseId();
    if (franchiseId == null) {
      return;
    }
    await _invoiceRepository.upsertInvoice(_toFlatInvoice(record, franchiseId));
  }

  List<InvoiceRecord> all() {
    if (!useLocalStorage) {
      return const [];
    }

    return _localRecords();
  }

  Stream<List<InvoiceRecord>> watchAll() async* {
    if (useLocalStorage) {
      final box = Hive.box<Map>(LocalDatabase.invoicesBox);
      yield _localRecords();
      yield* box.watch().map((_) => _localRecords());
      return;
    }

    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      yield const [];
      return;
    }

    final franchiseId = await _activeFranchiseId();
    if (franchiseId == null) {
      yield const [];
      return;
    }

    yield* _invoiceRepository
        .watchInvoices(franchiseId)
        .map(
          (snapshot) => _dedupeRecords(snapshot.map(_fromFlatInvoice).toList()),
        );
  }

  Future<void> deleteRecord(String id) async {
    if (useLocalStorage) {
      await Hive.box<Map>(LocalDatabase.invoicesBox).delete(id);
      await _queueDeletedInvoiceId(id);
      unawaited(syncPendingToCloud());
      return;
    }

    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }
    await _invoiceRepository.deleteInvoice(id);
  }

  Future<void> clearAll() async {
    if (useLocalStorage) {
      final localIds = Hive.box<Map>(
        LocalDatabase.invoicesBox,
      ).keys.map((key) => key.toString()).where((id) => id.isNotEmpty).toList();
      await _queueDeletedInvoiceIds(localIds);
      await Hive.box<Map>(LocalDatabase.invoicesBox).clear();
      unawaited(syncPendingToCloud());
      return;
    }

    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }

    final franchiseId = await _activeFranchiseId();
    if (franchiseId == null) {
      return;
    }
    await _invoiceRepository.deleteInvoicesByFranchise(franchiseId);
  }

  Future<void> cleanupLegacyDuplicatesOnce() async {
    if (_cleanupCompleted()) {
      return;
    }

    final localCleanupDone = await _cleanupLocalDuplicates();
    final cloudCleanupDone = await _cleanupCloudDuplicates();

    if (localCleanupDone && cloudCleanupDone) {
      await _setCleanupCompleted(true);
    }
  }

  Future<void> _saveLocal(GeneratedQuotation quotation) async {
    final now = DateTime.now();
    final recordId = _recordIdFor(quotation);
    final record = InvoiceRecord(
      id: recordId,
      quotationNo: quotation.quotationNo,
      parentQuotationNo: quotation.quotationNo,
      isInvoice: quotation.isInvoice,
      invoiceNo: quotation.invoiceNo,
      clientName: quotation.clientName,
      category: quotation.category,
      packageName: quotation.packageName,
      total: quotation.grandTotal,
      paymentReceived: quotation.paymentReceived,
      remainingPayment: quotation.remainingPayment,
      generatedAt: now,
      renderedTemplate: quotation.renderedTemplate,
      document: quotation,
    );
    await Hive.box<Map>(
      LocalDatabase.invoicesBox,
    ).put(record.id, record.toMap());
    await _setSyncPending(true);
  }

  Future<void> syncPendingToCloud() async {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }

    if (!_hasPendingSync()) {
      return;
    }

    final connectivityResults = await _connectivity.checkConnectivity();
    if (!_hasNetwork(connectivityResults)) {
      return;
    }

    final localRecords = _localRecords();
    final deletedIds = _pendingDeletedIds();
    final franchiseId = await _activeFranchiseId();
    if (franchiseId == null) {
      return;
    }

    if (localRecords.isEmpty && deletedIds.isEmpty) {
      await _clearSyncQueue();
      return;
    }

    try {
      for (final record in localRecords) {
        await _invoiceRepository.upsertInvoice(
          _toFlatInvoice(record, franchiseId),
        );
      }

      for (final deletedId in deletedIds) {
        await _invoiceRepository.deleteInvoice(deletedId);
      }
      await _clearSyncQueue();
    } catch (_) {
      // Keep the queue so the next online event can retry.
    }
  }

  Future<bool> _cleanupLocalDuplicates() async {
    if (!Hive.isBoxOpen(LocalDatabase.invoicesBox)) {
      return false;
    }

    final box = Hive.box<Map>(LocalDatabase.invoicesBox);
    final records = box.values.map(InvoiceRecord.fromMap).toList();
    final deduped = <String, InvoiceRecord>{};
    final duplicatesToDelete = <String>[];

    for (final record in records) {
      final key = _recordKey(record);
      final existing = deduped[key];
      if (existing == null) {
        deduped[key] = record;
        continue;
      }

      if (record.generatedAt.isAfter(existing.generatedAt)) {
        duplicatesToDelete.add(existing.id);
        deduped[key] = record;
      } else {
        duplicatesToDelete.add(record.id);
      }
    }

    for (final id in duplicatesToDelete) {
      await box.delete(id);
    }

    return true;
  }

  Future<bool> _cleanupCloudDuplicates() async {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return false;
    }

    final connectivityResults = await _connectivity.checkConnectivity();
    if (!_hasNetwork(connectivityResults)) {
      return false;
    }

    try {
      final franchiseId = await _activeFranchiseId();
      if (franchiseId == null) {
        return false;
      }

      final flatRecords = await _invoiceRepository.fetchInvoices(franchiseId);
      if (flatRecords.isEmpty) {
        return true;
      }

      final records = flatRecords.map(_fromFlatInvoice).toList();
      final deduped = <String, InvoiceRecord>{};
      final duplicateIds = <String>[];

      for (final record in records) {
        final key = _recordKey(record);
        final existing = deduped[key];
        if (existing == null) {
          deduped[key] = record;
          continue;
        }

        if (record.generatedAt.isAfter(existing.generatedAt)) {
          duplicateIds.add(existing.id);
          deduped[key] = record;
        } else {
          duplicateIds.add(record.id);
        }
      }

      if (duplicateIds.isEmpty) {
        return true;
      }

      for (var index = 0; index < duplicateIds.length; index += 450) {
        final end = (index + 450).clamp(0, duplicateIds.length);
        for (final id in duplicateIds.sublist(index, end)) {
          await _invoiceRepository.deleteInvoice(id);
        }
      }

      return true;
    } on FirebaseException {
      // Avoid blocking app startup in debug if rules/network are not ready.
      return false;
    }
  }

  List<InvoiceRecord> _localRecords() {
    final box = Hive.box<Map>(LocalDatabase.invoicesBox);
    final records = box.values.map(InvoiceRecord.fromMap).toList();
    return _dedupeRecords(records);
  }

  List<InvoiceRecord> _dedupeRecords(List<InvoiceRecord> records) {
    final deduped = <String, InvoiceRecord>{};
    for (final record in records) {
      final key = _recordKey(record);
      final existing = deduped[key];
      if (existing == null ||
          record.generatedAt.isAfter(existing.generatedAt)) {
        deduped[key] = record;
      }
    }

    final result = deduped.values.toList();
    result.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return result;
  }

  String _recordIdFor(GeneratedQuotation quotation) {
    return quotation.quotationNo;
  }

  String _recordKey(InvoiceRecord record) {
    if (record.isInvoice && record.invoiceNo.isNotEmpty) {
      return record.invoiceNo;
    }

    if (record.parentQuotationNo.isNotEmpty) {
      return record.parentQuotationNo;
    }

    return record.quotationNo;
  }

  bool _cleanupCompleted() {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return false;
    }

    return Hive.box(
              LocalDatabase.appSettingsBox,
            ).get(_invoiceHistoryCleanupCompletedKey, defaultValue: false)
            as bool? ??
        false;
  }

  Future<void> _setCleanupCompleted(bool completed) async {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return;
    }

    await Hive.box(
      LocalDatabase.appSettingsBox,
    ).put(_invoiceHistoryCleanupCompletedKey, completed);
  }

  bool _hasPendingSync() {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return false;
    }

    return Hive.box(
              LocalDatabase.appSettingsBox,
            ).get(_invoiceHistorySyncPendingKey, defaultValue: false)
            as bool? ??
        false;
  }

  Future<void> _setSyncPending(bool pending) async {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return;
    }

    await Hive.box(
      LocalDatabase.appSettingsBox,
    ).put(_invoiceHistorySyncPendingKey, pending);
  }

  Set<String> _pendingDeletedIds() {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return <String>{};
    }

    final raw = Hive.box(
      LocalDatabase.appSettingsBox,
    ).get(_invoiceHistoryDeletedIdsKey, defaultValue: const <String>[]);

    if (raw is List) {
      return raw.whereType<String>().toSet();
    }

    return <String>{};
  }

  Future<void> _queueDeletedInvoiceId(String id) async {
    await _queueDeletedInvoiceIds(<String>[id]);
  }

  Future<void> _queueDeletedInvoiceIds(Iterable<String> ids) async {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return;
    }

    final next = _pendingDeletedIds();
    next.addAll(ids.where((id) => id.isNotEmpty));
    await Hive.box(
      LocalDatabase.appSettingsBox,
    ).put(_invoiceHistoryDeletedIdsKey, next.toList());
    await _setSyncPending(true);
  }

  Future<void> _clearSyncQueue() async {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return;
    }

    final box = Hive.box(LocalDatabase.appSettingsBox);
    await box.put(_invoiceHistoryDeletedIdsKey, <String>[]);
    await box.put(_invoiceHistorySyncPendingKey, false);
  }

  bool _hasNetwork(List<ConnectivityResult> connectivityResults) {
    return connectivityResults.any(
      (result) => result != ConnectivityResult.none,
    );
  }

  FlatInvoiceModel _toFlatInvoice(InvoiceRecord record, String franchiseId) {
    return FlatInvoiceModel(
      id: record.id,
      invoiceNumber: record.invoiceNo.isNotEmpty
          ? record.invoiceNo
          : record.quotationNo,
      clientName: record.clientName,
      items: record.document.lineItems
          .map(
            (line) => {
              'name': line.name,
              'qty': line.quantity,
              'unitPrice': line.unitPrice,
              'total': line.total,
            },
          )
          .toList(),
      grandTotal: record.total,
      paymentReceived: record.paymentReceived,
      remainingPayment: record.remainingPayment,
      franchiseId: franchiseId,
      status: record.remainingPayment <= 0 ? 'paid' : 'pending',
      quotationNo: record.parentQuotationNo,
      isInvoice: record.isInvoice,
      renderedTemplate: record.renderedTemplate,
      createdAt: record.generatedAt,
    );
  }

  InvoiceRecord _fromFlatInvoice(FlatInvoiceModel flat) {
    final generatedAt = flat.createdAt ?? DateTime.now();
    final quotationNo = flat.quotationNo.isNotEmpty
        ? flat.quotationNo
        : flat.invoiceNumber;
    final category = ServiceCategory.electricFence;
    final lineItems = flat.items
        .map(
          (item) => QuotationLine(
            name: item['name']?.toString() ?? '',
            quantity: (item['qty'] as num?)?.toDouble() ?? 0,
            unitPrice: (item['unitPrice'] as num?)?.toDouble() ?? 0,
            unit: 'unit',
          ),
        )
        .toList();

    final generated = GeneratedQuotation(
      quotationNo: quotationNo,
      clientName: flat.clientName,
      category: category,
      packageName: '',
      templateName: '',
      generatedDate: generatedAt,
      lineItems: lineItems,
      optionalItems: const [],
      subtotal: flat.grandTotal,
      grandTotal: flat.grandTotal,
      warranty: '',
      terms: const [],
      globalSections: const [],
      placeholderValues: const {},
      renderedTemplate: flat.renderedTemplate,
      isInvoice: flat.isInvoice,
      invoiceNo: flat.invoiceNumber,
      paymentReceived: flat.paymentReceived,
      remainingPayment: flat.remainingPayment,
    );

    return InvoiceRecord(
      id: flat.id,
      quotationNo: quotationNo,
      parentQuotationNo: quotationNo,
      isInvoice: flat.isInvoice,
      invoiceNo: flat.invoiceNumber,
      clientName: flat.clientName,
      category: category,
      packageName: '',
      total: flat.grandTotal,
      paymentReceived: flat.paymentReceived,
      remainingPayment: flat.remainingPayment,
      generatedAt: generatedAt,
      renderedTemplate: flat.renderedTemplate,
      document: generated,
    );
  }
}

final invoiceHistoryServiceProvider = Provider<InvoiceHistoryService>((ref) {
  final useLocalStorage = ref.watch(appModeProvider);
  ref.watch(currentUserProvider);
  return InvoiceHistoryService(useLocalStorage: useLocalStorage);
});

final invoiceHistoryProvider = StreamProvider<List<InvoiceRecord>>((ref) {
  final service = ref.watch(invoiceHistoryServiceProvider);
  return service.watchAll();
});

final connectivityStateProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  final connectivity = Connectivity();
  return connectivity.onConnectivityChanged;
});

final invoiceHistorySyncProvider = Provider<void>((ref) {
  final service = ref.watch(invoiceHistoryServiceProvider);

  ref.listen<AsyncValue<List<ConnectivityResult>>>(connectivityStateProvider, (
    previous,
    next,
  ) {
    unawaited(service.syncPendingToCloud());
  });

  ref.listen<User?>(currentUserProvider, (previous, next) {
    if (next != null) {
      unawaited(service.cleanupLegacyDuplicatesOnce());
      unawaited(service.syncPendingToCloud());
    }
  });

  unawaited(service.cleanupLegacyDuplicatesOnce());
  unawaited(service.syncPendingToCloud());
});

final historyEditorDocumentProvider = StateProvider<GeneratedQuotation?>((ref) {
  return null;
});
