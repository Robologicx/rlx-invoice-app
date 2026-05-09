import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/erp_models.dart';

class ParsedPrompt {
  const ParsedPrompt({
    required this.category,
    required this.quantity,
    required this.packageHint,
    required this.systemHint,
    required this.clientName,
    required this.wantsInvoice,
  });

  final ServiceCategory? category;
  final double? quantity;
  final String packageHint;
  final String systemHint;
  final String clientName;
  final bool wantsInvoice;
}

class PromptParser {
  ParsedPrompt parse(String prompt) {
    final input = prompt.toLowerCase();
    final category = _detectCategory(input);
    final quantity = _extractQuantity(input);

    return ParsedPrompt(
      category: category,
      quantity: quantity,
      packageHint: _extractPackageHint(input),
      systemHint: _extractSystemHint(input),
      clientName: _extractClientName(prompt),
      wantsInvoice: _detectInvoiceIntent(input),
    );
  }

  bool _detectInvoiceIntent(String input) {
    return input.contains('invoice') ||
        input.contains('bill') ||
        input.contains('tax invoice') ||
        input.contains('generate invoice') ||
        input.contains('make invoice');
  }

  ServiceCategory? _detectCategory(String input) {
    if (input.contains('fence') ||
        input.contains('electric fence') ||
        input.contains('nemtek') ||
        input.contains('tonger')) {
      return ServiceCategory.electricFence;
    }
    if (input.contains('solar') ||
        input.contains('hybrid') ||
        input.contains('panel') ||
        input.contains('inverter')) {
      return ServiceCategory.solar;
    }
    if (input.contains('cctv') || input.contains('camera')) {
      return ServiceCategory.cctv;
    }
    if (input.contains('gate') ||
        input.contains('sliding') ||
        input.contains('swing')) {
      return ServiceCategory.smartGate;
    }
    if (input.contains('smart home') ||
        (input.contains('automation') && !input.contains('gate')) ||
        input.contains('voice assistant')) {
      return ServiceCategory.smartHome;
    }
    if (input.contains('robot') ||
        input.contains('plc') ||
        input.contains('servo')) {
      return ServiceCategory.robotics;
    }
    if (input.contains('network') ||
        input.contains('wifi') ||
        input.contains('cat6') ||
        input.contains('router') ||
        input.contains('switch')) {
      return ServiceCategory.networking;
    }
    if (input.contains('maintenance') ||
        input.contains('service visit') ||
        input.contains('amc') ||
        input.contains('repair')) {
      return ServiceCategory.maintenance;
    }
    return null;
  }

  double? _extractQuantity(String input) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*(feet|foot|ft|camera|cameras|kw|kva|visit|visits)?',
    ).firstMatch(input);
    return double.tryParse(match?.group(1) ?? '');
  }

  String _extractPackageHint(String input) {
    if (input.contains('8kw')) return '8KW';
    if (input.contains('5kw')) return '5KW';
    if (input.contains('hybrid')) return 'Hybrid';
    if (input.contains('5 camera')) return '5 Camera';
    if (input.contains('4 camera')) return '4 Camera';
    if (input.contains('industrial')) return 'Industrial';
    if (input.contains('office')) return 'Office';
    if (input.contains('standard maintenance')) return 'Standard Maintenance';
    if (input.contains('nemtek')) return 'Nemtek';
    if (input.contains('tonger')) return 'Tonger';
    return '';
  }

  String _extractSystemHint(String input) {
    if (input.contains('nemtek')) return 'Nemtek';
    if (input.contains('tonger')) return 'Tonger / Chinese';
    if (input.contains('hybrid')) return 'Hybrid';
    if (input.contains('sliding')) return 'Sliding';
    if (input.contains('swing')) return 'Swing';
    if (input.contains('italian')) return 'Italian';
    if (input.contains('heavy duty')) return 'Heavy Duty Industrial';
    return '';
  }

  String _extractClientName(String prompt) {
    final original = prompt.trim();
    final match = RegExp(
      r'\bfor\s+(.+?)(?:\s+with\b|\s+using\b|\s+package\b|\s+invoice\b|\s+quotation\b|$)',
      caseSensitive: false,
    ).firstMatch(original);

    if (match == null) {
      return '';
    }

    final value = match.group(1)?.trim() ?? '';
    if (value.isEmpty) {
      return '';
    }

    return value
        .replaceAll(RegExp(r'^(a|an|the)\s+', caseSensitive: false), '')
        .trim();
  }
}

final promptParserProvider = Provider<PromptParser>((ref) => PromptParser());
