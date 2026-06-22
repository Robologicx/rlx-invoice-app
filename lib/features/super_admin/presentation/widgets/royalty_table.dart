import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/super_admin_providers.dart';
import '../../data/models/royalty_model.dart';

class RoyaltyTable extends ConsumerWidget {
  final List<Royalty> royalties;

  const RoyaltyTable({Key? key, required this.royalties}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (royalties.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No royalty records'),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Month')),
          DataColumn(label: Text('Branch')),
          DataColumn(label: Text('Sales'), numeric: true),
          DataColumn(label: Text('Rate'), numeric: true),
          DataColumn(label: Text('Remaining Due'), numeric: true),
          DataColumn(label: Text('Paid'), numeric: true),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Action')),
        ],
        rows: royalties
            .map(
              (r) => DataRow(
                cells: [
                  DataCell(Text(r.monthYear)),
                  DataCell(Text(r.branchName)),
                  DataCell(Text('PKR ${r.totalSales.toStringAsFixed(0)}')),
                  DataCell(Text('${r.royaltyPercentage}%')),
                  DataCell(
                    Text(
                      r.remainingBalance <= 0
                          ? 'PKR 0'
                          : 'PKR ${r.remainingBalance.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: r.remainingBalance <= 0 ? Colors.green : null,
                        fontWeight: r.remainingBalance <= 0
                            ? FontWeight.w500
                            : null,
                      ),
                    ),
                  ),
                  DataCell(Text('PKR ${r.paidAmount.toStringAsFixed(0)}')),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(r.status).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r.status.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(r.status),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    r.status == RoyaltyStatus.paid
                        ? const Text('Recorded')
                        : TextButton.icon(
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Record Payment'),
                            onPressed: () async {
                              final result = await _showPaymentDialog(
                                context,
                                royalty: r,
                              );
                              if (result == null) return;

                              final repo = ref.read(royaltyRepositoryProvider);
                              try {
                                await repo.recordRoyaltyRowPayment(
                                  r,
                                  amount: result.amount,
                                  notes: result.notes,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Recorded PKR ${result.amount.toStringAsFixed(0)} for ${r.branchName}',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text('$e')));
                                }
                              }
                            },
                          ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Future<_PaymentEntry?> _showPaymentDialog(
    BuildContext context, {
    required Royalty royalty,
  }) async {
    final amountController = TextEditingController(
      text: royalty.remainingBalance > 0
          ? royalty.remainingBalance.toStringAsFixed(0)
          : royalty.royaltyAmount.toStringAsFixed(0),
    );
    final notesController = TextEditingController();

    return showDialog<_PaymentEntry>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Record payment for ${royalty.branchName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount received',
                  prefixText: 'PKR ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid amount')),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop(
                  _PaymentEntry(
                    amount: amount,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(RoyaltyStatus status) {
    switch (status) {
      case RoyaltyStatus.pending:
        return Colors.orange;
      case RoyaltyStatus.partiallyPaid:
        return Colors.blue;
      case RoyaltyStatus.paid:
        return Colors.green;
    }
  }
}

class _PaymentEntry {
  final double amount;
  final String? notes;

  const _PaymentEntry({required this.amount, this.notes});
}
