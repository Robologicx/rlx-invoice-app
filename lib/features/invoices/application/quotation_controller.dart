import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../ai/prompt_parser.dart';
import '../../../core/data/demo_data.dart';
import '../../../core/models/erp_models.dart';
import '../../../features/inventory/application/inventory_controller.dart';
import '../../../invoice_engine/service_rule_engine.dart';
import 'invoice_history_service.dart';
import 'template_engine.dart';

final templateEngineProvider = Provider<TemplateEngine>((ref) {
  return TemplateEngine();
});

final quotationControllerProvider =
    StateNotifierProvider<QuotationController, QuotationState>((ref) {
      final profiles = ref.watch(visibleServiceProfilesProvider);
      final engine = ref.watch(templateEngineProvider);
      final parser = ref.watch(promptParserProvider);
      final ruleEngine = ref.watch(serviceRuleEngineProvider);
      final historyService = ref.watch(invoiceHistoryServiceProvider);
      final invoicePolicySections = ref.watch(invoicePolicySectionsProvider);
      return QuotationController(
        ref: ref,
        profiles: profiles,
        templateEngine: engine,
        promptParser: parser,
        ruleEngine: ruleEngine,
        historyService: historyService,
        invoicePolicySections: invoicePolicySections,
      );
    });

final serviceRuleEngineProvider = Provider<ServiceRuleEngine>((ref) {
  return const ServiceRuleEngine();
});

class QuotationState {
  const QuotationState({
    required this.category,
    required this.selectedProfileId,
    required this.selectedPackageId,
    required this.clientName,
    required this.runningFeet,
    required this.systemType,
    required this.aiPrompt,
    required this.selectedOptionalIds,
    required this.excludedPackageProducts,
    required this.packageProductQuantities,
    required this.optionalItemQuantities,
    required this.manualProducts,
    this.generatedQuotation,
  });

  final ServiceCategory category;
  final String selectedProfileId;
  final String selectedPackageId;
  final String clientName;
  final String runningFeet;
  final String systemType;
  final String aiPrompt;
  final Set<String> selectedOptionalIds;
  final Set<String> excludedPackageProducts;
  final Map<String, double> packageProductQuantities;
  final Map<String, double> optionalItemQuantities;
  final List<QuotationLine> manualProducts;
  final GeneratedQuotation? generatedQuotation;

  QuotationState copyWith({
    ServiceCategory? category,
    String? selectedProfileId,
    String? selectedPackageId,
    String? clientName,
    String? runningFeet,
    String? systemType,
    String? aiPrompt,
    Set<String>? selectedOptionalIds,
    Set<String>? excludedPackageProducts,
    Map<String, double>? packageProductQuantities,
    Map<String, double>? optionalItemQuantities,
    List<QuotationLine>? manualProducts,
    GeneratedQuotation? generatedQuotation,
    bool clearGeneratedQuotation = false,
  }) {
    return QuotationState(
      category: category ?? this.category,
      selectedProfileId: selectedProfileId ?? this.selectedProfileId,
      selectedPackageId: selectedPackageId ?? this.selectedPackageId,
      clientName: clientName ?? this.clientName,
      runningFeet: runningFeet ?? this.runningFeet,
      systemType: systemType ?? this.systemType,
      aiPrompt: aiPrompt ?? this.aiPrompt,
      selectedOptionalIds: selectedOptionalIds ?? this.selectedOptionalIds,
      excludedPackageProducts:
          excludedPackageProducts ?? this.excludedPackageProducts,
      packageProductQuantities:
          packageProductQuantities ?? this.packageProductQuantities,
      optionalItemQuantities:
          optionalItemQuantities ?? this.optionalItemQuantities,
      manualProducts: manualProducts ?? this.manualProducts,
      generatedQuotation: clearGeneratedQuotation
          ? null
          : generatedQuotation ?? this.generatedQuotation,
    );
  }
}

