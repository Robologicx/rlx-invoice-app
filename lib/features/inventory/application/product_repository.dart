import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/flat_models.dart';
import '../../../core/services/firebase_auth_service.dart';

// ---------------------------------------------------------------------------
// ProductRepository  →  top-level `products` collection
// All queries are scoped by franchiseId.
// ---------------------------------------------------------------------------
class ProductRepository {
  ProductRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('products');

  // ── Real-time stream ──────────────────────────────────────────────────────

  Stream<List<ProductModel>> watchProducts(String franchiseId) {
    return _col
        .where('franchiseId', isEqualTo: franchiseId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => ProductModel.fromFirestore(doc)).toList(),
        )
        .handleError((_) => <ProductModel>[]);
  }

  // ── One-off read ──────────────────────────────────────────────────────────

  Future<List<ProductModel>> fetchProducts(String franchiseId) async {
    try {
      final snap = await _col
          .where('franchiseId', isEqualTo: franchiseId)
          .get();
      return snap.docs.map(ProductModel.fromFirestore).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<ProductModel?> fetchProduct(String productId) async {
    try {
      final doc = await _col.doc(productId).get();
      if (!doc.exists) return null;
      return ProductModel.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<String> upsertProduct(ProductModel product) async {
    final docRef = product.id.isEmpty ? _col.doc() : _col.doc(product.id);
    final data = product.toFirestore();
    await docRef.set(data, SetOptions(merge: true));
    return docRef.id;
  }

  /// Update only the quantity field of an existing product.
  Future<void> updateQuantity(String productId, int newQuantity) async {
    await _col.doc(productId).update({
      'quantity': newQuantity,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProduct(String productId) async {
    await _col.doc(productId).delete();
  }

  /// Idempotent write used during migration: only writes if no doc exists.
  Future<void> upsertIfAbsent(ProductModel product) async {
    final docRef = _col.doc(product.id);
    final existing = await docRef.get();
    if (existing.exists) return;
    await docRef.set(product.toFirestore());
  }
}

// ---------------------------------------------------------------------------
// MovementRepository  →  top-level `movements` collection  (append-only)
// ---------------------------------------------------------------------------
class MovementRepository {
  MovementRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('movements');

  // ── Real-time stream ──────────────────────────────────────────────────────

  Stream<List<StockMovementModel>> watchMovements(String franchiseId) {
    return _col
        .where('franchiseId', isEqualTo: franchiseId)
        .orderBy('createdAt', descending: true)
        .limit(500) // guard against unbounded scans
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => StockMovementModel.fromFirestore(doc))
              .toList(),
        )
        .handleError((_) => <StockMovementModel>[]);
  }

  // ── Writes (append-only — never delete, never update) ────────────────────

  Future<String> recordMovement(StockMovementModel movement) async {
    final docRef = movement.id.isEmpty ? _col.doc() : _col.doc(movement.id);
    await docRef.set(movement.toFirestore());
    return docRef.id;
  }

  /// Idempotent write used during migration.
  Future<void> recordIfAbsent(StockMovementModel movement) async {
    if (movement.id.isEmpty) {
      await _col.add(movement.toFirestore());
      return;
    }
    final existing = await _col.doc(movement.id).get();
    if (existing.exists) return;
    await _col.doc(movement.id).set(movement.toFirestore());
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(),
);

final movementRepositoryProvider = Provider<MovementRepository>(
  (ref) => MovementRepository(),
);

/// Resolves the franchiseId for the currently signed-in user.
/// Returns null when no user is signed in.
final franchiseIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final branchId = doc.data()?['branchId'] as String?;
    return (branchId != null && branchId.isNotEmpty) ? branchId : user.uid;
  } catch (_) {
    return user.uid;
  }
});

/// Live product list for the current franchise.
final productsStreamProvider = StreamProvider<List<ProductModel>>((ref) async* {
  final franchiseId = await ref.watch(franchiseIdProvider.future);
  if (franchiseId == null) {
    yield const [];
    return;
  }
  final repo = ref.watch(productRepositoryProvider);
  yield* repo.watchProducts(franchiseId);
});

/// Live movement list for the current franchise.
final movementsStreamProvider = StreamProvider<List<StockMovementModel>>((
  ref,
) async* {
  final franchiseId = await ref.watch(franchiseIdProvider.future);
  if (franchiseId == null) {
    yield const [];
    return;
  }
  final repo = ref.watch(movementRepositoryProvider);
  yield* repo.watchMovements(franchiseId);
});
