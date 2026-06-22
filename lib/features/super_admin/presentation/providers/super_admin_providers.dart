import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/repositories.dart';
import '../../data/models/models.dart';

// Repository providers
final branchRepositoryProvider = Provider((ref) => BranchRepository());

final royaltyRepositoryProvider = Provider((ref) => RoyaltyRepository());

final analyticsRepositoryProvider = Provider((ref) => AnalyticsRepository());

// Branch providers
final allBranchesProvider = StreamProvider((ref) {
  final repo = ref.watch(branchRepositoryProvider);
  return repo.streamAllBranches();
});

final activeBranchesProvider = FutureProvider((ref) {
  final repo = ref.watch(branchRepositoryProvider);
  return repo.getBranchesByStatus(BranchStatus.active);
});

final branchByIdProvider = StreamProvider.family((ref, String branchId) {
  final repo = ref.watch(branchRepositoryProvider);
  return repo.streamBranch(branchId);
});

final totalActiveBranchesProvider = FutureProvider((ref) {
  final repo = ref.watch(branchRepositoryProvider);
  return repo.getTotalActiveBranches();
});

final mainBranchProvider = FutureProvider((ref) {
  final repo = ref.watch(branchRepositoryProvider);
  return repo.getMainBranch();
});

final franchiseBranchesProvider = FutureProvider((ref) {
  final repo = ref.watch(branchRepositoryProvider);
  return repo.getFranchiseBranches();
});

// Royalty providers
final allRoyaltiesProvider = StreamProvider((ref) {
  final repo = ref.watch(royaltyRepositoryProvider);
  return repo.streamAllRoyalties();
});

final branchRoyaltiesProvider = StreamProvider.family((ref, String branchId) {
  final repo = ref.watch(royaltyRepositoryProvider);
  return repo.streamBranchRoyalties(branchId);
});

final monthlyRoyaltiesProvider = FutureProvider.family((
  ref,
  (int, int) params,
) {
  final repo = ref.watch(royaltyRepositoryProvider);
  return repo.getMonthlyRoyalties(params.$1, params.$2);
});

final pendingRoyaltiesProvider = FutureProvider((ref) {
  final repo = ref.watch(royaltyRepositoryProvider);
  return repo.getPendingRoyalties();
});

final totalRoyaltiesDueProvider = StreamProvider<double>((ref) {
  final repo = ref.watch(royaltyRepositoryProvider);
  return repo.streamCurrentMonthRoyaltiesDue();
});

final totalRoyaltiesCollectedProvider = StreamProvider<double>((ref) {
  final repo = ref.watch(royaltyRepositoryProvider);
  return repo.streamTotalRoyaltiesCollected();
});

/// Real-time royalty rows for the current month, computed from live analytics.
final computedCurrentRoyaltiesProvider = StreamProvider<List<Royalty>>((ref) {
  final repo = ref.watch(royaltyRepositoryProvider);
  return repo.streamCurrentMonthComputedRoyalties();
});

// Analytics providers
final currentMonthAnalyticsProvider = FutureProvider((ref) {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getCurrentMonthAnalytics();
});

/// Real-time stream of this month's analytics (auto-computes if empty).
final streamCurrentMonthAnalyticsProvider =
    StreamProvider<List<BranchAnalytics>>((ref) {
      final repo = ref.watch(analyticsRepositoryProvider);
      final now = DateTime.now();
      return repo.streamMonthAnalytics(now.month, now.year);
    });

final branchAnalyticsProvider = StreamProvider.family((ref, String branchId) {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.streamBranchAnalytics(branchId);
});

final totalMonthlySalesProvider = FutureProvider.family((
  ref,
  (int, int) params,
) {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getTotalMonthlySales(params.$1, params.$2);
});

final topBranchesProvider = FutureProvider.family((
  ref,
  (int, int, int) params,
) {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getTopBranches(params.$1, params.$2, limit: params.$3);
});

final totalInventoryValueProvider = FutureProvider((ref) {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getTotalInventoryValue();
});

final totalMonthlyProfitProvider = FutureProvider.family((
  ref,
  (int, int) params,
) {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getTotalMonthlyProfit(params.$1, params.$2);
});
