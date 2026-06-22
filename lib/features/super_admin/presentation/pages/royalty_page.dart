import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/firebase_auth_service.dart';
import '../providers/super_admin_providers.dart';
import '../widgets/royalty_table.dart';

class RoyaltyManagementPage extends ConsumerWidget {
  const RoyaltyManagementPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allRoyalties = ref.watch(computedCurrentRoyaltiesProvider);
    final totalDue = ref.watch(totalRoyaltiesDueProvider);
    final totalCollected = ref.watch(totalRoyaltiesCollectedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Royalty Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh live values',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(computedCurrentRoyaltiesProvider);
              ref.invalidate(totalRoyaltiesDueProvider);
              ref.invalidate(totalRoyaltiesCollectedProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Add manual royalty entry
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(logoutProvider.future);
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Summary Cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total Due',
                      amount: totalDue,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total Collected',
                      amount: totalCollected,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            // Royalties Table
            Padding(
              padding: const EdgeInsets.all(16),
              child: allRoyalties.when(
                data: (royalties) {
                  return RoyaltyTable(royalties: royalties);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final AsyncValue<double> amount;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 8),
            amount.when(
              data: (value) {
                return Text(
                  'PKR ${value.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                );
              },
              loading: () => const Text('PKR 0'),
              error: (err, stack) => const Text('PKR 0'),
            ),
          ],
        ),
      ),
    );
  }
}
