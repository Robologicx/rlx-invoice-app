import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/data/demo_data.dart';
import '../../../core/models/erp_models.dart';
import '../../../shared/presentation/widgets/glass_panel.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  late final TextEditingController _serviceNameController;
  final List<ServiceProduct> _newServiceManualProducts = [];
  final List<OptionalItem> _newServiceManualOptionals = [];
  final List<_NewServicePackageDraft> _newServicePackages = [];

  @override
  void initState() {
    super.initState();
    _serviceNameController = TextEditingController();
  }

  @override
  void dispose() {
    _serviceNameController.dispose();
    super.dispose();
  }

  void _addService() {
    final name = _serviceNameController.text.trim();
    final manualProducts = _newServiceManualProducts
        .map(
          (item) => ServiceProduct(
            name: item.name,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            unit: item.unit,
          ),
        )
        .toList();
    final manualOptionals = _newServiceManualOptionals
        .asMap()
        .entries
        .map(
          (entry) => OptionalItem(
            id: 'manual_optional_${DateTime.now().microsecondsSinceEpoch}_${entry.key}',
            name: entry.value.name,
            price: entry.value.price,
            enabled: true,
          ),
        )
        .toList();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter service name.')));
      return;
    }

    final packageDrafts = _newServicePackages
        .map(
          (draft) => _NewServicePackageDraft(
            name: draft.name,
            products: draft.products
                .map(
                  (item) => ServiceProduct(
                    name: item.name,
                    quantity: item.quantity,
                    unitPrice: item.unitPrice,
                    unit: item.unit,
                  ),
                )
                .toList(),
            optionals: draft.optionals
                .map(
                  (item) => OptionalItem(
                    id: item.id,
                    name: item.name,
                    price: item.price,
                    enabled: item.enabled,
                  ),
                )
                .toList(),
          ),
        )
        .toList();

    final primaryPackage = packageDrafts.isEmpty ? null : packageDrafts.first;

    final createdProfile = ref
        .read(customServiceProfilesProvider.notifier)
        .addService(
          title: name,
          category: ServiceCategory.smartHome,
          packageName: primaryPackage?.name ?? '',
          importedProducts: [...manualProducts, ...?primaryPackage?.products],
          importedOptionals: [
            ...manualOptionals,
            ...?primaryPackage?.optionals,
          ],
        );

    if (createdProfile != null && packageDrafts.length > 1) {
      final editsController = ref.read(serviceCatalogEditsProvider.notifier);
      for (var index = 1; index < packageDrafts.length; index++) {
        final draft = packageDrafts[index];
        final seed = DateTime.now().microsecondsSinceEpoch + index;
        editsController.addPackageToProfile(
          createdProfile.template.id,
          ServicePackage(
            id: 'user_pkg_$seed',
            name: draft.name,
            summary: 'Custom package added for ${createdProfile.title}.',
            category: createdProfile.category,
            templateId: createdProfile.template.id,
            products: draft.products,
            optionalItems: draft.optionals,
          ),
        );
      }
    }

    ref
        .read(enabledServicesProvider.notifier)
        .ensureEnabled(ServiceCategory.smartHome);

    _serviceNameController.clear();
    setState(() {
      _newServiceManualProducts.clear();
      _newServiceManualOptionals.clear();
      _newServicePackages.clear();
    });

    final itemCount = manualProducts.length + manualOptionals.length;
    final packageCount = packageDrafts.isEmpty ? 1 : packageDrafts.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          itemCount == 0
              ? 'New service added with $packageCount package(s).'
              : 'New service added with $packageCount package(s) and $itemCount item(s).',
        ),
      ),
    );
  }

  Future<void> _addNewServicePackage() async {
    final nameCtrl = TextEditingController();
    final products = <ServiceProduct>[];
    final optionals = <OptionalItem>[];

    final productNameCtrl = TextEditingController();
    final productQtyCtrl = TextEditingController(text: '1');
    final productPriceCtrl = TextEditingController();
    final productUnitCtrl = TextEditingController(text: 'unit');
    final optionalNameCtrl = TextEditingController();
    final optionalPriceCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Package To New Service'),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Package Name',
                          hintText: 'e.g. Starter Package',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Products'),
                      const SizedBox(height: 8),
                      ...products.asMap().entries.map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.value.name),
                          subtitle: Text(
                            '${entry.value.quantity} ${entry.value.unit} • PKR ${entry.value.unitPrice.toStringAsFixed(0)}',
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              setDialogState(
                                () => products.removeAt(entry.key),
                              );
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                      ),
                      TextField(
                        controller: productNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Product Name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: productQtyCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Qty',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: productUnitCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: productPriceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Price',
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            final itemName = productNameCtrl.text.trim();
                            final qty =
                                double.tryParse(productQtyCtrl.text) ?? 0;
                            final price =
                                double.tryParse(productPriceCtrl.text) ?? 0;
                            final unit = productUnitCtrl.text.trim();
                            if (itemName.isEmpty || qty <= 0) {
                              return;
                            }
                            setDialogState(() {
                              products.add(
                                ServiceProduct(
                                  name: itemName,
                                  quantity: qty,
                                  unitPrice: price,
                                  unit: unit.isEmpty ? 'unit' : unit,
                                ),
                              );
                              productNameCtrl.clear();
                              productQtyCtrl.text = '1';
                              productPriceCtrl.clear();
                              productUnitCtrl.text = 'unit';
                            });
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Product'),
                        ),
                      ),
                      const Divider(height: 28),
                      const Text('Optional Items'),
                      const SizedBox(height: 8),
                      ...optionals.asMap().entries.map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.value.name),
                          subtitle: Text(
                            'PKR ${entry.value.price.toStringAsFixed(0)}',
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              setDialogState(
                                () => optionals.removeAt(entry.key),
                              );
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                      ),
                      TextField(
                        controller: optionalNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Optional Item Name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: optionalPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Optional Price',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            final itemName = optionalNameCtrl.text.trim();
                            final price =
                                double.tryParse(optionalPriceCtrl.text) ?? 0;
                            if (itemName.isEmpty) {
                              return;
                            }
                            setDialogState(() {
                              optionals.add(
                                OptionalItem(
                                  id: 'new_pkg_optional_${DateTime.now().microsecondsSinceEpoch}',
                                  name: itemName,
                                  price: price,
                                  enabled: true,
                                ),
                              );
                              optionalNameCtrl.clear();
                              optionalPriceCtrl.clear();
                            });
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Optional Item'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final pkgName = nameCtrl.text.trim();
                    if (pkgName.isEmpty) {
                      return;
                    }
                    setState(() {
                      _newServicePackages.add(
                        _NewServicePackageDraft(
                          name: pkgName,
                          products: List.of(products),
                          optionals: List.of(optionals),
                        ),
                      );
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Add Package'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    productNameCtrl.dispose();
    productQtyCtrl.dispose();
    productPriceCtrl.dispose();
    productUnitCtrl.dispose();
    optionalNameCtrl.dispose();
    optionalPriceCtrl.dispose();
  }

  Future<void> _editNewServiceItems() async {
    final products = _newServiceManualProducts
        .map(
          (item) => ServiceProduct(
            name: item.name,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            unit: item.unit,
          ),
        )
        .toList();
    final optionals = _newServiceManualOptionals
        .map(
          (item) => OptionalItem(
            id: item.id,
            name: item.name,
            price: item.price,
            enabled: item.enabled,
          ),
        )
        .toList();

    final productNameCtrl = TextEditingController();
    final productQtyCtrl = TextEditingController(text: '1');
    final productPriceCtrl = TextEditingController();
    final productUnitCtrl = TextEditingController(text: 'unit');
    final optionalNameCtrl = TextEditingController();
    final optionalPriceCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Manual Service Items'),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Products'),
                      const SizedBox(height: 8),
                      ...products.asMap().entries.map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.value.name),
                          subtitle: Text(
                            '${entry.value.quantity} ${entry.value.unit} • PKR ${entry.value.unitPrice.toStringAsFixed(0)}',
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                products.removeAt(entry.key);
                              });
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                      ),
                      TextField(
                        controller: productNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Product Name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: productQtyCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Qty',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: productUnitCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: productPriceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Price',
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            final name = productNameCtrl.text.trim();
                            final qty =
                                double.tryParse(productQtyCtrl.text) ?? 0;
                            final price =
                                double.tryParse(productPriceCtrl.text) ?? 0;
                            final unit = productUnitCtrl.text.trim();
                            if (name.isEmpty || qty <= 0 || price < 0) {
                              return;
                            }
                            setDialogState(() {
                              products.add(
                                ServiceProduct(
                                  name: name,
                                  quantity: qty,
                                  unitPrice: price,
                                  unit: unit.isEmpty ? 'unit' : unit,
                                ),
                              );
                              productNameCtrl.clear();
                              productQtyCtrl.text = '1';
                              productPriceCtrl.clear();
                              productUnitCtrl.text = 'unit';
                            });
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Product'),
                        ),
                      ),
                      const Divider(height: 28),
                      const Text('Optional Items'),
                      const SizedBox(height: 8),
                      ...optionals.asMap().entries.map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.value.name),
                          subtitle: Text(
                            'PKR ${entry.value.price.toStringAsFixed(0)}',
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                optionals.removeAt(entry.key);
                              });
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                      ),
                      TextField(
                        controller: optionalNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Optional Item Name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: optionalPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Optional Price',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            final name = optionalNameCtrl.text.trim();
                            final price =
                                double.tryParse(optionalPriceCtrl.text) ?? 0;
                            if (name.isEmpty || price < 0) {
                              return;
                            }
                            setDialogState(() {
                              optionals.add(
                                OptionalItem(
                                  id: 'new_optional_${DateTime.now().microsecondsSinceEpoch}',
                                  name: name,
                                  price: price,
                                  enabled: true,
                                ),
                              );
                              optionalNameCtrl.clear();
                              optionalPriceCtrl.clear();
                            });
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Optional Item'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _newServiceManualProducts
                        ..clear()
                        ..addAll(products);
                      _newServiceManualOptionals
                        ..clear()
                        ..addAll(optionals);
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save Items'),
                ),
              ],
            );
          },
        );
      },
    );

    productNameCtrl.dispose();
    productQtyCtrl.dispose();
    productPriceCtrl.dispose();
    productUnitCtrl.dispose();
    optionalNameCtrl.dispose();
    optionalPriceCtrl.dispose();
  }

  Future<void> _addPackageToProfile(ServiceProfile profile) async {
    final nameCtrl = TextEditingController();
    final products = <ServiceProduct>[];
    final optionals = <OptionalItem>[];

    final productNameCtrl = TextEditingController();
    final productQtyCtrl = TextEditingController(text: '1');
    final productPriceCtrl = TextEditingController();
    final productUnitCtrl = TextEditingController(text: 'unit');
    final optionalNameCtrl = TextEditingController();
    final optionalPriceCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add Package — ${profile.title}'),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Package Name',
                          hintText: 'e.g. 2 Kanal Package',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Products'),
                      const SizedBox(height: 8),
                      ...products.asMap().entries.map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.value.name),
                          subtitle: Text(
                            '${entry.value.quantity} ${entry.value.unit} • PKR ${entry.value.unitPrice.toStringAsFixed(0)}',
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              setDialogState(
                                () => products.removeAt(entry.key),
                              );
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                      ),
                      TextField(
                        controller: productNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Product Name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: productQtyCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Qty',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: productUnitCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: productPriceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Price',
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            final name = productNameCtrl.text.trim();
                            final qty =
                                double.tryParse(productQtyCtrl.text) ?? 0;
                            final price =
                                double.tryParse(productPriceCtrl.text) ?? 0;
                            final unit = productUnitCtrl.text.trim();
                            if (name.isEmpty || qty <= 0) return;
                            setDialogState(() {
                              products.add(
                                ServiceProduct(
                                  name: name,
                                  quantity: qty,
                                  unitPrice: price,
                                  unit: unit.isEmpty ? 'unit' : unit,
                                ),
                              );
                              productNameCtrl.clear();
                              productQtyCtrl.text = '1';
                              productPriceCtrl.clear();
                              productUnitCtrl.text = 'unit';
                            });
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Product'),
                        ),
                      ),
                      const Divider(height: 28),
                      const Text('Optional Items'),
                      const SizedBox(height: 8),
                      ...optionals.asMap().entries.map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.value.name),
                          subtitle: Text(
                            'PKR ${entry.value.price.toStringAsFixed(0)}',
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              setDialogState(
                                () => optionals.removeAt(entry.key),
                              );
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                      ),
                      TextField(
                        controller: optionalNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Optional Item Name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: optionalPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Optional Price',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            final name = optionalNameCtrl.text.trim();
                            final price =
                                double.tryParse(optionalPriceCtrl.text) ?? 0;
                            if (name.isEmpty) return;
                            setDialogState(() {
                              optionals.add(
                                OptionalItem(
                                  id: 'pkg_opt_${DateTime.now().microsecondsSinceEpoch}',
                                  name: name,
                                  price: price,
                                  enabled: true,
                                ),
                              );
                              optionalNameCtrl.clear();
                              optionalPriceCtrl.clear();
                            });
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Optional Item'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final pkgName = nameCtrl.text.trim();
                    if (pkgName.isEmpty) return;
                    final seed = DateTime.now().microsecondsSinceEpoch
                        .toString();
                    final newPackage = ServicePackage(
                      id: 'user_pkg_$seed',
                      name: pkgName,
                      summary: 'Custom package added for ${profile.title}.',
                      category: profile.category,
                      templateId: profile.template.id,
                      products: List.of(products),
                      optionalItems: List.of(optionals),
                    );
                    ref
                        .read(serviceCatalogEditsProvider.notifier)
                        .addPackageToProfile(profile.template.id, newPackage);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Package "$pkgName" added.')),
                    );
                  },
                  child: const Text('Add Package'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    productNameCtrl.dispose();
    productQtyCtrl.dispose();
    productPriceCtrl.dispose();
    productUnitCtrl.dispose();
    optionalNameCtrl.dispose();
    optionalPriceCtrl.dispose();
  }

  Future<void> _editPackageItems(
    ServiceProfile profile,
    ServicePackage package,
  ) async {
    final products = package.products
        .map(
          (item) => ServiceProduct(
            name: item.name,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            unit: item.unit,
          ),
        )
        .toList();
    final optionals = package.optionalItems
        .map(
          (item) => OptionalItem(
            id: item.id,
            name: item.name,
            price: item.price,
            enabled: item.enabled,
          ),
        )
        .toList();
    final productNameCtrl = TextEditingController();
    final productQtyCtrl = TextEditingController(text: '1');
    final productPriceCtrl = TextEditingController();
    final productUnitCtrl = TextEditingController(text: 'unit');
    final optionalNameCtrl = TextEditingController();
    final optionalPriceCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit ${package.name}'),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Template: ${profile.template.fileName}'),
                      const SizedBox(height: 14),
                      const Text('Products'),
                      const SizedBox(height: 8),
                      ...products.asMap().entries.map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.value.name),
                          subtitle: Text(
                            '${entry.value.quantity} ${entry.value.unit} • PKR ${entry.value.unitPrice.toStringAsFixed(0)}',
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                products.removeAt(entry.key);
                              });
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                      ),
                      TextField(
                        controller: productNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Product Name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: productQtyCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Qty',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: productUnitCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: productPriceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Price',
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            final name = productNameCtrl.text.trim();
                            final qty =
                                double.tryParse(productQtyCtrl.text) ?? 0;
                            final price =
                                double.tryParse(productPriceCtrl.text) ?? 0;
                            final unit = productUnitCtrl.text.trim();
                            if (name.isEmpty || qty <= 0 || price <= 0) {
                              return;
                            }
                            setDialogState(() {
                              products.add(
                                ServiceProduct(
                                  name: name,
                                  quantity: qty,
                                  unitPrice: price,
                                  unit: unit.isEmpty ? 'unit' : unit,
                                ),
                              );
                              productNameCtrl.clear();
                              productQtyCtrl.text = '1';
                              productPriceCtrl.clear();
                              productUnitCtrl.text = 'unit';
                            });
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Product'),
                        ),
                      ),
                      const Divider(height: 28),
                      const Text('Optional Items'),
                      const SizedBox(height: 8),
                      ...optionals.asMap().entries.map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.value.name),
                          subtitle: Text(
                            'PKR ${entry.value.price.toStringAsFixed(0)}',
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                optionals.removeAt(entry.key);
                              });
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                      ),
                      TextField(
                        controller: optionalNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Optional Item Name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: optionalPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Optional Price',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            final name = optionalNameCtrl.text.trim();
                            final price =
                                double.tryParse(optionalPriceCtrl.text) ?? 0;
                            if (name.isEmpty || price <= 0) {
                              return;
                            }
                            setDialogState(() {
                              optionals.add(
                                OptionalItem(
                                  id: 'custom_optional_${DateTime.now().microsecondsSinceEpoch}',
                                  name: name,
                                  price: price,
                                  enabled: true,
                                ),
                              );
                              optionalNameCtrl.clear();
                              optionalPriceCtrl.clear();
                            });
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Optional Item'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    ref
                        .read(serviceCatalogEditsProvider.notifier)
                        .setPackageEdits(
                          packageId: package.id,
                          products: products,
                          optionals: optionals,
                        );
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Service items updated.')),
                    );
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    productNameCtrl.dispose();
    productQtyCtrl.dispose();
    productPriceCtrl.dispose();
    productUnitCtrl.dispose();
    optionalNameCtrl.dispose();
    optionalPriceCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(editableServiceProfilesProvider);
    final allProfiles = ref.watch(allServiceProfilesProvider);
    final customProfiles = ref.watch(customServiceProfilesProvider);
    final customTemplateIds = customProfiles
        .map((item) => item.template.id)
        .toSet();
    final standardProfiles = profiles
        .where((item) => !customTemplateIds.contains(item.template.id))
        .toList();
    final separatedCustomProfiles = profiles
        .where((item) => customTemplateIds.contains(item.template.id))
        .toList();
    // For package toggle display we need the unfiltered profile (all packages)
    final allProfileById = {for (final p in allProfiles) p.template.id: p};
    final enabledServices = ref.watch(enabledServicesProvider);
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Service Manager', style: textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Add new services and enable or disable categories used in invoice generation.',
            style: textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 24),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add New Service', style: textTheme.titleLarge),
                const SizedBox(height: 10),
                TextField(
                  controller: _serviceNameController,
                  decoration: const InputDecoration(labelText: 'Service Name'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only service name is required. New services are listed separately as custom services.',
                  style: textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _editNewServiceItems,
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Manual Items'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _addNewServicePackage,
                      icon: const Icon(Icons.inventory_2_rounded),
                      label: const Text('Add Package'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_newServiceManualProducts.length} product(s), ${_newServiceManualOptionals.length} optional item(s), ${_newServicePackages.length} package draft(s) ready',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_newServicePackages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _newServicePackages.length; i++)
                        InputChip(
                          label: Text(_newServicePackages[i].name),
                          onDeleted: () {
                            setState(() {
                              _newServicePackages.removeAt(i);
                            });
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _addService,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Service'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${enabledServices.length} category(s) active • ${standardProfiles.length + separatedCustomProfiles.length} service(s)',
                    style: textTheme.titleLarge,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(enabledServicesProvider.notifier).enableAll();
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Restore All'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final profile in standardProfiles)
                SizedBox(
                  width: 360,
                  child: GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _iconFor(profile.category),
                              color: AppTheme.accent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                profile.title,
                                style: textTheme.titleLarge,
                              ),
                            ),
                            Switch.adaptive(
                              value: enabledServices.contains(profile.category),
                              onChanged: (_) {
                                final isLastEnabled =
                                    enabledServices.length == 1 &&
                                    enabledServices.contains(profile.category);
                                if (isLastEnabled) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'At least one service must stay active.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                ref
                                    .read(enabledServicesProvider.notifier)
                                    .toggle(profile.category);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          profile.tagline,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text(profile.category.label)),
                            Chip(
                              label: Text(
                                '${profile.packages.length} package(s)',
                              ),
                            ),
                            Chip(label: Text(profile.template.fileType.label)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Template: ${profile.template.fileName}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _PackageList(
                          profile:
                              allProfileById[profile.template.id] ?? profile,
                          onEdit: (pkg) => _editPackageItems(profile, pkg),
                          onAdd: () => _addPackageToProfile(profile),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (separatedCustomProfiles.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Custom Services', style: textTheme.headlineSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final profile in separatedCustomProfiles)
                  SizedBox(
                    width: 360,
                    child: GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _iconFor(profile.category),
                                color: AppTheme.accent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  profile.title,
                                  style: textTheme.titleLarge,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  ref
                                      .read(
                                        customServiceProfilesProvider.notifier,
                                      )
                                      .removeServiceByTemplateId(
                                        profile.template.id,
                                      );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Custom service removed.'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.delete_outline_rounded),
                                tooltip: 'Remove custom service',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            profile.tagline,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppTheme.muted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text(profile.category.label)),
                              Chip(
                                label: Text(
                                  '${profile.packages.length} package(s)',
                                ),
                              ),
                              Chip(
                                label: Text(profile.template.fileType.label),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Template: ${profile.template.fileName}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppTheme.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _PackageList(
                            profile:
                                allProfileById[profile.template.id] ?? profile,
                            onEdit: (pkg) => _editPackageItems(profile, pkg),
                            onAdd: () => _addPackageToProfile(profile),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(ServiceCategory category) => switch (category) {
    ServiceCategory.electricFence => Icons.fence_rounded,
    ServiceCategory.solar => Icons.solar_power_rounded,
    ServiceCategory.cctv => Icons.videocam_rounded,
    ServiceCategory.smartGate => Icons.garage_rounded,
    ServiceCategory.smartHome => Icons.home_work_rounded,
    ServiceCategory.robotics => Icons.smart_toy_rounded,
    ServiceCategory.networking => Icons.router_rounded,
    ServiceCategory.maintenance => Icons.build_circle_rounded,
  };
}

class _NewServicePackageDraft {
  const _NewServicePackageDraft({
    required this.name,
    required this.products,
    required this.optionals,
  });

  final String name;
  final List<ServiceProduct> products;
  final List<OptionalItem> optionals;
}

// Shows all packages for a service with per-package enable/disable toggle,
// edit button and an Add Package button.
class _PackageList extends ConsumerWidget {
  const _PackageList({
    required this.profile,
    required this.onEdit,
    required this.onAdd,
  });

  final ServiceProfile profile;
  final void Function(ServicePackage) onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edits = ref.watch(serviceCatalogEditsProvider);
    // Show all packages including user-added ones (before filtering for invoice)
    // and resolve each package with current edited products/optionals.
    final allPackages =
        [
          ...profile.packages,
          ...(edits.addedPackagesByProfile[profile.template.id] ?? []),
        ].map((pkg) {
          return ServicePackage(
            id: pkg.id,
            name: pkg.name,
            summary: pkg.summary,
            category: pkg.category,
            templateId: pkg.templateId,
            products: edits.productsByPackage[pkg.id] ?? pkg.products,
            optionalItems:
                edits.optionalsByPackage[pkg.id] ?? pkg.optionalItems,
            systemVariants: pkg.systemVariants,
            hardwareRate: pkg.hardwareRate,
            configurationCharge: pkg.configurationCharge,
            installationCharge: pkg.installationCharge,
            calculationNotes: pkg.calculationNotes,
          );
        }).toList();
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Packages', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final pkg in allPackages)
          Builder(
            builder: (context) {
              final isEnabled = !edits.disabledPackageIds.contains(pkg.id);
              final isLastEnabled =
                  allPackages
                          .where(
                            (p) => !edits.disabledPackageIds.contains(p.id),
                          )
                          .length ==
                      1 &&
                  isEnabled;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Switch.adaptive(
                      value: isEnabled,
                      onChanged: isLastEnabled
                          ? null
                          : (_) {
                              ref
                                  .read(serviceCatalogEditsProvider.notifier)
                                  .togglePackage(pkg.id);
                            },
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ActionChip(
                        avatar: const Icon(Icons.edit_note_rounded, size: 16),
                        label: Text(pkg.name, overflow: TextOverflow.ellipsis),
                        onPressed: () => onEdit(pkg),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Package'),
        ),
        const SizedBox(height: 4),
        Text(
          'Toggle to enable/disable a package in Invoice. Tap chip to edit items.',
          style: textTheme.bodySmall?.copyWith(color: AppTheme.muted),
        ),
      ],
    );
  }
}
