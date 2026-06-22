import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/firebase_auth_service.dart';
import '../../data/models/royalty_model.dart';
import '../providers/super_admin_providers.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  late DateTime selectedMonth;

  DateTime _monthOption(int offset) {
    final now = DateTime.now();
    return DateTime(now.year, now.month - offset);
  }

  @override
  void initState() {
    super.initState();
    selectedMonth = _monthOption(0);
  }

  @override
  Widget build(BuildContext context) {
    final monthlyAnalytics = ref.watch(currentMonthAnalyticsProvider);
    final monthlyRoyalties = ref.watch(
      monthlyRoyaltiesProvider((selectedMonth.month, selectedMonth.year)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            tooltip: 'Refresh live values',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(currentMonthAnalyticsProvider);
              ref.invalidate(
                monthlyRoyaltiesProvider((
                  selectedMonth.month,
                  selectedMonth.year,
                )),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // TODO: Export to PDF/Excel
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('Select Month:'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButton<DateTime>(
                        isExpanded: true,
                        value: selectedMonth,
                        items: [
                          for (int i = 0; i < 12; i++)
                            DropdownMenuItem(
                              value: _monthOption(i),
                              child: Text(_formatMonth(_monthOption(i))),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedMonth = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Monthly Summary
            const Text(
              'Monthly Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            monthlyAnalytics.when(
              data: (analyticsList) {
                final total = _calculateMonthlyTotals(analyticsList);
                return _MonthlySummaryCard(
                  totalSales: total['sales'] as double,
                  totalInvoices: total['invoices'] as int,
                  totalProfit: total['profit'] as double,
                  branchCount: analyticsList.length,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
            const SizedBox(height: 32),

            // Monthly Royalties
            const Text(
              'Monthly Royalties',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            monthlyRoyalties.when(
              data: (royalties) {
                if (royalties.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No royalties for this month'),
                    ),
                  );
                }
                return _RoyaltyReportTable(royalties: royalties);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
            const SizedBox(height: 32),

            // Export Options
            const Text(
              'Export Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.file_download),
                    label: const Text('Export as PDF'),
                    onPressed: () {
                      // TODO: Generate PDF
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Export as Excel'),
                    onPressed: () {
                      // TODO: Generate Excel
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatMonth(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Map<String, dynamic> _calculateMonthlyTotals(List<dynamic> analyticsList) {
    double totalSales = 0;
    int totalInvoices = 0;
    double totalProfit = 0;

    for (var analytics in analyticsList) {
      totalSales += analytics.totalSales;
      totalInvoices += (analytics.invoiceCount as num).toInt();
      totalProfit += analytics.profit;
    }

    return {
      'sales': totalSales,
      'invoices': totalInvoices,
      'profit': totalProfit,
    };
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  final double totalSales;
  final int totalInvoices;
  final double totalProfit;
  final int branchCount;

  const _MonthlySummaryCard({
    required this.totalSales,
    required this.totalInvoices,
    required this.totalProfit,
    required this.branchCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SummaryStat(
              label: 'Total Sales',
              value: 'PKR ${totalSales.toStringAsFixed(0)}',
            ),
            const Divider(),
            _SummaryStat(
              label: 'Total Invoices',
              value: totalInvoices.toString(),
            ),
            const Divider(),
            _SummaryStat(
              label: 'Total Profit',
              value: 'PKR ${totalProfit.toStringAsFixed(0)}',
            ),
            const Divider(),
            _SummaryStat(
              label: 'Active Branches',
              value: branchCount.toString(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _RoyaltyReportTable extends StatelessWidget {
  final List<Royalty> royalties;

  const _RoyaltyReportTable({required this.royalties});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Branch')),
          DataColumn(label: Text('Sales'), numeric: true),
          DataColumn(label: Text('Rate'), numeric: true),
          DataColumn(label: Text('Royalty'), numeric: true),
          DataColumn(label: Text('Status')),
        ],
        rows: royalties
            .map(
              (r) => DataRow(
                cells: [
                  DataCell(Text(r.branchName)),
                  DataCell(Text('PKR ${r.totalSales.toStringAsFixed(0)}')),
                  DataCell(Text('${r.royaltyPercentage}%')),
                  DataCell(Text('PKR ${r.royaltyAmount.toStringAsFixed(0)}')),
                  DataCell(Text(r.status.label)),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
