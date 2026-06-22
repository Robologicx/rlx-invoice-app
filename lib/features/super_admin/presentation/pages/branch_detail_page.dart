import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/branch_model.dart';
import '../providers/super_admin_providers.dart';

class BranchDetailPage extends ConsumerWidget {
  final String branchId;

  const BranchDetailPage({Key? key, required this.branchId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(branchByIdProvider(branchId));
    final analytics = ref.watch(branchAnalyticsProvider(branchId));
    final royalties = ref.watch(branchRoyaltiesProvider(branchId));

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title:
              branch.whenData((b) {
                return Text(b?.name ?? 'Branch Details');
              }).value ??
              const Text('Branch Details'),
          actions: [
            IconButton(
              tooltip: 'Refresh live values',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(branchByIdProvider(branchId));
                ref.invalidate(branchAnalyticsProvider(branchId));
                ref.invalidate(branchRoyaltiesProvider(branchId));
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Monthly Reports'),
              Tab(text: 'Royalties'),
              Tab(text: 'Finance'),
              Tab(text: 'Inventory'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Overview Tab
            _OverviewTab(branchId: branchId, branch: branch),

            // Monthly Reports Tab
            _MonthlyReportsTab(analytics: analytics),

            // Royalties Tab
            _RoyaltiesTab(royalties: royalties),

            // Finance Tab
            const Center(child: Text('Finance data loading...')),

            // Inventory Tab
            const Center(child: Text('Inventory data loading...')),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final String branchId;
  final AsyncValue branch;

  const _OverviewTab({required this.branchId, required this.branch});

  @override
  Widget build(BuildContext context) {
    return branch.when(
      data: (b) {
        if (b == null) {
          return const Center(child: Text('Branch not found'));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(title: 'Branch Information'),
              _InfoRow(label: 'Name', value: b.name),
              _InfoRow(label: 'Code', value: b.code),
              _InfoRow(label: 'City', value: b.city),
              _InfoRow(label: 'Type', value: b.type.label),
              _InfoRow(label: 'Status', value: b.status.label),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Owner Information'),
              _InfoRow(label: 'Name', value: b.ownerName),
              _InfoRow(label: 'Email', value: b.email),
              _InfoRow(label: 'Phone', value: b.phone),
              _InfoRow(label: 'Address', value: b.address),
              const SizedBox(height: 24),
              if (b.type == BranchType.franchise)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(title: 'Royalty Information'),
                    _InfoRow(
                      label: 'Royalty Rate',
                      value: '${b.royaltyPercentage.toStringAsFixed(1)}%',
                    ),
                  ],
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class _MonthlyReportsTab extends StatelessWidget {
  final AsyncValue analytics;

  const _MonthlyReportsTab({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return analytics.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No analytics data available'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final data = list[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.monthYear}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StatRow(
                      label: 'Total Sales',
                      value: 'PKR ${data.totalSales.toStringAsFixed(0)}',
                    ),
                    _StatRow(
                      label: 'Invoices',
                      value: data.invoiceCount.toString(),
                    ),
                    _StatRow(
                      label: 'Profit',
                      value: 'PKR ${data.profit.toStringAsFixed(0)}',
                    ),
                    _StatRow(
                      label: 'Receivables',
                      value: 'PKR ${data.receivables.toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class _RoyaltiesTab extends StatelessWidget {
  final AsyncValue royalties;

  const _RoyaltiesTab({required this.royalties});

  @override
  Widget build(BuildContext context) {
    return royalties.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No royalty records'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final royalty = list[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(royalty.monthYear),
                subtitle: Text(
                  'PKR ${royalty.royaltyAmount.toStringAsFixed(0)} - ${royalty.status.label}',
                ),
                trailing: Text(
                  'Paid: PKR ${royalty.paidAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
