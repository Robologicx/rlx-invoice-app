enum ServiceCategory {
  electricFence,
  solar,
  cctv,
  smartGate,
  smartHome,
  robotics,
  networking,
  maintenance,
}

extension ServiceCategoryX on ServiceCategory {
  String get label => switch (this) {
    ServiceCategory.electricFence => 'Electric Fence',
    ServiceCategory.solar => 'Solar System',
    ServiceCategory.cctv => 'CCTV / IP Camera',
    ServiceCategory.smartGate => 'Smart Gate Automation',
    ServiceCategory.smartHome => 'Smart Home',
    ServiceCategory.robotics => 'Robotics Projects',
    ServiceCategory.networking => 'Networking',
    ServiceCategory.maintenance => 'Maintenance Services',
  };
}

enum UserRole { admin, salesStaff }

extension UserRoleX on UserRole {
  String get label => switch (this) {
    UserRole.admin => 'Admin',
    UserRole.salesStaff => 'Sales Staff',
  };
}

enum TemplateFileType { pdf, docx, excel, html }

extension TemplateFileTypeX on TemplateFileType {
  String get label => switch (this) {
    TemplateFileType.pdf => 'PDF',
    TemplateFileType.docx => 'DOCX',
    TemplateFileType.excel => 'Excel',
    TemplateFileType.html => 'HTML',
  };
}

class BusinessTemplate {
  const BusinessTemplate({
    required this.id,
    required this.name,
    required this.fileName,
    required this.fileType,
    required this.category,
    required this.sourceMarkup,
  });

  final String id;
  final String name;
  final String fileName;
  final TemplateFileType fileType;
  final ServiceCategory category;
  final String sourceMarkup;
}

class ServiceProduct {
  const ServiceProduct({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.unit = 'unit',
  });

  final String name;
  final double quantity;
  final double unitPrice;
  final String unit;

  double get total => quantity * unitPrice;
}

class OptionalItem {
  const OptionalItem({
    required this.id,
    required this.name,
    required this.price,
    this.enabled = true,
  });

  final String id;
  final String name;
  final double price;
  final bool enabled;

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'price': price, 'enabled': enabled};
  }

  factory OptionalItem.fromMap(Map<dynamic, dynamic> map) {
    return OptionalItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      enabled: map['enabled'] as bool? ?? true,
    );
  }
}

class ServicePackage {
  const ServicePackage({
    required this.id,
    required this.name,
    required this.summary,
    required this.category,
    required this.templateId,
    this.products = const [],
    this.optionalItems = const [],
    this.systemVariants = const {},
    this.hardwareRate = 0,
    this.configurationCharge = 0,
    this.installationCharge = 0,
    this.calculationNotes = '',
  });

  final String id;
  final String name;
  final String summary;
  final ServiceCategory category;
  final String templateId;
  final List<ServiceProduct> products;
  final List<OptionalItem> optionalItems;
  final Map<String, double> systemVariants;
  final double hardwareRate;
  final double configurationCharge;
  final double installationCharge;
  final String calculationNotes;
}

class ServiceProfile {
  const ServiceProfile({
    required this.category,
    required this.title,
    required this.tagline,
    required this.template,
    required this.packages,
    required this.warranty,
    required this.terms,
    required this.notes,
  });

  final ServiceCategory category;
  final String title;
  final String tagline;
  final BusinessTemplate template;
  final List<ServicePackage> packages;
  final String warranty;
  final List<String> terms;
  final List<String> notes;
}

class QuotationLine {
  const QuotationLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.unit,
  });

  final String name;
  final double quantity;
  final double unitPrice;
  final String unit;

  double get total => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'unit': unit,
    };
  }

  factory QuotationLine.fromMap(Map<dynamic, dynamic> map) {
    return QuotationLine(
      name: map['name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      unit: map['unit'] as String? ?? 'unit',
    );
  }
}

class GeneratedQuotation {
  const GeneratedQuotation({
    required this.quotationNo,
    required this.clientName,
    required this.category,
    required this.packageName,
    required this.templateName,
    required this.generatedDate,
    required this.lineItems,
    required this.optionalItems,
    required this.subtotal,
    required this.grandTotal,
    required this.warranty,
    required this.terms,
    required this.globalSections,
    required this.placeholderValues,
    required this.renderedTemplate,
    this.isInvoice = false,
    this.invoiceNo = '',
    this.paymentReceived = 0,
    this.remainingPayment = 0,
  });

