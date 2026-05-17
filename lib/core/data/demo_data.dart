import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../database/local_database.dart';
import '../models/erp_models.dart';
import '../services/firebase_auth_service.dart';
import 'cloud_providers.dart';

const _defaultInvoicePolicySections = <InvoicePolicySection>[
  InvoicePolicySection(
    title: 'TERM & CONDITIONS',
    items: [
      '1)- We reserve the right to change the price at any time, due to fluctuations in currencies and supply.',
      '2)- No warranty for broken or physical damage or Burn or Natural disaster',
    ],
  ),
  InvoicePolicySection(
    title: 'Scope of Work',
    items: [
      '1)- Supply of Material for above system as per attached BOQ.',
      '2)- Installation, Testing, Commissioning and Handover of above system as per attached BOQ',
    ],
  ),
  InvoicePolicySection(
    title: 'Out of Scope',
    items: [
      '1)- Any work beyond the BOQ, including civil and electrical work, will be charged separately.',
      '2)- Client is responsible for all required approvals and permissions.',
      '3)- Prices exclude VAT, taxes, and other government levies.',
      '4)- Replacement of faulty or unrepairable cables, hardware, or devices will be charged separately.',
      '5)- Internet connection must be provided by the client.',
    ],
  ),
  InvoicePolicySection(
    title: 'Services & Support',
    items: [
      '1)- Life time After sale service , visit charge will be applied .',
      '2)- Response time will be from 24 to 48 hours.',
    ],
  ),
];

const invoiceLogoSettingsKey = 'invoice_logo_base64';
const invoiceBusinessDetailsSettingsKey = 'invoice_business_details';
const _enabledServicesKey = 'enabled_services';
const _customServiceProfilesKey = 'custom_service_profiles';
const _serviceCatalogEditsKey = 'service_catalog_edits';

const _defaultInvoiceBusinessDetails = InvoiceBusinessDetails(
  businessName: 'RLX Invoice',
  address: 'Near NBP bank, Hussani Chowk, Bahawalpur',
  phone: '0301-8777220',
  email: 'info.robologicx@gmail.com',
  website: 'www.robologicx.org',
);

String? _activeUserId() => FirebaseAuth.instance.currentUser?.uid;

String? _scopedSettingsKey(String key) {
  final userId = _activeUserId();
  if (userId == null || userId.isEmpty) {
    return null;
  }
  return '$userId::$key';
}

DocumentReference<Map<String, dynamic>>? _settingsDocRef() {
  final userId = _activeUserId();
  if (userId == null || userId.isEmpty) {
    return null;
  }
  return FirebaseFirestore.instance.collection('users').doc(userId);
}

Future<void> _mirrorSettingToFirestore(String key, dynamic value) async {
  final ref = _settingsDocRef();
  if (ref == null) {
    return;
  }
  await ref.set({
    'appSettings': {key: value},
  }, SetOptions(merge: true));
}

Future<void> _removeSettingFromFirestore(String key) async {
  final ref = _settingsDocRef();
  if (ref == null) {
    return;
  }
  try {
    await ref.update({'appSettings.$key': FieldValue.delete()});
  } catch (_) {
    // Ignore missing document/field errors.
  }
}

Future<dynamic> _readSettingFromFirestore(String key) async {
  final ref = _settingsDocRef();
  if (ref == null) {
    return null;
  }

  final snapshot = await ref.get();
  final data = snapshot.data();
  if (data == null) {
    return null;
  }

  final appSettings = data['appSettings'];
  if (appSettings is! Map) {
    return null;
  }
  return appSettings[key];
}

Future<void> _cacheSettingToHive(String key, dynamic value) async {
  if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
    return;
  }
  final scopedKey = _scopedSettingsKey(key);
  if (scopedKey == null) {
    return;
  }
  await Hive.box(LocalDatabase.appSettingsBox).put(scopedKey, value);
}

class InvoiceBusinessDetails {
  const InvoiceBusinessDetails({
    required this.businessName,
    required this.address,
    required this.phone,
    required this.email,
    required this.website,
  });

  final String businessName;
  final String address;
  final String phone;
  final String email;
  final String website;

  InvoiceBusinessDetails copyWith({
    String? businessName,
    String? address,
    String? phone,
    String? email,
    String? website,
  }) {
    return InvoiceBusinessDetails(
      businessName: businessName ?? this.businessName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
    );
  }

  Map<String, dynamic> toMap() => {
    'businessName': businessName,
    'address': address,
    'phone': phone,
    'email': email,
    'website': website,
  };

  factory InvoiceBusinessDetails.fromMap(Map<dynamic, dynamic> map) {
    return InvoiceBusinessDetails(
      businessName: map['businessName'] as String? ?? 'RLX Invoice',
      address: map['address'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      website: map['website'] as String? ?? '',
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null || name.isEmpty) {
    return fallback;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

Map<String, dynamic> _serviceProductToMap(ServiceProduct item) {
  return {
    'name': item.name,
    'quantity': item.quantity,
    'unitPrice': item.unitPrice,
    'unit': item.unit,
  };
}

ServiceProduct _serviceProductFromMap(Map<dynamic, dynamic> map) {
  return ServiceProduct(
    name: map['name'] as String? ?? '',
    quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
    unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
    unit: map['unit'] as String? ?? 'unit',
  );
}

Map<String, dynamic> _businessTemplateToMap(BusinessTemplate template) {
  return {
    'id': template.id,
    'name': template.name,
    'fileName': template.fileName,
    'fileType': template.fileType.name,
    'category': template.category.name,
    'sourceMarkup': template.sourceMarkup,
  };
}

BusinessTemplate _businessTemplateFromMap(Map<dynamic, dynamic> map) {
  return BusinessTemplate(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    fileName: map['fileName'] as String? ?? '',
    fileType: _enumByName(
      TemplateFileType.values,
      map['fileType'] as String?,
      TemplateFileType.html,
    ),
    category: _enumByName(
      ServiceCategory.values,
      map['category'] as String?,
      ServiceCategory.smartHome,
    ),
    sourceMarkup: map['sourceMarkup'] as String? ?? '',
  );
}

Map<String, dynamic> _servicePackageToMap(ServicePackage package) {
  return {
    'id': package.id,
    'name': package.name,
    'summary': package.summary,
    'category': package.category.name,
    'templateId': package.templateId,
    'products': package.products.map(_serviceProductToMap).toList(),
    'optionalItems': package.optionalItems.map((item) => item.toMap()).toList(),
    'systemVariants': package.systemVariants,
    'hardwareRate': package.hardwareRate,
    'quantityLabel': package.quantityLabel,
    'quantityDescription': package.quantityDescription,
    'defaultQuantity': package.defaultQuantity,
    'rateRules': package.rateRules.map((r) => r.toMap()).toList(),
    'calculationNotes': package.calculationNotes,
  };
}

ServicePackage _servicePackageFromMap(Map<dynamic, dynamic> map) {
  final rawProducts = map['products'] as List? ?? const [];
  final rawOptionals = map['optionalItems'] as List? ?? const [];
  final rawVariants = map['systemVariants'] as Map? ?? const {};

  return ServicePackage(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    summary: map['summary'] as String? ?? '',
    category: _enumByName(
      ServiceCategory.values,
      map['category'] as String?,
      ServiceCategory.smartHome,
    ),
    templateId: map['templateId'] as String? ?? '',
    products: rawProducts.whereType<Map>().map(_serviceProductFromMap).toList(),
    optionalItems: rawOptionals
        .whereType<Map>()
        .map((item) => OptionalItem.fromMap(item))
        .toList(),
    systemVariants: {
      for (final entry in rawVariants.entries)
        entry.key.toString(): (entry.value as num?)?.toDouble() ?? 0,
    },
    hardwareRate: (map['hardwareRate'] as num?)?.toDouble() ?? 0,
    quantityLabel: map['quantityLabel'] as String? ?? '',
    quantityDescription: map['quantityDescription'] as String? ?? '',
    defaultQuantity: (map['defaultQuantity'] as num?)?.toDouble() ?? 0,
    rateRules: (map['rateRules'] as List? ?? const [])
        .whereType<Map>()
        .map(RateRule.fromMap)
        .toList(),
    calculationNotes: map['calculationNotes'] as String? ?? '',
  );
}

Map<String, dynamic> _serviceProfileToMap(ServiceProfile profile) {
  return {
    'category': profile.category.name,
    'title': profile.title,
    'tagline': profile.tagline,
    'template': _businessTemplateToMap(profile.template),
    'packages': profile.packages.map(_servicePackageToMap).toList(),
    'warranty': profile.warranty,
    'terms': profile.terms,
    'notes': profile.notes,
  };
}

ServiceProfile? _serviceProfileFromMap(Map<dynamic, dynamic> map) {
  final rawTemplate = map['template'];
  if (rawTemplate is! Map) {
    return null;
  }
  final rawPackages = map['packages'] as List? ?? const [];

  return ServiceProfile(
    category: _enumByName(
      ServiceCategory.values,
      map['category'] as String?,
      ServiceCategory.smartHome,
    ),
    title: map['title'] as String? ?? '',
    tagline: map['tagline'] as String? ?? '',
    template: _businessTemplateFromMap(rawTemplate),
    packages: rawPackages.whereType<Map>().map(_servicePackageFromMap).toList(),
    warranty: map['warranty'] as String? ?? '',
    terms: (map['terms'] as List? ?? const []).whereType<String>().toList(),
    notes: (map['notes'] as List? ?? const []).whereType<String>().toList(),
  );
}

Set<ServiceCategory> _loadEnabledServices() {
  if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
    return {...ServiceCategory.values};
  }
  final scopedKey = _scopedSettingsKey(_enabledServicesKey);
  if (scopedKey == null) {
    return {...ServiceCategory.values};
  }
  final saved = Hive.box(LocalDatabase.appSettingsBox).get(scopedKey);
  if (saved is! List) {
    return {...ServiceCategory.values};
  }
  final result = saved
      .whereType<String>()
      .map(
        (name) => _enumByName(
          ServiceCategory.values,
          name,
          ServiceCategory.smartHome,
        ),
      )
      .toSet();
  return result.isEmpty ? {...ServiceCategory.values} : result;
}

Future<void> _saveEnabledServices(Set<ServiceCategory> categories) async {
  if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
    return Future.value();
  }
  final scopedKey = _scopedSettingsKey(_enabledServicesKey);
  if (scopedKey == null) {
    return;
  }
  final data = categories.map((item) => item.name).toList();
  await Hive.box(LocalDatabase.appSettingsBox).put(scopedKey, data);
  await _mirrorSettingToFirestore(_enabledServicesKey, data);
}

List<ServiceProfile> _loadCustomServiceProfiles() {
  if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
    return const [];
  }
  final scopedKey = _scopedSettingsKey(_customServiceProfilesKey);
  if (scopedKey == null) {
    return const [];
  }
  final saved = Hive.box(LocalDatabase.appSettingsBox).get(scopedKey);
  if (saved is! List) {
    return const [];
  }
  return saved
      .whereType<Map>()
      .map(_serviceProfileFromMap)
      .whereType<ServiceProfile>()
      .toList();
}

Future<void> _saveCustomServiceProfiles(List<ServiceProfile> profiles) async {
  if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
    return Future.value();
  }
  final scopedKey = _scopedSettingsKey(_customServiceProfilesKey);
  if (scopedKey == null) {
    return;
  }
  final data = profiles.map(_serviceProfileToMap).toList();
  await Hive.box(LocalDatabase.appSettingsBox).put(scopedKey, data);
  await _mirrorSettingToFirestore(_customServiceProfilesKey, data);
}

