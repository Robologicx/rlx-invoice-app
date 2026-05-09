import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/data/demo_data.dart';
import '../../../shared/presentation/widgets/glass_panel.dart';
import '../../../shared/presentation/widgets/metric_card.dart';
import '../../invoices/application/invoice_history_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider);
    final recordsAsync = ref.watch(invoiceHistoryProvider);
    final textTheme = Theme.of(context).textTheme;
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
            'Manage quotations, template-driven invoices, project delivery, and stock from one industrial-grade workspace.',
            style: textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (var index = 0; index < metrics.length; index++)
                SizedBox(
                  width: 280,
                  child: MetricCard(
                    title: metrics[index].label,
                    value: metrics[index].value,
                    delta: metrics[index].delta,
                    icon: [
                      Icons.account_tree_rounded,
                      Icons.pending_actions_rounded,
                      Icons.task_alt_rounded,
                      Icons.engineering_rounded,
                      Icons.today_rounded,
                      Icons.payments_rounded,
                    ][index],
                  ),
                ),
            ],
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
