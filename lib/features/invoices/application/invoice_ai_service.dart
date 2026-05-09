import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../ai/prompt_parser.dart';
import '../../../core/models/erp_models.dart';

class InvoiceAiPromptResult {
  const InvoiceAiPromptResult({
    required this.prompt,
    required this.usedOnlineAi,
  });

  final ParsedPrompt prompt;
  final bool usedOnlineAi;

  bool get usedOfflineFallback => !usedOnlineAi;
}

class InvoiceAiService {
  InvoiceAiService({required PromptParser promptParser, String? apiKey})
    : _promptParser = promptParser,
      _apiKey = apiKey ?? '';

  final PromptParser _promptParser;
  final String _apiKey;

  bool get isEnabled => _apiKey.trim().isNotEmpty;

  Future<ParsedPrompt> interpretPrompt({
    required String prompt,
    required List<ServiceProfile> profiles,
  }) async {
    if (!isEnabled) {
      throw StateError('GEMINI_API_KEY is not configured.');
    }

    final model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        maxOutputTokens: 512,
      ),
    );

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

    final response = await model.generateContent([
      Content.text('$instruction\nPrompt: $prompt'),
    ]);

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
      );
    }

    try {
      return InvoiceAiPromptResult(
        prompt: await interpretPrompt(prompt: prompt, profiles: profiles),
        usedOnlineAi: true,
      );
    } catch (_) {
      return InvoiceAiPromptResult(
        prompt: _promptParser.parse(prompt),
        usedOnlineAi: false,
      );
    }
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

final invoiceAiServiceProvider = Provider<InvoiceAiService>((ref) {
  return InvoiceAiService(
    promptParser: ref.watch(promptParserProvider),
    apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
  );
});