ServiceCatalogEdits _loadServiceCatalogEdits() {
  if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
    return const ServiceCatalogEdits();
  }
  final scopedKey = _scopedSettingsKey(_serviceCatalogEditsKey);
  if (scopedKey == null) {
    return const ServiceCatalogEdits();
  }
  final saved = Hive.box(LocalDatabase.appSettingsBox).get(scopedKey);
  if (saved is! Map) {
    return const ServiceCatalogEdits();
  }

  final productsByPackage = <String, List<ServiceProduct>>{};
  final optionalsByPackage = <String, List<OptionalItem>>{};
  final templatesByTemplateId = <String, BusinessTemplate>{};
  final disabledPackageIds = <String>{};
  final addedPackagesByProfile = <String, List<ServicePackage>>{};
  final systemVariantsByPackage = <String, Map<String, double>>{};
  final quantityLabelByPackage = <String, String>{};
  final quantityDescriptionByPackage = <String, String>{};
  final defaultQuantityByPackage = <String, double>{};
  final rateRulesByPackage = <String, List<RateRule>>{};

  final rawProducts = saved['productsByPackage'];
  if (rawProducts is Map) {
    for (final entry in rawProducts.entries) {
      final value = entry.value;
      if (value is List) {
        productsByPackage[entry.key.toString()] = value
            .whereType<Map>()
            .map(_serviceProductFromMap)
            .toList();
      }
    }
  }

  final rawOptionals = saved['optionalsByPackage'];
  if (rawOptionals is Map) {
    for (final entry in rawOptionals.entries) {
      final value = entry.value;
      if (value is List) {
        optionalsByPackage[entry.key.toString()] = value
            .whereType<Map>()
            .map((item) => OptionalItem.fromMap(item))
            .toList();
      }
    }
  }

  final rawTemplates = saved['templatesByTemplateId'];
  if (rawTemplates is Map) {
    for (final entry in rawTemplates.entries) {
      final value = entry.value;
      if (value is Map) {
        templatesByTemplateId[entry.key.toString()] = _businessTemplateFromMap(
          value,
        );
      }
    }
  }

  final rawDisabled = saved['disabledPackageIds'];
  if (rawDisabled is List) {
    disabledPackageIds.addAll(rawDisabled.whereType<String>());
  }

  final rawAddedPackages = saved['addedPackagesByProfile'];
  if (rawAddedPackages is Map) {
    for (final entry in rawAddedPackages.entries) {
      final value = entry.value;
      if (value is List) {
        addedPackagesByProfile[entry.key.toString()] = value
            .whereType<Map>()
            .map(_servicePackageFromMap)
            .toList();
      }
    }
  }

  final rawSystemVariants = saved['systemVariantsByPackage'];
  if (rawSystemVariants is Map) {
    for (final entry in rawSystemVariants.entries) {
      final value = entry.value;
      if (value is Map) {
        systemVariantsByPackage[entry.key.toString()] = {
          for (final e in value.entries)
            e.key.toString(): (e.value as num?)?.toDouble() ?? 0,
        };
      }
    }
  }

  final rawQtyLabels = saved['quantityLabelByPackage'];
  if (rawQtyLabels is Map) {
    for (final entry in rawQtyLabels.entries) {
      quantityLabelByPackage[entry.key.toString()] = entry.value.toString();
    }
  }

  final rawQtyDescriptions = saved['quantityDescriptionByPackage'];
  if (rawQtyDescriptions is Map) {
    for (final entry in rawQtyDescriptions.entries) {
      quantityDescriptionByPackage[entry.key.toString()] = entry.value
          .toString();
    }
  }

  final rawDefaultQty = saved['defaultQuantityByPackage'];
  if (rawDefaultQty is Map) {
    for (final entry in rawDefaultQty.entries) {
      defaultQuantityByPackage[entry.key.toString()] =
          (entry.value as num?)?.toDouble() ?? 0;
    }
  }

  final rawRateRules = saved['rateRulesByPackage'];
  if (rawRateRules is Map) {
    for (final entry in rawRateRules.entries) {
      final value = entry.value;
      if (value is List) {
        rateRulesByPackage[entry.key.toString()] = value
            .whereType<Map>()
            .map(RateRule.fromMap)
            .toList();
      }
    }
  }

  return ServiceCatalogEdits(
    productsByPackage: productsByPackage,
    optionalsByPackage: optionalsByPackage,
    templatesByTemplateId: templatesByTemplateId,
    disabledPackageIds: disabledPackageIds,
    addedPackagesByProfile: addedPackagesByProfile,
    systemVariantsByPackage: systemVariantsByPackage,
    quantityLabelByPackage: quantityLabelByPackage,
    quantityDescriptionByPackage: quantityDescriptionByPackage,
    defaultQuantityByPackage: defaultQuantityByPackage,
    rateRulesByPackage: rateRulesByPackage,
  );
}

Future<void> _saveServiceCatalogEdits(ServiceCatalogEdits edits) async {
  if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
    return Future.value();
  }
  final scopedKey = _scopedSettingsKey(_serviceCatalogEditsKey);
  if (scopedKey == null) {
    return;
  }

  final data = {
    'productsByPackage': {
      for (final entry in edits.productsByPackage.entries)
        entry.key: entry.value.map(_serviceProductToMap).toList(),
    },
    'optionalsByPackage': {
      for (final entry in edits.optionalsByPackage.entries)
        entry.key: entry.value.map((item) => item.toMap()).toList(),
    },
    'templatesByTemplateId': {
      for (final entry in edits.templatesByTemplateId.entries)
        entry.key: _businessTemplateToMap(entry.value),
    },
    'disabledPackageIds': edits.disabledPackageIds.toList(),
    'addedPackagesByProfile': {
      for (final entry in edits.addedPackagesByProfile.entries)
        entry.key: entry.value.map(_servicePackageToMap).toList(),
    },
    'systemVariantsByPackage': {
      for (final entry in edits.systemVariantsByPackage.entries)
        entry.key: entry.value,
    },
    'quantityLabelByPackage': edits.quantityLabelByPackage,
    'quantityDescriptionByPackage': edits.quantityDescriptionByPackage,
    'defaultQuantityByPackage': edits.defaultQuantityByPackage,
    'rateRulesByPackage': {
      for (final entry in edits.rateRulesByPackage.entries)
        entry.key: entry.value.map((r) => r.toMap()).toList(),
    },
  };

  await Hive.box(LocalDatabase.appSettingsBox).put(scopedKey, data);
  await _mirrorSettingToFirestore(_serviceCatalogEditsKey, data);
}

