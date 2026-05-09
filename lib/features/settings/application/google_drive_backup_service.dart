import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../../database/local_database.dart';

class LocalBackupService {
  static const _backupFileName = 'rlx_invoice_backup.json';

  Future<String> exportBackupFile() async {
    final payload = _buildBackupPayload();
    final rawJson = const JsonEncoder.withIndent('  ').convert(payload);
    final fileName =
        'rlx_invoice_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final bytes = Uint8List.fromList(utf8.encode(rawJson));

    if (kIsWeb) {
      _downloadBackupInBrowser(bytes, fileName);
      return 'Backup file downloaded in browser.';
    }

    String? selectedPath;
    try {
      selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup File',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
      );
    } on UnimplementedError {
      selectedPath = null;
    }

    if (selectedPath != null && selectedPath.isNotEmpty) {
      final file = File(selectedPath);
      await file.writeAsString(rawJson, flush: true);
      return 'Backup file saved: ${file.path}';
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final file = File('${docsDir.path}/$_backupFileName');
    await file.writeAsString(rawJson, flush: true);
    return 'Backup saved in app storage: ${file.path}';
  }

  void _downloadBackupInBrowser(Uint8List bytes, String fileName) {
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  Future<String> restoreFromBackupFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null) {
      throw Exception('No backup file selected.');
    }

    String rawJson;
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      rawJson = utf8.decode(file.bytes!);
    } else if (file.path != null && file.path!.isNotEmpty) {
      rawJson = await File(file.path!).readAsString();
    } else {
      throw Exception('Unable to read selected backup file.');
    }

    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw Exception('Backup file format is invalid.');
    }

    await _restoreFromPayload(_toStringDynamicMap(decoded));
    return 'Backup restored successfully from file.';
  }

  Map<String, dynamic> _toStringDynamicMap(Map source) {
    final output = <String, dynamic>{};
    for (final entry in source.entries) {
      output[entry.key.toString()] = entry.value;
    }
    return output;
  }

  Map<String, dynamic> _buildBackupPayload() {
    return {
      'schemaVersion': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'boxes': {
        LocalDatabase.templatesBox: _boxToJsonMap(
          Hive.box<Map>(LocalDatabase.templatesBox),
        ),
        LocalDatabase.invoicesBox: _boxToJsonMap(
          Hive.box<Map>(LocalDatabase.invoicesBox),
        ),
        LocalDatabase.productsBox: _boxToJsonMap(
          Hive.box<Map>(LocalDatabase.productsBox),
        ),
        LocalDatabase.appSettingsBox: _boxToJsonMap(
          Hive.box(LocalDatabase.appSettingsBox),
        ),
      },
    };
  }

  Future<void> _restoreFromPayload(Map<String, dynamic> payload) async {
    final boxes = payload['boxes'];
    if (boxes is! Map) {
      throw Exception('Backup does not contain valid box data.');
    }

    await _restoreMapBox(
      Hive.box<Map>(LocalDatabase.templatesBox),
      boxes,
      LocalDatabase.templatesBox,
    );
    await _restoreMapBox(
      Hive.box<Map>(LocalDatabase.invoicesBox),
      boxes,
      LocalDatabase.invoicesBox,
    );
    await _restoreMapBox(
      Hive.box<Map>(LocalDatabase.productsBox),
      boxes,
      LocalDatabase.productsBox,
    );
    await _restoreDynamicBox(
      Hive.box(LocalDatabase.appSettingsBox),
      boxes,
      LocalDatabase.appSettingsBox,
    );
  }

  Future<void> _restoreMapBox(Box<Map> box, Map boxes, String key) async {
    final raw = boxes[key];
    if (raw is! Map) {
      return;
    }

    await box.clear();
    for (final entry in raw.entries) {
      final decoded = _decodeValue(entry.value);
      if (decoded is Map) {
        await box.put(entry.key, Map<dynamic, dynamic>.from(decoded));
      }
    }
  }

  Future<void> _restoreDynamicBox(Box box, Map boxes, String key) async {
    final raw = boxes[key];
    if (raw is! Map) {
      return;
    }

    final restored = <dynamic, dynamic>{};
    for (final entry in raw.entries) {
      restored[entry.key] = _decodeValue(entry.value);
    }

    await box.clear();
    await box.putAll(restored);
  }

  Map<String, dynamic> _boxToJsonMap(Box box) {
    final output = <String, dynamic>{};
    for (final key in box.keys) {
      output[key.toString()] = _encodeValue(box.get(key));
    }
    return output;
  }

  dynamic _encodeValue(dynamic value) {
    if (value is Uint8List) {
      return {'__type': 'bytes', 'data': base64Encode(value)};
    }
    if (value is List) {
      return value.map(_encodeValue).toList();
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _encodeValue(entry.value),
      };
    }
    return value;
  }

  dynamic _decodeValue(dynamic value) {
    if (value is Map && value['__type'] == 'bytes' && value['data'] is String) {
      return base64Decode(value['data'] as String);
    }
    if (value is List) {
      return value.map(_decodeValue).toList();
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _decodeValue(entry.value),
      };
    }
    return value;
  }
}

final localBackupServiceProvider = Provider<LocalBackupService>(
  (ref) => LocalBackupService(),
);
