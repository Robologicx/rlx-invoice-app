import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../../../core/models/erp_models.dart';
import '../../../database/local_database.dart';

class ExpenseService {
  Future<Box<Map>?> _ensureExpenseBox() async {
    try {
      if (!Hive.isBoxOpen(LocalDatabase.expensesBox)) {
        await Hive.openBox<Map>(LocalDatabase.expensesBox);
      }
      return Hive.box<Map>(LocalDatabase.expensesBox);
    } catch (_) {
      return null;
    }
  }

  Future<Box<Map>?> _ensureFixedBox() async {
    try {
      if (!Hive.isBoxOpen(LocalDatabase.fixedMonthlyExpensesBox)) {
        await Hive.openBox<Map>(LocalDatabase.fixedMonthlyExpensesBox);
      }
      return Hive.box<Map>(LocalDatabase.fixedMonthlyExpensesBox);
    } catch (_) {
      return null;
    }
  }

  Box<Map>? get _box {
    if (!Hive.isBoxOpen(LocalDatabase.expensesBox)) {
      return null;
    }
    return Hive.box<Map>(LocalDatabase.expensesBox);
  }

  Box<Map>? get _fixedBox {
    if (!Hive.isBoxOpen(LocalDatabase.fixedMonthlyExpensesBox)) {
      return null;
    }
    return Hive.box<Map>(LocalDatabase.fixedMonthlyExpensesBox);
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
    final box = await _ensureExpenseBox();
    if (box == null) {
      return false;
    }

    final resolvedId =
        customId ?? 'exp_${DateTime.now().microsecondsSinceEpoch}';
    if (skipIfIdExists && box.containsKey(resolvedId)) {
      return false;
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

    await box.put(record.id, record.toMap());
    return true;
  }

  Future<void> deleteExpense(String id) async {
    final box = await _ensureExpenseBox();
    if (box == null) {
      return;
    }
    await box.delete(id);
  }

  Future<void> clearAll() async {
    final box = await _ensureExpenseBox();
    if (box == null) {
      return;
    }
    await box.clear();
  }

  Future<void> upsertFixedMonthlyExpense({
    String? id,
    required String title,
    required double amount,
    required String category,
    String note = '',
    bool isActive = true,
  }) async {
    final box = await _ensureFixedBox();
    if (box == null) {
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

    await box.put(record.id, record.toMap());
  }

  Future<void> deleteFixedMonthlyExpense(String id) async {
    final box = await _ensureFixedBox();
    if (box == null) {
      return;
    }
    await box.delete(id);
  }

  Future<void> setFixedMonthlyExpenseActive(String id, bool isActive) async {
    final box = await _ensureFixedBox();
    if (box == null) {
      return;
    }
    final raw = box.get(id);
    if (raw == null) {
      return;
    }
    final current = FixedMonthlyExpense.fromMap(raw);
    await box.put(
      id,
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
    final box = _fixedBox;
    if (box == null) {
      return const [];
    }

    return box.values
        .map((value) => FixedMonthlyExpense.fromMap(value))
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  Stream<List<FixedMonthlyExpense>> watchFixedMonthlyExpenses() async* {
    final box = _fixedBox;
    if (box == null) {
      yield const [];
      return;
    }

    yield allFixedMonthlyExpenses();
    await for (final _ in box.watch()) {
      yield allFixedMonthlyExpenses();
    }
  }

  Future<int> syncFixedExpensesForMonth({DateTime? month}) async {
    final targetMonth = month ?? DateTime.now();
    final monthKey = DateFormat('yyyyMM').format(targetMonth);
    final expenseDate = DateTime(targetMonth.year, targetMonth.month, 1);
    final fixedExpenses = allFixedMonthlyExpenses()
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
    final box = _box;
    if (box == null) {
      return const [];
    }

    return box.values.map((value) => ExpenseRecord.fromMap(value)).toList()
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
  }

  Stream<List<ExpenseRecord>> watchAll() async* {
    final box = _box;
    if (box == null) {
      yield const [];
      return;
    }

    yield all();
    await for (final _ in box.watch()) {
      yield all();
    }
  }
}

final expenseServiceProvider = Provider<ExpenseService>((ref) {
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
