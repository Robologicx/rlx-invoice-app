import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/flat_models.dart';

class ExpenseRepository {
  ExpenseRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('expenses');

  Stream<List<FlatExpenseModel>> watchExpenses(String franchiseId) {
    return _col
        .where('franchiseId', isEqualTo: franchiseId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => FlatExpenseModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<List<FlatExpenseModel>> fetchExpenses(String franchiseId) async {
    final snap = await _col
        .where('franchiseId', isEqualTo: franchiseId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((doc) => FlatExpenseModel.fromFirestore(doc)).toList();
  }

  Future<String> upsertExpense(FlatExpenseModel expense) async {
    final docRef = expense.id.isEmpty ? _col.doc() : _col.doc(expense.id);
    await docRef.set(expense.toFirestore(), SetOptions(merge: true));
    return docRef.id;
  }

  Future<void> upsertIfAbsent(FlatExpenseModel expense) async {
    if (expense.id.isEmpty) {
      await _col.add(expense.toFirestore());
      return;
    }
    final existing = await _col.doc(expense.id).get();
    if (existing.exists) return;
    await _col.doc(expense.id).set(expense.toFirestore());
  }

  Future<void> deleteExpense(String expenseId) async {
    await _col.doc(expenseId).delete();
  }

  Future<void> deleteExpensesByFranchise(String franchiseId) async {
    final snap = await _col.where('franchiseId', isEqualTo: franchiseId).get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