class InvoicePolicySectionsController
    extends StateNotifier<List<InvoicePolicySection>> {
  InvoicePolicySectionsController() : super(_loadInvoicePolicySections()) {
    unawaited(_hydrateFromCloud());
  }

  static const _settingsKey = 'invoice_policy_sections';

  void updateSection(String title, List<String> items) {
    state = [
      for (final section in state)
        if (section.title == title) section.copyWith(items: items) else section,
    ];
    _saveInvoicePolicySections(state);
  }

  Future<void> _hydrateFromCloud() async {
    final cloudValue = await _readSettingFromFirestore(_settingsKey);
    if (cloudValue is! List) {
      return;
    }

    await _cacheSettingToHive(_settingsKey, cloudValue);
    state = _loadInvoicePolicySections();
  }

  static List<InvoicePolicySection> _loadInvoicePolicySections() {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return _defaultInvoicePolicySections;
    }
    final scopedKey = _scopedSettingsKey(_settingsKey);
    if (scopedKey == null) {
      return _defaultInvoicePolicySections;
    }
    final box = Hive.box(LocalDatabase.appSettingsBox);
    final saved = box.get(scopedKey);
    if (saved is! List) {
      return _defaultInvoicePolicySections;
    }

    final sections = <InvoicePolicySection>[];
    for (final section in saved) {
      if (section is! Map) {
        continue;
      }
      final title = section['title'];
      final items = section['items'];
      if (title is! String || items is! List) {
        continue;
      }
      sections.add(
        InvoicePolicySection(
          title: title,
          items: items.whereType<String>().toList(),
        ),
      );
    }

    return sections.isEmpty ? _defaultInvoicePolicySections : sections;
  }

  static Future<void> _saveInvoicePolicySections(
    List<InvoicePolicySection> sections,
  ) async {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return Future.value();
    }
    final scopedKey = _scopedSettingsKey(_settingsKey);
    if (scopedKey == null) {
      return;
    }
    final data = [
      for (final section in sections)
        {'title': section.title, 'items': section.items},
    ];
    await Hive.box(LocalDatabase.appSettingsBox).put(scopedKey, data);
    await _mirrorSettingToFirestore(_settingsKey, data);
  }
}

final invoicePolicySectionsProvider =
    StateNotifierProvider<
      InvoicePolicySectionsController,
      List<InvoicePolicySection>
    >((ref) {
      ref.watch(currentUserProvider);
      return InvoicePolicySectionsController();
    });

class InvoiceBusinessDetailsController
    extends StateNotifier<InvoiceBusinessDetails> {
  InvoiceBusinessDetailsController() : super(_loadInvoiceBusinessDetails()) {
    unawaited(_hydrateFromCloud());
  }

  void setDetails(InvoiceBusinessDetails details) {
    state = details;
    _saveInvoiceBusinessDetails(details);
  }

  Future<void> _hydrateFromCloud() async {
    final cloudValue = await _readSettingFromFirestore(
      invoiceBusinessDetailsSettingsKey,
    );
    if (cloudValue is! Map) {
      return;
    }

    await _cacheSettingToHive(invoiceBusinessDetailsSettingsKey, cloudValue);
    state = _loadInvoiceBusinessDetails();
  }

  static InvoiceBusinessDetails _loadInvoiceBusinessDetails() {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return _defaultInvoiceBusinessDetails;
    }
    final scopedKey = _scopedSettingsKey(invoiceBusinessDetailsSettingsKey);
    if (scopedKey == null) {
      return _defaultInvoiceBusinessDetails;
    }
    final saved = Hive.box(LocalDatabase.appSettingsBox).get(scopedKey);
    if (saved is! Map) {
      return _defaultInvoiceBusinessDetails;
    }
    final parsed = InvoiceBusinessDetails.fromMap(saved);
    return _defaultInvoiceBusinessDetails.copyWith(
      businessName: parsed.businessName.trim().isEmpty
          ? _defaultInvoiceBusinessDetails.businessName
          : parsed.businessName,
      address: parsed.address.trim().isEmpty
          ? _defaultInvoiceBusinessDetails.address
          : parsed.address,
      phone: parsed.phone.trim().isEmpty
          ? _defaultInvoiceBusinessDetails.phone
          : parsed.phone,
      email: parsed.email.trim().isEmpty
          ? _defaultInvoiceBusinessDetails.email
          : parsed.email,
      website: parsed.website,
    );
  }

  static Future<void> _saveInvoiceBusinessDetails(
    InvoiceBusinessDetails details,
  ) async {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return Future.value();
    }
    final scopedKey = _scopedSettingsKey(invoiceBusinessDetailsSettingsKey);
    if (scopedKey == null) {
      return;
    }
    final data = details.toMap();
    await Hive.box(LocalDatabase.appSettingsBox).put(scopedKey, data);
    await _mirrorSettingToFirestore(invoiceBusinessDetailsSettingsKey, data);
  }
}

final invoiceBusinessDetailsProvider =
    StateNotifierProvider<
      InvoiceBusinessDetailsController,
      InvoiceBusinessDetails
    >((ref) {
      ref.watch(currentUserProvider);
      return InvoiceBusinessDetailsController();
    });

class InvoiceLogoController extends StateNotifier<Uint8List?> {
  InvoiceLogoController() : super(_loadLogo()) {
    unawaited(_hydrateFromCloud());
  }

  void setLogoBytes(Uint8List bytes) {
    state = bytes;
    _saveLogo(bytes);
  }

  void clearLogo() {
    state = null;
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return;
    }
    final scopedKey = _scopedSettingsKey(invoiceLogoSettingsKey);
    if (scopedKey == null) {
      return;
    }
    Hive.box(LocalDatabase.appSettingsBox).delete(scopedKey);
    unawaited(_removeSettingFromFirestore(invoiceLogoSettingsKey));
  }

  Future<void> _hydrateFromCloud() async {
    final cloudValue = await _readSettingFromFirestore(invoiceLogoSettingsKey);
    if (cloudValue is! Uint8List && cloudValue is! String) {
      return;
    }

    await _cacheSettingToHive(invoiceLogoSettingsKey, cloudValue);
    state = _loadLogo();
  }

  static Uint8List? _loadLogo() {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return null;
    }
    final scopedKey = _scopedSettingsKey(invoiceLogoSettingsKey);
    if (scopedKey == null) {
      return null;
    }
    final saved = Hive.box(LocalDatabase.appSettingsBox).get(scopedKey);
    if (saved is Uint8List && saved.isNotEmpty) {
      return saved;
    }
    if (saved is! String || saved.isEmpty) {
      return null;
    }
    try {
      return base64Decode(saved);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveLogo(Uint8List bytes) async {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return Future.value();
    }
    final scopedKey = _scopedSettingsKey(invoiceLogoSettingsKey);
    if (scopedKey == null) {
      return;
    }
    await Hive.box(LocalDatabase.appSettingsBox).put(scopedKey, bytes);
    await _mirrorSettingToFirestore(invoiceLogoSettingsKey, bytes);
  }
}

final invoiceLogoBytesProvider =
    StateNotifierProvider<InvoiceLogoController, Uint8List?>((ref) {
      ref.watch(currentUserProvider);
      return InvoiceLogoController();
    });

class EnabledServicesController extends StateNotifier<Set<ServiceCategory>> {
  EnabledServicesController() : super(_loadEnabledServices()) {
    unawaited(_hydrateFromCloud());
  }

  Future<void> _hydrateFromCloud() async {
    final cloudValue = await _readSettingFromFirestore(_enabledServicesKey);
    if (cloudValue is! List) {
      return;
    }

    await _cacheSettingToHive(_enabledServicesKey, cloudValue);
    state = _loadEnabledServices();
  }

  void toggle(ServiceCategory category) {
    if (state.contains(category)) {
      if (state.length == 1) {
        return;
      }
      state = {...state}..remove(category);
      _saveEnabledServices(state);
      return;
    }

    state = {...state, category};
    _saveEnabledServices(state);
  }

  void enableAll() {
    state = {...ServiceCategory.values};
    _saveEnabledServices(state);
  }

  void ensureEnabled(ServiceCategory category) {
    if (state.contains(category)) {
      return;
    }
    state = {...state, category};
    _saveEnabledServices(state);
  }
}

final enabledServicesProvider =
    StateNotifierProvider<EnabledServicesController, Set<ServiceCategory>>((
      ref,
    ) {
      ref.watch(currentUserProvider);
      return EnabledServicesController();
    });

