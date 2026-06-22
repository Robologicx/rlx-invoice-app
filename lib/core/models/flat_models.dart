import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// Flat Firestore model layer
// Each top-level collection carries a [franchiseId] for tenant isolation.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Franchise  →  Firestore: branches/{franchiseId}
// ---------------------------------------------------------------------------
class FranchiseModel {
  const FranchiseModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.phone,
    required this.ownerName,
    this.royaltyPercentage = 7,
    this.status = 'active',
    this.type = 'franchisee',
    this.mainBranchId,
    this.createdAt,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final String phone;
  final String ownerName;
  final double royaltyPercentage;
  final String status;
  final String type;
  final String? mainBranchId;
  final DateTime? createdAt;

  factory FranchiseModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return FranchiseModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      city: data['city'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      royaltyPercentage: (data['royaltyPercentage'] as num?)?.toDouble() ?? 7.0,
      status: data['status'] as String? ?? 'active',
      type: data['type'] as String? ?? 'franchisee',
      mainBranchId: data['mainBranchId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'address': address,
    'city': city,
    'phone': phone,
    'ownerName': ownerName,
    'royaltyPercentage': royaltyPercentage,
    'status': status,
    'type': type,
    'mainBranchId': mainBranchId,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };
}

// ---------------------------------------------------------------------------
// AppUserProfile  →  Firestore: users/{uid}   (profile only, no business data)
// ---------------------------------------------------------------------------
class AppUserProfile {
  const AppUserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.branchId,
    this.phone,
    this.isDisabled = false,
  });

  final String uid;
  final String email;
  final String displayName;

  /// 'super_admin' | 'branch_admin' | 'staff'
  final String role;

  /// null for super admin / main branch owner
  final String? branchId;
  final String? phone;
  final bool isDisabled;

  /// The franchise this user belongs to.
  /// Falls back to uid so that standalone (non-franchised) installs still work.
  String get franchiseId =>
      (branchId != null && branchId!.isNotEmpty) ? branchId! : uid;

  factory AppUserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return AppUserProfile(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: data['role'] as String? ?? 'branch_admin',
      branchId: data['branchId'] as String?,
      phone: data['phone'] as String?,
      isDisabled: data['isDisabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'role': role,
    'branchId': branchId,
    'phone': phone,
    'isDisabled': isDisabled,
  };
}

