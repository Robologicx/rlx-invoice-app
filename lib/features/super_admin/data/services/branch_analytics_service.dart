import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

class BranchAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AnalyticsRepository _analyticsRepo;

  BranchAnalyticsService({required AnalyticsRepository analyticsRepo})
    : _analyticsRepo = analyticsRepo;

  /// Generate analytics for all branches for current month
  Future<void> generateCurrentMonthAnalytics() async {
    try {
      final now = DateTime.now();
      await generateMonthAnalytics(now.month, now.year);
    } catch (e) {
      throw 'Error generating current month analytics: $e';
    }
  }

  /// Generate analytics for a specific month/year
  Future<void> generateMonthAnalytics(int month, int year) async {
    try {
      // Get all branches
      final branchesSnapshot = await _firestore.collection('branches').get();

      for (final branchDoc in branchesSnapshot.docs) {
        final branchId = branchDoc.id;
        final branchData = branchDoc.data();
        final branchName = branchData['name'] as String?;

        // Get analytics data for this branch
        final analytics = await _calculateBranchAnalytics(
          branchId,
          branchName ?? '',
          month,
          year,
        );

        // Store in Firestore
        if (analytics != null) {
          await _analyticsRepo.upsertAnalytics(analytics);
        }
      }
    } catch (e) {
      throw 'Error generating month analytics: $e';
    }
  }

  /// Calculate analytics for a specific branch
  Future<BranchAnalytics?> _calculateBranchAnalytics(
    String branchId,
    String branchName,
    int month,
    int year,
  ) async {
    try {
      // Get all users with this branchId
      final usersSnapshot = await _firestore
          .collection('users')
          .where('branchId', isEqualTo: branchId)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        return null;
      }

      double totalSales = 0.0;
      int invoiceCount = 0;
      int quotationCount = 0;
      int projectCount = 0;
      double totalProfit = 0.0;
      double totalReceivables = 0.0;
      double totalInventoryValue = 0.0;

      // Aggregate data from all users in this branch
      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;

        // Get all invoices for this user
        final invoicesSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('data')
            .where('type', isEqualTo: 'invoice')
            .where('branchId', isEqualTo: branchId)
            .get();

        for (final invoiceDoc in invoicesSnapshot.docs) {
          final data = invoiceDoc.data();
          final amount = (data['total'] as num?)?.toDouble() ?? 0.0;
          totalSales += amount;

          // Track receivables (unpaid invoices)
          if (data['status'] != 'paid') {
            totalReceivables += amount;
          }
        }

        invoiceCount += invoicesSnapshot.size;

        // Get quotations
        final quotationsSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('data')
            .where('type', isEqualTo: 'quotation')
            .where('branchId', isEqualTo: branchId)
            .get();

        quotationCount += quotationsSnapshot.size;

        // Get projects
        final projectsSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('data')
            .where('type', isEqualTo: 'project')
            .where('branchId', isEqualTo: branchId)
            .get();

        projectCount += projectsSnapshot.size;

        // Get inventory value
        final inventorySnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('data')
            .where('type', isEqualTo: 'inventory')
            .where('branchId', isEqualTo: branchId)
            .get();

        for (final inventoryDoc in inventorySnapshot.docs) {
          final data = inventoryDoc.data();
          final quantity = (data['quantity'] as num?)?.toDouble() ?? 0.0;
          final unitPrice = (data['unitPrice'] as num?)?.toDouble() ?? 0.0;
          totalInventoryValue += quantity * unitPrice;
        }

        // Calculate profit from finance data
        final financeSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('data')
            .where('type', isEqualTo: 'finance')
            .where('branchId', isEqualTo: branchId)
            .get();

        for (final financeDoc in financeSnapshot.docs) {
          final data = financeDoc.data();
          if (data['category'] == 'profit') {
            totalProfit += (data['amount'] as num?)?.toDouble() ?? 0.0;
          } else if (data['category'] == 'expense') {
            totalProfit -= (data['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }

      return BranchAnalytics(
        id: '${branchId}_${year}_${month.toString().padLeft(2, '0')}',
        branchId: branchId,
        branchName: branchName,
        month: month,
        year: year,
        totalSales: totalSales,
        invoiceCount: invoiceCount,
        quotationCount: quotationCount,
        projectCount: projectCount,
        profit: totalProfit,
        receivables: totalReceivables,
        inventoryValue: totalInventoryValue,
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get profit margin for a branch
  Future<double> getBranchProfitMargin(
    String branchId,
    int month,
    int year,
  ) async {
    try {
      final analytics = await _analyticsRepo.getBranchMonthAnalytics(
        branchId,
        month,
        year,
      );
      if (analytics == null || analytics.totalSales == 0) return 0.0;

      return (analytics.profit / analytics.totalSales) * 100;
    } catch (e) {
      throw 'Error calculating profit margin: $e';
    }
  }

  /// Get average transaction value for a branch
  Future<double> getBranchAvgTransaction(
    String branchId,
    int month,
    int year,
  ) async {
    try {
      final analytics = await _analyticsRepo.getBranchMonthAnalytics(
        branchId,
        month,
        year,
      );
      if (analytics == null || analytics.invoiceCount == 0) return 0.0;

      return analytics.totalSales / analytics.invoiceCount;
    } catch (e) {
      throw 'Error calculating average transaction: $e';
    }
  }

  /// Compare branches performance
  Future<List<BranchComparison>> compareBranchesPerformance(
    int month,
    int year,
  ) async {
    try {
      final analyticsList = await _firestore
          .collection('branch_analytics')
          .where('month', isEqualTo: month)
          .where('year', isEqualTo: year)
          .get();

      final comparisons = <BranchComparison>[];

      for (final doc in analyticsList.docs) {
        final data = BranchAnalytics.fromMap(doc.data(), doc.id);

        final profitMargin = data.totalSales > 0
            ? (data.profit / data.totalSales) * 100
            : 0.0;
        final avgTransaction = data.invoiceCount > 0
            ? data.totalSales / data.invoiceCount
            : 0.0;

        comparisons.add(
          BranchComparison(
            branchName: data.branchName,
            totalSales: data.totalSales,
            invoiceCount: data.invoiceCount,
            profitMargin: profitMargin,
            avgTransaction: avgTransaction,
            inventoryValue: data.inventoryValue,
            receivables: data.receivables,
          ),
        );
      }

      // Sort by sales descending
      comparisons.sort((a, b) => b.totalSales.compareTo(a.totalSales));

      return comparisons;
    } catch (e) {
      throw 'Error comparing branches: $e';
    }
  }
}

/// Model for branch comparison
class BranchComparison {
  final String branchName;
  final double totalSales;
  final int invoiceCount;
  final double profitMargin; // Percentage
  final double avgTransaction;
  final double inventoryValue;
  final double receivables;

  BranchComparison({
    required this.branchName,
    required this.totalSales,
    required this.invoiceCount,
    required this.profitMargin,
    required this.avgTransaction,
    required this.inventoryValue,
    required this.receivables,
  });
}
