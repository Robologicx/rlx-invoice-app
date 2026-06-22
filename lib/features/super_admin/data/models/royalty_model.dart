import 'package:cloud_firestore/cloud_firestore.dart';

enum RoyaltyStatus { pending, partiallyPaid, paid }

extension RoyaltyStatusX on RoyaltyStatus {
  String get label => switch (this) {
    RoyaltyStatus.pending => 'Pending',
    RoyaltyStatus.partiallyPaid => 'Partially Paid',
    RoyaltyStatus.paid => 'Paid',
  };

  String get key => switch (this) {
    RoyaltyStatus.pending => 'pending',
    RoyaltyStatus.partiallyPaid => 'partiallyPaid',
    RoyaltyStatus.paid => 'paid',
  };

  static RoyaltyStatus fromKey(String? raw) {
    switch (raw) {
      case 'pending':
        return RoyaltyStatus.pending;
      case 'partiallyPaid':
        return RoyaltyStatus.partiallyPaid;
      case 'paid':
        return RoyaltyStatus.paid;
      default:
        return RoyaltyStatus.pending;
    }
  }
}

class Royalty {
  const Royalty({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.month,
    required this.year,
    required this.totalSales,
    required this.royaltyPercentage,
    required this.royaltyAmount,
    required this.paidAmount,
    required this.status,
    this.paymentDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String branchId;
  final String branchName;
  final int month; // 1-12
  final int year; // e.g., 2026
  final double totalSales;
  final double royaltyPercentage;
  final double royaltyAmount;
  final double paidAmount;
  final RoyaltyStatus status;
  final DateTime? paymentDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get remainingBalance => royaltyAmount - paidAmount;

  String get monthYear => '$month/$year';

  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'branchName': branchName,
      'month': month,
      'year': year,
      'totalSales': totalSales,
      'royaltyPercentage': royaltyPercentage,
      'royaltyAmount': royaltyAmount,
      'paidAmount': paidAmount,
      'status': status.key,
      'paymentDate': paymentDate,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Royalty.fromMap(Map<String, dynamic> map, String id) {
    return Royalty(
      id: id,
      branchId: map['branchId'] as String? ?? '',
      branchName: map['branchName'] as String? ?? '',
      month: map['month'] as int? ?? 1,
      year: map['year'] as int? ?? DateTime.now().year,
      totalSales: (map['totalSales'] as num?)?.toDouble() ?? 0.0,
      royaltyPercentage: (map['royaltyPercentage'] as num?)?.toDouble() ?? 0.0,
      royaltyAmount: (map['royaltyAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      status: RoyaltyStatusX.fromKey(map['status'] as String?),
      paymentDate: (map['paymentDate'] as Timestamp?)?.toDate(),
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Royalty copyWith({
    double? paidAmount,
    double? royaltyPercentage,
    double? royaltyAmount,
    RoyaltyStatus? status,
    DateTime? paymentDate,
    String? notes,
  }) {
    return Royalty(
      id: id,
      branchId: branchId,
      branchName: branchName,
      month: month,
      year: year,
      totalSales: totalSales,
      royaltyPercentage: royaltyPercentage ?? this.royaltyPercentage,
      royaltyAmount: royaltyAmount ?? this.royaltyAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      paymentDate: paymentDate ?? this.paymentDate,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