class CustomServiceProfilesController
    extends StateNotifier<List<ServiceProfile>> {
  CustomServiceProfilesController() : super(_loadCustomServiceProfiles()) {
    unawaited(_hydrateFromCloud());
  }

  Future<void> _hydrateFromCloud() async {
    final cloudValue = await _readSettingFromFirestore(
      _customServiceProfilesKey,
    );
    if (cloudValue is! List) {
      return;
    }

    await _cacheSettingToHive(_customServiceProfilesKey, cloudValue);
    state = _loadCustomServiceProfiles();
  }

  ServiceProfile? addService({
    required String title,
    required ServiceCategory category,
    String packageName = '',
    double basePrice = 0,
    UploadedTemplate? uploadedTemplate,
    List<ServiceProduct> importedProducts = const [],
    List<OptionalItem> importedOptionals = const [],
  }) {
    final cleanTitle = title.trim();
    final cleanPackage = packageName.trim().isEmpty
        ? '$cleanTitle Package'
        : packageName.trim();

    if (cleanTitle.isEmpty) {
      return null;
    }

    final idSeed = DateTime.now().microsecondsSinceEpoch.toString();
    final serviceId = 'custom_service_$idSeed';
    final templateId = 'custom_template_$idSeed';
    final packageId = 'custom_package_$idSeed';
    final markup = '''
RLX Invoice Custom Service Template
Client: {{client_name}}
Quotation No: {{quotation_no}}
Date: {{date}}
Package: {{package_name}}
Subtotal: {{subtotal}}
Grand Total: {{grand_total}}
''';
    final template = BusinessTemplate(
      id: templateId,
      name: uploadedTemplate == null
          ? '$cleanTitle Template'
          : '$cleanTitle Imported Template',
      fileName:
          uploadedTemplate?.fileName ??
          '${cleanTitle.toLowerCase().replaceAll(' ', '_')}.html',
      fileType: switch (uploadedTemplate?.fileExtension.toLowerCase()) {
        'pdf' => TemplateFileType.pdf,
        'docx' => TemplateFileType.docx,
        'xlsx' || 'xls' => TemplateFileType.excel,
        _ => TemplateFileType.html,
      },
      category: category,
      sourceMarkup: uploadedTemplate?.rawContent ?? markup,
    );

    final products = <ServiceProduct>[
      if (basePrice > 0)
        ServiceProduct(
          name: '$cleanTitle Service',
          quantity: 1,
          unitPrice: basePrice,
          unit: 'job',
        ),
      ...importedProducts,
    ];
    if (products.isEmpty) {
      products.add(
        ServiceProduct(
          name: cleanTitle,
          quantity: 1,
          unitPrice: 0,
          unit: 'unit',
        ),
      );
    }

    final service = ServiceProfile(
      category: category,
      title: cleanTitle,
      tagline: 'Custom service added by admin.',
      template: template,
      packages: [
        ServicePackage(
          id: packageId,
          name: cleanPackage,
          summary: 'Custom package for $cleanTitle',
          category: category,
          templateId: templateId,
          products: products,
          optionalItems: importedOptionals,
          calculationNotes: uploadedTemplate == null
              ? 'Custom service package generated by admin.'
              : 'Products and optional items were imported from ${uploadedTemplate.fileName}.',
        ),
      ],
      warranty: 'Standard warranty as per agreement.',
      terms: ['Payment terms and scope are defined in work order.'],
      notes: ['Service created from Service Manager. ID: $serviceId'],
    );

    state = [...state, service];
    _saveCustomServiceProfiles(state);
    return service;
  }

  void removeServiceByTemplateId(String templateId) {
    state = state.where((item) => item.template.id != templateId).toList();
    _saveCustomServiceProfiles(state);
  }
}

final customServiceProfilesProvider =
    StateNotifierProvider<
      CustomServiceProfilesController,
      List<ServiceProfile>
    >((ref) {
      ref.watch(currentUserProvider);
      return CustomServiceProfilesController();
    });

class ServiceCatalogEdits {
  const ServiceCatalogEdits({
    this.productsByPackage = const {},
    this.optionalsByPackage = const {},
    this.templatesByTemplateId = const {},
    this.disabledPackageIds = const {},
    this.addedPackagesByProfile = const {},
    this.systemVariantsByPackage = const {},
    this.quantityLabelByPackage = const {},
    this.quantityDescriptionByPackage = const {},
    this.defaultQuantityByPackage = const {},
    this.rateRulesByPackage = const {},
  });

  final Map<String, List<ServiceProduct>> productsByPackage;
  final Map<String, List<OptionalItem>> optionalsByPackage;
  final Map<String, BusinessTemplate> templatesByTemplateId;
  final Set<String> disabledPackageIds;
  final Map<String, List<ServicePackage>> addedPackagesByProfile;
  final Map<String, Map<String, double>> systemVariantsByPackage;
  final Map<String, String> quantityLabelByPackage;
  final Map<String, String> quantityDescriptionByPackage;
  final Map<String, double> defaultQuantityByPackage;
  final Map<String, List<RateRule>> rateRulesByPackage;

  ServiceCatalogEdits copyWith({
    Map<String, List<ServiceProduct>>? productsByPackage,
    Map<String, List<OptionalItem>>? optionalsByPackage,
    Map<String, BusinessTemplate>? templatesByTemplateId,
    Set<String>? disabledPackageIds,
    Map<String, List<ServicePackage>>? addedPackagesByProfile,
    Map<String, Map<String, double>>? systemVariantsByPackage,
    Map<String, String>? quantityLabelByPackage,
    Map<String, String>? quantityDescriptionByPackage,
    Map<String, double>? defaultQuantityByPackage,
    Map<String, List<RateRule>>? rateRulesByPackage,
  }) {
    return ServiceCatalogEdits(
      productsByPackage: productsByPackage ?? this.productsByPackage,
      optionalsByPackage: optionalsByPackage ?? this.optionalsByPackage,
      templatesByTemplateId:
          templatesByTemplateId ?? this.templatesByTemplateId,
      disabledPackageIds: disabledPackageIds ?? this.disabledPackageIds,
      addedPackagesByProfile:
          addedPackagesByProfile ?? this.addedPackagesByProfile,
      systemVariantsByPackage:
          systemVariantsByPackage ?? this.systemVariantsByPackage,
      quantityLabelByPackage:
          quantityLabelByPackage ?? this.quantityLabelByPackage,
      quantityDescriptionByPackage:
          quantityDescriptionByPackage ?? this.quantityDescriptionByPackage,
      defaultQuantityByPackage:
          defaultQuantityByPackage ?? this.defaultQuantityByPackage,
      rateRulesByPackage: rateRulesByPackage ?? this.rateRulesByPackage,
    );
  }
}

class ServiceCatalogEditsController extends StateNotifier<ServiceCatalogEdits> {
  ServiceCatalogEditsController() : super(_loadServiceCatalogEdits()) {
    unawaited(_hydrateFromCloud());
  }

  Future<void> _hydrateFromCloud() async {
    final cloudValue = await _readSettingFromFirestore(_serviceCatalogEditsKey);
    if (cloudValue is! Map) {
      return;
    }

    await _cacheSettingToHive(_serviceCatalogEditsKey, cloudValue);
    state = _loadServiceCatalogEdits();
  }

  void setPackageEdits({
    required String packageId,
    required List<ServiceProduct> products,
    required List<OptionalItem> optionals,
    String? templateId,
    BusinessTemplate? template,
    Map<String, double>? systemVariants,
    String? quantityLabel,
    String? quantityDescription,
    double? defaultQuantity,
    List<RateRule>? rateRules,
  }) {
    final nextProducts = {...state.productsByPackage, packageId: products};
    final nextOptionals = {...state.optionalsByPackage, packageId: optionals};
    final nextTemplates = {...state.templatesByTemplateId};
    if (templateId != null && template != null) {
      nextTemplates[templateId] = template;
    }
    final nextSystemVariants = {...state.systemVariantsByPackage};
    if (systemVariants != null) {
      nextSystemVariants[packageId] = systemVariants;
    }
    final nextQtyLabels = {...state.quantityLabelByPackage};
    if (quantityLabel != null) {
      nextQtyLabels[packageId] = quantityLabel;
    }
    final nextQtyDescriptions = {...state.quantityDescriptionByPackage};
    if (quantityDescription != null) {
      nextQtyDescriptions[packageId] = quantityDescription;
    }
    final nextDefaultQty = {...state.defaultQuantityByPackage};
    if (defaultQuantity != null) {
      nextDefaultQty[packageId] = defaultQuantity;
    }
    final nextRateRules = {...state.rateRulesByPackage};
    if (rateRules != null) {
      nextRateRules[packageId] = rateRules;
    }

    state = state.copyWith(
      productsByPackage: nextProducts,
      optionalsByPackage: nextOptionals,
      templatesByTemplateId: nextTemplates,
      systemVariantsByPackage: nextSystemVariants,
      quantityLabelByPackage: nextQtyLabels,
      quantityDescriptionByPackage: nextQtyDescriptions,
      defaultQuantityByPackage: nextDefaultQty,
      rateRulesByPackage: nextRateRules,
    );
    _saveServiceCatalogEdits(state);
  }