  final String quotationNo;
  final String clientName;
  final ServiceCategory category;
  final String packageName;
  final String templateName;
  final DateTime generatedDate;
  final List<QuotationLine> lineItems;
  final List<OptionalItem> optionalItems;
  final double subtotal;
  final double grandTotal;
  final String warranty;
  final List<String> terms;
  final List<InvoicePolicySection> globalSections;
  final Map<String, String> placeholderValues;
  final String renderedTemplate;
  final bool isInvoice;
  final String invoiceNo;
  final double paymentReceived;
  final double remainingPayment;

  GeneratedQuotation copyWith({
    bool? isInvoice,
    String? invoiceNo,
    double? paymentReceived,
    double? remainingPayment,
    Map<String, String>? placeholderValues,
  }) {
    return GeneratedQuotation(
      quotationNo: quotationNo,
      clientName: clientName,
      category: category,
      packageName: packageName,
      templateName: templateName,
      generatedDate: generatedDate,
      lineItems: lineItems,
      optionalItems: optionalItems,
      subtotal: subtotal,
      grandTotal: grandTotal,
      warranty: warranty,
      terms: terms,
      globalSections: globalSections,
      placeholderValues: placeholderValues ?? this.placeholderValues,
      renderedTemplate: renderedTemplate,
      isInvoice: isInvoice ?? this.isInvoice,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      paymentReceived: paymentReceived ?? this.paymentReceived,
      remainingPayment: remainingPayment ?? this.remainingPayment,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quotationNo': quotationNo,
      'clientName': clientName,
      'category': category.name,
      'packageName': packageName,
      'templateName': templateName,
      'generatedDate': generatedDate.toIso8601String(),
      'lineItems': lineItems.map((item) => item.toMap()).toList(),
      'optionalItems': optionalItems.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'grandTotal': grandTotal,
      'warranty': warranty,
      'terms': terms,
      'globalSections': globalSections
          .map((section) => {'title': section.title, 'items': section.items})
          .toList(),
      'placeholderValues': placeholderValues,
      'renderedTemplate': renderedTemplate,
      'isInvoice': isInvoice,
      'invoiceNo': invoiceNo,
      'paymentReceived': paymentReceived,
      'remainingPayment': remainingPayment,
    };
  }

