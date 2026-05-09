import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/models/erp_models.dart';
import '../../../shared/presentation/widgets/glass_panel.dart';
import '../../invoices/application/invoice_pdf_exporter.dart';
import '../../invoices/application/invoice_history_service.dart';

class InvoiceHistoryScreen extends ConsumerWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(invoiceHistoryProvider);
    final historyService = ref.read(invoiceHistoryServiceProvider);
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
          Text(
            'Invoice History',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Offline archive of all generated quotations and invoices.',
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
                      child: ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: AppTheme.outline),
                        itemBuilder: (context, index) {
                          final item = records[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.accent.withValues(
                                alpha: 0.15,
                              ),
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
                              children: [
                                Text(money.format(item.total)),
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      ref
                                              .read(
                                                historyEditorDocumentProvider
                                                    .notifier,
                                              )
                                              .state =
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
                                          placeholderValues:
                                              item.document.placeholderValues,
                                        );
                                        if (!context.mounted) {
                                          return;
                                        }
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Unable to reprint this record.',
                                            ),
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    if (value == 'delete') {
                                      await historyService.deleteRecord(
                                        item.id,
                                      );
                                      if (!context.mounted) {
                                        return;
                                      }
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Record deleted.'),
                                        ),
                                      );
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'reprint',
                                      child: Text('Reprint / Send Receipt'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
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