  void setPackageProducts(String packageId, List<ServiceProduct> products) {
    final next = {...state.productsByPackage, packageId: products};
    state = state.copyWith(productsByPackage: next);
    _saveServiceCatalogEdits(state);
  }

  void setPackageOptionalItems(String packageId, List<OptionalItem> optionals) {
    final next = {...state.optionalsByPackage, packageId: optionals};
    state = state.copyWith(optionalsByPackage: next);
    _saveServiceCatalogEdits(state);
  }

  void setTemplate(String templateId, BusinessTemplate template) {
    final next = {...state.templatesByTemplateId, templateId: template};
    state = state.copyWith(templatesByTemplateId: next);
    _saveServiceCatalogEdits(state);
  }

  void togglePackage(String packageId) {
    final next = {...state.disabledPackageIds};
    if (!next.remove(packageId)) {
      next.add(packageId);
    }
    state = state.copyWith(disabledPackageIds: next);
    _saveServiceCatalogEdits(state);
  }

  void addPackageToProfile(String profileTemplateId, ServicePackage package) {
    final existing = state.addedPackagesByProfile[profileTemplateId] ?? [];
    state = state.copyWith(
      addedPackagesByProfile: {
        ...state.addedPackagesByProfile,
        profileTemplateId: [...existing, package],
      },
    );
    _saveServiceCatalogEdits(state);
  }
}

final serviceCatalogEditsProvider =
    StateNotifierProvider<ServiceCatalogEditsController, ServiceCatalogEdits>((
      ref,
    ) {
      ref.watch(currentUserProvider);
      return ServiceCatalogEditsController();
    });

const _electricFenceMarkup = '''
RLX Invoice Electric Fence Template
Client: {{client_name}}
Quotation No: {{quotation_no}}
Date: {{date}}
Running Feet: {{running_feet}}
System Type: {{system_type}}
Subtotal: {{subtotal}}
Grand Total: {{grand_total}}
''';

const _cctvMarkup = '''
RLX Invoice CCTV Template
Client: {{client_name}}
Quotation No: {{quotation_no}}
Package: {{package_name}}
Hardware Subtotal: {{subtotal}}
Grand Total: {{grand_total}}
''';

const _solarMarkup = '''
RLX Invoice Solar Template
Client: {{client_name}}
Quotation No: {{quotation_no}}
Package: {{package_name}}
Backup Upgrade: {{system_type}}
Grand Total: {{grand_total}}
''';

const _gateMarkup = '''
RLX Invoice Smart Gate Template
Client: {{client_name}}
Quotation No: {{quotation_no}}
Motor Type: {{system_type}}
Grand Total: {{grand_total}}
''';

const _smartHomeMarkup = '''
RLX Invoice Smart Home Template
Client: {{client_name}}
Quotation No: {{quotation_no}}
Package: {{package_name}}
Grand Total: {{grand_total}}
''';

const _roboticsMarkup = '''
RLX Invoice Robotics Project Template
Client: {{client_name}}
Quotation No: {{quotation_no}}
Package: {{package_name}}
System Type: {{system_type}}
Subtotal: {{subtotal}}
Grand Total: {{grand_total}}
''';

const _networkingMarkup = '''
RLX Invoice Networking Template
Client: {{client_name}}
Quotation No: {{quotation_no}}
Package: {{package_name}}
Subtotal: {{subtotal}}
Grand Total: {{grand_total}}
''';

const _maintenanceMarkup = '''
RLX Invoice Maintenance Service Template
Client: {{client_name}}
Quotation No: {{quotation_no}}
Date: {{date}}
Package: {{package_name}}
Subtotal: {{subtotal}}
Grand Total: {{grand_total}}
''';