// ---------------------------------------------------------------------------
// ProductModel  →  Firestore: products/{productId}
// ---------------------------------------------------------------------------
class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.franchiseId,
    this.threshold = 10,
    this.supplier = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final int quantity;
  final double unitPrice;
  final int threshold;
  final String supplier;
  final String franchiseId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLowStock => quantity < threshold;

  double get totalValue => quantity * unitPrice;

  ProductModel copyWith({
    String? id,
    String? name,
    int? quantity,
    double? unitPrice,
    int? threshold,
    String? supplier,
    String? franchiseId,
  }) => ProductModel(
    id: id ?? this.id,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    threshold: threshold ?? this.threshold,
    supplier: supplier ?? this.supplier,
    franchiseId: franchiseId ?? this.franchiseId,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );

  factory ProductModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ProductModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
      threshold: (data['threshold'] as num?)?.toInt() ?? 10,
      supplier: data['supplier'] as String? ?? '',
      franchiseId: data['franchiseId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ProductModel.fromMap(Map<dynamic, dynamic> data, {String? docId}) {
    final id = docId ?? data['id'] as String? ?? '';
    return ProductModel(
      id: id,
      name: data['name'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      unitPrice:
          (data['unitPrice'] as num?)?.toDouble() ??
          (data['price'] as num?)?.toDouble() ??
          0,
      threshold:
          (data['threshold'] as num?)?.toInt() ??
          (data['minQuantity'] as num?)?.toInt() ??
          10,
      supplier: data['supplier'] as String? ?? '',
      franchiseId: data['franchiseId'] as String? ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'threshold': threshold,
    'supplier': supplier,
    'franchiseId': franchiseId,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

// ---------------------------------------------------------------------------
// StockMovementModel  →  Firestore: movements/{movementId}  (append-only)
// ---------------------------------------------------------------------------
class StockMovementModel {
  const StockMovementModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.previousQuantity,
    required this.newQuantity,
    required this.franchiseId,
    this.reason = '',
    this.createdAt,
  });

  final String id;
  final String productId;
  final String productName;

  /// 'in' | 'out' | 'adjustment' | 'add' | 'remove' | 'update' | 'reorder'
  final String type;
  final int quantity;
  final int previousQuantity;
  final int newQuantity;
  final String franchiseId;
  final String reason;
  final DateTime? createdAt;

  factory StockMovementModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return StockMovementModel(
      id: doc.id,
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      type: data['type'] as String? ?? 'adjustment',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      previousQuantity: (data['previousQuantity'] as num?)?.toInt() ?? 0,
      newQuantity: (data['newQuantity'] as num?)?.toInt() ?? 0,
      franchiseId: data['franchiseId'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory StockMovementModel.fromMap(
    Map<dynamic, dynamic> data, {
    required String franchiseId,
  }) {
    return StockMovementModel(
      id: data['id'] as String? ?? '',
      productId:
          data['productId'] as String? ?? data['itemId'] as String? ?? '',
      productName:
          data['productName'] as String? ?? data['itemName'] as String? ?? '',
      type: data['type'] as String? ?? 'adjustment',
      quantity:
          (data['quantity'] as num?)?.toInt() ??
          (data['quantityChange'] as num?)?.toInt() ??
          0,
      previousQuantity: (data['previousQuantity'] as num?)?.toInt() ?? 0,
      newQuantity: (data['newQuantity'] as num?)?.toInt() ?? 0,
      franchiseId: franchiseId,
      reason: data['reason'] as String? ?? data['note'] as String? ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'productId': productId,
    'productName': productName,
    'type': type,
    'quantity': quantity,
    'previousQuantity': previousQuantity,
    'newQuantity': newQuantity,
    'franchiseId': franchiseId,
    'reason': reason,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };
}

// ---------------------------------------------------------------------------
// FlatInvoiceModel  →  Firestore: invoices/{invoiceId}
// ---------------------------------------------------------------------------
class FlatInvoiceModel {
  const FlatInvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.clientName,
    required this.items,
    required this.grandTotal,
    required this.franchiseId,
    this.paymentReceived = 0,
    this.remainingPayment = 0,
    this.status = 'pending',
    this.quotationNo = '',
    this.isInvoice = true,
    this.renderedTemplate = '',
    this.createdAt,
  });

  final String id;
  final String invoiceNumber;
  final String clientName;
  final List<Map<String, dynamic>> items;
  final double grandTotal;
  final double paymentReceived;
  final double remainingPayment;
  final String franchiseId;
  final String status;
  final String quotationNo;
  final bool isInvoice;
  final String renderedTemplate;
  final DateTime? createdAt;

  factory FlatInvoiceModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return FlatInvoiceModel(
      id: doc.id,
      invoiceNumber: data['invoiceNumber'] as String? ?? doc.id,
      clientName: data['clientName'] as String? ?? '',
      items:
          (data['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          const [],
      grandTotal: (data['grandTotal'] as num?)?.toDouble() ?? 0,
      paymentReceived: (data['paymentReceived'] as num?)?.toDouble() ?? 0,
      remainingPayment: (data['remainingPayment'] as num?)?.toDouble() ?? 0,
      franchiseId: data['franchiseId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      quotationNo: data['quotationNo'] as String? ?? '',
      isInvoice: data['isInvoice'] as bool? ?? true,
      renderedTemplate: data['renderedTemplate'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'invoiceNumber': invoiceNumber,
    'clientName': clientName,
    'items': items,
    'grandTotal': grandTotal,
    'paymentReceived': paymentReceived,
    'remainingPayment': remainingPayment,
    'franchiseId': franchiseId,
    'status': status,
    'quotationNo': quotationNo,
    'isInvoice': isInvoice,
    'renderedTemplate': renderedTemplate,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };
}

// ---------------------------------------------------------------------------
// FlatExpenseModel  →  Firestore: expenses/{expenseId}
// ---------------------------------------------------------------------------
class FlatExpenseModel {
  const FlatExpenseModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.franchiseId,
    this.expenseDate,
    this.note = '',
    this.createdAt,
  });

  final String id;
  final String description;
  final double amount;
  final String category;
  final String franchiseId;
  final DateTime? expenseDate;
  final String note;
  final DateTime? createdAt;

  factory FlatExpenseModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return FlatExpenseModel(
      id: doc.id,
      description: data['description'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      category: data['category'] as String? ?? 'General',
      franchiseId: data['franchiseId'] as String? ?? '',
      expenseDate: (data['expenseDate'] as Timestamp?)?.toDate(),
      note: data['note'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'description': description,
    'amount': amount,
    'category': category,
    'franchiseId': franchiseId,
    'expenseDate': expenseDate != null
        ? Timestamp.fromDate(expenseDate!)
        : FieldValue.serverTimestamp(),
    'note': note,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };
}
