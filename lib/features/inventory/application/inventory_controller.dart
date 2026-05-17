import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/erp_models.dart';
import '../../../core/services/firebase_auth_service.dart';

class InventoryState {
  const InventoryState({required this.items, required this.movements});

  final List<InventoryItem> items;
  final List<InventoryMovement> movements;

  int get totalStock =>
      items.fold<int>(0, (total, item) => total + item.quantity);
  int get lowStockCount => items.where((item) => item.isLowStock).length;
  double get totalValue => items.fold<double>(
    0,
    (total, item) => total + (item.quantity * item.price),
  );

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
  InventoryController()
    : super(const InventoryState(items: [], movements: [])) {
    _bootstrap();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  static String? _activeUserId() => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return null;
    }
    return _firestore.collection('users').doc(userId);
  }

  Future<void> _bootstrap() async {
    final userDoc = _userDoc;
    if (userDoc == null) {
      state = const InventoryState(items: [], movements: []);
      return;
    }

    final snapshot = await userDoc.get();
    final initial = _mapState(snapshot.data());
    state = initial;

    _subscription = userDoc.snapshots().listen((event) {
      state = _mapState(event.data());
    });
  }

  InventoryState _mapState(Map<String, dynamic>? data) {
    if (data == null) {
      return const InventoryState(items: [], movements: []);
    }

    final rawItems = data['inventory'] as List? ?? const [];
    final rawMovements = data['inventoryMovements'] as List? ?? const [];

    final items = rawItems
        .whereType<Map>()
        .map((map) => InventoryItem.fromMap(map))
        .toList();
    final movements =
        rawMovements
            .whereType<Map>()
            .map((map) => InventoryMovement.fromMap(map))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return InventoryState(items: items, movements: movements);
  }

  Future<void> _saveState(InventoryState nextState) async {
    final userDoc = _userDoc;
    if (userDoc == null) {
      return;
    }

    await userDoc.set({
      'inventory': nextState.items.map((item) => item.toMap()).toList(),
      'inventoryMovements': nextState.movements
          .map((movement) => movement.toMap())
          .toList(),
    }, SetOptions(merge: true));
  }

  List<InventoryItem> get items => state.items;
  List<InventoryMovement> get movements => state.movements;

  void addItem(InventoryItem item) {
    final next = [...state.items, item];
    state = state.copyWith(items: next);
    _saveState(state);
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
    _saveState(state);
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
    _saveState(state);
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
    _saveState(state);
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
    _saveState(state);
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
    _saveState(state);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final inventoryProvider =
    StateNotifierProvider<InventoryController, InventoryState>((ref) {
      ref.watch(currentUserProvider);
      return InventoryController();
    });
