import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:hive/hive.dart';
import 'package:xml/xml.dart';

import '../../../core/models/erp_models.dart';
import '../../../database/local_database.dart';
import 'template_engine.dart';

/// Provider that holds the currently uploaded template (null = none uploaded).
final uploadedTemplateProvider = StateProvider<UploadedTemplate?>(
  (ref) => null,
);

/// Service that handles file picking and text extraction.
class TemplateUploadService {
  static const _supportedExtensions = [
    'html',
    'htm',
    'txt',
    'md',
    'csv',
    'pdf',
    'docx',
    'xlsx',
    'xls',
    'png',
    'jpg',
    'jpeg',
    'webp',
  ];

  static const _ignoredLineKeywords = [
    'client',
    'quotation',
    'date',
    'subtotal',
    'grand total',
    'package',
    'template',
    'warranty',
    'term',
    'scope',
    'support',
  ];

  /// Opens a file picker and returns an [UploadedTemplate] on success.
  /// Returns `null` if the user cancels or the file cannot be read.
  Future<UploadedTemplate?> pickTemplate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _supportedExtensions,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return null;

    final ext = (file.extension ?? 'txt').toLowerCase();
    final content = _extractContent(bytes, ext, file.name);
    final engine = TemplateEngine();
    final placeholders = engine.extractPlaceholders(content);

    await Hive.box<Map>(LocalDatabase.templatesBox).put(file.name, {
      'fileName': file.name,
      'fileExtension': ext,
      'rawContent': content,
      'placeholders': placeholders.toList(),
      'uploadedAt': DateTime.now().toIso8601String(),
    });

