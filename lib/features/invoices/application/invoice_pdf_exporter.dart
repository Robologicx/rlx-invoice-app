import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/models/erp_models.dart';
import '../../../database/local_database.dart';

const _invoiceBusinessDetailsSettingsKey = 'invoice_business_details';

String? _activeUserId() => FirebaseAuth.instance.currentUser?.uid;

String? _scopedSettingsKey(String key) {
  final userId = _activeUserId();
  if (userId == null || userId.isEmpty) {
    return null;
  }
  return '$userId::$key';
}

/// Generates and previews a PDF from a [GeneratedQuotation].
/// If [uploadedTemplate] is provided and non-null, the filled template text
/// is embedded as an additional page in the PDF.
Future<void> previewInvoicePdf({
  required BuildContext context,
  required GeneratedQuotation quotation,
  UploadedTemplate? uploadedTemplate,
  Map<String, String>? placeholderValues,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _PdfPreviewPage(
        quotation: quotation,
        uploadedTemplate: uploadedTemplate,
        placeholderValues: placeholderValues,
      ),
      fullscreenDialog: true,
    ),
  );
}

Future<void> downloadInvoicePdf({
  required GeneratedQuotation quotation,
  UploadedTemplate? uploadedTemplate,
  Map<String, String>? placeholderValues,
}) async {
  final bytes = await buildInvoicePdfBytes(
    quotation: quotation,
    uploadedTemplate: uploadedTemplate,
    placeholderValues: placeholderValues,
  );

  await Printing.sharePdf(
    bytes: bytes,
    filename: '${quotation.quotationNo}.pdf',
  );
}