final serviceProfilesProvider = Provider<List<ServiceProfile>>((ref) {
  return const [
    ServiceProfile(
      category: ServiceCategory.electricFence,
      title: 'Electric Fence Quotations',
      tagline:
          'Uploaded PDF template with running-feet pricing and auto-added terms.',
      template: BusinessTemplate(
        id: 'electric_fence_template',
        name: 'Electric Fence Template',
        fileName: 'electric_fence_template.pdf',
        fileType: TemplateFileType.pdf,
        category: ServiceCategory.electricFence,
        sourceMarkup: _electricFenceMarkup,
      ),
      packages: [
        ServicePackage(
          id: 'fence_core',
          name: 'Perimeter Protection Package',
          summary: '300 PKR per running foot plus energizer system selection.',
          category: ServiceCategory.electricFence,
          templateId: 'electric_fence_template',
          hardwareRate: 300,
          quantityLabel: 'Running Feet',
          rateRules: [
            RateRule(upTo: 100, rate: 450),
            RateRule(upTo: double.infinity, rate: 350),
          ],
          systemVariants: {'Tonger / Chinese': 45000, 'Nemtek': 55000},
          optionalItems: [
            OptionalItem(id: 'fence_light', name: 'Fence Light', price: 3500),
            OptionalItem(id: 'siren_light', name: 'Siren Light', price: 3000),
            OptionalItem(id: 'wifi_card', name: 'WiFi Card', price: 21500),
            OptionalItem(id: 'ta_da', name: 'TA/DA', price: 5000),
          ],
          calculationNotes:
              'Hardware calculated by running feet and selected energizer.',
        ),
        ServicePackage(
          id: 'fence_5marla',
          name: '5 Marla Package',
          summary: 'Typical ~40 running feet for a 5 Marla plot.',
          category: ServiceCategory.electricFence,
          templateId: 'electric_fence_template',
          hardwareRate: 300,
          quantityLabel: 'Running Feet',
          defaultQuantity: 40,
          rateRules: [
            RateRule(upTo: 100, rate: 450),
            RateRule(upTo: double.infinity, rate: 350),
          ],
          systemVariants: {'Tonger / Chinese': 45000, 'Nemtek': 55000},
          optionalItems: [
            OptionalItem(
              id: 'fence_5m_light',
              name: 'Fence Light',
              price: 3500,
            ),
            OptionalItem(
              id: 'fence_5m_siren',
              name: 'Siren Light',
              price: 3000,
            ),
            OptionalItem(id: 'fence_5m_wifi', name: 'WiFi Card', price: 21500),
            OptionalItem(id: 'fence_5m_tada', name: 'TA/DA', price: 5000),
          ],
          calculationNotes: 'Typical 5 Marla plot. Default is 40 running feet.',
        ),
        ServicePackage(
          id: 'fence_10marla',
          name: '10 Marla Package',
          summary: 'Typical ~120 running feet for a 10 Marla plot.',
          category: ServiceCategory.electricFence,
          templateId: 'electric_fence_template',
          hardwareRate: 300,
          quantityLabel: 'Running Feet',
          defaultQuantity: 120,
          rateRules: [
            RateRule(upTo: 100, rate: 450),
            RateRule(upTo: double.infinity, rate: 350),
          ],
          systemVariants: {'Tonger / Chinese': 45000, 'Nemtek': 55000},
          optionalItems: [
            OptionalItem(
              id: 'fence_10m_light',
              name: 'Fence Light',
              price: 3500,
            ),
            OptionalItem(
              id: 'fence_10m_siren',
              name: 'Siren Light',
              price: 3000,
            ),
            OptionalItem(id: 'fence_10m_wifi', name: 'WiFi Card', price: 21500),
            OptionalItem(id: 'fence_10m_tada', name: 'TA/DA', price: 5000),
          ],
          calculationNotes:
              'Typical 10 Marla plot. Default is 120 running feet.',
        ),
        ServicePackage(
          id: 'fence_1kanal',
          name: '1 Kanal Package',
          summary: 'Typical ~400 running feet for a 1 Kanal plot.',
          category: ServiceCategory.electricFence,
          templateId: 'electric_fence_template',
          hardwareRate: 300,
          quantityLabel: 'Running Feet',
          rateRules: [
            RateRule(upTo: 100, rate: 450),
            RateRule(upTo: double.infinity, rate: 350),
          ],
          systemVariants: {'Tonger / Chinese': 45000, 'Nemtek': 55000},
          optionalItems: [
            OptionalItem(
              id: 'fence_1k_light',
              name: 'Fence Light',
              price: 3500,
            ),
            OptionalItem(
              id: 'fence_1k_siren',
              name: 'Siren Light',
              price: 3000,
            ),
            OptionalItem(id: 'fence_1k_wifi', name: 'WiFi Card', price: 21500),
            OptionalItem(id: 'fence_1k_tada', name: 'TA/DA', price: 5000),
          ],
          calculationNotes: 'Typical 1 Kanal plot. Enter ~400 in Running Feet.',
        ),
      ],
      warranty: '12-month hardware warranty with lifetime after-sale service.',
      terms: [
        'Civil work and power backup are excluded unless added as optional items.',
        'Advance payment confirms material reservation and installation slot.',
        'Quotation preserves the uploaded template layout and replaces placeholders only.',
      ],
      notes: [
        'Fence specifications are inserted automatically.',
        'Salesperson enters only client, feet, system, and optional items.',
      ],
    ),
    ServiceProfile(
      category: ServiceCategory.cctv,
      title: 'CCTV / IP Camera Invoices',
      tagline:
          'Predefined CCTV packages with hardware, configuration, and installation charges.',
      template: BusinessTemplate(
        id: 'cctv_template',
        name: 'CCTV Invoice Template',
        fileName: 'cctv_template.pdf',
        fileType: TemplateFileType.pdf,
        category: ServiceCategory.cctv,
        sourceMarkup: _cctvMarkup,
      ),
      packages: [
        ServicePackage(
          id: 'cctv_5_camera',
          name: '5 Camera CCTV Package',
          summary: 'Five 4MP IP cameras with NVR, storage, and installation.',
          category: ServiceCategory.cctv,
          templateId: 'cctv_template',
          products: [
            ServiceProduct(
              name: 'Dahua 4MP IP Camera',
              quantity: 5,
              unitPrice: 12500,
            ),
            ServiceProduct(
              name: '8 Channel NVR',
              quantity: 1,
              unitPrice: 28500,
            ),
            ServiceProduct(name: 'POE Switch', quantity: 1, unitPrice: 9500),
            ServiceProduct(name: 'Hard Drive', quantity: 1, unitPrice: 18000),
            ServiceProduct(
              name: 'Networking Box',
              quantity: 1,
              unitPrice: 6500,
            ),
            ServiceProduct(
              name: 'CAT6 Cable',
              quantity: 1,
              unitPrice: 15000,
              unit: 'roll',
            ),
            ServiceProduct(
              name: 'Water Proof Box',
              quantity: 5,
              unitPrice: 750,
            ),
            ServiceProduct(name: 'RJ45 Connector', quantity: 20, unitPrice: 45),
          ],
          optionalItems: [
            OptionalItem(id: 'led_monitor', name: 'LED Monitor', price: 28000),
            OptionalItem(
              id: 'wireless_bridge',
              name: 'Wireless Bridge',
              price: 18500,
            ),
            OptionalItem(
              id: 'electrical_work',
              name: 'Electrical Work',
              price: 12000,
            ),
            OptionalItem(id: 'ta_da', name: 'TA/DA', price: 6000),
          ],
          calculationNotes:
              'Final amount = hardware subtotal + configuration + installation.',
        ),
        ServicePackage(
          id: 'cctv_10_camera',
          name: '10 Camera CCTV Package',
          summary: 'Ten 4MP IP cameras with NVR, storage, and installation.',
          category: ServiceCategory.cctv,
          templateId: 'cctv_template',
          products: [
            ServiceProduct(
              name: 'Dahua 4MP IP Camera',
              quantity: 10,
              unitPrice: 12500,
            ),
            ServiceProduct(
              name: '16 Channel NVR',
              quantity: 1,
              unitPrice: 38500,
            ),
            ServiceProduct(name: 'POE Switch', quantity: 2, unitPrice: 9500),
            ServiceProduct(
              name: '4TB Hard Drive',
              quantity: 1,
              unitPrice: 24000,
            ),
            ServiceProduct(
              name: 'Networking Box',
              quantity: 1,
              unitPrice: 6500,
            ),
            ServiceProduct(
              name: 'CAT6 Cable',
              quantity: 2,
              unitPrice: 15000,
              unit: 'roll',
            ),
            ServiceProduct(
              name: 'Water Proof Box',
              quantity: 10,
              unitPrice: 750,
            ),
            ServiceProduct(name: 'RJ45 Connector', quantity: 40, unitPrice: 45),
          ],
          optionalItems: [
            OptionalItem(
              id: 'cctv_10_monitor',
              name: 'LED Monitor',
              price: 28000,
            ),
            OptionalItem(
              id: 'cctv_10_bridge',
              name: 'Wireless Bridge',
              price: 18500,
            ),
            OptionalItem(
              id: 'cctv_10_elec',
              name: 'Electrical Work',
              price: 14000,
            ),
            OptionalItem(id: 'cctv_10_tada', name: 'TA/DA', price: 6000),
          ],
          calculationNotes:
              'Final amount = hardware subtotal + configuration + installation.',
        ),
        ServicePackage(
          id: 'cctv_16_camera',
          name: '16 Camera CCTV Package',
          summary:
              'Sixteen 4MP IP cameras with NVR, dual storage, and installation.',
          category: ServiceCategory.cctv,
          templateId: 'cctv_template',
          products: [
            ServiceProduct(
              name: 'Dahua 4MP IP Camera',
              quantity: 16,
              unitPrice: 12500,
            ),
            ServiceProduct(
              name: '16 Channel NVR',
              quantity: 1,
              unitPrice: 42000,
            ),
            ServiceProduct(name: 'POE Switch', quantity: 2, unitPrice: 9500),
            ServiceProduct(
              name: '4TB Hard Drive',
              quantity: 2,
              unitPrice: 24000,
            ),
            ServiceProduct(
              name: 'Networking Box',
              quantity: 2,
              unitPrice: 6500,
            ),
            ServiceProduct(
              name: 'CAT6 Cable',
              quantity: 3,
              unitPrice: 15000,
              unit: 'roll',
            ),
            ServiceProduct(
              name: 'Water Proof Box',
              quantity: 16,
              unitPrice: 750,
            ),
            ServiceProduct(name: 'RJ45 Connector', quantity: 60, unitPrice: 45),
          ],
          optionalItems: [
            OptionalItem(
              id: 'cctv_16_monitor',
              name: 'LED Monitor',
              price: 35000,
            ),
            OptionalItem(
              id: 'cctv_16_bridge',
              name: 'Wireless Bridge',
              price: 18500,
            ),
            OptionalItem(
              id: 'cctv_16_elec',
              name: 'Electrical Work',
              price: 18000,
            ),
            OptionalItem(id: 'cctv_16_tada', name: 'TA/DA', price: 6000),
          ],
          calculationNotes:
              'Final amount = hardware subtotal + configuration + installation.',
        ),
      ],
      warranty:
          'One year camera, NVR, and accessories warranty with maintenance support.',
      terms: [
        'Network backbone must be available before commissioning.',
        'Maintenance visit schedule follows signed SLA.',
        'Invoice output keeps logo, footer, and table alignment from the uploaded template.',
      ],
      notes: [
        'Installation notes are appended automatically.',
        'Template placeholders are extracted dynamically before generation.',
      ],
    ),
    ServiceProfile(
      category: ServiceCategory.smartGate,
      title: 'Smart Gate Automation',
      tagline:
          'Template-linked motor packages with automation options and maintenance terms.',
      template: BusinessTemplate(
        id: 'gate_template',
        name: 'Smart Gate Template',
        fileName: 'smart_gate_template.pdf',
        fileType: TemplateFileType.pdf,
        category: ServiceCategory.smartGate,
        sourceMarkup: _gateMarkup,
      ),
      packages: [
        ServicePackage(
          id: 'gate_sliding',
          name: 'Sliding Gate Automation Package',
          summary: 'Motor, sensors, rack, controller, and installation.',
          category: ServiceCategory.smartGate,
          templateId: 'gate_template',
          products: [
            ServiceProduct(name: 'Sensors', quantity: 1, unitPrice: 8500),
            ServiceProduct(name: 'Rack', quantity: 1, unitPrice: 14000),
            ServiceProduct(name: 'Installation', quantity: 1, unitPrice: 25000),
            ServiceProduct(
              name: 'WiFi Gate Controller',
              quantity: 1,
              unitPrice: 18500,
            ),
          ],
          systemVariants: {
            'Chinese': 98000,
            'Italian': 165000,
            'Heavy Duty Industrial': 245000,
          },
          optionalItems: [
            OptionalItem(id: 'wifi_switch', name: 'WiFi Switch', price: 9500),
            OptionalItem(id: 'gsm_control', name: 'GSM Control', price: 28500),
            OptionalItem(id: 'extra_remote', name: 'Extra Remote', price: 3500),
          ],
        ),
      ],
      warranty:
          '12-month gate motor warranty and preventive maintenance guidance.',
      terms: [
        'Structural fabrication is billed separately unless included in package.',
        'Commissioning is completed after power and limit-switch verification.',
      ],
      notes: ['Optional automation accessories can be toggled per quotation.'],
    ),
    ServiceProfile(
      category: ServiceCategory.solar,
      title: 'Solar Quotations',
      tagline:
          'Excel-driven package quotations with predefined hybrid system packages.',
      template: BusinessTemplate(
        id: 'solar_template',
        name: 'Solar Excel Template',
        fileName: 'solar_quotation_template.xlsx',
        fileType: TemplateFileType.excel,
        category: ServiceCategory.solar,
        sourceMarkup: _solarMarkup,
      ),
      packages: [
        ServicePackage(
          id: 'solar_5kw',
          name: '5KW Hybrid Package',
          summary:
              'Panels, inverter, batteries, wiring, structure, and installation.',
          category: ServiceCategory.solar,
          templateId: 'solar_template',
          products: [
            ServiceProduct(
              name: 'Solar Panels',
              quantity: 10,
              unitPrice: 18000,
            ),
            ServiceProduct(
              name: 'Hybrid Inverter',
              quantity: 1,
              unitPrice: 245000,
            ),
            ServiceProduct(name: 'Batteries', quantity: 2, unitPrice: 85000),
            ServiceProduct(name: 'Structure', quantity: 1, unitPrice: 65000),
            ServiceProduct(name: 'Wiring', quantity: 1, unitPrice: 42000),
            ServiceProduct(name: 'Installation', quantity: 1, unitPrice: 90000),
          ],
          optionalItems: [
            OptionalItem(
              id: 'extra_battery',
              name: 'Optional Battery',
              price: 85000,
            ),
            OptionalItem(
              id: 'backup_upgrade',
              name: 'Backup Upgrade',
              price: 120000,
            ),
            OptionalItem(
              id: 'net_metering',
              name: 'Net Metering',
              price: 150000,
            ),
            OptionalItem(
              id: 'smart_monitoring',
              name: 'Smart Monitoring',
              price: 25000,
            ),
          ],
          systemVariants: {'Standard Backup': 0, 'Extended Backup': 95000},
          calculationNotes:
              'Load, backup, and battery sizing are derived from selected package and upgrades.',
        ),
        ServicePackage(
          id: 'solar_6kw',
          name: '6KW Hybrid Package',
          summary:
              '6KW hybrid inverter with panels, batteries, and installation.',
          category: ServiceCategory.solar,
          templateId: 'solar_template',
          products: [
            ServiceProduct(
              name: 'Solar Panel 585W',
              quantity: 11,
              unitPrice: 18000,
            ),
            ServiceProduct(
              name: '6KW Hybrid Inverter',
              quantity: 1,
              unitPrice: 295000,
            ),
            ServiceProduct(
              name: 'Lithium Battery 100Ah',
              quantity: 2,
              unitPrice: 95000,
            ),
            ServiceProduct(name: 'Structure', quantity: 1, unitPrice: 75000),
            ServiceProduct(name: 'Wiring', quantity: 1, unitPrice: 50000),
            ServiceProduct(
              name: 'Installation',
              quantity: 1,
              unitPrice: 100000,
            ),
          ],
          optionalItems: [
            OptionalItem(
              id: 'solar_6k_battery',
              name: 'Extra Battery',
              price: 95000,
            ),
            OptionalItem(
              id: 'solar_6k_net',
              name: 'Net Metering',
              price: 150000,
            ),
            OptionalItem(
              id: 'solar_6k_monitor',
              name: 'Smart Monitoring',
              price: 25000,
            ),
          ],
          systemVariants: {'Standard Backup': 0, 'Extended Backup': 110000},
          calculationNotes: 'Suitable for medium load households with backup.',
        ),
        ServicePackage(
          id: 'solar_8kw',
          name: '8KW Hybrid Package',
          summary:
              '8KW hybrid inverter with panels, batteries, and installation.',
          category: ServiceCategory.solar,
          templateId: 'solar_template',
          products: [
            ServiceProduct(
              name: 'Solar Panel 585W',
              quantity: 14,
              unitPrice: 18000,
            ),
            ServiceProduct(
              name: '8KW Hybrid Inverter',
              quantity: 1,
              unitPrice: 350000,
            ),
            ServiceProduct(
              name: 'Lithium Battery 100Ah',
              quantity: 2,
              unitPrice: 135000,
            ),
            ServiceProduct(name: 'Structure', quantity: 1, unitPrice: 85000),
            ServiceProduct(name: 'Wiring', quantity: 1, unitPrice: 65000),
            ServiceProduct(
              name: 'Installation',
              quantity: 1,
              unitPrice: 120000,
            ),
          ],
          optionalItems: [
            OptionalItem(
              id: 'solar_8k_battery',
              name: 'Extra Battery',
              price: 135000,
            ),
            OptionalItem(
              id: 'solar_8k_net',
              name: 'Net Metering',
              price: 150000,
            ),
            OptionalItem(
              id: 'solar_8k_monitor',
              name: 'Smart Monitoring',
              price: 25000,
            ),
          ],
          systemVariants: {'Standard Backup': 0, 'Extended Backup': 150000},
          calculationNotes:
              'Suitable for large load households or small offices.',
        ),
        ServicePackage(
          id: 'solar_10kw',
          name: '10KW Hybrid Package',
          summary:
              '10KW hybrid inverter with panels, batteries, and installation.',
          category: ServiceCategory.solar,
          templateId: 'solar_template',
          products: [
            ServiceProduct(
              name: 'Solar Panel 585W',
              quantity: 18,
              unitPrice: 18000,
            ),
            ServiceProduct(
              name: '10KW Hybrid Inverter',
              quantity: 1,
              unitPrice: 450000,
            ),
            ServiceProduct(
              name: 'Lithium Battery 200Ah',
              quantity: 2,
              unitPrice: 185000,
            ),
            ServiceProduct(name: 'Structure', quantity: 1, unitPrice: 100000),
            ServiceProduct(name: 'Wiring', quantity: 1, unitPrice: 80000),
            ServiceProduct(
              name: 'Installation',
              quantity: 1,
              unitPrice: 150000,
            ),
          ],
          optionalItems: [
            OptionalItem(
              id: 'solar_10k_battery',
              name: 'Extra Battery',
              price: 185000,
            ),
            OptionalItem(
              id: 'solar_10k_net',
              name: 'Net Metering',
              price: 150000,
            ),
            OptionalItem(
              id: 'solar_10k_monitor',
              name: 'Smart Monitoring',
              price: 25000,
            ),
          ],
          systemVariants: {'Standard Backup': 0, 'Extended Backup': 200000},
          calculationNotes:
              'Suitable for commercial or high-consumption sites.',
        ),
      ],
      warranty:
          'Panel and inverter warranty follows OEM documentation, installation warranty 1 year.',
      terms: [
        'Civil works and metering approval fees are excluded unless selected.',
        'Battery sizing is indicative and confirmed after site survey.',
      ],
      notes: [
        'Solar package selection auto-populates line items from the uploaded workbook mapping.',
      ],
    ),
    ServiceProfile(
      category: ServiceCategory.smartHome,
      title: 'Smart Home Packages',
      tagline:
          'Premium automation bundles using uploaded templates and reusable packages.',
      template: BusinessTemplate(
        id: 'smart_home_template',
        name: 'Smart Home Template',
        fileName: 'smart_home_template.html',
        fileType: TemplateFileType.html,
        category: ServiceCategory.smartHome,
        sourceMarkup: _smartHomeMarkup,
      ),
      packages: [
        ServicePackage(
          id: 'smart_home_core',
          name: 'Core Smart Home Package',
          summary: 'Sensors, smart switches, hub, and configuration.',
          category: ServiceCategory.smartHome,
          templateId: 'smart_home_template',
          products: [
            ServiceProduct(
              name: 'Smart Switches',
              quantity: 6,
              unitPrice: 6500,
            ),
            ServiceProduct(name: 'Sensors', quantity: 4, unitPrice: 4200),
            ServiceProduct(name: 'Smart Hub', quantity: 1, unitPrice: 28000),
            ServiceProduct(
              name: 'Configuration',
              quantity: 1,
              unitPrice: 35000,
            ),
          ],
          optionalItems: [
            OptionalItem(
              id: 'scene_upgrade',
              name: 'Scene Upgrade',
              price: 18000,
            ),
            OptionalItem(
              id: 'voice_assistant',
              name: 'Voice Assistant',
              price: 32000,
            ),
          ],
        ),
      ],
      warranty: 'Smart home electronics carry 12 months replacement warranty.',
      terms: [
        'Third-party ecosystem setup depends on available internet connectivity.',
      ],
      notes: [
        'HTML template output is ready for PDF export or WhatsApp share workflows.',
      ],
    ),
    ServiceProfile(
      category: ServiceCategory.robotics,
      title: 'Robotics Project Quotations',
      tagline: 'Robot integration and custom automation project proposals.',
      template: BusinessTemplate(
        id: 'robotics_template',
        name: 'Robotics Template',
        fileName: 'robotics_template.docx',
        fileType: TemplateFileType.docx,
        category: ServiceCategory.robotics,
        sourceMarkup: _roboticsMarkup,
      ),
      packages: [
        ServicePackage(
          id: 'robotics_industrial',
          name: 'Industrial Robotics Starter',
          summary: 'PLC, actuators, control cabinet, and commissioning.',
          category: ServiceCategory.robotics,
          templateId: 'robotics_template',
          products: [
            ServiceProduct(
              name: 'PLC Controller',
              quantity: 1,
              unitPrice: 180000,
            ),
            ServiceProduct(
              name: 'Servo Motor Set',
              quantity: 2,
              unitPrice: 95000,
            ),
            ServiceProduct(
              name: 'Control Cabinet',
              quantity: 1,
              unitPrice: 125000,
            ),
            ServiceProduct(
              name: 'Safety Sensors',
              quantity: 4,
              unitPrice: 9500,
            ),
            ServiceProduct(
              name: 'Programming',
              quantity: 1,
              unitPrice: 95000,
              unit: 'job',
            ),
            ServiceProduct(
              name: 'Commissioning',
              quantity: 1,
              unitPrice: 75000,
              unit: 'job',
            ),
          ],
          optionalItems: [
            OptionalItem(
              id: 'hmi_screen',
              name: 'HMI Touch Panel',
              price: 85000,
            ),
            OptionalItem(id: 'amc_robotics', name: 'Annual AMC', price: 125000),
          ],
          calculationNotes:
              'Robotics pricing is package-based, not running-feet.',
        ),
      ],
      warranty: '12-month robotics hardware warranty with remote support.',
      terms: [
        'Mechanical fabrication and third-party equipment are quoted separately unless included.',
      ],
      notes: [
        'Project milestones and commissioning timelines can be added as custom notes.',
      ],
    ),
    ServiceProfile(
      category: ServiceCategory.networking,
      title: 'Networking Solutions',
      tagline:
          'Structured cabling, switching, and enterprise WiFi deployments.',
      template: BusinessTemplate(
        id: 'networking_template',
        name: 'Networking Template',
        fileName: 'networking_template.xlsx',
        fileType: TemplateFileType.excel,
        category: ServiceCategory.networking,
        sourceMarkup: _networkingMarkup,
      ),
      packages: [
        ServicePackage(
          id: 'networking_office',
          name: 'Office Networking Package',
          summary: 'Switch, patch panel, CAT6, racks, and configuration.',
          category: ServiceCategory.networking,
          templateId: 'networking_template',
          products: [
            ServiceProduct(
              name: 'Managed POE Switch',
              quantity: 2,
              unitPrice: 45000,
            ),
            ServiceProduct(name: 'Patch Panel', quantity: 2, unitPrice: 8500),
            ServiceProduct(
              name: 'CAT6 Cable',
              quantity: 4,
              unitPrice: 15000,
              unit: 'roll',
            ),
            ServiceProduct(
              name: 'Networking Rack',
              quantity: 1,
              unitPrice: 32000,
            ),
            ServiceProduct(
              name: 'Configuration',
              quantity: 1,
              unitPrice: 45000,
              unit: 'job',
            ),
          ],
          optionalItems: [
            OptionalItem(
              id: 'wifi_ap',
              name: 'Enterprise WiFi AP',
              price: 28000,
            ),
            OptionalItem(
              id: 'fiber_uplink',
              name: 'Fiber Uplink Module',
              price: 22000,
            ),
          ],
          calculationNotes:
              'Networking uses fixed unit-based pricing and quantities.',
        ),
      ],
      warranty: 'Networking hardware warranty as per OEM policy.',
      terms: ['Civil and conduit work is excluded unless explicitly added.'],
      notes: ['Rack elevation and IP schema can be attached to final invoice.'],
    ),
    ServiceProfile(
      category: ServiceCategory.maintenance,
      title: 'Maintenance Service Billing',
      tagline: 'Quarterly and annual maintenance contract quotations.',
      template: BusinessTemplate(
        id: 'maintenance_template',
        name: 'Maintenance Template',
        fileName: 'maintenance_template.pdf',
        fileType: TemplateFileType.pdf,
        category: ServiceCategory.maintenance,
        sourceMarkup: _maintenanceMarkup,
      ),
      packages: [
        ServicePackage(
          id: 'maintenance_standard',
          name: 'Standard Maintenance Plan',
          summary: 'Inspection, cleaning, diagnostics, and minor replacements.',
          category: ServiceCategory.maintenance,
          templateId: 'maintenance_template',
          products: [
            ServiceProduct(
              name: 'Preventive Visit',
              quantity: 4,
              unitPrice: 18000,
              unit: 'visit',
            ),
            ServiceProduct(
              name: 'Diagnostics',
              quantity: 4,
              unitPrice: 8000,
              unit: 'visit',
            ),
            ServiceProduct(
              name: 'Minor Parts Allowance',
              quantity: 1,
              unitPrice: 35000,
            ),
          ],
          optionalItems: [
            OptionalItem(
              id: 'emergency_callout',
              name: 'Emergency Callout Coverage',
              price: 45000,
            ),
            OptionalItem(
              id: 'priority_support',
              name: 'Priority Support',
              price: 30000,
            ),
          ],
          calculationNotes: 'Maintenance charges are visit and contract based.',
        ),
      ],
      warranty: 'Service workmanship warranty for 90 days per visit.',
      terms: [
        'Major component replacement is billed separately after approval.',
      ],
      notes: ['AMC plans can be duplicated from invoice history for renewal.'],
    ),
  ];
});

