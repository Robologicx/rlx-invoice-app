import 'package:flutter/material.dart';

class BranchSummaryCard extends StatelessWidget {
  final String branchName;
  final double totalSales;
  final int invoiceCount;
  final int quotationCount;
  final int projectCount;
  final double profit;
  final double receivables;
  final double inventoryValue;

  const BranchSummaryCard({
    Key? key,
    required this.branchName,
    required this.totalSales,
    required this.invoiceCount,
    required this.quotationCount,
    required this.projectCount,
    required this.profit,
    required this.receivables,
    required this.inventoryValue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              branchName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatBox(
                  label: 'Sales',
                  value: 'PKR ${totalSales.toStringAsFixed(0)}',
                ),
                _StatBox(label: 'Invoices', value: invoiceCount.toString()),
                _StatBox(label: 'Quotations', value: quotationCount.toString()),
                _StatBox(label: 'Projects', value: projectCount.toString()),
                _StatBox(
                  label: 'Profit',
                  value: 'PKR ${profit.toStringAsFixed(0)}',
                ),
                _StatBox(
                  label: 'Receivables',
                  value: 'PKR ${receivables.toStringAsFixed(0)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
