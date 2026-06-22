import 'package:cloud_firestore/cloud_firestore.dart';

enum BranchType { main, franchise }

extension BranchTypeX on BranchType {
  String get label => this == BranchType.main ? 'Main Branch' : 'Franchise';

  String get key => this == BranchType.main ? 'main' : 'franchise';

  static BranchType fromKey(String? raw) {
    switch (raw) {
      case 'main':
        return BranchType.main;
      case 'franchise':
        return BranchType.franchise;
      default:
        return BranchType.franchise;
    }
  }
}

enum BranchStatus { active, suspended, closed }

extension BranchStatusX on BranchStatus {
  String get label => switch (this) {
    BranchStatus.active => 'Active',
    BranchStatus.suspended => 'Suspended',
    BranchStatus.closed => 'Closed',
  };

  String get key => switch (this) {
    BranchStatus.active => 'active',
    BranchStatus.suspended => 'suspended',
    BranchStatus.closed => 'closed',
  };

  static BranchStatus fromKey(String? raw) {
    switch (raw) {
      case 'active':
        return BranchStatus.active;
      case 'suspended':
        return BranchStatus.suspended;
      case 'closed':
        return BranchStatus.closed;
      default:
        return BranchStatus.active;
    }
  }
}

class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.code,
    required this.city,
    required this.type,
    required this.ownerName,
    required this.phone,
    required this.email,
    required this.address,
    required this.royaltyPercentage,
    required this.status,
    this.loginEmail,
    this.authUid,
    this.mainBranchId,
    required this.createdAt,
    required this.createdBy,
  });

  final String id;
  final String name;
  final String code; // e.g., "KHI", "RYK"
  final String city;
  final BranchType type;
  final String ownerName;
  final String phone;
  final String email;
  final String address;
  final double royaltyPercentage; // e.g., 5.0, 7.0, 0.0 for main
  final BranchStatus status;
  final String? loginEmail;
  final String? authUid;
  final String?
  mainBranchId; // If this is a franchise, reference to main branch
  final DateTime createdAt;
  final String createdBy;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'city': city,
      'type': type.key,
      'ownerName': ownerName,
      'phone': phone,
      'email': email,
      'address': address,
      'royaltyPercentage': royaltyPercentage,
      'status': status.key,
      'loginEmail': loginEmail,
      'authUid': authUid,
      'mainBranchId': mainBranchId,
      'createdAt': createdAt,
      'createdBy': createdBy,
    };
  }

  factory Branch.fromMap(Map<String, dynamic> map, String id) {
    return Branch(
      id: id,
      name: map['name'] as String? ?? '',
      code: map['code'] as String? ?? '',
      city: map['city'] as String? ?? '',
      type: BranchTypeX.fromKey(map['type'] as String?),
      ownerName: map['ownerName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      address: map['address'] as String? ?? '',
      royaltyPercentage: (map['royaltyPercentage'] as num?)?.toDouble() ?? 0.0,
      status: BranchStatusX.fromKey(map['status'] as String?),
      loginEmail: map['loginEmail'] as String?,
      authUid: map['authUid'] as String?,
      mainBranchId: map['mainBranchId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] as String? ?? '',
    );
  }

  Branch copyWith({
    String? name,
    String? code,
    String? city,
    BranchType? type,
    String? ownerName,
    String? phone,
    String? email,
    String? address,
    double? royaltyPercentage,
    BranchStatus? status,
    String? loginEmail,
    String? authUid,
    String? mainBranchId,
  }) {
    return Branch(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      city: city ?? this.city,
      type: type ?? this.type,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      royaltyPercentage: royaltyPercentage ?? this.royaltyPercentage,
      status: status ?? this.status,
      loginEmail: loginEmail ?? this.loginEmail,
      authUid: authUid ?? this.authUid,
      mainBranchId: mainBranchId ?? this.mainBranchId,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }
}
