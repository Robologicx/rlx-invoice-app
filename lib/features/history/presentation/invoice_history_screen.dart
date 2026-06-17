import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/models/erp_models.dart';
import '../../../core/services/app_mode_service.dart';
import '../../../shared/presentation/widgets/glass_panel.dart';
import '../../invoices/application/invoice_pdf_exporter.dart';
import '../../invoices/application/invoice_history_service.dart';

class InvoiceHistoryScreen extends ConsumerWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(invoiceHistoryProvider);
    final historyService = ref.read(invoiceHistoryServiceProvider);
    final offlineMode = ref.watch(appModeProvider);
    final money = NumberFormat.currency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 0,
    );
    final date = DateFormat('dd MMM yyyy, hh:mm a');

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('History', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            offlineMode
                ? 'Local archive of all generated quotations and invoices.'
                : 'Cloud archive of all generated quotations and invoices.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: recordsAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return Text(
                    'No invoice generated yet.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  );
                }

                final invoiceRecords = records
                    .where((record) => record.isInvoice)
                    .toList();
                final quotationRecords = records
                    .where((record) => !record.isInvoice)
                    .toList();

                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Clear All History'),
                              content: const Text(
                                'Delete all quotation and invoice records?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  child: const Text('Delete All'),
                                ),
                              ],
                            ),
                          );

                          if (confirm != true) {
                            return;
                          }
                          await historyService.clearAll();
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('History cleared successfully.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_sweep_rounded),
                        label: const Text('Clear All'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            const TabBar(
                              tabs: [
                                Tab(text: 'Invoices'),
                                Tab(text: 'Quotations'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _HistoryRecordsList(
                                    records: invoiceRecords,
                                    money: money,
                                    date: date,
                                    historyService: historyService,
                                    emptyMessage: 'No invoices found yet.',
                                  ),
                                  _HistoryRecordsList(
                                    records: quotationRecords,
                                    money: money,
                                    date: date,
                                    historyService: historyService,
                                    emptyMessage: 'No quotations found yet.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Failed to load history: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRecordsList extends ConsumerWidget {
  const _HistoryRecordsList({
    required this.records,
    required this.money,
    required this.date,
    required this.historyService,
    required this.emptyMessage,
  });

  final List<InvoiceRecord> records;
  final NumberFormat money;
  final DateFormat date;
  final InvoiceHistoryService historyService;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (records.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(emptyMessage, style: Theme.of(context).textTheme.bodyLarge),
      );
    }

    return ListView.separated(
      itemCount: records.length,
      separatorBuilder: (_, _) => const Divider(color: AppTheme.outline),
      itemBuilder: (context, index) {
        final item = records[index];
        final isReceivable = item.isInvoice && item.remainingPayment > 0;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppTheme.accent,
            ),
          ),
          title: Text(
            '${item.isInvoice && item.invoiceNo.isNotEmpty ? item.invoiceNo : item.quotationNo}  •  ${item.clientName}',
          ),
          subtitle: Text(
            '${item.isInvoice ? 'Invoice' : 'Quotation'} • ${item.category.label} • ${item.packageName}\nReceived: ${money.format(item.paymentReceived)} • Remaining: ${money.format(item.remainingPayment)}\n${date.format(item.generatedAt)}',
          ),
          isThreeLine: true,
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isReceivable)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'Receivable',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Text(money.format(item.total)),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    ref.read(historyEditorDocumentProvider.notifier).state =
                        item.document;
                    if (context.mounted) {
                      context.go('/invoices');
                    }
                    return;
                  }

                  if (value == 'reprint') {
                    try {
                      await downloadInvoicePdf(
                        quotation: item.document,
                        placeholderValues: item.document.placeholderValues,
                      );
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Receipt sent to print/share: ${item.document.isInvoice && item.document.invoiceNo.isNotEmpty ? item.document.invoiceNo : item.document.quotationNo}',
                          ),
                        ),
                      );
                    } catch (_) {
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unable to reprint this record.'),
                        ),
                      );
                    }
                    return;
                  }

                  if (value == 'delete') {
                    await historyService.deleteRecord(item.id);
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Record deleted.')),
                    );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'reprint',
                    child: Text('Reprint / Send Receipt'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
