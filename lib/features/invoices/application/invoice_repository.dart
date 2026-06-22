import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/flat_models.dart';

class InvoiceRepository {
  InvoiceRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('invoices');

  Stream<List<FlatInvoiceModel>> watchInvoices(String franchiseId) {
    return _col
        .where('franchiseId', isEqualTo: franchiseId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => FlatInvoiceModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<List<FlatInvoiceModel>> fetchInvoices(String franchiseId) async {
    final snap = await _col
        .where('franchiseId', isEqualTo: franchiseId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((doc) => FlatInvoiceModel.fromFirestore(doc)).toList();
  }

  Future<String> upsertInvoice(FlatInvoiceModel invoice) async {
    final docRef = invoice.id.isEmpty ? _col.doc() : _col.doc(invoice.id);
    await docRef.set(invoice.toFirestore(), SetOptions(merge: true));
    return docRef.id;
  }

  Future<void> upsertIfAbsent(FlatInvoiceModel invoice) async {
    if (invoice.id.isEmpty) {
      await _col.add(invoice.toFirestore());
      return;
    }
    final existing = await _col.doc(invoice.id).get();
    if (existing.exists) return;
    await _col.doc(invoice.id).set(invoice.toFirestore());
  }

  Future<void> deleteInvoice(String invoiceId) async {
    await _col.doc(invoiceId).delete();
  }

  Future<void> deleteInvoicesByFranchise(String franchiseId) async {
    final snap = await _col.where('franchiseId', isEqualTo: franchiseId).get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
