import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/models/erp_models.dart';
import '../../../shared/presentation/widgets/glass_panel.dart';
import '../application/inventory_controller.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showItemDialog({InventoryItem? item}) async {
    final nameController = TextEditingController(text: item?.name ?? '');
    final quantityController = TextEditingController(
      text: item?.quantity.toString() ?? '0',
    );
    final priceController = TextEditingController(
      text: item?.price.toStringAsFixed(0) ?? '',
    );
    final supplierController = TextEditingController(
      text: item?.supplier ?? '',
    );
    final minStockController = TextEditingController(
      text: item?.minQuantity.toString() ?? '10',
    );

    final result = await showDialog<InventoryItem>(
      context: context,
      builder: (dialogContext) {
        final isCompact = MediaQuery.sizeOf(dialogContext).width < 480;
        return AlertDialog(
          title: Text(item == null ? 'Add Product' : 'Edit Product'),
          content: SizedBox(
            width: MediaQuery.sizeOf(dialogContext).width > 640
                ? 560
                : MediaQuery.sizeOf(dialogContext).width * 0.82,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isCompact)
                    Column(
                      children: [
                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Qty'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: minStockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Low stock threshold',
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qty'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: minStockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Low stock threshold',
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Unit Price'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: supplierController,
                    decoration: const InputDecoration(labelText: 'Supplier'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final quantity = int.tryParse(quantityController.text.trim());
                final price = double.tryParse(priceController.text.trim());
                final supplier = supplierController.text.trim();
                final minStock = int.tryParse(minStockController.text.trim());
                if (name.isEmpty ||
                    quantity == null ||
                    price == null ||
                    supplier.isEmpty ||
                    minStock == null) {
                  return;
                }
                Navigator.of(dialogContext).pop(
                  InventoryItem(
                    id:
                        item?.id ??
                        'inv_${DateTime.now().microsecondsSinceEpoch}',
                    name: name,
                    quantity: quantity,
                    price: price,
                    supplier: supplier,
                    minQuantity: minStock,
                  ),
                );
              },
              child: Text(item == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      nameController.dispose();
      quantityController.dispose();
      priceController.dispose();
      supplierController.dispose();
      minStockController.dispose();
      return;
    }

    final controller = ref.read(inventoryProvider.notifier);
    if (item == null) {
      controller.addItem(result);
    } else {
      controller.updateItem(result);
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(item == null ? 'Product added.' : 'Product updated.'),
      ),
    );

    nameController.dispose();
    quantityController.dispose();
    priceController.dispose();
    supplierController.dispose();
    minStockController.dispose();
  }

  Future<void> _showAdjustDialog(InventoryItem item) async {
    final qtyController = TextEditingController(text: '1');
    final noteController = TextEditingController(text: 'Stock adjustment');

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Adjust Stock - ${item.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity change',
                  hintText: 'Use negative value to reduce stock',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final delta = int.tryParse(qtyController.text.trim());
                if (delta == null || delta == 0) {
                  return;
                }
                Navigator.of(context).pop(delta);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      qtyController.dispose();
      noteController.dispose();
      return;
    }

    ref
        .read(inventoryProvider.notifier)
        .adjustStock(
          itemId: item.id,
          delta: result,
          note: noteController.text.trim().isEmpty
              ? 'Stock adjustment'
              : noteController.text.trim(),
        );

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Stock updated for ${item.name}.')));

    qtyController.dispose();
    noteController.dispose();
  }

  Future<void> _showReorderDialog(InventoryItem item) async {
    final thresholdController = TextEditingController(
      text: item.minQuantity.toString(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Set Threshold - ${item.name}'),
          content: TextField(
            controller: thresholdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Low-stock threshold'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(thresholdController.text.trim());
                if (value == null || value < 0) {
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      thresholdController.dispose();
      return;
    }

    ref.read(inventoryProvider.notifier).reorderItem(item.id, result);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Threshold updated for ${item.name}.')),
    );
    thresholdController.dispose();
  }

  Future<void> _confirmDelete(InventoryItem item) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Product?'),
          content: Text('Delete ${item.name} from inventory records?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (delete != true) {
      return;
    }

    ref.read(inventoryProvider.notifier).removeItem(item.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${item.name} removed.')));
  }

  Color _movementColor(String type) {
    return switch (type) {
      'add' => AppTheme.success,
      'remove' => Colors.redAccent,
      'in' => AppTheme.success,
      'out' => AppTheme.warning,
      'reorder' => Colors.lightBlueAccent,
      _ => AppTheme.accent,
    };
  }

  String _movementLabel(String type) {
    return switch (type) {
      'add' => 'Added',
      'remove' => 'Removed',
      'in' => 'Stock In',
      'out' => 'Stock Out',
      'reorder' => 'Threshold',
      _ => 'Updated',
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final currency = NumberFormat.currency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 0,
    );
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.sizeOf(context).width < 720;

    final filteredItems = state.items.where((item) {
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) {
        return true;
      }
      return item.name.toLowerCase().contains(query) ||
          item.supplier.toLowerCase().contains(query);
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCompact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Inventory Control', style: textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  'Add products, remove products, adjust stock, and keep a record of every inventory movement.',
                  style: textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => _showItemDialog(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Product'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inventory Control', style: textTheme.headlineLarge),
                      const SizedBox(height: 8),
                      Text(
                        'Add products, remove products, adjust stock, and keep a record of every inventory movement.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showItemDialog(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Product'),
                ),
              ],
            ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                label: 'Products',
                value: state.items.length.toString(),
                icon: Icons.inventory_2_rounded,
              ),
              _StatCard(
                label: 'Total Stock',
                value: state.totalStock.toString(),
                icon: Icons.all_inbox_rounded,
              ),
              _StatCard(
                label: 'Low Stock',
                value: state.lowStockCount.toString(),
                icon: Icons.warning_amber_rounded,
              ),
              _StatCard(
                label: 'Inventory Value',
                value: currency.format(state.totalValue),
                icon: Icons.payments_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCompact)
                  Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() => _query = value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Search products or suppliers',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear_rounded),
                          label: const Text('Clear'),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() => _query = value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Search products or suppliers',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear_rounded),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilterChip(
                      label: Text('${filteredItems.length} visible'),
                      selected: true,
                      onSelected: (_) {},
                    ),
                    FilterChip(
                      label: Text('${state.items.length} total'),
                      selected: true,
                      onSelected: (_) {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 1200
                  ? (constraints.maxWidth - 32) / 3
                  : constraints.maxWidth >= 780
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final item in filteredItems)
                    SizedBox(
                      width: cardWidth,
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
                                    avatar: Icon(
                                      Icons.warning_amber_rounded,
                                      color: AppTheme.warning,
                                      size: 18,
                                    ),
                                    label: Text('Low stock'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Quantity: ${item.quantity}',
                              style: textTheme.bodyLarge,
                            ),
                            Text(
                              'Unit Price: ${currency.format(item.price)}',
                              style: textTheme.bodyLarge,
                            ),
                            Text(
                              'Supplier: ${item.supplier}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Threshold: ${item.minQuantity}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: () => _showAdjustDialog(item),
                                  icon: const Icon(Icons.swap_vert_rounded),
                                  label: const Text('Adjust Stock'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _showItemDialog(item: item),
                                  icon: const Icon(Icons.edit_rounded),
                                  label: const Text('Edit'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _showReorderDialog(item),
                                  icon: const Icon(
                                    Icons.notification_add_rounded,
                                  ),
                                  label: const Text('Threshold'),
                                ),
                                TextButton.icon(
                                  onPressed: () => _confirmDelete(item),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  label: const Text('Remove'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Stock Records', style: textTheme.titleLarge),
                    ),
                    Text(
                      '${state.movements.length} movement(s)',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.movements.isEmpty)
                  Text(
                    'No inventory movements recorded yet.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.muted,
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final movement in state.movements.take(12))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.outline),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: _movementColor(
                                      movement.type,
                                    ).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    movement.type == 'remove'
                                        ? Icons.remove_circle_outline_rounded
                                        : movement.type == 'add'
                                        ? Icons.add_circle_outline_rounded
                                        : Icons.swap_horiz_rounded,
                                    color: _movementColor(movement.type),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_movementLabel(movement.type)} • ${movement.itemName}',
                                        style: textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${movement.quantityChange >= 0 ? '+' : ''}${movement.quantityChange} | ${movement.previousQuantity} → ${movement.newQuantity}',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: AppTheme.muted,
                                        ),
                                      ),
                                      Text(
                                        movement.note,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppTheme.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'dd MMM, hh:mm a',
                                  ).format(movement.createdAt),
                                  style: textTheme.bodySmall?.copyWith(
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
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 220,
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppTheme.accent),
            ),
            const SizedBox(height: 14),
            Text(value, style: textTheme.headlineLarge),
            const SizedBox(height: 4),
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}