final allServiceProfilesProvider = Provider<List<ServiceProfile>>((ref) {
  final base = ref.watch(serviceProfilesProvider);
  final custom = ref.watch(customServiceProfilesProvider);
  return [...base, ...custom];
});

final editableServiceProfilesProvider = Provider<List<ServiceProfile>>((ref) {
  final profiles = ref.watch(allServiceProfilesProvider);
  final edits = ref.watch(serviceCatalogEditsProvider);

  return profiles.map((profile) {
    // Combine base packages with user-added packages for this profile
    final allPackages = [
      ...profile.packages,
      ...(edits.addedPackagesByProfile[profile.template.id] ?? []),
    ];

    final nextPackages = allPackages
        .where((pkg) => !edits.disabledPackageIds.contains(pkg.id))
        .map((package) {
          final editedProducts = edits.productsByPackage[package.id];
          final editedOptionals = edits.optionalsByPackage[package.id];
          final resolvedProducts = editedProducts ?? package.products;
          final fallbackProducts =
              resolvedProducts.isEmpty &&
                  profile.template.id.startsWith('custom_template_')
              ? [
                  ServiceProduct(
                    name: profile.title,
                    quantity: 1,
                    unitPrice: 0,
                    unit: 'unit',
                  ),
                ]
              : resolvedProducts;

          return ServicePackage(
            id: package.id,
            name: package.name,
            summary: package.summary,
            category: package.category,
            templateId: package.templateId,
            products: fallbackProducts,
            optionalItems: editedOptionals ?? package.optionalItems,
            systemVariants:
                edits.systemVariantsByPackage[package.id] ??
                package.systemVariants,
            hardwareRate: package.hardwareRate,
            quantityLabel:
                edits.quantityLabelByPackage[package.id] ??
                package.quantityLabel,
            quantityDescription:
                edits.quantityDescriptionByPackage[package.id] ??
                package.quantityDescription,
            defaultQuantity:
                edits.defaultQuantityByPackage[package.id] ??
                package.defaultQuantity,
            rateRules:
                edits.rateRulesByPackage[package.id] ?? package.rateRules,
            calculationNotes: package.calculationNotes,
          );
        })
        .toList();

    // Always keep at least one package to avoid empty selection crash
    final List<ServicePackage> visiblePackages =
        nextPackages.isEmpty && allPackages.isNotEmpty
        ? [allPackages.first]
        : nextPackages;

    return ServiceProfile(
      category: profile.category,
      title: profile.title,
      tagline: profile.tagline,
      template:
          edits.templatesByTemplateId[profile.template.id] ?? profile.template,
      packages: visiblePackages,
      warranty: profile.warranty,
      terms: profile.terms,
      notes: profile.notes,
    );
  }).toList();
});

