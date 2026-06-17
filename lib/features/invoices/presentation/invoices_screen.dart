import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/models/erp_models.dart';
import '../../inventory/application/inventory_controller.dart';
import '../../../shared/presentation/widgets/glass_panel.dart';
import '../application/invoice_ai_service.dart';
import '../application/invoice_history_service.dart';
import '../application/invoice_pdf_exporter.dart';
import '../application/quotation_controller.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  late final TextEditingController _clientController;
  late final TextEditingController _feetController;
  late final TextEditingController _promptController;
  late final TextEditingController _manualNameController;
  late final TextEditingController _manualQtyController;
  late final TextEditingController _manualPriceController;
  late final TextEditingController _manualUnitController;
  late final TextEditingController _paymentReceivedController;
  late final TextEditingController _paymentTotalController;
  late final TextEditingController _discountController;
  final Set<String> _selectedInventoryItemIds = <String>{};
  final Map<String, double> _selectedInventoryQuantities = <String, double>{};
  String _paymentForQuotationNo = '';
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'PKR ',
    decimalDigits: 0,
  );
  String _aiStatusText = 'AI status: offline fallback ready';
  Color _aiStatusColor = AppTheme.muted;
  String _aiResultText = 'AI result: no prompt has been generated yet.';

  @override
  void initState() {
    super.initState();
    final state = ref.read(quotationControllerProvider);
    _clientController = TextEditingController(text: state.clientName);
    _feetController = TextEditingController(text: state.runningFeet);
    _promptController = TextEditingController(text: state.aiPrompt);
    _manualNameController = TextEditingController();
    _manualQtyController = TextEditingController(text: '1');
    _manualPriceController = TextEditingController();
    _manualUnitController = TextEditingController(text: 'unit');
    _paymentReceivedController = TextEditingController();
    _paymentTotalController = TextEditingController();
    _discountController = TextEditingController();
  }

  @override
  void dispose() {
    _clientController.dispose();
    _feetController.dispose();
    _promptController.dispose();
    _manualNameController.dispose();
    _manualQtyController.dispose();
    _manualPriceController.dispose();
    _manualUnitController.dispose();
    _paymentReceivedController.dispose();
    _paymentTotalController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _editInventorySelectedQuantity(InventoryItem item) async {
    final current = _selectedInventoryQuantities[item.id] ?? 1;
    final quantityController = TextEditingController(
      text: current.toStringAsFixed(
        current.truncateToDouble() == current ? 0 : 1,
      ),
    );

    final nextQuantity = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Selected Qty - ${item.name}'),
          content: TextField(
            controller: quantityController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Quantity',
              helperText: 'Available stock: ${item.quantity}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(quantityController.text);
                if (parsed == null || parsed <= 0) {
                  return;
                }
                Navigator.of(
                  dialogContext,
                ).pop(parsed.clamp(1, item.quantity.toDouble()).toDouble());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (nextQuantity == null) {
      return;
    }

    setState(() {
      _selectedInventoryQuantities[item.id] = nextQuantity;
    });
  }

  Future<void> _editPackageProductQuantity({
    required QuotationController controller,
    required ServiceProduct product,
    required double currentQuantity,
  }) async {
    final quantityController = TextEditingController(
      text: currentQuantity.toStringAsFixed(
        currentQuantity.truncateToDouble() == currentQuantity ? 0 : 1,
      ),
    );

    final nextQuantity = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Edit Qty - ${product.name}'),
          content: TextField(
            controller: quantityController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(quantityController.text);
                if (parsed == null || parsed <= 0) {
                  return;
                }
                Navigator.of(dialogContext).pop(parsed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (nextQuantity == null) {
      return;
    }

    controller.updatePackageProductQuantity(
      product.name,
      nextQuantity,
      fallbackQuantity: 1,
    );
  }

  void _addManualProduct(QuotationController controller) {
    final name = _manualNameController.text.trim();
    final quantity = double.tryParse(_manualQtyController.text) ?? 0;
    final unitPrice = double.tryParse(_manualPriceController.text) ?? 0;
    final unit = _manualUnitController.text.trim();
    if (name.isEmpty || quantity <= 0 || unitPrice < 0) {
      return;
    }

    controller.addManualProduct(
      name: name,
      quantity: quantity,
      unitPrice: unitPrice,
      unit: unit.isEmpty ? 'unit' : unit,
    );

    _manualNameController.clear();
    _manualQtyController.text = '1';
    _manualPriceController.clear();
    _manualUnitController.text = 'unit';
  }

  void _editManualProduct(
    int index,
    QuotationLine line,
    QuotationController controller,
  ) {
    final nameController = TextEditingController(text: line.name);
    final qtyController = TextEditingController(
      text: line.quantity.toStringAsFixed(
        line.quantity.truncateToDouble() == line.quantity ? 0 : 1,
      ),
    );
    final priceController = TextEditingController(
      text: line.unitPrice.toStringAsFixed(
        line.unitPrice.truncateToDouble() == line.unitPrice ? 0 : 1,
      ),
    );
    final unitController = TextEditingController(text: line.unit);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Manual Product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Qty'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: unitController,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Unit Price'),
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
                final name = nameController.text.trim();
                final qty = double.tryParse(qtyController.text) ?? 0;
                final price = double.tryParse(priceController.text) ?? 0;
                final unit = unitController.text.trim();
                if (name.isEmpty || qty <= 0 || price < 0) {
                  return;
                }
                controller.updateManualProductAt(
                  index,
                  name: name,
                  quantity: qty,
                  unitPrice: price,
                  unit: unit.isEmpty ? 'unit' : unit,
                );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _addSelectedInventoryProducts({
    required QuotationController controller,
    required List<InventoryItem> inventoryItems,
  }) {
    for (final item in inventoryItems) {
      if (!_selectedInventoryItemIds.contains(item.id)) {
        continue;
      }
      final quantity = _selectedInventoryQuantities[item.id] ?? 1;
      if (quantity <= 0) {
        continue;
      }
      controller.addManualProduct(
        name: item.name,
        quantity: quantity,
        unitPrice: item.price,
        unit: 'unit',
      );
    }

    setState(() {
      _selectedInventoryItemIds.clear();
      _selectedInventoryQuantities.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(quotationControllerProvider.notifier);
    final state = ref.watch(quotationControllerProvider);
    final inventoryState = ref.watch(inventoryProvider);
    final historyDocument = ref.watch(historyEditorDocumentProvider);
    if (historyDocument != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadFromHistory(historyDocument);
        ref.read(historyEditorDocumentProvider.notifier).state = null;
      });
    }
    final profiles = controller.profiles;
    final profile = profiles.firstWhere(
      (item) => item.template.id == state.selectedProfileId,
      orElse: () => profiles.first,
    );
    final selectedPackage = profile.packages.firstWhere(
      (item) => item.id == state.selectedPackageId,
      orElse: () => profile.packages.first,
    );
    final textTheme = Theme.of(context).textTheme;

    _syncController(_clientController, state.clientName);
    _syncController(_feetController, state.runningFeet);
    _syncController(_promptController, state.aiPrompt);
    final generated = state.generatedQuotation;
    final showGenerateQuotationButton =
        generated == null || !generated.isInvoice;
    if (generated != null && _paymentForQuotationNo != generated.quotationNo) {
      _paymentForQuotationNo = generated.quotationNo;
      _paymentReceivedController.text = generated.paymentReceived
          .toStringAsFixed(
            generated.paymentReceived.truncateToDouble() ==
                    generated.paymentReceived
                ? 0
                : 1,
          );
      _paymentTotalController.text = generated.paymentReceived.toStringAsFixed(
        generated.paymentReceived.truncateToDouble() ==
                generated.paymentReceived
            ? 0
            : 1,
      );
      _discountController.text = generated.discountAmount.toStringAsFixed(
        generated.discountAmount.truncateToDouble() == generated.discountAmount
            ? 0
            : 1,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final form = GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Select a real business template, pick a predefined package, and replace placeholders only.',
                style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
              ),
              const SizedBox(height: 18),

              SizedBox(
                height: 72,
                child: TextField(
                  controller: _promptController,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  decoration: InputDecoration(
                    labelText: 'AI Prompt (Gemini + Offline Fallback)',
                    hintText:
                        'Example: Make invoice for solar cleaning, 8 panels, Rs 100 per panel',
                    suffixIcon: IconButton(
                      tooltip: 'Generate quotation or invoice from prompt',
                      icon: const Icon(Icons.psychology_alt_rounded),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final promptText = _promptController.text.trim();
                        controller.updatePrompt(promptText);

                        final aiService = ref.read(invoiceAiServiceProvider);
                        GeneratedQuotation? result;
                        final aiResult = await aiService
                            .interpretPromptWithFallback(
                              prompt: promptText,
                              profiles: controller.profiles,
                            );
                        result = await controller.generateFromParsedPrompt(
                          aiResult.prompt,
                        );
                        if (!mounted) return;
                        setState(() {
                          if (aiResult.usedOnlineAi) {
                            _aiStatusText = 'AI status: ${aiResult.status}';
                            _aiStatusColor = AppTheme.success;
                          } else {
                            _aiStatusText = 'AI status: ${aiResult.status}';
                            _aiStatusColor = AppTheme.warning;
                          }
                          final parsed = aiResult.prompt;
                          final pieces = <String>[];
                          if (parsed.category != null) {
                            pieces.add(parsed.category!.label);
                          }
                          if (parsed.packageHint.isNotEmpty) {
                            pieces.add('package: ${parsed.packageHint}');
                          }
                          if (parsed.systemHint.isNotEmpty) {
                            pieces.add('system: ${parsed.systemHint}');
                          }
                          if (parsed.quantity != null) {
                            pieces.add(
                              'qty: ${parsed.quantity!.toStringAsFixed(parsed.quantity!.truncateToDouble() == parsed.quantity ? 0 : 1)}',
                            );
                          }
                          if (parsed.clientName.isNotEmpty) {
                            pieces.add('client: ${parsed.clientName}');
                          }
                          pieces.add(
                            parsed.wantsInvoice ? 'invoice' : 'quotation',
                          );
                          _aiResultText = 'AI result: ${pieces.join(' | ')}';
                        });
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              result?.isInvoice == true
                                  ? 'AI prompt created an invoice.'
                                  : 'AI prompt created a quotation.',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  onChanged: controller.updatePrompt,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: Icon(
                    _aiStatusText.contains('online')
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    size: 18,
                    color: _aiStatusColor,
                  ),
                  label: Text(
                    _aiStatusText,
                    style: TextStyle(color: _aiStatusColor),
                  ),
                  side: BorderSide(
                    color: _aiStatusColor.withValues(alpha: 0.35),
                  ),
                  backgroundColor: _aiStatusColor.withValues(alpha: 0.08),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _aiResultText,
                style: textTheme.bodySmall?.copyWith(color: AppTheme.muted),
              ),
              const SizedBox(height: 18),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in profiles)
                    ChoiceChip(
                      label: Text(item.title),
                      selected: state.selectedProfileId == item.template.id,
                      onSelected: (_) =>
                          controller.setProfile(item.template.id),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: state.selectedPackageId,
                decoration: const InputDecoration(
                  labelText: 'Predefined Package',
                ),
                items: [
                  for (final item in profile.packages)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.setPackage(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _clientController,
                decoration: const InputDecoration(labelText: 'Client Name'),
                onChanged: controller.updateClientName,
              ),

              if (selectedPackage.quantityLabel.isNotEmpty &&
                  selectedPackage.rateRules.isNotEmpty) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _feetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: selectedPackage.quantityLabel,
                  ),
                  onChanged: controller.updateRunningFeet,
                ),
              ],
              const SizedBox(height: 16),
              if (selectedPackage.systemVariants.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: state.systemType.isEmpty
                      ? null
                      : state.systemType,
                  decoration: const InputDecoration(labelText: 'System Type'),
                  items: [
                    for (final item in selectedPackage.systemVariants.entries)
                      DropdownMenuItem(
                        value: item.key,
                        child: Text(
                          '${item.key}  •  ${_currency.format(item.value)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      controller.setSystemType(value);
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
              Text('Package Product List', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in selectedPackage.products)
                    Builder(
                      builder: (context) {
                        final isSelected = !state.excludedPackageProducts
                            .contains(item.name);
                        final quantity = controller.packageProductQuantity(
                          item.name,
                          1,
                        );

                        return GestureDetector(
                          onLongPress: isSelected
                              ? () => _editPackageProductQuantity(
                                  controller: controller,
                                  product: item,
                                  currentQuantity: quantity,
                                )
                              : null,
                          child: FilterChip(
                            label: Text(
                              '${item.name}  •  ${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1)} ${item.unit}  •  ${_currency.format(item.unitPrice)}',
                            ),
                            selected: isSelected,
                            onSelected: (_) {
                              controller.incrementPackageProductQuantity(
                                item.name,
                                fallbackQuantity: 1,
                              );
                            },
                            deleteIcon: isSelected
                                ? const Icon(Icons.remove_circle_outline)
                                : null,
                            onDeleted: isSelected
                                ? () => controller
                                      .decrementPackageProductQuantity(
                                        item.name,
                                        fallbackQuantity: 1,
                                      )
                                : null,
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tap chip for +1 qty. Use minus icon for -1 qty (removes item at 0). Long press to type exact qty.',
                style: textTheme.bodySmall?.copyWith(color: AppTheme.muted),
              ),
              const SizedBox(height: 12),
              Text('Add Manual Product', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _manualNameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualQtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Qty'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _manualUnitController,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _manualPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Unit Price',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _addManualProduct(controller),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Product'),
                ),
              ),
              if (state.manualProducts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Manual Products', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                ...state.manualProducts.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${entry.value.name}  •  ${entry.value.quantity.toStringAsFixed(entry.value.quantity.truncateToDouble() == entry.value.quantity ? 0 : 1)} ${entry.value.unit}',
                          ),
                        ),
                        Text(_currency.format(entry.value.total)),
                        IconButton(
                          onPressed: () => _editManualProduct(
                            entry.key,
                            entry.value,
                            controller,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          onPressed: () =>
                              controller.removeManualProductAt(entry.key),
                          icon: const Icon(Icons.delete_outline_rounded),
                          tooltip: 'Remove',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text('Optional Items', style: textTheme.titleLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in selectedPackage.optionalItems.where(
                    (item) => item.enabled,
                  ))
                    Builder(
                      builder: (context) {
                        final isSelected = state.selectedOptionalIds.contains(
                          item.id,
                        );
                        final quantity = controller.optionalItemQuantity(
                          item.id,
                        );
                        return FilterChip(
                          label: Text(
                            '${item.name}  •  Qty ${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1)}  •  ${_currency.format(item.price)}',
                          ),
                          selected: isSelected,
                          onSelected: (_) =>
                              controller.incrementOptionalItemQuantity(item.id),
                          deleteIcon: isSelected
                              ? const Icon(Icons.remove_circle_outline)
                              : null,
                          onDeleted: isSelected
                              ? () => controller.decrementOptionalItemQuantity(
                                  item.id,
                                )
                              : null,
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Optional items also support + and - qty with default 1.',
                style: textTheme.bodySmall?.copyWith(color: AppTheme.muted),
              ),
              const SizedBox(height: 20),
              Text('Existing Product List', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              if (inventoryState.items.isEmpty)
                Text(
                  'No inventory products are available yet.',
                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final item in inventoryState.items)
                          GestureDetector(
                            onLongPress:
                                _selectedInventoryItemIds.contains(item.id)
                                ? () => _editInventorySelectedQuantity(item)
                                : null,
                            child: FilterChip(
                              selected: _selectedInventoryItemIds.contains(
                                item.id,
                              ),
                              onSelected: item.quantity <= 0
                                  ? null
                                  : (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedInventoryItemIds.add(
                                            item.id,
                                          );
                                          _selectedInventoryQuantities[item
                                                  .id] =
                                              _selectedInventoryQuantities[item
                                                  .id] ??
                                              1;
                                        } else {
                                          _selectedInventoryItemIds.remove(
                                            item.id,
                                          );
                                          _selectedInventoryQuantities.remove(
                                            item.id,
                                          );
                                        }
                                      });
                                    },
                              avatar: Icon(
                                item.isLowStock
                                    ? Icons.warning_amber_rounded
                                    : Icons.inventory_2_rounded,
                                size: 18,
                                color: item.isLowStock
                                    ? AppTheme.warning
                                    : AppTheme.accent,
                              ),
                              label: Text(
                                '${item.name}  •  ${item.quantity} in stock  •  ${_currency.format(item.price)}${_selectedInventoryItemIds.contains(item.id) ? '  •  Qty ${(_selectedInventoryQuantities[item.id] ?? 1).toStringAsFixed((_selectedInventoryQuantities[item.id] ?? 1).truncateToDouble() == (_selectedInventoryQuantities[item.id] ?? 1) ? 0 : 1)}' : ''}',
                              ),
                              side: BorderSide(
                                color: item.isLowStock
                                    ? AppTheme.warning.withValues(alpha: 0.45)
                                    : AppTheme.outline,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Select products, then long press a selected chip to edit qty.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _selectedInventoryItemIds.isEmpty
                          ? null
                          : () {
                              _addSelectedInventoryProducts(
                                controller: controller,
                                inventoryItems: inventoryState.items,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Selected products added to manual items.',
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: Text(
                        'Add Selected to Manual Products (${_selectedInventoryItemIds.length})',
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              if (showGenerateQuotationButton)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final current = ref
                          .read(quotationControllerProvider)
                          .generatedQuotation;
                      if (current?.isInvoice == true) {
                        return;
                      }
                      await controller.generateQuotation();
                    },
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Generate quotation'),
                  ),
                ),
              if (state.generatedQuotation != null) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _paymentReceivedController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: state.generatedQuotation!.isInvoice
                        ? 'Add New Payment'
                        : 'First Payment Received',
                    hintText: state.generatedQuotation!.isInvoice
                        ? 'Enter additional payment amount (will be added)'
                        : 'Enter first received amount to convert into invoice',
                  ),
                ),
                if (!state.generatedQuotation!.isInvoice) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _discountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Discount (Optional)',
                      hintText: 'Enter fixed discount amount before invoice',
                      prefixText: 'PKR ',
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final quotation = state.generatedQuotation;
                      if (quotation == null) {
                        return;
                      }
                      final amount =
                          double.tryParse(_paymentReceivedController.text) ?? 0;
                      final discount = !quotation.isInvoice
                          ? double.tryParse(_discountController.text) ?? 0
                          : quotation.discountAmount;
                      await controller.convertToInvoice(
                        paymentReceived: amount,
                        discountAmount: discount,
                      );
                      final updated = ref
                          .read(quotationControllerProvider)
                          .generatedQuotation;
                      if (updated != null) {
                        _paymentTotalController.text = updated.paymentReceived
                            .toStringAsFixed(
                              updated.paymentReceived.truncateToDouble() ==
                                      updated.paymentReceived
                                  ? 0
                                  : 1,
                            );
                      }
                      _paymentReceivedController.clear();
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            quotation.isInvoice
                                ? 'Payment added and invoice updated.'
                                : 'Quotation converted to invoice.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_rounded),
                    label: Text(
                      state.generatedQuotation!.isInvoice
                          ? 'Add Payment to Invoice'
                          : 'Convert to Invoice',
                    ),
                  ),
                ),
                if (state.generatedQuotation!.isInvoice) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _discountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Apply Discount',
                      hintText: 'Enter fixed discount amount',
                      prefixText: 'PKR ',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final discount =
                            double.tryParse(_discountController.text) ?? 0;
                        await controller.updateInvoiceDiscount(
                          discountAmount: discount,
                        );
                        final updated = ref
                            .read(quotationControllerProvider)
                            .generatedQuotation;
                        if (updated != null) {
                          _discountController.text = updated.discountAmount
                              .toStringAsFixed(
                                updated.discountAmount.truncateToDouble() ==
                                        updated.discountAmount
                                    ? 0
                                    : 1,
                              );
                        }
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Invoice discount updated successfully.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.money_off_rounded),
                      label: const Text('Apply Discount'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _paymentTotalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Edit Total Payment Received',
                      hintText:
                          'Correct payment total if previous entry was wrong',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final total =
                            double.tryParse(_paymentTotalController.text) ?? 0;
                        await controller.updateInvoicePaymentReceived(
                          paymentReceived: total,
                        );
                        final updated = ref
                            .read(quotationControllerProvider)
                            .generatedQuotation;
                        if (updated != null) {
                          _paymentTotalController.text = updated.paymentReceived
                              .toStringAsFixed(
                                updated.paymentReceived.truncateToDouble() ==
                                        updated.paymentReceived
                                    ? 0
                                    : 1,
                              );
                        }
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Invoice payment corrected successfully.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Update Total Received Amount'),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await previewInvoicePdf(
                          context: context,
                          quotation: state.generatedQuotation!,
                          placeholderValues:
                              state.generatedQuotation!.placeholderValues,
                        );
                      } catch (_) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Preview failed. Try Download PDF.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('Export / Print PDF'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await downloadInvoicePdf(
                          quotation: state.generatedQuotation!,
                          placeholderValues:
                              state.generatedQuotation!.placeholderValues,
                        );
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('PDF download started.'),
                          ),
                        );
                      } catch (_) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Download failed. Please try Export / Print PDF.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download PDF'),
                  ),
                ),
              ],
            ],
          ),
        );

        final preview = GlassPanel(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: state.generatedQuotation == null
                ? _EmptyPreview(profile: profile)
                : _QuotationPreview(
                    quotation: state.generatedQuotation!,
                    currency: _currency,
                  ),
          ),
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SingleChildScrollView(child: form)),
              const SizedBox(width: 16),
              Expanded(child: SingleChildScrollView(child: preview)),
            ],
          );
        }

        return SingleChildScrollView(
          child: Column(children: [form, const SizedBox(height: 16), preview]),
        );
      },
    );
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }

    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview({required this.profile});

  final ServiceProfile profile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      key: const ValueKey('empty-preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Template Preview', style: textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'The generated document keeps the uploaded ${profile.template.fileType.label} design and swaps placeholders only.',
          style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
        ),
        const SizedBox(height: 18),
        SelectableText(
          profile.template.sourceMarkup,
          style: textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _QuotationPreview extends StatelessWidget {
  const _QuotationPreview({required this.quotation, required this.currency});

  final GeneratedQuotation quotation;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      key: ValueKey(quotation.quotationNo),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                quotation.isInvoice
                    ? 'Generated Invoice'
                    : 'Generated Quotation',
                style: textTheme.headlineMedium,
              ),
            ),
            Chip(
              label: Text(
                quotation.isInvoice
                    ? (quotation.invoiceNo.isEmpty
                          ? quotation.quotationNo
                          : quotation.invoiceNo)
                    : quotation.quotationNo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${quotation.clientName}  •  ${quotation.category.label}',
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Template: ${quotation.templateName}  •  Package: ${quotation.packageName}',
          style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
        ),
        const SizedBox(height: 18),
        ...quotation.lineItems.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  'Qty: ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unit}  •  Unit Price: ${currency.format(item.unitPrice)}  •  Total: ${currency.format(item.total)}',
                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 28, color: AppTheme.outline),
        if (quotation.discountPercent > 0) ...[
          Row(
            children: [
              Expanded(child: Text('Subtotal', style: textTheme.bodyLarge)),
              Text(
                currency.format(quotation.subtotal),
                style: textTheme.bodyLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Discount',
                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
              ),
              Text(
                '- ${currency.format(quotation.discountAmount)}',
                style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(child: Text('Grand Total', style: textTheme.titleLarge)),
            Text(
              currency.format(quotation.grandTotal),
              style: textTheme.headlineMedium,
            ),
          ],
        ),
        if (quotation.isInvoice) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text('Payment Received', style: textTheme.bodyLarge),
              ),
              Text(
                currency.format(quotation.paymentReceived),
                style: textTheme.bodyLarge,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text('Remaining Payment', style: textTheme.titleLarge),
              ),
              Text(
                currency.format(quotation.remainingPayment),
                style: textTheme.headlineSmall,
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        Text('Warranty', style: textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          quotation.warranty,
          style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
        ),
        const SizedBox(height: 16),
        if (!quotation.globalSections.any(
          (section) => section.title.toUpperCase().contains('TERM'),
        )) ...[
          Text('Terms & Conditions', style: textTheme.titleLarge),
          const SizedBox(height: 6),
          ...quotation.terms.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $item',
                style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        for (final section in quotation.globalSections) ...[
          Text(section.title, style: textTheme.titleLarge),
          const SizedBox(height: 6),
          ...section.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $item',
                style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 16),
        Text('Rendered Template Preview', style: textTheme.titleLarge),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(18),
          ),
          child: SelectableText(
            quotation.renderedTemplate,
            style: textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
