import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/firebase_auth_service.dart';
import '../../data/models/models.dart';
import '../providers/super_admin_providers.dart';
import '../widgets/dashboard_stats.dart';
import '../widgets/sales_chart.dart';

class SuperAdminDashboard extends ConsumerWidget {
  const SuperAdminDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final allBranches = ref.watch(allBranchesProvider);
    final activeBranches = ref.watch(activeBranchesProvider);
    final totalRoyaltiesDue = ref.watch(totalRoyaltiesDueProvider);
    final totalRoyaltiesCollected = ref.watch(totalRoyaltiesCollectedProvider);
    final totalInventoryValue = ref.watch(totalInventoryValueProvider);
    final liveAnalytics = ref.watch(streamCurrentMonthAnalyticsProvider);
    final monthLabel = DateFormat.yMMMM().format(now);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Super Admin Dashboard'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            tooltip: 'Refresh live values',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(streamCurrentMonthAnalyticsProvider);
              ref.invalidate(totalRoyaltiesDueProvider);
              ref.invalidate(totalRoyaltiesCollectedProvider);
              ref.invalidate(totalInventoryValueProvider);
              ref.invalidate(allBranchesProvider);
              ref.invalidate(activeBranchesProvider);
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(logoutProvider.future);
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(streamCurrentMonthAnalyticsProvider);
          ref.invalidate(totalRoyaltiesDueProvider);
          ref.invalidate(totalRoyaltiesCollectedProvider);
          ref.invalidate(totalInventoryValueProvider);
          ref.invalidate(allBranchesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardStats(
                allBranches: allBranches,
                totalRoyaltiesDue: totalRoyaltiesDue,
                totalRoyaltiesCollected: totalRoyaltiesCollected,
                totalInventoryValue: totalInventoryValue,
              ),
              const SizedBox(height: 24),

              _SectionHeader(title: 'Sales by Franchise - $monthLabel'),
              const SizedBox(height: 8),
              SalesChart(month: now.month, year: now.year),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _SectionHeader(title: 'Top Performing Franchises'),
                  TextButton(
                    onPressed: () => context.go('/super_admin/branches'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              liveAnalytics.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const _EmptyState(message: 'Could not load franchise data'),
                data: (analytics) {
                  return activeBranches.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (branches) {
                      final franchiseIds = branches
                          .where((b) => b.type == BranchType.franchise)
                          .map((b) => b.id)
                          .toSet();

                      if (franchiseIds.isEmpty) {
                        return const _EmptyState(
                          message: 'No franchise branches yet',
                        );
                      }

                      final analyticsMap = {
                        for (final a in analytics) a.branchId: a,
                      };
                      final rows =
                          branches
                              .where((b) => b.type == BranchType.franchise)
                              .map(
                                (b) =>
                                    (branch: b, analytics: analyticsMap[b.id]),
                              )
                              .toList()
                            ..sort((a, b) {
                              final aSales = a.analytics?.totalSales ?? 0.0;
                              final bSales = b.analytics?.totalSales ?? 0.0;
                              return bSales.compareTo(aSales);
                            });

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final a = row.analytics;
                          return _FranchiseRow(
                            rank: index + 1,
                            name: row.branch.name,
                            city: row.branch.city,
                            totalSales: a?.totalSales ?? 0.0,
                            invoiceCount: a?.invoiceCount ?? 0,
                            quotationCount: a?.quotationCount ?? 0,
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
      ),
    );
  }
}

class _FranchiseRow extends StatelessWidget {
  const _FranchiseRow({
    required this.rank,
    required this.name,
    required this.city,
    required this.totalSales,
    required this.invoiceCount,
    required this.quotationCount,
  });

  final int rank;
  final String name;
  final String city;
  final double totalSales;
  final int invoiceCount;
  final int quotationCount;

  @override
  Widget build(BuildContext context) {
    final pkrFmt = NumberFormat('#,###', 'en_US');
    final rankColors = [Colors.amber, Colors.grey, Colors.brown];
    final rankColor = rank <= 3 ? rankColors[rank - 1] : Colors.grey[400]!;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: rankColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (city.isNotEmpty)
                    Text(
                      city,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                ],
              ),
            ),
            _Chip(
              label: 'PKR ${pkrFmt.format(totalSales.toInt())}',
              color: Colors.teal,
            ),
            const SizedBox(width: 6),
            _Chip(label: '$invoiceCount inv', color: Colors.blue),
            if (quotationCount > 0) ...[
              const SizedBox(width: 6),
              _Chip(label: '$quotationCount quo', color: Colors.purple),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
