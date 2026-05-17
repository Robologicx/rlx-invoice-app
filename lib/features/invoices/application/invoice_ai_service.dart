import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hive/hive.dart';
import 'package:universal_html/html.dart' as html;

import '../../../ai/prompt_parser.dart';
import '../../../core/models/erp_models.dart';
import '../../../database/local_database.dart';

const _geminiApiKeySettingKey = 'gemini_api_key';

String? _activeUserId() => FirebaseAuth.instance.currentUser?.uid;

String? _scopedApiKeySetting() {
  final userId = _activeUserId();
  if (userId == null || userId.isEmpty) {
    return null;
  }
  return '$userId::$_geminiApiKeySettingKey';
}

class InvoiceAiPromptResult {
  const InvoiceAiPromptResult({
    required this.prompt,
    required this.usedOnlineAi,
    required this.status,
  });

  final ParsedPrompt prompt;
  final bool usedOnlineAi;
  final String status;

  bool get usedOfflineFallback => !usedOnlineAi;
}

class InvoiceAiService {
  InvoiceAiService({required PromptParser promptParser, String? apiKey})
    : _promptParser = promptParser,
      _bootstrapApiKey = apiKey ?? '';

  final PromptParser _promptParser;
  final String _bootstrapApiKey;

  String get _resolvedApiKey {
    final bootstrap = _bootstrapApiKey.trim();
    if (bootstrap.isNotEmpty) {
      return bootstrap;
    }
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return '';
    }
    final scopedKey = _scopedApiKeySetting();
    if (scopedKey == null) {
      return '';
    }
    final raw = Hive.box(LocalDatabase.appSettingsBox).get(scopedKey);
    return raw is String ? raw.trim() : '';
  }

  bool get isEnabled => _resolvedApiKey.isNotEmpty;

  Future<ParsedPrompt> interpretPrompt({
    required String prompt,
    required List<ServiceProfile> profiles,
  }) async {
    final apiKey = _resolvedApiKey;
    if (apiKey.isEmpty) {
      throw StateError('GEMINI_API_KEY is not configured.');
    }

    final categories = ServiceCategory.values
        .map((item) => item.name)
        .join(', ');
    final profileSummary = profiles
        .map((profile) => '- ${profile.title}: ${profile.template.fileName}')
        .join('\n');

    final instruction =
        '''
You are helping RLX Invoice generate structured invoice data from a natural language prompt.
Return only a JSON object with these exact keys:
{
  "category": one of [$categories] or null,
  "quantity": number or null,
  "packageHint": string,
  "systemHint": string,
  "clientName": string,
  "wantsInvoice": boolean
}

Rules:
- Use null when the prompt does not clearly specify a value.
- Set wantsInvoice to true when the user asks to make, create, generate, or prepare an invoice.
- packageHint and systemHint should be short and useful for matching the right business template.
- clientName should be the customer name if the prompt mentions one.
- Do not include any markdown, code fences, or explanations.

Available templates:
$profileSummary
''';

    GenerateContentResponse? response;
    Object? lastError;
    // Try stable model IDs first to avoid "model not found" errors.
    const candidateModels = [
      'gemini-1.5-flash',
      'gemini-1.5-flash-8b',
      'gemini-2.0-flash',
    ];

    for (final modelName in candidateModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            temperature: 0.2,
            maxOutputTokens: 512,
          ),
        );
        response = await model.generateContent([
          Content.text('$instruction\nPrompt: $prompt'),
        ]);
        break;
      } catch (error) {
        lastError = error;
      }
    }

    if (response == null) {
      throw StateError('Gemini request failed: ${_compactError(lastError)}');
    }

    final rawText = response.text;
    if (rawText == null || rawText.trim().isEmpty) {
      throw StateError('AI model returned an empty response.');
    }

    final decoded = _decodeJsonObject(rawText);
    return ParsedPrompt(
      category: _parseCategory(decoded['category']),
      quantity: _parseQuantity(decoded['quantity']),
      packageHint: decoded['packageHint']?.toString().trim() ?? '',
      systemHint: decoded['systemHint']?.toString().trim() ?? '',
      clientName: decoded['clientName']?.toString().trim() ?? '',
      wantsInvoice: decoded['wantsInvoice'] == true,
    );
  }

  Future<InvoiceAiPromptResult> interpretPromptWithFallback({
    required String prompt,
    required List<ServiceProfile> profiles,
  }) async {
    if (!isEnabled) {
      return InvoiceAiPromptResult(
        prompt: _promptParser.parse(prompt),
        usedOnlineAi: false,
        status: 'offline (no Gemini key)',
      );
    }

    final hasInternet = await _isInternetAvailable();
    if (!hasInternet) {
      return InvoiceAiPromptResult(
        prompt: _promptParser.parse(prompt),
        usedOnlineAi: false,
        status: 'offline (no internet)',
      );
    }

    try {
      return InvoiceAiPromptResult(
        prompt: await interpretPrompt(prompt: prompt, profiles: profiles),
        usedOnlineAi: true,
        status: 'online Gemini',
      );
    } catch (error) {
      final reason = _compactError(error);
      return InvoiceAiPromptResult(
        prompt: _promptParser.parse(prompt),
        usedOnlineAi: false,
        status: 'offline fallback (Gemini: $reason)',
      );
    }
  }

  String _compactError(Object? error) {
    if (error == null) {
      return 'unknown error';
    }
    final raw = error.toString().replaceAll('\n', ' ').trim();
    if (raw.length <= 60) {
      return raw;
    }
    return '${raw.substring(0, 60)}...';
  }

  Future<bool> _isInternetAvailable() async {
    if (kIsWeb) {
      return html.window.navigator.onLine ?? false;
    }
    return true;
  }

  Map<String, dynamic> _decodeJsonObject(String rawText) {
    final trimmed = rawText.trim();
    final fenced = trimmed.replaceAll(
      RegExp(r'^```(?:json)?\s*|\s*```$', multiLine: true),
      '',
    );
    final jsonText = fenced.contains('{') ? fenced : trimmed;

    final firstBrace = jsonText.indexOf('{');
    final lastBrace = jsonText.lastIndexOf('}');
    if (firstBrace == -1 || lastBrace == -1 || lastBrace <= firstBrace) {
      throw const FormatException('AI response is not valid JSON.');
    }

    final body = jsonText.substring(firstBrace, lastBrace + 1);
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('AI response JSON must be an object.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  ServiceCategory? _parseCategory(dynamic value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();
    for (final category in ServiceCategory.values) {
      if (category.name == normalized ||
          category.label.toLowerCase() == normalized.toLowerCase()) {
        return category;
      }
    }
    return null;
  }

  double? _parseQuantity(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}

class GeminiApiKeyController extends StateNotifier<String> {
  GeminiApiKeyController() : super(_loadSavedKey());

  static String _loadSavedKey() {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return '';
    }
    final scopedKey = _scopedApiKeySetting();
    if (scopedKey == null) {
      return '';
    }
    final raw = Hive.box(LocalDatabase.appSettingsBox).get(scopedKey);
    return raw is String ? raw : '';
  }

  void setKey(String value) {
    final key = value.trim();
    state = key;
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return;
    }
    final scopedKey = _scopedApiKeySetting();
    if (scopedKey == null) {
      return;
    }
    Hive.box(LocalDatabase.appSettingsBox).put(scopedKey, key);
  }

  void clearKey() {
    state = '';
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return;
    }
    final scopedKey = _scopedApiKeySetting();
    if (scopedKey == null) {
      return;
    }
    Hive.box(LocalDatabase.appSettingsBox).delete(scopedKey);
  }
}

final geminiApiKeyProvider =
    StateNotifierProvider<GeminiApiKeyController, String>((ref) {
      return GeminiApiKeyController();
    });

final invoiceAiServiceProvider = Provider<InvoiceAiService>((ref) {
  final savedKey = ref.watch(geminiApiKeyProvider).trim();
  const envKey = String.fromEnvironment('GEMINI_API_KEY');
  final resolvedKey = savedKey.isNotEmpty ? savedKey : envKey;
  return InvoiceAiService(
    promptParser: ref.watch(promptParserProvider),
    apiKey: resolvedKey,
  );
});