final visibleServiceProfilesProvider = Provider<List<ServiceProfile>>((ref) {
  final enabled = ref.watch(enabledServicesProvider);
  final profiles = ref.watch(editableServiceProfilesProvider);
  return profiles
      .where((profile) => enabled.contains(profile.category))
      .toList();
});

final dashboardMetricsProvider = Provider<List<DashboardMetric>>((ref) {
  return const [
    DashboardMetric(label: 'Total Projects', value: '128', delta: '+14%'),
    DashboardMetric(label: 'Pending Work', value: '23', delta: '-6%'),
    DashboardMetric(label: 'Completed Jobs', value: '94', delta: '+11%'),
    DashboardMetric(label: 'Active Technicians', value: '18', delta: '+3'),
    DashboardMetric(label: "Today's Tasks", value: '31', delta: '7 urgent'),
    DashboardMetric(label: 'Monthly Revenue', value: 'PKR 4.8M', delta: '+19%'),
  ];
});

final clientsProvider = StreamProvider<List<ClientRecord>>((ref) {
  final cloudClients = ref.watch(cloudClientsProvider);

  return cloudClients.when(
    data: (clients) {
      return Stream.value(
        clients
            .map(
              (clientData) => ClientRecord.fromMap(
                clientData,
                docId: clientData['id'] as String?,
              ),
            )
            .toList(),
      );
    },
    loading: () => Stream.value(const []),
    error: (err, stack) => Stream.value(const []),
  );
});
