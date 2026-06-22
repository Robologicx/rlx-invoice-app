import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/models/erp_models.dart';
import '../../../core/models/flat_models.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../database/local_database.dart';
import 'expense_repository.dart';

class ExpenseService {
  final FirebaseFirestore _firestore;
  final ExpenseRepository _expenseRepository;

  ExpenseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _expenseRepository = ExpenseRepository(firestore: firestore);

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

  CollectionReference<Map<String, dynamic>> _fixedCollection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('fixed_monthly_expenses');
  }

  Future<bool> addExpense({
    required String title,
    required double amount,
    required String category,
    required DateTime expenseDate,
    String? customId,
    bool skipIfIdExists = false,
    String note = '',
  }) async {
    try {
      final userId = _activeUserId();
      if (userId == null || userId.isEmpty) {
        return false;
      }

      final resolvedId =
          customId ?? 'exp_${DateTime.now().microsecondsSinceEpoch}';

      // Check local storage first
      if (skipIfIdExists && Hive.isBoxOpen(LocalDatabase.expensesBox)) {
        final box = Hive.box<Map>(LocalDatabase.expensesBox);
        if (box.containsKey(resolvedId)) {
          return false;
        }
      }

      final now = DateTime.now();
      final record = ExpenseRecord(
        id: resolvedId,
        title: title.trim(),
        amount: amount,
        category: category.trim().isEmpty ? 'General' : category.trim(),
        expenseDate: expenseDate,
        createdAt: now,
        note: note.trim(),
      );

      // Save to local Hive first for immediate UI feedback
      if (Hive.isBoxOpen(LocalDatabase.expensesBox)) {
        await Hive.box<Map>(
          LocalDatabase.expensesBox,
        ).put(record.id, record.toMap());
      }

      // Sync to Firestore in background (don't wait for result)
      unawaited(() async {
        final franchiseId = await _activeFranchiseId();
        if (franchiseId == null) return;
        await _expenseRepository.upsertExpense(
          FlatExpenseModel(
            id: record.id,
            description: record.title,
            amount: record.amount,
            category: record.category,
            franchiseId: franchiseId,
            expenseDate: record.expenseDate,
            note: record.note,
            createdAt: record.createdAt,
          ),
        );
      }());

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      final userId = _activeUserId();
      if (userId == null || userId.isEmpty) {
        return;
      }
      await _expenseRepository.deleteExpense(id);
    } catch (_) {
      // Silently fail
    }
  }

  Future<void> clearAll() async {
    try {
      final userId = _activeUserId();
      if (userId == null || userId.isEmpty) {
        return;
      }

      final franchiseId = await _activeFranchiseId();
      if (franchiseId == null) {
        return;
      }
      await _expenseRepository.deleteExpensesByFranchise(franchiseId);
    } catch (_) {
      // Silently fail
    }
  }

  Future<void> upsertFixedMonthlyExpense({
    String? id,
    required String title,
    required double amount,
    required String category,
    String note = '',
    bool isActive = true,
  }) async {
    try {
      final userId = _activeUserId();
      if (userId == null || userId.isEmpty) {
        return;
      }

      final now = DateTime.now();
      final record = FixedMonthlyExpense(
        id: id ?? 'fixed_${now.microsecondsSinceEpoch}',
        title: title.trim(),
        amount: amount,
        category: category.trim().isEmpty ? 'Fixed Expense' : category.trim(),
        createdAt: now,
        note: note.trim(),
        isActive: isActive,
      );

      await _fixedCollection(userId).doc(record.id).set(record.toMap());
    } catch (_) {
      // Silently fail
    }
  }

  Future<void> deleteFixedMonthlyExpense(String id) async {
    try {
      final userId = _activeUserId();
      if (userId == null || userId.isEmpty) {
        return;
      }
      await _fixedCollection(userId).doc(id).delete();
    } catch (_) {
      // Silently fail
    }
  }

  Future<void> setFixedMonthlyExpenseActive(String id, bool isActive) async {
    try {
      final userId = _activeUserId();
      if (userId == null || userId.isEmpty) {
        return;
      }
      final raw = await _fixedCollection(userId).doc(id).get();
      if (!raw.exists) {
        return;
      }
      final current = FixedMonthlyExpense.fromMap(raw.data()!);
      await _fixedCollection(userId)
          .doc(id)
          .set(
            FixedMonthlyExpense(
              id: current.id,
              title: current.title,
              amount: current.amount,
              category: current.category,
              createdAt: current.createdAt,
              note: current.note,
              isActive: isActive,
            ).toMap(),
          );
    } catch (_) {
      // Silently fail
    }
  }

  List<FixedMonthlyExpense> allFixedMonthlyExpenses() {
    return const [];
  }

  Stream<List<FixedMonthlyExpense>> watchFixedMonthlyExpenses() async* {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      yield const [];
      return;
    }

    yield const [];
    await for (final snapshot in _fixedCollection(userId).snapshots()) {
      yield snapshot.docs
          .map((doc) => FixedMonthlyExpense.fromMap(doc.data()))
          .toList()
        ..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }
  }

  Future<List<FixedMonthlyExpense>> _fetchFixedMonthlyExpenses() async {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return const [];
    }

    try {
      final snapshot = await _fixedCollection(userId).get();
      final records = snapshot.docs
          .map((doc) => FixedMonthlyExpense.fromMap(doc.data()))
          .toList();
      records.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      return records;
    } catch (_) {
      return const [];
    }
  }

  Future<int> syncFixedExpensesForMonth({DateTime? month}) async {
    final targetMonth = month ?? DateTime.now();
    final monthKey = DateFormat('yyyyMM').format(targetMonth);
    final expenseDate = DateTime(targetMonth.year, targetMonth.month, 1);
    final fixedExpenses = (await _fetchFixedMonthlyExpenses())
        .where((item) => item.isActive && item.amount > 0)
        .toList();

    var created = 0;
    for (final item in fixedExpenses) {
      final added = await addExpense(
        title: item.title,
        amount: item.amount,
        category: item.category,
        expenseDate: expenseDate,
        customId: 'fixed_${item.id}_$monthKey',
        skipIfIdExists: true,
        note: item.note,
      );
      if (added) {
        created += 1;
      }
    }

    return created;
  }

  List<ExpenseRecord> all() {
    return const [];
  }

  Stream<List<ExpenseRecord>> watchAll() async* {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      yield const [];
      return;
    }

    // Watch local Hive box first
    if (Hive.isBoxOpen(LocalDatabase.expensesBox)) {
      final box = Hive.box<Map>(LocalDatabase.expensesBox);
      yield _localExpenses(box);
      yield* box.watch().map((_) => _localExpenses(box));
      return;
    }

    // Fallback to Firestore top-level collection if Hive isn't available
    final franchiseId = await _activeFranchiseId();
    if (franchiseId == null) {
      yield const [];
      return;
    }

    yield const [];
    yield* _expenseRepository.watchExpenses(franchiseId).map((items) {
      final records = items
          .map(
            (item) => ExpenseRecord(
              id: item.id,
              title: item.description,
              amount: item.amount,
              category: item.category,
              expenseDate: item.expenseDate ?? item.createdAt ?? DateTime.now(),
              createdAt: item.createdAt ?? item.expenseDate ?? DateTime.now(),
              note: item.note,
            ),
          )
          .toList();
      records.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      return records;
    });
  }

  List<ExpenseRecord> _localExpenses(Box<Map> box) {
    final records = box.values
        .map((data) => ExpenseRecord.fromMap(data))
        .toList();
    records.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    return records;
  }
}

final expenseServiceProvider = Provider<ExpenseService>((ref) {
  ref.watch(currentUserProvider);
  return ExpenseService();
});

final expenseHistoryProvider = StreamProvider<List<ExpenseRecord>>((ref) {
  final service = ref.watch(expenseServiceProvider);
  return service.watchAll();
});

final fixedMonthlyExpensesProvider = StreamProvider<List<FixedMonthlyExpense>>((
  ref,
) {
  final service = ref.watch(expenseServiceProvider);
  return service.watchFixedMonthlyExpenses();
});
