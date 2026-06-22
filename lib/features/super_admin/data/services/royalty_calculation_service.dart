import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

class RoyaltyCalculationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RoyaltyRepository _royaltyRepo;
  final AnalyticsRepository _analyticsRepo;

  RoyaltyCalculationService({
    required RoyaltyRepository royaltyRepo,
    required AnalyticsRepository analyticsRepo,
  }) : _royaltyRepo = royaltyRepo,
       _analyticsRepo = analyticsRepo;

  /// Calculate and create monthly royalty records for all branches
  Future<void> calculateMonthlyRoyalties(int month, int year) async {
    try {
      // Get current month analytics for all branches
      final analyticsList = await _analyticsRepo.getCurrentMonthAnalytics();

      // Get all branches to get royalty rates
      final branchesSnapshot = await _firestore.collection('branches').get();

      final branchMap = {
        for (var doc in branchesSnapshot.docs) doc.id: doc.data(),
      };

      // Create royalty record for each branch with analytics data
      for (final analytics in analyticsList) {
        final branchData = branchMap[analytics.branchId];
        if (branchData == null) continue;

        final royaltyPercentage =
            (branchData['royaltyPercentage'] as num?)?.toDouble() ?? 0.0;

        // Skip main branch (0% royalty)
        if (royaltyPercentage == 0.0) continue;

        // Calculate royalty amount
        final royaltyAmount = analytics.totalSales * (royaltyPercentage / 100);

        // Create royalty record
        final royalty = Royalty(
          id: '', // Firestore will generate
          branchId: analytics.branchId,
          branchName: analytics.branchName,
          month: month,
          year: year,
          totalSales: analytics.totalSales,
          royaltyPercentage: royaltyPercentage,
          royaltyAmount: royaltyAmount,
          paidAmount: 0.0,
          status: RoyaltyStatus.pending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Check if royalty for this month already exists
        final existingRoyalties = await _royaltyRepo.getMonthlyRoyalties(
          month,
          year,
        );
        final exists = existingRoyalties.any(
          (r) => r.branchId == analytics.branchId,
        );

        if (!exists) {
          await _royaltyRepo.createRoyalty(royalty);
        }
      }
    } catch (e) {
      throw 'Error calculating monthly royalties: $e';
    }
  }

  /// Recalculate royalty for a specific branch and month
  Future<void> recalculateRoyalty(String branchId, int month, int year) async {
    try {
      // Get analytics for this branch/month
      final analytics = await _analyticsRepo.getBranchMonthAnalytics(
        branchId,
        month,
        year,
      );
      if (analytics == null) {
        throw 'No analytics data found for branch $branchId';
      }

      // Get branch data
      final branchDoc = await _firestore
          .collection('branches')
          .doc(branchId)
          .get();
      if (!branchDoc.exists) {
        throw 'Branch not found';
      }

      final branchData = branchDoc.data()!;
      final royaltyPercentage =
          (branchData['royaltyPercentage'] as num?)?.toDouble() ?? 0.0;

      final royaltyAmount = analytics.totalSales * (royaltyPercentage / 100);

      // Get existing royalty record
      final existingRoyalties = await _royaltyRepo.getMonthlyRoyalties(
        month,
        year,
      );
      Royalty? existingRoyalty;
      try {
        existingRoyalty = existingRoyalties.firstWhere(
          (r) => r.branchId == branchId,
        );
      } catch (_) {
        existingRoyalty = null;
      }

      if (existingRoyalty == null) {
        // Create new if doesn't exist
        final newRoyalty = Royalty(
          id: '',
          branchId: branchId,
          branchName: analytics.branchName,
          month: month,
          year: year,
          totalSales: analytics.totalSales,
          royaltyPercentage: royaltyPercentage,
          royaltyAmount: royaltyAmount,
          paidAmount: 0.0,
          status: RoyaltyStatus.pending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _royaltyRepo.createRoyalty(newRoyalty);
      }

      final currentRoyalty = existingRoyalty!;
      final updated = currentRoyalty.copyWith(
        royaltyPercentage: royaltyPercentage,
        royaltyAmount: royaltyAmount,
        status: _calculateStatus(royaltyAmount, currentRoyalty.paidAmount),
      );

      await _royaltyRepo.updateRoyalty(currentRoyalty.id, updated);
    } catch (e) {
      throw 'Error recalculating royalty: $e';
    }
  }

  /// Get royalty summary for a branch
  Future<RoyaltySummary> getBranchRoyaltySummary(String branchId) async {
    try {
      final royalties = await _royaltyRepo.getBranchRoyalties(branchId);

      double totalDue = 0.0;
      double totalPaid = 0.0;
      double totalRemaining = 0.0;

      for (final royalty in royalties) {
        totalDue += royalty.royaltyAmount;
        totalPaid += royalty.paidAmount;
        totalRemaining += royalty.remainingBalance;
      }

      return RoyaltySummary(
        branchId: branchId,
        totalDue: totalDue,
        totalPaid: totalPaid,
        totalRemaining: totalRemaining,
        pendingCount: royalties
            .where((r) => r.status == RoyaltyStatus.pending)
            .length,
      );
    } catch (e) {
      throw 'Error getting royalty summary: $e';
    }
  }

  /// Calculate system-wide royalty summary
  Future<SystemRoyaltySummary> getSystemRoyaltySummary() async {
    try {
      final allRoyalties = await _royaltyRepo.getAllRoyalties();

      double totalDue = 0.0;
      double totalPaid = 0.0;
      double totalRemaining = 0.0;

      for (final royalty in allRoyalties) {
        totalDue += royalty.royaltyAmount;
        totalPaid += royalty.paidAmount;
        totalRemaining += royalty.remainingBalance;
      }

      final pendingCount = allRoyalties
          .where((r) => r.status == RoyaltyStatus.pending)
          .length;
      final partialCount = allRoyalties
          .where((r) => r.status == RoyaltyStatus.partiallyPaid)
          .length;
      final paidCount = allRoyalties
          .where((r) => r.status == RoyaltyStatus.paid)
          .length;

      return SystemRoyaltySummary(
        totalDue: totalDue,
        totalPaid: totalPaid,
        totalRemaining: totalRemaining,
        pendingCount: pendingCount,
        partialCount: partialCount,
        paidCount: paidCount,
      );
    } catch (e) {
      throw 'Error getting system royalty summary: $e';
    }
  }

  RoyaltyStatus _calculateStatus(double due, double paid) {
    if (paid >= due) return RoyaltyStatus.paid;
    if (paid > 0) return RoyaltyStatus.partiallyPaid;
    return RoyaltyStatus.pending;
  }
}

/// Model for branch royalty summary
class RoyaltySummary {
  final String branchId;
  final double totalDue;
  final double totalPaid;
  final double totalRemaining;
  final int pendingCount;

  RoyaltySummary({
    required this.branchId,
    required this.totalDue,
    required this.totalPaid,
    required this.totalRemaining,
    required this.pendingCount,
  });

  double get collectionRate => totalDue > 0 ? (totalPaid / totalDue) * 100 : 0;
}

/// Model for system-wide royalty summary
class SystemRoyaltySummary {
  final double totalDue;
  final double totalPaid;
  final double totalRemaining;
  final int pendingCount;
  final int partialCount;
  final int paidCount;

  SystemRoyaltySummary({
    required this.totalDue,
    required this.totalPaid,
    required this.totalRemaining,
    required this.pendingCount,
    required this.partialCount,
    required this.paidCount,
  });

  double get collectionRate => totalDue > 0 ? (totalPaid / totalDue) * 100 : 0;

  int get totalRecords => pendingCount + partialCount + paidCount;
}