Future<Uint8List> buildInvoicePdfBytes({
  required GeneratedQuotation quotation,
  UploadedTemplate? uploadedTemplate,
  Map<String, String>? placeholderValues,
  PdfPageFormat pageFormat = PdfPageFormat.a4,
}) async {
  final doc = pw.Document();

  const primaryBlue = PdfColor.fromInt(0xFF1F4E8C);
  const accentRed = PdfColor.fromInt(0xFFE53935);
  const darkText = PdfColor.fromInt(0xFF202124);
  const muted = PdfColor.fromInt(0xFF9E9E9E);

  final baseFont = await PdfGoogleFonts.robotoRegular();
  final logoBytes = _loadInvoiceLogoBytes();
  final logoImage = logoBytes == null ? null : pw.MemoryImage(logoBytes);
  final businessDetails = _loadInvoiceBusinessDetails();
  final headerStyle = pw.TextStyle(
    fontSize: 20,
    fontWeight: pw.FontWeight.bold,
    color: primaryBlue,
  );
  final titleStyle = pw.TextStyle(
    fontSize: 14,
    fontWeight: pw.FontWeight.bold,
    color: darkText,
  );
  final invoiceHeadingStyle = pw.TextStyle(
    fontSize: 28,
    fontWeight: pw.FontWeight.bold,
    color: accentRed,
  );
  final bodyStyle = pw.TextStyle(fontSize: 10, color: darkText);
  final mutedStyle = pw.TextStyle(fontSize: 9, color: muted);
  final quantityDescription =
      (placeholderValues?['quantity_description'] ??
              quotation.placeholderValues['quantity_description'] ??
              '')
          .trim();
  final quantityLabel =
      (placeholderValues?['quantity_label'] ??
              quotation.placeholderValues['quantity_label'] ??
              '')
          .trim();
  final documentNumber = quotation.isInvoice && quotation.invoiceNo.isNotEmpty
      ? quotation.invoiceNo
      : quotation.quotationNo;

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: pageFormat,
        theme: pw.ThemeData.withFont(base: baseFont),
        margin: const pw.EdgeInsets.all(36),
      ),
      build: (ctx) => [
        if (logoImage != null)
          pw.Center(
            child: pw.Container(
              width: 230,
              height: 95,
              margin: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(businessDetails['businessName']!, style: headerStyle),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Address: ${businessDetails['address']}',
                  style: mutedStyle,
                ),
                pw.Text(
                  'Phone: ${businessDetails['phone']}',
                  style: mutedStyle,
                ),
                pw.Text(
                  'Email: ${businessDetails['email']}',
                  style: mutedStyle,
                ),
                if ((businessDetails['website'] ?? '').trim().isNotEmpty)
                  pw.Text(
                    'Website: ${businessDetails['website']}',
                    style: mutedStyle,
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  quotation.isInvoice ? 'INVOICE' : 'QUOTATION',
                  style: invoiceHeadingStyle,
                ),
                pw.SizedBox(height: 5),
                pw.Text('No: $documentNumber', style: titleStyle),
                pw.Text(
                  '${quotation.generatedDate.day}/${quotation.generatedDate.month}/${quotation.generatedDate.year}',
                  style: mutedStyle,
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: primaryBlue, thickness: 1.2),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: primaryBlue, width: 0.8),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      quotation.isInvoice ? 'Invoice For' : 'Quotation For',
                      style: titleStyle,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(quotation.clientName, style: bodyStyle),
                    pw.Text(
                      '${quotation.category.label} - ${quotation.packageName}',
                      style: mutedStyle,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Prepared By', style: titleStyle),
                    pw.SizedBox(height: 4),
                    pw.Text('RLX Invoice Team', style: bodyStyle),
                    if (!quotation.isInvoice)
                      pw.Text(
                        'Valid until: ${_validUntil(quotation.generatedDate)}',
                        style: mutedStyle,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Table(
          border: pw.TableBorder(
            top: pw.BorderSide(color: primaryBlue, width: 0.8),
            bottom: pw.BorderSide(color: primaryBlue, width: 0.8),
            left: pw.BorderSide(color: primaryBlue, width: 0.8),
            right: pw.BorderSide(color: primaryBlue, width: 0.8),
            horizontalInside: pw.BorderSide(color: muted, width: 0.4),
            verticalInside: pw.BorderSide(color: muted, width: 0.4),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(3.8),
            1: const pw.FlexColumnWidth(1.4),
            2: const pw.FlexColumnWidth(1.8),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: primaryBlue),
              children: [
                _cell(
                  'DESCRIPTION',
                  pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  align: pw.Alignment.centerLeft,
                ),
                _cell(
                  'QTY',
                  pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                _cell(
                  'UNIT PRICE',
                  pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  align: pw.Alignment.centerRight,
                ),
                _cell(
                  'TOTAL',
                  pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  align: pw.Alignment.centerRight,
                ),
              ],
            ),
            ...quotation.lineItems.map(
              (item) => pw.TableRow(
                children: [
                  _cell(
                    _lineItemDescription(
                      quotation,
                      item,
                      quantityLabel: quantityLabel,
                      quantityDescription: quantityDescription,
                    ),
                    bodyStyle,
                    align: pw.Alignment.centerLeft,
                  ),
                  _cell(
                    '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unit}',
                    bodyStyle,
                  ),
                  _cell(
                    'PKR ${_fmt(item.unitPrice)}',
                    bodyStyle,
                    align: pw.Alignment.centerRight,
                  ),
                  _cell(
                    'PKR ${_fmt(item.total)}',
                    bodyStyle,
                    align: pw.Alignment.centerRight,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        if (quotation.discountPercent > 0) ...[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Subtotal: PKR ${_fmt(quotation.subtotal)}',
                    style: bodyStyle,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Discount: - PKR ${_fmt(quotation.discountAmount)}',
                    style: bodyStyle,
                  ),
                  pw.SizedBox(height: 4),
                ],
              ),
            ],
          ),
        ],
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: pw.BoxDecoration(
                color: primaryBlue,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Text(
                'Grand Total: PKR ${_fmt(quotation.grandTotal)}',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ],
        ),
        if (quotation.isInvoice) ...[
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Payment Received: PKR ${_fmt(quotation.paymentReceived)}',
                    style: bodyStyle,
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Remaining Payment: PKR ${_fmt(quotation.remainingPayment)}',
                    style: titleStyle,
                  ),
                ],
              ),
            ],
          ),
        ],
        pw.SizedBox(height: 20),
        pw.Text('WARRANTY', style: mutedStyle),
        pw.SizedBox(height: 4),
        pw.Text(quotation.warranty, style: bodyStyle),
        pw.SizedBox(height: 16),
        if (!quotation.globalSections.any(
          (section) => section.title.toUpperCase().contains('TERM'),
        )) ...[
          pw.Text('TERMS & CONDITIONS', style: mutedStyle),
          pw.SizedBox(height: 4),
          ...quotation.terms.map(
            (t) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text('• $t', style: bodyStyle),
            ),
          ),
          pw.SizedBox(height: 16),
        ],
        ...quotation.globalSections.expand(
          (section) => [
            pw.Text(section.title.toUpperCase(), style: mutedStyle),
            pw.SizedBox(height: 4),
            ...section.items.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text('• $item', style: bodyStyle),
              ),
            ),
            pw.SizedBox(height: 12),
          ],
        ),
      ],
    ),
  );

  if (uploadedTemplate != null && placeholderValues != null) {
    final rendered = uploadedTemplate.render(placeholderValues);
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          theme: pw.ThemeData.withFont(base: baseFont),
          margin: const pw.EdgeInsets.all(36),
        ),
        build: (ctx) => [
          pw.Text('UPLOADED TEMPLATE — FILLED', style: mutedStyle),
          pw.SizedBox(height: 8),
          pw.Divider(color: primaryBlue, thickness: 1),
          pw.SizedBox(height: 10),
          pw.Text(rendered, style: bodyStyle),
        ],
      ),
    );
  }

  return doc.save();
}

