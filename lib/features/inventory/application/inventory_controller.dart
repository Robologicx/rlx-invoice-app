import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/models/erp_models.dart';
import '../../../database/local_database.dart';

class InventoryState {
  const InventoryState({required this.items, required this.movements});

  final List<InventoryItem> items;
  final List<InventoryMovement> movements;

  int get totalStock => items.fold<int>(0, (sum, item) => sum + item.quantity);
  int get lowStockCount => items.where((item) => item.isLowStock).length;
  double get totalValue =>
      items.fold<double>(0, (sum, item) => sum + (item.quantity * item.price));

  InventoryState copyWith({
    List<InventoryItem>? items,
    List<InventoryMovement>? movements,
  }) {
    return InventoryState(
      items: items ?? this.items,
      movements: movements ?? this.movements,
    );
  }
}

class InventoryController extends StateNotifier<InventoryState> {
  InventoryController() : super(_loadState());

  static InventoryState _loadState() {
    final itemsBox = localBoxOrNull(LocalDatabase.inventoryItemsBox);
    final movementsBox = localBoxOrNull(LocalDatabase.inventoryMovementsBox);

    final items = <InventoryItem>[];
    if (itemsBox != null) {
      for (final entry in itemsBox.toMap().entries) {
        items.add(InventoryItem.fromMap(entry.value));
      }
    }

    if (items.isEmpty) {
      items.addAll(_seedItems());
    }

    final movements = <InventoryMovement>[];
    if (movementsBox != null) {
      final entries = movementsBox.toMap().entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      for (final entry in entries) {
        movements.add(InventoryMovement.fromMap(entry.value));
      }
    }

    _saveItems(items);
    return InventoryState(items: items, movements: movements);
  }

  static List<InventoryItem> _seedItems() {
    return [
      InventoryItem(
        id: 'inv_solar_panels',
        name: 'Solar Panels',
        quantity: 26,
        price: 18000,
        supplier: 'SunNova',
      ),
      InventoryItem(
        id: 'inv_batteries',
        name: 'Batteries',
        quantity: 8,
        price: 85000,
        supplier: 'VoltEdge',
      ),
      InventoryItem(
        id: 'inv_fence_wire',
        name: 'Electric Fence Wire',
        quantity: 12,
        price: 25000,
        supplier: 'FenceCore',
      ),
      InventoryItem(
        id: 'inv_cameras',
        name: 'Cameras',
        quantity: 42,
        price: 12500,
        supplier: 'Dahua Partner',
      ),
      InventoryItem(
        id: 'inv_sensors',
        name: 'Sensors',
        quantity: 7,
        price: 4200,
        supplier: 'SmartGrid',
      ),
      InventoryItem(
        id: 'inv_switches',
        name: 'Smart Switches',
        quantity: 5,
        price: 6500,
        supplier: 'SmartGrid',
      ),
    ];
  }

  List<InventoryItem> get items => state.items;
  List<InventoryMovement> get movements => state.movements;

  void addItem(InventoryItem item) {
    final next = [...state.items, item];
    state = state.copyWith(items: next);
    _saveItems(next);
    _recordMovement(
      itemId: item.id,
      itemName: item.name,
      type: 'add',
      quantityChange: item.quantity,
      previousQuantity: 0,
      newQuantity: item.quantity,
      note: 'Product added',
    );
  }

  void updateItem(InventoryItem updatedItem) {
    final index = state.items.indexWhere((item) => item.id == updatedItem.id);
    if (index == -1) {
      return;
    }
    final previous = state.items[index];
    final next = [...state.items];
    next[index] = updatedItem;
    state = state.copyWith(items: next);
    _saveItems(next);
    _recordMovement(
      itemId: updatedItem.id,
      itemName: updatedItem.name,
      type: 'update',
      quantityChange: updatedItem.quantity - previous.quantity,
      previousQuantity: previous.quantity,
      newQuantity: updatedItem.quantity,
      note: 'Product updated',
    );
  }

  void removeItem(String itemId) {
    final item = state.items.firstWhere(
      (entry) => entry.id == itemId,
      orElse: () => const InventoryItem(
        id: '',
        name: '',
        quantity: 0,
        price: 0,
        supplier: '',
      ),
    );
    if (item.id.isEmpty) {
      return;
    }
    final next = state.items.where((entry) => entry.id != itemId).toList();
    state = state.copyWith(items: next);
    _saveItems(next);
    _recordMovement(
      itemId: item.id,
      itemName: item.name,
      type: 'remove',
      quantityChange: -item.quantity,
      previousQuantity: item.quantity,
      newQuantity: 0,
      note: 'Product removed',
    );
  }

  void adjustStock({
    required String itemId,
    required int delta,
    required String note,
  }) {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index == -1 || delta == 0) {
      return;
    }
    final current = state.items[index];
    final nextQuantity = (current.quantity + delta).clamp(0, 1000000);
    final updated = current.copyWith(quantity: nextQuantity);
    final next = [...state.items];
    next[index] = updated;
    state = state.copyWith(items: next);
    _saveItems(next);
    _recordMovement(
      itemId: itemId,
      itemName: current.name,
      type: delta > 0 ? 'in' : 'out',
      quantityChange: delta,
      previousQuantity: current.quantity,
      newQuantity: nextQuantity,
      note: note,
    );
  }

  void reorderItem(String itemId, int newMinQuantity) {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      return;
    }
    final current = state.items[index];
    final updated = current.copyWith(minQuantity: newMinQuantity);
    final next = [...state.items];
    next[index] = updated;
    state = state.copyWith(items: next);
    _saveItems(next);
    _recordMovement(
      itemId: itemId,
      itemName: current.name,
      type: 'reorder',
      quantityChange: 0,
      previousQuantity: current.quantity,
      newQuantity: updated.quantity,
      note: 'Low-stock threshold set to $newMinQuantity',
    );
  }

  void _recordMovement({
    required String itemId,
    required String itemName,
    required String type,
    required int quantityChange,
    required int previousQuantity,
    required int newQuantity,
    required String note,
  }) {
    final movement = InventoryMovement(
      id: 'movement_${DateTime.now().microsecondsSinceEpoch}',
      itemId: itemId,
      itemName: itemName,
      type: type,
      quantityChange: quantityChange,
      previousQuantity: previousQuantity,
      newQuantity: newQuantity,
      note: note,
      createdAt: DateTime.now(),
    );
    final next = [movement, ...state.movements];
    state = state.copyWith(movements: next);
    _saveMovements(next);
  }

  static void _saveItems(List<InventoryItem> items) {
    final box = localBoxOrNull(LocalDatabase.inventoryItemsBox);
    if (box == null) {
      return;
    }
    box
      ..clear()
      ..putAll({for (final item in items) item.id: item.toMap()});
  }

  static void _saveMovements(List<InventoryMovement> movements) {
    final box = localBoxOrNull(LocalDatabase.inventoryMovementsBox);
    if (box == null) {
      return;
    }
    box
      ..clear()
      ..putAll({for (final item in movements) item.id: item.toMap()});
  }
}

Box<Map>? localBoxOrNull(String boxName) {
  if (!Hive.isBoxOpen(boxName)) {
    return null;
  }
  return Hive.box<Map>(boxName);
}

final inventoryProvider =
    StateNotifierProvider<InventoryController, InventoryState>(
      (ref) => InventoryController(),
    );
