import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/branch_model.dart';
import '../providers/super_admin_providers.dart';

class DashboardStats extends ConsumerWidget {
  final AsyncValue allBranches;
  final AsyncValue<double> totalRoyaltiesDue;
  final AsyncValue<double> totalRoyaltiesCollected;
  final AsyncValue<double> totalInventoryValue;

  const DashboardStats({
    Key? key,
    required this.allBranches,
    required this.totalRoyaltiesDue,
    required this.totalRoyaltiesCollected,
    required this.totalInventoryValue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAnalytics = ref.watch(streamCurrentMonthAnalyticsProvider);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.store,
                iconColor: Colors.blue,
                title: 'Total Branches',
                child: allBranches.when(
                  loading: () => const _LoadingValue(),
                  error: (_, __) => const _Value('—'),
                  data: (d) => _Value('${(d as List?)?.length ?? 0}'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.business,
                iconColor: Colors.indigo,
                title: 'Active Franchises',
                child: allBranches.when(
                  loading: () => const _LoadingValue(),
                  error: (_, __) => const _Value('—'),
                  data: (d) {
                    final count =
                        (d as List<Branch>?)
                            ?.where((b) => b.type == BranchType.franchise)
                            .length ??
                        0;
                    return _Value('$count');
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up,
                iconColor: Colors.teal,
                title: 'Total Sales (Month)',
                child: liveAnalytics.when(
                  loading: () => const _LoadingValue(),
                  error: (_, __) => const _Value('PKR 0', isMonetary: true),
                  data: (list) {
                    final total = list.fold<double>(
                      0.0,
                      (s, a) => s + a.totalSales,
                    );
                    return _Value(
                      'PKR ${total.toStringAsFixed(0)}',
                      isMonetary: true,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.account_balance_wallet,
                iconColor: Colors.orange,
                title: 'Royalties Due',
                child: totalRoyaltiesDue.when(
                  loading: () => const _LoadingValue(),
                  error: (_, __) => const _Value('PKR 0', color: Colors.orange),
                  data: (v) => _Value(
                    'PKR ${v.toStringAsFixed(0)}',
                    color: Colors.orange,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_outline,
                iconColor: Colors.green,
                title: 'Royalties Collected',
                child: totalRoyaltiesCollected.when(
                  loading: () => const _LoadingValue(),
                  error: (_, __) => const _Value('PKR 0', color: Colors.green),
                  data: (v) => _Value(
                    'PKR ${v.toStringAsFixed(0)}',
                    color: Colors.green,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.inventory_2_outlined,
                iconColor: Colors.purple,
                title: 'Inventory Value',
                child: totalInventoryValue.when(
                  loading: () => const _LoadingValue(),
                  error: (_, __) => const _Value('PKR 0'),
                  data: (v) => _Value('PKR ${v.toStringAsFixed(0)}'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.child,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final Widget child;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 2),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text, {this.isMonetary = false, this.color});
  final String text;
  final bool isMonetary;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: isMonetary ? 15 : 20,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }
}

class _LoadingValue extends StatelessWidget {
  const _LoadingValue();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 16,
    width: 16,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
