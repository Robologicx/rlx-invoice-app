import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/erp_models.dart';
import '../../../core/services/firebase_auth_service.dart';

class ExpenseService {
  final FirebaseFirestore _firestore;

  ExpenseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  String? _activeUserId() => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _expenseCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('expenses');
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
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return false;
    }

    final resolvedId =
        customId ?? 'exp_${DateTime.now().microsecondsSinceEpoch}';
    if (skipIfIdExists) {
      final existing = await _expenseCollection(userId).doc(resolvedId).get();
      if (existing.exists) {
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

    await _expenseCollection(userId).doc(record.id).set(record.toMap());
    return true;
  }

  Future<void> deleteExpense(String id) async {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }
    await _expenseCollection(userId).doc(id).delete();
  }

  Future<void> clearAll() async {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }

    final snapshot = await _expenseCollection(userId).get();
    if (snapshot.docs.isEmpty) {
      return;
    }
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> upsertFixedMonthlyExpense({
    String? id,
    required String title,
    required double amount,
    required String category,
    String note = '',
    bool isActive = true,
  }) async {
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
  }

  Future<void> deleteFixedMonthlyExpense(String id) async {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }
    await _fixedCollection(userId).doc(id).delete();
  }

  Future<void> setFixedMonthlyExpenseActive(String id, bool isActive) async {
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

    yield* _fixedCollection(userId).snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map((doc) => FixedMonthlyExpense.fromMap(doc.data()))
              .toList()
            ..sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
            ),
    );
  }

  Future<List<FixedMonthlyExpense>> _fetchFixedMonthlyExpenses() async {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return const [];
    }

    final snapshot = await _fixedCollection(userId).get();
    final records = snapshot.docs
        .map((doc) => FixedMonthlyExpense.fromMap(doc.data()))
        .toList();
    records.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return records;
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

    yield* _expenseCollection(userId).snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => ExpenseRecord.fromMap(doc.data())).toList()
            ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate)),
    );
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
