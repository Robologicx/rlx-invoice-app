import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/models/erp_models.dart';
import '../../../database/local_database.dart';

class InvoiceHistoryService {
  Box<Map>? get _box {
    if (!Hive.isBoxOpen(LocalDatabase.invoicesBox)) {
      return null;
    }
    return Hive.box<Map>(LocalDatabase.invoicesBox);
  }

  Future<void> save(GeneratedQuotation quotation) async {
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

    final box = _box;
    if (box == null) {
      return;
    }

    await box.put(record.id, record.toMap());
  }

  List<InvoiceRecord> all() {
    final box = _box;
    if (box == null) {
      return const [];
    }

    return box.values.map((value) => InvoiceRecord.fromMap(value)).toList()
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
  }

  Stream<List<InvoiceRecord>> watchAll() async* {
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

  Future<void> deleteRecord(String id) async {
    final box = _box;
    if (box == null) {
      return;
    }
    await box.delete(id);
  }

  Future<void> clearAll() async {
    final box = _box;
    if (box == null) {
      return;
    }
    await box.clear();
  }
}

final invoiceHistoryServiceProvider = Provider<InvoiceHistoryService>((ref) {
  return InvoiceHistoryService();
});

final invoiceHistoryProvider = StreamProvider<List<InvoiceRecord>>((ref) {
  final service = ref.watch(invoiceHistoryServiceProvider);
  return service.watchAll();
});

final historyEditorDocumentProvider = StateProvider<GeneratedQuotation?>((ref) {
  return null;
});