    return UploadedTemplate(
      fileName: file.name,
      fileExtension: ext,
      rawContent: content,
      placeholders: placeholders,
    );
  }

  String _extractContent(List<int> bytes, String ext, String fileName) {
    switch (ext) {
      case 'docx':
        return _extractDocx(bytes, fileName);
      case 'xlsx':
      case 'xls':
        return _extractExcel(bytes, fileName);
      case 'pdf':
        return _fallbackText(
          fileName,
          'PDF imported. Add placeholders manually (for example {{client_name}}) in template editor when needed.',
        );
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
        return _fallbackText(
          fileName,
          'Image imported. OCR mapping can be added later; placeholders can be configured manually now.',
        );
      default:
        return String.fromCharCodes(bytes);
    }
  }

  String _extractDocx(List<int> bytes, String fileName) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final entry = archive.files.firstWhere(
        (item) => item.name == 'word/document.xml',
      );
      final xml = XmlDocument.parse(String.fromCharCodes(entry.content));
      final texts = xml
          .findAllElements('w:t')
          .map((node) => node.innerText)
          .where((value) => value.trim().isNotEmpty)
          .toList();
      if (texts.isEmpty) {
        return _fallbackText(
          fileName,
          'DOCX imported but text blocks were empty.',
        );
      }
      return texts.join('\n');
    } catch (_) {
      return _fallbackText(
        fileName,
        'DOCX parsing failed; import completed in raw mode.',
      );
    }
  }

  String _extractExcel(List<int> bytes, String fileName) {
    try {
      final excel = Excel.decodeBytes(bytes);
      final buffer = StringBuffer();
      for (final sheet in excel.tables.entries) {
        buffer.writeln('[Sheet] ${sheet.key}');
        for (final row in sheet.value.rows) {
          final line = row
              .map((cell) => cell?.value?.toString() ?? '')
              .where((value) => value.isNotEmpty)
              .join(' | ');
          if (line.isNotEmpty) {
            buffer.writeln(line);
          }
        }
        buffer.writeln('');
      }
      final text = buffer.toString().trim();
      return text.isEmpty
          ? _fallbackText(
              fileName,
              'Excel imported but readable cells were empty.',
            )
          : text;
    } catch (_) {
      return _fallbackText(
        fileName,
        'Excel parsing failed; import completed in raw mode.',
      );
    }
  }

  List<ServiceProduct> extractServiceProducts(
    UploadedTemplate template,
    String fallbackUnit,
  ) {
    final products = <ServiceProduct>[];
    for (final line in _candidateLines(template.rawContent)) {
      final parsed = _parseLineItem(line);
      if (parsed == null || parsed.item.price <= 0) {
        continue;
      }
      if (parsed.optional) {
        continue;
      }
      products.add(
        ServiceProduct(
          name: parsed.item.name,
          quantity: parsed.item.quantity,
          unitPrice: parsed.item.price,
          unit: parsed.item.unit.isEmpty ? fallbackUnit : parsed.item.unit,
        ),
      );
    }
    return products;
  }

  List<OptionalItem> extractOptionalItems(UploadedTemplate template) {
    final optionals = <OptionalItem>[];
    for (final line in _candidateLines(template.rawContent)) {
      final parsed = _parseLineItem(line);
      if (parsed == null || parsed.item.price <= 0 || !parsed.optional) {
        continue;
      }
      optionals.add(
        OptionalItem(
          id: 'imported_optional_${optionals.length}_${DateTime.now().microsecondsSinceEpoch}',
          name: parsed.item.name,
          price: parsed.item.price,
        ),
      );
    }
    return optionals;
  }

  Iterable<String> _candidateLines(String rawContent) sync* {
    for (final rawLine in rawContent.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.contains('{{')) {
        continue;
      }
      final lower = line.toLowerCase();
      if (_ignoredLineKeywords.any(lower.contains)) {
        continue;
      }
      yield line.replaceFirst(RegExp(r'^[\-•*\da-zA-Z]+[\)\.]?\s*'), '');
    }
  }

  _ParsedTemplateItem? _parseLineItem(String line) {
    final cleaned = line.replaceAll('PKR', '').replaceAll(',', ' ').trim();
    final parts = cleaned
        .split(RegExp(r'\s*[|\t]\s*'))
        .where((item) => item.trim().isNotEmpty)
        .toList();

    if (parts.length >= 4) {
      final name = parts.first.trim();
      final quantity = _extractNumber(parts[1]) ?? 1;
      final unit = parts[2].trim();
      final price = _extractNumber(parts.last) ?? 0;
      if (name.isEmpty || price <= 0) {
        return null;
      }
      return _ParsedTemplateItem(
        item: _ImportedLineItem(
          name: name,
          quantity: quantity,
          unit: unit,
          price: price,
        ),
        optional: _looksOptional(name),
      );
    }

    final matches = RegExp(r'(\d+(?:\.\d+)?)').allMatches(cleaned).toList();
    if (matches.isEmpty) {
      return null;
    }
    final price = double.tryParse(matches.last.group(0) ?? '') ?? 0;
    if (price <= 0) {
      return null;
    }
    final quantity = matches.length > 1
        ? (double.tryParse(matches.first.group(0) ?? '') ?? 1.0)
        : 1.0;
    final name = cleaned
        .replaceAll(RegExp(r'\d+(?:\.\d+)?'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (name.length < 3) {
      return null;
    }

    final unitMatch = RegExp(
      r'\b(ft|feet|meter|mtr|m|pcs|piece|pieces|set|job|unit|camera|nos?)\b',
      caseSensitive: false,
    ).firstMatch(cleaned);

    return _ParsedTemplateItem(
      item: _ImportedLineItem(
        name: name,
        quantity: quantity,
        unit: unitMatch?.group(0) ?? 'unit',
        price: price,
      ),
      optional: _looksOptional(cleaned),
    );
  }

  bool _looksOptional(String line) {
    final lower = line.toLowerCase();
    return lower.contains('optional') ||
        lower.contains('extra') ||
        lower.contains('additional');
  }

  double? _extractNumber(String text) {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
    return double.tryParse(match?.group(0) ?? '');
  }

  String _fallbackText(String fileName, String message) {
    return 'Template File: $fileName\n$message';
  }
}

class _ImportedLineItem {
  const _ImportedLineItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.price,
  });

  final String name;
  final double quantity;
  final String unit;
  final double price;
}

class _ParsedTemplateItem {
  const _ParsedTemplateItem({required this.item, required this.optional});

  final _ImportedLineItem item;
  final bool optional;
}

final templateUploadServiceProvider = Provider<TemplateUploadService>(
  (_) => TemplateUploadService(),
);
