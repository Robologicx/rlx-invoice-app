import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/erp_models.dart';
import '../../../core/services/firebase_auth_service.dart';

class InvoiceHistoryService {
  final FirebaseFirestore _firestore;

  InvoiceHistoryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  String? _activeUserId() => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('invoice_history');
  }

  Future<void> save(GeneratedQuotation quotation) async {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final uniqueId =
        '${quotation.quotationNo}-${now.microsecondsSinceEpoch}-${quotation.isInvoice ? 'inv' : 'quo'}';
    final record = InvoiceRecord(
      id: uniqueId,
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
    await _collection(userId).doc(record.id).set(record.toMap());
  }

  List<InvoiceRecord> all() {
    return const [];
  }

  Stream<List<InvoiceRecord>> watchAll() async* {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      yield const [];
      return;
    }

    yield* _collection(userId)
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => InvoiceRecord.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<void> deleteRecord(String id) async {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }
    await _collection(userId).doc(id).delete();
  }

  Future<void> clearAll() async {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }

    final snapshot = await _collection(userId).get();
    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

final invoiceHistoryServiceProvider = Provider<InvoiceHistoryService>((ref) {
  ref.watch(currentUserProvider);
  return InvoiceHistoryService();
});

final invoiceHistoryProvider = StreamProvider<List<InvoiceRecord>>((ref) {
  final service = ref.watch(invoiceHistoryServiceProvider);
  return service.watchAll();
});

final historyEditorDocumentProvider = StateProvider<GeneratedQuotation?>((ref) {
  return null;
});