pw.Widget _cell(
  String text,
  pw.TextStyle style, {
  pw.Alignment align = pw.Alignment.center,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
  child: pw.Align(
    alignment: align,
    child: pw.Text(text, style: style),
  ),
);

String _lineItemDescription(
  GeneratedQuotation quotation,
  QuotationLine item, {
  String quantityLabel = '',
  String quantityDescription = '',
}) {
  final normalizedQtyLabel = quantityLabel.trim().toLowerCase();
  final isQuantityLine =
      normalizedQtyLabel.isNotEmpty &&
      item.name.trim().toLowerCase() == normalizedQtyLabel;
  if (isQuantityLine && quantityDescription.trim().isNotEmpty) {
    return '${item.name}\n${quantityDescription.trim()}';
  }

  final isFenceHardware = item.name.toLowerCase() == 'fence hardware';
  if (quotation.category != ServiceCategory.electricFence || !isFenceHardware) {
    return item.name;
  }

  return '''${item.name}
Electric Fence Specification (2 year warranty)
- Lifetime after-sale service
- 2-Year Spring & Jurassic Warranty.
1. Fence Wire Inter-Line Distance is 04 inches
2. Aluminum Rust Proof Solid Wires 1.6 mm Dia (Life Time Warrenty)
3. Stainless Steel Square Tube (Pole) 1.1/09, Rust Proof.
4. No of Wires are 08
5. Middle Insulators (Jurasick)
6. Tensioner Insulators
7. Spring Insulators
8. HT Wire
9. Metal Enclosure for Energizer
10. Warning Sign Plate''';
}

String _fmt(double value) => value
    .toStringAsFixed(0)
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

String _validUntil(DateTime date) {
  final next = date.add(const Duration(days: 3));
  return '${next.day}/${next.month}/${next.year}';
}

Uint8List? _loadInvoiceLogoBytes() {
  if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
    return null;
  }
  final scopedKey = _scopedSettingsKey('invoice_logo_base64');
  if (scopedKey == null) {
    return null;
  }
  final saved = Hive.box(LocalDatabase.appSettingsBox).get(scopedKey);
  if (saved is Uint8List && saved.isNotEmpty) {
    return _isPdfSupportedImageBytes(saved) ? saved : null;
  }
  if (saved is! String || saved.isEmpty) {
    return null;
  }
  try {
    final decoded = base64Decode(saved);
    return _isPdfSupportedImageBytes(decoded) ? decoded : null;
  } catch (_) {
    return null;
  }
}

Map<String, String> _loadInvoiceBusinessDetails() {
  const fallback = <String, String>{
    'businessName': 'RLX Invoice',
    'address': 'Near NBP bank, Hussani Chowk, Bahawalpur',
    'phone': '0301-8777220',
    'email': 'info.robologicx@gmail.com',
    'website': 'www.robologicx.org',
  };

  if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
    return fallback;
  }
  final scopedKey = _scopedSettingsKey(_invoiceBusinessDetailsSettingsKey);
  if (scopedKey == null) {
    return fallback;
  }
  final saved = Hive.box(LocalDatabase.appSettingsBox).get(scopedKey);
  if (saved is! Map) {
    return fallback;
  }

  return {
    'businessName':
        (saved['businessName'] as String?)?.trim().isNotEmpty == true
        ? (saved['businessName'] as String).trim()
        : fallback['businessName']!,
    'address': (saved['address'] as String?)?.trim().isNotEmpty == true
        ? (saved['address'] as String).trim()
        : fallback['address']!,
    'phone': (saved['phone'] as String?)?.trim().isNotEmpty == true
        ? (saved['phone'] as String).trim()
        : fallback['phone']!,
    'email': (saved['email'] as String?)?.trim().isNotEmpty == true
        ? (saved['email'] as String).trim()
        : fallback['email']!,
    'website': (saved['website'] as String?)?.trim() ?? fallback['website']!,
  };
}

bool _isPdfSupportedImageBytes(Uint8List bytes) {
  if (bytes.length < 4) {
    return false;
  }

  final isPng =
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A;
  if (isPng) {
    return true;
  }

  final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
  return isJpeg;
}

class _PdfPreviewPage extends StatelessWidget {
  const _PdfPreviewPage({
    required this.quotation,
    this.uploadedTemplate,
    this.placeholderValues,
  });

  final GeneratedQuotation quotation;
  final UploadedTemplate? uploadedTemplate;
  final Map<String, String>? placeholderValues;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('PDF Preview — ${quotation.quotationNo}')),
      body: PdfPreview(
        build: (format) => buildInvoicePdfBytes(
          quotation: quotation,
          uploadedTemplate: uploadedTemplate,
          placeholderValues: placeholderValues,
          pageFormat: format,
        ),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: '${quotation.quotationNo}.pdf',
      ),
    );
  }
}