class QuotationController extends StateNotifier<QuotationState> {
  QuotationController({
    required Ref ref,
    required List<ServiceProfile> profiles,
    required TemplateEngine templateEngine,
    required PromptParser promptParser,
    required ServiceRuleEngine ruleEngine,
    required InvoiceHistoryService historyService,
    required List<InvoicePolicySection> invoicePolicySections,
  }) : _profiles = profiles,
       _ref = ref,
       _templateEngine = templateEngine,
       _promptParser = promptParser,
       _ruleEngine = ruleEngine,
       _historyService = historyService,
       _invoicePolicySections = invoicePolicySections,
       super(
         QuotationState(
           category: profiles.first.category,
           selectedProfileId: profiles.first.template.id,
           selectedPackageId: profiles.first.packages.first.id,
           clientName: '',
           runningFeet: _defaultQuantityText(profiles.first.packages.first),
           systemType:
               profiles.first.packages.first.systemVariants.keys.firstOrNull ??
               '',
           aiPrompt: '',
           selectedOptionalIds: <String>{},
           excludedPackageProducts: <String>{},
           packageProductQuantities: const <String, double>{},
           optionalItemQuantities: const <String, double>{},
           manualProducts: const [],
         ),
       );

  final List<ServiceProfile> _profiles;
  final Ref _ref;
  final TemplateEngine _templateEngine;
  final PromptParser _promptParser;
  final ServiceRuleEngine _ruleEngine;
  final InvoiceHistoryService _historyService;
  final List<InvoicePolicySection> _invoicePolicySections;
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'PKR ',
    decimalDigits: 0,
  );
  final DateFormat _date = DateFormat('dd MMM yyyy');

  static String _defaultQuantityText(ServicePackage package) {
    final hasQtyInput =
        package.quantityLabel.isNotEmpty && package.rateRules.isNotEmpty;
    if (!hasQtyInput || package.defaultQuantity <= 0) {
      return '';
    }
    return package.defaultQuantity.truncateToDouble() == package.defaultQuantity
        ? package.defaultQuantity.toInt().toString()
        : package.defaultQuantity.toString();
  }

  List<ServiceProfile> get profiles => _profiles;

  void setCategory(ServiceCategory category) {
    final profile = _profiles.firstWhere((item) => item.category == category);
    final firstPackage = profile.packages.first;
    state = state.copyWith(
      category: category,
      selectedProfileId: profile.template.id,
      selectedPackageId: firstPackage.id,
      systemType: firstPackage.systemVariants.keys.firstOrNull ?? '',
      selectedOptionalIds: <String>{},
      excludedPackageProducts: <String>{},
      packageProductQuantities: const <String, double>{},
      optionalItemQuantities: const <String, double>{},
      manualProducts: const [],
      runningFeet: _defaultQuantityText(firstPackage),
      clearGeneratedQuotation: true,
    );
  }

  void setProfile(String profileId) {
    final profile = _selectedProfile(profileId);
    final firstPackage = profile.packages.first;
    state = state.copyWith(
      category: profile.category,
      selectedProfileId: profile.template.id,
      selectedPackageId: firstPackage.id,
      systemType: firstPackage.systemVariants.keys.firstOrNull ?? '',
      selectedOptionalIds: <String>{},
      excludedPackageProducts: <String>{},
      packageProductQuantities: const <String, double>{},
      optionalItemQuantities: const <String, double>{},
      manualProducts: const [],
      runningFeet: _defaultQuantityText(firstPackage),
      clearGeneratedQuotation: true,
    );
  }

  void setPackage(String packageId) {
    final profile = _selectedProfile(state.selectedProfileId);
    final selectedPackage = profile.packages.firstWhere(
      (item) => item.id == packageId,
    );
    state = state.copyWith(
      selectedPackageId: packageId,
      systemType: selectedPackage.systemVariants.keys.firstOrNull ?? '',
      selectedOptionalIds: <String>{},
      excludedPackageProducts: <String>{},
      packageProductQuantities: const <String, double>{},
      optionalItemQuantities: const <String, double>{},
      manualProducts: const [],
      runningFeet: _defaultQuantityText(selectedPackage),
      clearGeneratedQuotation: true,
    );
  }

  void updateClientName(String value) {
    state = state.copyWith(clientName: value, clearGeneratedQuotation: true);
  }

  void updateRunningFeet(String value) {
    state = state.copyWith(runningFeet: value, clearGeneratedQuotation: true);
  }

  void setSystemType(String value) {
    state = state.copyWith(systemType: value, clearGeneratedQuotation: true);
  }

  void updatePrompt(String value) {
    state = state.copyWith(aiPrompt: value);
  }

  void loadFromHistory(GeneratedQuotation document) {
    final profile = _profileFromDocument(document);
    final package = profile.packages.firstWhere(
      (item) => item.name == document.packageName,
      orElse: () => profile.packages.first,
    );

    final lineByName = {for (final item in document.lineItems) item.name: item};

    final packageQuantities = <String, double>{};
    final excludedProducts = <String>{};
    for (final product in package.products) {
      final line = lineByName[product.name];
      if (line == null || line.quantity <= 0) {
        excludedProducts.add(product.name);
      } else {
        packageQuantities[product.name] = line.quantity;
      }
    }

    final optionalSelected = <String>{};
    final optionalQuantities = <String, double>{};
    for (final optional in package.optionalItems) {
      final line = lineByName[optional.name];
      if (line != null && line.quantity > 0) {
        optionalSelected.add(optional.id);
        optionalQuantities[optional.id] = line.quantity;
      }
    }

    // Extract manual products - items that are not in the package
    final systemType = document.placeholderValues['system_type'] ?? '';
    final packageProductNames = {
      ...package.products.map((p) => p.name),
      ...package.optionalItems.map((o) => o.name),
      if (systemType.isNotEmpty) systemType, // Skip system type if present
    };
    final manualProducts = <QuotationLine>[];
    for (final line in document.lineItems) {
      if (!packageProductNames.contains(line.name)) {
        manualProducts.add(line);
      }
    }

    state = state.copyWith(
      category: document.category,
      selectedProfileId: profile.template.id,
      selectedPackageId: package.id,
      clientName: document.clientName,
      runningFeet:
          document.placeholderValues['running_feet'] ?? state.runningFeet,
      systemType: document.placeholderValues['system_type'] ?? '',
      aiPrompt: '',
      selectedOptionalIds: optionalSelected,
      excludedPackageProducts: excludedProducts,
      packageProductQuantities: packageQuantities,
      optionalItemQuantities: optionalQuantities,
      manualProducts: manualProducts,
      generatedQuotation: document,
    );
  }

  Future<GeneratedQuotation?> generateFromPrompt() async {
    return _generateFromParsedPrompt(_promptParser.parse(state.aiPrompt));
  }

  Future<GeneratedQuotation?> generateFromParsedPrompt(
    ParsedPrompt parsed,
  ) async {
    return _generateFromParsedPrompt(parsed);
  }

  Future<GeneratedQuotation?> _generateFromParsedPrompt(
    ParsedPrompt parsed,
  ) async {
    if (parsed.category != null) {
      setCategory(parsed.category!);
    }

    final profile = _selectedProfile(state.selectedProfileId);
    final matchedPackage = _matchPackage(profile, parsed.packageHint);
    if (matchedPackage != null &&
        matchedPackage.id != state.selectedPackageId) {
      setPackage(matchedPackage.id);
    }

    if (parsed.clientName.isNotEmpty) {
      updateClientName(parsed.clientName);
    }

    if (parsed.quantity != null) {
      final activePackage = profile.packages.firstWhere(
        (item) => item.id == state.selectedPackageId,
        orElse: () => profile.packages.first,
      );
      if (activePackage.quantityLabel.isNotEmpty &&
          activePackage.rateRules.isNotEmpty) {
        updateRunningFeet(parsed.quantity!.toStringAsFixed(0));
      }

      if (parsed.category == ServiceCategory.cctv) {
        final mapped = _ruleEngine.cctvMappedProducts(parsed.quantity!);
        await _generateMappedQuotation(mapped);
        if (parsed.wantsInvoice) {
          await convertToInvoice(paymentReceived: 0);
        }
        return state.generatedQuotation;
      }

      if (parsed.category == ServiceCategory.solar) {
        final mapped = _ruleEngine.solarMappedProducts(parsed.quantity!);
        await _generateMappedQuotation(mapped);
        if (parsed.wantsInvoice) {
          await convertToInvoice(paymentReceived: 0);
        }
        return state.generatedQuotation;
      }
    }

    if (parsed.systemHint.isNotEmpty) {
      final nextProfile = _selectedProfile(state.selectedProfileId);
      final nextPackage = nextProfile.packages.firstWhere(
        (item) => item.id == state.selectedPackageId,
      );
      final matchedSystem = _matchSystemType(nextPackage, parsed.systemHint);
      if (matchedSystem.isNotEmpty) {
        setSystemType(matchedSystem);
      }
    }

    await generateQuotation();
    if (parsed.wantsInvoice) {
      await convertToInvoice(paymentReceived: 0);
    }

    return state.generatedQuotation;
  }

  void toggleOptional(String optionalId) {
    final next = {...state.selectedOptionalIds};
    final nextQuantities = {...state.optionalItemQuantities};
    if (!next.add(optionalId)) {
      next.remove(optionalId);
      nextQuantities.remove(optionalId);
    } else {
      nextQuantities[optionalId] = 1.0;
    }
    state = state.copyWith(
      selectedOptionalIds: next,
      optionalItemQuantities: nextQuantities,
      clearGeneratedQuotation: true,
    );
  }

  void togglePackageProduct(String productName) {
    final next = {...state.excludedPackageProducts};
    final nextQuantities = {...state.packageProductQuantities};
    if (!next.add(productName)) {
      next.remove(productName);
      nextQuantities[productName] = 1.0;
    } else {
      nextQuantities.remove(productName);
    }

    state = state.copyWith(
      excludedPackageProducts: next,
      packageProductQuantities: nextQuantities,
      clearGeneratedQuotation: true,
    );
  }

  double packageProductQuantity(String productName, double fallbackQuantity) {
    return state.packageProductQuantities[productName] ?? fallbackQuantity;
  }

  void incrementPackageProductQuantity(
    String productName, {
    required double fallbackQuantity,
  }) {
    final isExcluded = state.excludedPackageProducts.contains(productName);
    final current = packageProductQuantity(productName, fallbackQuantity);
    final nextQuantities = {
      ...state.packageProductQuantities,
      productName: isExcluded ? 1.0 : current + 1,
    };
    final nextExcluded = {...state.excludedPackageProducts}
      ..remove(productName);
    state = state.copyWith(
      packageProductQuantities: nextQuantities,
      excludedPackageProducts: nextExcluded,
      clearGeneratedQuotation: true,
    );
  }

  void decrementPackageProductQuantity(
    String productName, {
    required double fallbackQuantity,
  }) {
    if (state.excludedPackageProducts.contains(productName)) {
      return;
    }
    final current = packageProductQuantity(productName, fallbackQuantity);
    final nextQuantities = {...state.packageProductQuantities};
    final nextExcluded = {...state.excludedPackageProducts};

    if (current <= 1) {
      nextQuantities.remove(productName);
      nextExcluded.add(productName);
    } else {
      nextQuantities[productName] = current - 1;
    }

    state = state.copyWith(
      packageProductQuantities: nextQuantities,
      excludedPackageProducts: nextExcluded,
      clearGeneratedQuotation: true,
    );
  }

  void updatePackageProductQuantity(
    String productName,
    double quantity, {
    required double fallbackQuantity,
  }) {
    if (quantity <= 0) {
      return;
    }
    final nextQuantities = {
      ...state.packageProductQuantities,
      productName: quantity,
    };
    final nextExcluded = {...state.excludedPackageProducts}
      ..remove(productName);
    state = state.copyWith(
      packageProductQuantities: nextQuantities,
      excludedPackageProducts: nextExcluded,
      clearGeneratedQuotation: true,
    );
  }

  double optionalItemQuantity(String optionalId) {
    return state.optionalItemQuantities[optionalId] ?? 1.0;
  }

  void incrementOptionalItemQuantity(String optionalId) {
    final isSelected = state.selectedOptionalIds.contains(optionalId);
    final current = optionalItemQuantity(optionalId);
    final nextSelected = {...state.selectedOptionalIds}..add(optionalId);
    final nextQuantities = {
      ...state.optionalItemQuantities,
      optionalId: isSelected ? current + 1 : 1.0,
    };

    state = state.copyWith(
      selectedOptionalIds: nextSelected,
      optionalItemQuantities: nextQuantities,
      clearGeneratedQuotation: true,
    );
  }

  void decrementOptionalItemQuantity(String optionalId) {
    if (!state.selectedOptionalIds.contains(optionalId)) {
      return;
    }
    final current = optionalItemQuantity(optionalId);
    final nextSelected = {...state.selectedOptionalIds};
    final nextQuantities = {...state.optionalItemQuantities};

    if (current <= 1) {
      nextSelected.remove(optionalId);
      nextQuantities.remove(optionalId);
    } else {
      nextQuantities[optionalId] = current - 1;
    }

    state = state.copyWith(
      selectedOptionalIds: nextSelected,
      optionalItemQuantities: nextQuantities,
      clearGeneratedQuotation: true,
    );
  }

  void addManualProduct({
    required String name,
    required double quantity,
    required double unitPrice,
    String unit = 'unit',
  }) {
    final trimmed = name.trim();
    final safeUnit = unit.trim().isEmpty ? 'unit' : unit.trim();
    if (trimmed.isEmpty || quantity <= 0 || unitPrice < 0) {
      return;
    }

    final next = [...state.manualProducts];
    final existingIndex = next.indexWhere(
      (item) =>
          item.name.toLowerCase() == trimmed.toLowerCase() &&
          item.unit.toLowerCase() == safeUnit.toLowerCase() &&
          (item.unitPrice - unitPrice).abs() < 0.0001,
    );

    if (existingIndex >= 0) {
      final existing = next[existingIndex];
      next[existingIndex] = QuotationLine(
        name: existing.name,
        quantity: existing.quantity + quantity,
        unitPrice: existing.unitPrice,
        unit: existing.unit,
      );
    } else {
      next.add(
        QuotationLine(
          name: trimmed,
          quantity: quantity,
          unitPrice: unitPrice,
          unit: safeUnit,
        ),
      );
    }

    state = state.copyWith(manualProducts: next, clearGeneratedQuotation: true);
  }

  void removeManualProductAt(int index) {
    if (index < 0 || index >= state.manualProducts.length) {
      return;
    }
    final next = [...state.manualProducts]..removeAt(index);
    state = state.copyWith(manualProducts: next, clearGeneratedQuotation: true);
  }

  void updateManualProductAt(
    int index, {
    required String name,
    required double quantity,
    required double unitPrice,
    String unit = 'unit',
  }) {
    if (index < 0 || index >= state.manualProducts.length) {
      return;
    }
    final trimmed = name.trim();
    final safeUnit = unit.trim().isEmpty ? 'unit' : unit.trim();
    if (trimmed.isEmpty || quantity <= 0 || unitPrice < 0) {
      return;
    }

    final next = [...state.manualProducts];
    next[index] = QuotationLine(
      name: trimmed,
      quantity: quantity,
      unitPrice: unitPrice,
      unit: safeUnit,
    );
    state = state.copyWith(manualProducts: next, clearGeneratedQuotation: true);
  }

  Future<void> generateQuotation() async {
    final profile = _selectedProfile(state.selectedProfileId);
    final selectedPackage = profile.packages.firstWhere(
      (item) => item.id == state.selectedPackageId,
    );
    final usesQtyInput =
        selectedPackage.quantityLabel.isNotEmpty &&
        selectedPackage.rateRules.isNotEmpty;
    final inputQty = usesQtyInput
        ? (double.tryParse(state.runningFeet) ?? 0)
        : 0.0;
    final now = DateTime.now();
    final clientName = state.clientName.trim().isEmpty
        ? 'Walk-in Client'
        : state.clientName.trim();

    final lineItems = <QuotationLine>[];
    final hardwareRate = selectedPackage.rateRules.isNotEmpty
        ? _computeRateFromRules(selectedPackage.rateRules, inputQty)
        : selectedPackage.hardwareRate;

    final qtyLabel = selectedPackage.quantityLabel;

    if (hardwareRate > 0 &&
        inputQty > 0 &&
        qtyLabel.isNotEmpty &&
        selectedPackage.rateRules.isNotEmpty) {
      lineItems.add(
        QuotationLine(
          name: qtyLabel,
          quantity: inputQty,
          unitPrice: hardwareRate,
          unit: 'unit',
        ),
      );
    }

    if (state.systemType.isNotEmpty &&
        selectedPackage.systemVariants.containsKey(state.systemType)) {
      lineItems.add(
        QuotationLine(
          name: state.systemType,
          quantity: 1,
          unitPrice: selectedPackage.systemVariants[state.systemType] ?? 0,
          unit: 'system',
        ),
      );
    }

    for (final product in selectedPackage.products) {
      if (state.excludedPackageProducts.contains(product.name)) {
        continue;
      }
      final quantity = packageProductQuantity(product.name, 1);
      if (quantity <= 0) {
        continue;
      }
      lineItems.add(
        QuotationLine(
          name: product.name,
          quantity: quantity,
          unitPrice: product.unitPrice,
          unit: product.unit,
        ),
      );
    }

    lineItems.addAll(state.manualProducts);

    final selectedOptionals = selectedPackage.optionalItems
        .where(
          (item) => state.selectedOptionalIds.contains(item.id) && item.enabled,
        )
        .toList();

    final optionalLines = selectedOptionals
        .map((item) {
          final quantity = optionalItemQuantity(item.id);
          return QuotationLine(
            name: item.name,
            quantity: quantity,
            unitPrice: item.price,
            unit: 'item',
          );
        })
        .where((item) => item.quantity > 0)
        .toList();

    final subtotal = [
      ...lineItems,
      ...optionalLines,
    ].fold<double>(0, (sum, item) => sum + item.total);
    final quotationNo =
        'RLGX-${now.year}${now.month.toString().padLeft(2, '0')}-${now.microsecondsSinceEpoch % 10000}';

    final placeholders = <String, String>{
      'client_name': clientName,
      'quotation_no': quotationNo,
      'date': _date.format(now),
      'running_feet': state.runningFeet,
      'quantity_label': selectedPackage.quantityLabel,
      'quantity_description': selectedPackage.quantityDescription,
      'system_type': state.systemType,
      'subtotal': _currency.format(subtotal),
      'grand_total': _currency.format(subtotal),
      'package_name': selectedPackage.name,
    };

    final quotation = GeneratedQuotation(
      quotationNo: quotationNo,
      clientName: clientName,
      category: profile.category,
      packageName: selectedPackage.name,
      templateName: profile.template.fileName,
      generatedDate: now,
      lineItems: [...lineItems, ...optionalLines],
      optionalItems: selectedOptionals,
      subtotal: subtotal,
      grandTotal: subtotal,
      warranty: profile.warranty,
      terms: profile.terms,
      globalSections: _invoicePolicySections,
      placeholderValues: placeholders,
      renderedTemplate: _templateEngine.render(
        profile.template.sourceMarkup,
        placeholders,
      ),
      paymentReceived: 0,
      remainingPayment: subtotal,
    );

    state = state.copyWith(generatedQuotation: quotation);

    await _historyService.save(quotation);
  }

  Future<void> convertToInvoice({required double paymentReceived}) async {
    final current = state.generatedQuotation;
    if (current == null) {
      return;
    }

    final additionalPayment = paymentReceived < 0 ? 0.0 : paymentReceived;
    final previousReceived = current.isInvoice ? current.paymentReceived : 0.0;
    final safeReceived = (previousReceived + additionalPayment)
        .clamp(0, current.grandTotal)
        .toDouble();
    await _applyInvoicePayment(current, safeReceived);
  }

  Future<void> updateInvoicePaymentReceived({
    required double paymentReceived,
  }) async {
    final current = state.generatedQuotation;
    if (current == null) {
      return;
    }

    final safeReceived = paymentReceived
        .clamp(0, current.grandTotal)
        .toDouble();
    await _applyInvoicePayment(current, safeReceived);
  }

  Future<void> _applyInvoicePayment(
    GeneratedQuotation current,
    double safeReceived,
  ) async {
    final remaining = (current.grandTotal - safeReceived)
        .clamp(0, current.grandTotal)
        .toDouble();
    final invoiceNo = current.invoiceNo.isEmpty
        ? 'INV-${current.quotationNo.substring(5)}'
        : current.invoiceNo;

    final updatedPlaceholders = {
      ...current.placeholderValues,
      'invoice_no': invoiceNo,
      'payment_received': _currency.format(safeReceived),
      'remaining_payment': _currency.format(remaining),
    };

    final updated = current.copyWith(
      isInvoice: true,
      invoiceNo: invoiceNo,
      paymentReceived: safeReceived,
      remainingPayment: remaining,
      placeholderValues: updatedPlaceholders,
    );

    if (!current.isInvoice) {
      _consumeInventoryForInvoice(updated);
    }

    state = state.copyWith(generatedQuotation: updated);
    await _historyService.save(updated);
  }

  void _consumeInventoryForInvoice(GeneratedQuotation quotation) {
    final inventoryController = _ref.read(inventoryProvider.notifier);
    final currentItems = inventoryController.items;
    final soldTotals = <String, double>{};

    for (final line in quotation.lineItems) {
      final index = currentItems.indexWhere(
        (item) =>
            item.name.toLowerCase().trim() == line.name.toLowerCase().trim(),
      );
      if (index == -1) {
        continue;
      }
      soldTotals.update(
        currentItems[index].id,
        (value) => value + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }

    for (final entry in soldTotals.entries) {
      final item = currentItems.firstWhere((value) => value.id == entry.key);
      final soldQuantity = entry.value.round();
      if (soldQuantity <= 0) {
        continue;
      }
      inventoryController.adjustStock(
        itemId: item.id,
        delta: -soldQuantity,
        note:
            'Sold via ${quotation.isInvoice && quotation.invoiceNo.isNotEmpty ? quotation.invoiceNo : quotation.quotationNo}',
      );
    }
  }

  Future<void> _generateMappedQuotation(
    List<ServiceProduct> mappedProducts,
  ) async {
    final profile = _selectedProfile(state.selectedProfileId);
    final selectedPackage = profile.packages.firstWhere(
      (item) => item.id == state.selectedPackageId,
    );

    final mappedLineItems = mappedProducts
        .map(
          (item) => QuotationLine(
            name: item.name,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            unit: item.unit,
          ),
        )
        .toList();

    final now = DateTime.now();
    final clientName = state.clientName.trim().isEmpty
        ? 'Walk-in Client'
        : state.clientName.trim();
    final quotationNo =
        'RLGX-${now.year}${now.month.toString().padLeft(2, '0')}-${now.microsecondsSinceEpoch % 10000}';
    final subtotal = mappedLineItems.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    final placeholders = <String, String>{
      'client_name': clientName,
      'quotation_no': quotationNo,
      'date': _date.format(now),
      'running_feet': state.runningFeet,
      'quantity_label': selectedPackage.quantityLabel,
      'quantity_description': selectedPackage.quantityDescription,
      'system_type': state.systemType,
      'subtotal': _currency.format(subtotal),
      'grand_total': _currency.format(subtotal),
      'package_name': selectedPackage.name,
    };

    state = state.copyWith(
      generatedQuotation: GeneratedQuotation(
        quotationNo: quotationNo,
        clientName: clientName,
        category: profile.category,
        packageName: selectedPackage.name,
        templateName: profile.template.fileName,
        generatedDate: now,
        lineItems: mappedLineItems,
        optionalItems: const [],
        subtotal: subtotal,
        grandTotal: subtotal,
        warranty: profile.warranty,
        terms: profile.terms,
        globalSections: _invoicePolicySections,
        placeholderValues: placeholders,
        renderedTemplate: _templateEngine.render(
          profile.template.sourceMarkup,
          placeholders,
        ),
        paymentReceived: 0,
        remainingPayment: subtotal,
      ),
    );

    final generated = state.generatedQuotation;
    if (generated != null) {
      await _historyService.save(generated);
    }
  }

  ServiceProfile _selectedProfile(String profileId) {
    return _profiles.firstWhere(
      (item) => item.template.id == profileId,
      orElse: () => _profiles.first,
    );
  }

  ServiceProfile _profileFromDocument(GeneratedQuotation document) {
    final byTemplateName = _profiles.where(
      (item) => item.template.fileName == document.templateName,
    );
    if (byTemplateName.isNotEmpty) {
      return byTemplateName.first;
    }
    final byPackageAndCategory = _profiles.where(
      (item) =>
          item.category == document.category &&
          item.packages.any((pkg) => pkg.name == document.packageName),
    );
    if (byPackageAndCategory.isNotEmpty) {
      return byPackageAndCategory.first;
    }
    return _profiles.firstWhere(
      (item) => item.category == document.category,
      orElse: () => _profiles.first,
    );
  }

  double _computeRateFromRules(List<RateRule> rules, double qty) {
    for (final rule in rules) {
      if (qty <= rule.upTo) return rule.rate;
    }
    return rules.last.rate;
  }

  ServicePackage? _matchPackage(ServiceProfile profile, String packageHint) {
    if (packageHint.trim().isEmpty) {
      return null;
    }

    final normalizedHint = packageHint.toLowerCase();
    for (final package in profile.packages) {
      final name = package.name.toLowerCase();
      final summary = package.summary.toLowerCase();
      if (name.contains(normalizedHint) || summary.contains(normalizedHint)) {
        return package;
      }
    }
    return null;
  }

  String _matchSystemType(ServicePackage package, String systemHint) {
    if (systemHint.trim().isEmpty) {
      return '';
    }

    final normalizedHint = systemHint.toLowerCase();
    for (final system in package.systemVariants.keys) {
      if (system.toLowerCase().contains(normalizedHint)) {
        return system;
      }
    }
    return '';
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}
