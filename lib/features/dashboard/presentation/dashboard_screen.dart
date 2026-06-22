import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/models/erp_models.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../shared/presentation/widgets/glass_panel.dart';
import '../../../shared/presentation/widgets/metric_card.dart';
import '../../finance/application/finance_report_provider.dart';
import 'package:rlx_invoice/features/inventory/application/inventory_controller_v2.dart';
import '../../invoices/application/invoice_history_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(invoiceHistoryProvider);
    final financeAsync = ref.watch(financeSummaryProvider);
    final inventoryState = ref.watch(inventoryProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final loginName =
        (authUser?.displayName != null &&
            authUser!.displayName!.trim().isNotEmpty)
        ? authUser.displayName!.trim()
        : (authUser?.email?.trim().isNotEmpty ?? false)
        ? authUser!.email!.trim()
        : 'Unknown user';
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final metricWidth = screenWidth < 640 ? screenWidth - 40 : 280.0;
    final money = NumberFormat.currency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 0,
    );
    final date = DateFormat('dd MMM yyyy, hh:mm a');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Workshop Command Center', style: textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Logged in as: $loginName',
            style: textTheme.bodyMedium?.copyWith(
              color: AppTheme.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage quotations, template-driven invoices, project delivery, and stock from one industrial-grade workspace.',
            style: textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 24),
          financeAsync.when(
            data: (summary) {
              final records =
                  recordsAsync.valueOrNull ?? const <InvoiceRecord>[];
              final invoices = _latestInvoiceRecords(records);
              final totalReceivable = invoices.fold<double>(
                0,
                (sum, item) => sum + item.remainingPayment,
              );
              final thisMonth = summary.currentMonthReport;
              final previousMonth = summary.previousMonthReport;

              final currentProfit =
                  summary.totalSales - summary.totalExpenses - totalReceivable;
              final previousProfit = previousMonth?.profit ?? 0;
              final profitDelta = previousProfit == 0
                  ? 'Reset monthly'
                  : '${(((currentProfit - previousProfit) / previousProfit.abs()) * 100).toStringAsFixed(0)}% vs last month';

              final metrics = [
                (
                  label: 'Total Sales',
                  value: money.format(summary.totalSales),
                  delta: '${invoices.length} invoices',
                  icon: Icons.point_of_sale_rounded,
                ),
                (
                  label: 'Total Expense',
                  value: money.format(summary.totalExpenses),
                  delta:
                      '${summary.monthlyReports.fold<int>(0, (sum, item) => sum + item.expenseCount)} entries',
                  icon: Icons.money_off_csred_rounded,
                ),
                (
                  label: 'Total Receivable',
                  value: money.format(totalReceivable),
                  delta:
                      '${invoices.where((item) => item.remainingPayment > 0).length} invoices',
                  icon: Icons.account_balance_wallet_rounded,
                ),
                (
                  label: currentProfit >= 0
                      ? 'This Month Profit'
                      : 'This Month Loss',
                  value: money.format(currentProfit.abs()),
                  delta: profitDelta,
                  icon: currentProfit >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                ),
                (
                  label: 'This Month Sales',
                  value: money.format(thisMonth.totalSales),
                  delta: '${thisMonth.invoiceCount} invoices',
                  icon: Icons.calendar_month_rounded,
                ),
                (
                  label: 'Products in Stock',
                  value: inventoryState.items.length.toString(),
                  delta: '${inventoryState.lowStockCount} low stock',
                  icon: Icons.inventory_2_rounded,
                ),
                (
                  label: 'Total Stock Units',
                  value: inventoryState.totalStock.toString(),
                  delta: 'Real-time inventory',
                  icon: Icons.stacked_line_chart_rounded,
                ),
              ];

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final item in metrics)
                    SizedBox(
                      width: metricWidth,
                      child: MetricCard(
                        title: item.label,
                        value: item.value,
                        delta: item.delta,
                        icon: item.icon,
                      ),
                    ),
                ],
              );
            },
            loading: () => Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (var i = 0; i < 6; i++)
                  SizedBox(
                    width: metricWidth,
                    child: MetricCard(
                      title: 'Loading...',
                      value: '--',
                      delta: 'Syncing',
                      icon: Icons.hourglass_top_rounded,
                    ),
                  ),
              ],
            ),
            error: (error, _) => Text(
              'Failed to load real-time metrics: $error',
              style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final recentDocuments = GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Invoices & Quotations',
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    recordsAsync.when(
                      data: (records) {
                        if (records.isEmpty) {
                          return Text(
                            'No invoice or quotation generated yet.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppTheme.muted,
                            ),
                          );
                        }

                        final recent = records.take(6).toList();
                        return Column(
                          children: [
                            for (final item in recent)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      item.isInvoice
                                          ? Icons.receipt_long_rounded
                                          : Icons.description_rounded,
                                      color: AppTheme.accent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${item.isInvoice && item.invoiceNo.isNotEmpty ? item.invoiceNo : item.quotationNo}  •  ${item.clientName}',
                                            style: textTheme.bodyLarge,
                                          ),
                                          Text(
                                            '${item.isInvoice ? 'Invoice' : 'Quotation'} • ${money.format(item.total)} • ${date.format(item.generatedAt)}',
                                            style: textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: AppTheme.muted,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                      loading: () => const Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (error, _) => Text(
                        'Failed to load history: $error',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              final quickActions = GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Actions', style: textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _QuickAction(
                          label: 'Create Invoice',
                          icon: Icons.note_add_rounded,
                          onTap: () => context.go('/invoices'),
                        ),
                        _QuickAction(
                          label: 'Upload Template',
                          icon: Icons.upload_file_rounded,
                          onTap: () => context.go('/invoices'),
                        ),
                        _QuickAction(
                          label: 'Services',
                          icon: Icons.precision_manufacturing_rounded,
                          onTap: () => context.go('/projects'),
                        ),
                        _QuickAction(
                          label: 'Products',
                          icon: Icons.inventory_2_rounded,
                          onTap: () => context.go('/inventory'),
                        ),
                        _QuickAction(
                          label: 'Finance',
                          icon: Icons.analytics_rounded,
                          onTap: () => context.go('/finance'),
                        ),
                        _QuickAction(
                          label: 'Invoice History',
                          icon: Icons.history_rounded,
                          onTap: () => context.go('/history'),
                        ),
                        _QuickAction(
                          label: 'Settings',
                          icon: Icons.tune_rounded,
                          onTap: () => context.go('/settings'),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: recentDocuments),
                    const SizedBox(width: 16),
                    Expanded(child: quickActions),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  recentDocuments,
                  const SizedBox(height: 16),
                  quickActions,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppTheme.accent),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

List<InvoiceRecord> _latestInvoiceRecords(List<InvoiceRecord> records) {
  final invoiceMap = <String, InvoiceRecord>{};

  for (final item in records.where((entry) => entry.isInvoice)) {
    final key = item.parentQuotationNo;
    final existing = invoiceMap[key];
    if (existing == null || item.generatedAt.isAfter(existing.generatedAt)) {
      invoiceMap[key] = item;
    }
  }

  return invoiceMap.values.toList();
}
