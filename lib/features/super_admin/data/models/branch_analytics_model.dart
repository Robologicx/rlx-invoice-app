import 'package:cloud_firestore/cloud_firestore.dart';

class BranchAnalytics {
  const BranchAnalytics({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.month,
    required this.year,
    required this.totalSales,
    required this.invoiceCount,
    required this.quotationCount,
    required this.projectCount,
    required this.profit,
    required this.receivables,
    required this.inventoryValue,
    required this.updatedAt,
  });

  final String id;
  final String branchId;
  final String branchName;
  final int month; // 1-12
  final int year;
  final double totalSales;
  final int invoiceCount;
  final int quotationCount;
  final int projectCount;
  final double profit;
  final double receivables; // Outstanding amounts
  final double inventoryValue;
  final DateTime updatedAt;

  String get monthYear => '$month/$year';

  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'branchName': branchName,
      'month': month,
      'year': year,
      'totalSales': totalSales,
      'invoiceCount': invoiceCount,
      'quotationCount': quotationCount,
      'projectCount': projectCount,
      'profit': profit,
      'receivables': receivables,
      'inventoryValue': inventoryValue,
      'updatedAt': updatedAt,
    };
  }

  factory BranchAnalytics.fromMap(Map<String, dynamic> map, String id) {
    return BranchAnalytics(
      id: id,
      branchId: map['branchId'] as String? ?? '',
      branchName: map['branchName'] as String? ?? '',
      month: map['month'] as int? ?? 1,
      year: map['year'] as int? ?? DateTime.now().year,
      totalSales: (map['totalSales'] as num?)?.toDouble() ?? 0.0,
      invoiceCount: map['invoiceCount'] as int? ?? 0,
      quotationCount: map['quotationCount'] as int? ?? 0,
      projectCount: map['projectCount'] as int? ?? 0,
      profit: (map['profit'] as num?)?.toDouble() ?? 0.0,
      receivables: (map['receivables'] as num?)?.toDouble() ?? 0.0,
      inventoryValue: (map['inventoryValue'] as num?)?.toDouble() ?? 0.0,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  BranchAnalytics copyWith({
    double? totalSales,
    int? invoiceCount,
    int? quotationCount,
    int? projectCount,
    double? profit,
    double? receivables,
    double? inventoryValue,
  }) {
    return BranchAnalytics(
      id: id,
      branchId: branchId,
      branchName: branchName,
      month: month,
      year: year,
      totalSales: totalSales ?? this.totalSales,
      invoiceCount: invoiceCount ?? this.invoiceCount,
      quotationCount: quotationCount ?? this.quotationCount,
      projectCount: projectCount ?? this.projectCount,
      profit: profit ?? this.profit,
      receivables: receivables ?? this.receivables,
      inventoryValue: inventoryValue ?? this.inventoryValue,
      updatedAt: DateTime.now(),
    );
  }
}
