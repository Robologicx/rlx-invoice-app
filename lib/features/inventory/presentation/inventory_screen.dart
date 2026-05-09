import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/data/demo_data.dart';
import '../../../shared/presentation/widgets/glass_panel.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inventoryProvider);
    final currency = NumberFormat.currency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 0,
    );
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inventory Control', style: textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Low-stock warnings, supplier pricing, and reusable workshop material tracking.',
            style: textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final item in items)
                SizedBox(
                  width: 320,
                  child: GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: textTheme.titleLarge,
                              ),
                            ),
                            if (item.isLowStock)
                              const Chip(
                                label: Text('Low Stock'),
                                avatar: Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppTheme.warning,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Quantity: ${item.quantity}',
                          style: textTheme.bodyLarge,
                        ),
                        Text(
                          'Price: ${currency.format(item.price)}',
                          style: textTheme.bodyLarge,
                        ),
                        Text(
                          'Supplier: ${item.supplier}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
