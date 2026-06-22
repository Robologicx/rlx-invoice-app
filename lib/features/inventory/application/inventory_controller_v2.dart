import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/erp_models.dart';
import '../../../core/models/flat_models.dart';
import '../../../core/services/firebase_auth_service.dart';
import 'product_repository.dart';

// ---------------------------------------------------------------------------
// InventoryState - unchanged API so all screens continue to work.
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// InventoryController
//
// Data is now stored in two flat top-level Firestore collections:
//   * products/{productId}   - one doc per product, carries franchiseId
//   * movements/{movementId} - append-only audit trail, carries franchiseId
//
// The public API (addItem / updateItem / removeItem / adjustStock /
// reorderItem) is IDENTICAL to the previous implementation so no screen
// changes are needed.
// ---------------------------------------------------------------------------
class InventoryController extends StateNotifier<InventoryState> {
  InventoryController()
    : super(const InventoryState(items: [], movements: [])) {
    _bootstrap();
  }

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProductRepository _productRepo = ProductRepository();
  final MovementRepository _movementRepo = MovementRepository();

  String? _franchiseId;
  StreamSubscription<List<ProductModel>>? _itemsSub;
  StreamSubscription<List<StockMovementModel>>? _movementsSub;

  static String? _activeUserId() => FirebaseAuth.instance.currentUser?.uid;

  // -- Initialisation -------------------------------------------------------

  Future<void> _bootstrap() async {
    final uid = _activeUserId();
    if (uid == null || uid.isEmpty) {
      state = const InventoryState(items: [], movements: []);
      return;
    }

    _franchiseId = await _resolveFranchiseId(uid);

    List<InventoryItem> currentItems = const [];
    List<InventoryMovement> currentMovements = const [];

    _itemsSub = _productRepo.watchProducts(_franchiseId!).listen((products) {
      currentItems = products.map(_productToItem).toList();
      state = InventoryState(items: currentItems, movements: currentMovements);
    });

    _movementsSub = _movementRepo.watchMovements(_franchiseId!).listen((
      movements,
    ) {
      currentMovements = movements.map(_movementToLegacy).toList();
      state = InventoryState(items: currentItems, movements: currentMovements);
    });
  }

  Future<String> _resolveFranchiseId(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final branchId = doc.data()?['branchId'] as String?;
      return (branchId != null && branchId.isNotEmpty) ? branchId : uid;
    } catch (_) {
      return uid;
    }
  }

  // -- Public write API (same as before) ------------------------------------

  void addItem(InventoryItem item) {
    if (_franchiseId == null) return;
    _productRepo.upsertProduct(_itemToProduct(item, _franchiseId!));
    _writeMovement(
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
    if (_franchiseId == null) return;
    final previous = state.items.firstWhere(
      (i) => i.id == updatedItem.id,
      orElse: () => updatedItem,
    );
    _productRepo.upsertProduct(_itemToProduct(updatedItem, _franchiseId!));
    _writeMovement(
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
    if (_franchiseId == null) return;
    final item = state.items.firstWhere(
      (i) => i.id == itemId,
      orElse: () => const InventoryItem(
        id: '',
        name: '',
        quantity: 0,
        price: 0,
        supplier: '',
      ),
    );
    if (item.id.isEmpty) return;
    _productRepo.deleteProduct(itemId);
    _writeMovement(
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
    if (_franchiseId == null || delta == 0) return;
    final item = state.items.firstWhere(
      (i) => i.id == itemId,
      orElse: () => const InventoryItem(
        id: '',
        name: '',
        quantity: 0,
        price: 0,
        supplier: '',
      ),
    );
    if (item.id.isEmpty) return;
    final newQty = (item.quantity + delta).clamp(0, 1000000);
    _productRepo.updateQuantity(itemId, newQty);
    _writeMovement(
      itemId: itemId,
      itemName: item.name,
      type: delta > 0 ? 'in' : 'out',
      quantityChange: delta,
      previousQuantity: item.quantity,
      newQuantity: newQty,
      note: note,
    );
  }

  void reorderItem(String itemId, int newMinQuantity) {
    if (_franchiseId == null) return;
    final item = state.items.firstWhere(
      (i) => i.id == itemId,
      orElse: () => const InventoryItem(
        id: '',
        name: '',
        quantity: 0,
        price: 0,
        supplier: '',
      ),
    );
    if (item.id.isEmpty) return;
    _db
        .collection('products')
        .doc(itemId)
        .update({
          'threshold': newMinQuantity,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .catchError((_) {});
    _writeMovement(
      itemId: itemId,
      itemName: item.name,
      type: 'reorder',
      quantityChange: 0,
      previousQuantity: item.quantity,
      newQuantity: item.quantity,
      note: 'Low-stock threshold set to $newMinQuantity',
    );
  }

  // Backwards-compat accessors
  List<InventoryItem> get items => state.items;
  List<InventoryMovement> get movements => state.movements;

  // -- Private helpers -------------------------------------------------------

  void _writeMovement({
    required String itemId,
    required String itemName,
    required String type,
    required int quantityChange,
    required int previousQuantity,
    required int newQuantity,
    required String note,
  }) {
    if (_franchiseId == null) return;
    _movementRepo.recordMovement(
      StockMovementModel(
        id: 'mov_${DateTime.now().microsecondsSinceEpoch}',
        productId: itemId,
        productName: itemName,
        type: type,
        quantity: quantityChange.abs(),
        previousQuantity: previousQuantity,
        newQuantity: newQuantity,
        franchiseId: _franchiseId!,
        reason: note,
        createdAt: DateTime.now(),
      ),
    );
  }

  static ProductModel _itemToProduct(InventoryItem item, String franchiseId) =>
      ProductModel(
        id: item.id,
        name: item.name,
        quantity: item.quantity,
        unitPrice: item.price,
        threshold: item.minQuantity,
        supplier: item.supplier,
        franchiseId: franchiseId,
      );

  static InventoryItem _productToItem(ProductModel p) => InventoryItem(
    id: p.id,
    name: p.name,
    quantity: p.quantity,
    price: p.unitPrice,
    supplier: p.supplier,
    minQuantity: p.threshold,
  );

  static InventoryMovement _movementToLegacy(StockMovementModel m) =>
      InventoryMovement(
        id: m.id,
        itemId: m.productId,
        itemName: m.productName,
        type: m.type,
        quantityChange: m.quantity,
        previousQuantity: m.previousQuantity,
        newQuantity: m.newQuantity,
        note: m.reason,
        createdAt: m.createdAt ?? DateTime.now(),
      );

  @override
  void dispose() {
    _itemsSub?.cancel();
    _movementsSub?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider - same name, zero screen changes needed.
// ---------------------------------------------------------------------------
final inventoryProvider =
    StateNotifierProvider<InventoryController, InventoryState>((ref) {
      ref.watch(currentUserProvider);
      return InventoryController();
    });