  factory GeneratedQuotation.fromMap(Map<dynamic, dynamic> map) {
    return GeneratedQuotation(
      quotationNo: map['quotationNo'] as String? ?? '',
      clientName: map['clientName'] as String? ?? '',
      category: ServiceCategory.values.firstWhere(
        (item) => item.name == map['category'],
        orElse: () => ServiceCategory.electricFence,
      ),
      packageName: map['packageName'] as String? ?? '',
      templateName: map['templateName'] as String? ?? '',
      generatedDate:
          DateTime.tryParse(map['generatedDate'] as String? ?? '') ??
          DateTime.now(),
      lineItems: (map['lineItems'] as List<dynamic>? ?? const [])
          .map((item) => QuotationLine.fromMap(item as Map<dynamic, dynamic>))
          .toList(),
      optionalItems: (map['optionalItems'] as List<dynamic>? ?? const [])
          .map((item) => OptionalItem.fromMap(item as Map<dynamic, dynamic>))
          .toList(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      grandTotal: (map['grandTotal'] as num?)?.toDouble() ?? 0,
      warranty: map['warranty'] as String? ?? '',
      terms: (map['terms'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      globalSections: (map['globalSections'] as List<dynamic>? ?? const [])
          .map(
            (section) => InvoicePolicySection(
              title:
                  (section as Map<dynamic, dynamic>)['title'] as String? ?? '',
              items: (section['items'] as List<dynamic>? ?? const [])
                  .map((item) => item.toString())
                  .toList(),
            ),
          )
          .toList(),
      placeholderValues:
          (map['placeholderValues'] as Map<dynamic, dynamic>? ?? const {}).map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
      renderedTemplate: map['renderedTemplate'] as String? ?? '',
      isInvoice: map['isInvoice'] as bool? ?? false,
      invoiceNo: map['invoiceNo'] as String? ?? '',
      paymentReceived: (map['paymentReceived'] as num?)?.toDouble() ?? 0,
      remainingPayment: (map['remainingPayment'] as num?)?.toDouble() ?? 0,
    );
  }
}

class InvoicePolicySection {
  const InvoicePolicySection({required this.title, required this.items});

  final String title;
  final List<String> items;

  InvoicePolicySection copyWith({String? title, List<String>? items}) {
    return InvoicePolicySection(
      title: title ?? this.title,
      items: items ?? this.items,
    );
  }
}

class InvoiceRecord {
  const InvoiceRecord({
    required this.id,
    required this.quotationNo,
    required this.parentQuotationNo,
    required this.isInvoice,
    required this.invoiceNo,
    required this.clientName,
    required this.category,
    required this.packageName,
    required this.total,
    required this.paymentReceived,
    required this.remainingPayment,
    required this.generatedAt,
    required this.renderedTemplate,
    required this.document,
  });

  final String id;
  final String quotationNo;
  final String parentQuotationNo;
  final bool isInvoice;
  final String invoiceNo;
  final String clientName;
  final ServiceCategory category;
  final String packageName;
  final double total;
  final double paymentReceived;
  final double remainingPayment;
  final DateTime generatedAt;
  final String renderedTemplate;
  final GeneratedQuotation document;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quotationNo': quotationNo,
      'parentQuotationNo': parentQuotationNo,
      'isInvoice': isInvoice,
      'invoiceNo': invoiceNo,
      'clientName': clientName,
      'category': category.name,
      'packageName': packageName,
      'total': total,
      'paymentReceived': paymentReceived,
      'remainingPayment': remainingPayment,
      'generatedAt': generatedAt.toIso8601String(),
      'renderedTemplate': renderedTemplate,
      'document': document.toMap(),
    };
  }

  factory InvoiceRecord.fromMap(Map<dynamic, dynamic> map) {
    final category = ServiceCategory.values.firstWhere(
      (item) => item.name == map['category'],
      orElse: () => ServiceCategory.electricFence,
    );
    final quotationNo = map['quotationNo'] as String? ?? '';
    final invoiceNo = map['invoiceNo'] as String? ?? '';
    final clientName = map['clientName'] as String? ?? '';
    final packageName = map['packageName'] as String? ?? '';
    final total = (map['total'] as num?)?.toDouble() ?? 0;
    final paymentReceived = (map['paymentReceived'] as num?)?.toDouble() ?? 0;
    final remainingPayment = (map['remainingPayment'] as num?)?.toDouble() ?? 0;
    final generatedAt =
        DateTime.tryParse(map['generatedAt'] as String? ?? '') ??
        DateTime.now();
    final documentMap = map['document'] as Map<dynamic, dynamic>?;

    return InvoiceRecord(
      id: map['id'] as String? ?? '',
      quotationNo: quotationNo,
      parentQuotationNo: map['parentQuotationNo'] as String? ?? quotationNo,
      isInvoice: map['isInvoice'] as bool? ?? false,
      invoiceNo: invoiceNo,
      clientName: clientName,
      category: category,
      packageName: packageName,
      total: total,
      paymentReceived: paymentReceived,
      remainingPayment: remainingPayment,
      generatedAt: generatedAt,
      renderedTemplate: map['renderedTemplate'] as String? ?? '',
      document: documentMap != null
          ? GeneratedQuotation.fromMap(documentMap)
          : GeneratedQuotation(
              quotationNo: quotationNo,
              clientName: clientName,
              category: category,
              packageName: packageName,
              templateName: '',
              generatedDate: generatedAt,
              lineItems: const [],
              optionalItems: const [],
              subtotal: total,
              grandTotal: total,
              warranty: '',
              terms: const [],
              globalSections: const [],
              placeholderValues: const {},
              renderedTemplate: map['renderedTemplate'] as String? ?? '',
              isInvoice: map['isInvoice'] as bool? ?? false,
              invoiceNo: invoiceNo,
              paymentReceived: paymentReceived,
              remainingPayment: remainingPayment,
            ),
    );
  }
}

class DashboardMetric {
  const DashboardMetric({
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final String value;
  final String delta;
}

class InventoryItem {
  const InventoryItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.supplier,
  });

  final String name;
  final int quantity;
  final double price;
  final String supplier;

  bool get isLowStock => quantity < 10;
}

class ClientRecord {
  const ClientRecord({
    required this.name,
    required this.phone,
    required this.address,
    required this.projectType,
    required this.paymentStatus,
    required this.previousHistory,
  });

  final String name;
  final String phone;
  final String address;
  final String projectType;
  final String paymentStatus;
  final String previousHistory;
}

/// Represents a template file uploaded by the user from their device.
class UploadedTemplate {
  const UploadedTemplate({
    required this.fileName,
    required this.fileExtension,
    required this.rawContent,
    required this.placeholders,
  });

  final String fileName;
  final String fileExtension; // e.g. 'html', 'txt', 'htm'
  final String rawContent;
  final Set<String> placeholders;

  String render(Map<String, String> values) {
    final regex = RegExp(r'{{\s*([a-zA-Z0-9_]+)\s*}}');
    return rawContent.replaceAllMapped(regex, (match) {
      final key = match.group(1);
      return values[key] ?? match.group(0) ?? '';
    });
  }
}

const firestoreCollections = <String>[
  'templates',
  'services',
  'products',
  'packages',
  'quotations',
  'clients',
  'settings',
  'users',
];
