import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class BranchRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collectionName = 'branches';

  /// Get all branches
  Future<List<Branch>> getAllBranches() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => Branch.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Error fetching branches: $e';
    }
  }

  /// Stream all branches
  Stream<List<Branch>> streamAllBranches() {
    return _firestore
        .collection(_collectionName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Branch.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Get branches by status
  Future<List<Branch>> getBranchesByStatus(BranchStatus status) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('status', isEqualTo: status.key)
          .get();
      return snapshot.docs
          .map((doc) => Branch.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Error fetching branches by status: $e';
    }
  }

  /// Get single branch
  Future<Branch?> getBranch(String branchId) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(branchId)
          .get();
      if (!doc.exists) return null;
      return Branch.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw 'Error fetching branch: $e';
    }
  }

  /// Stream single branch
  Stream<Branch?> streamBranch(String branchId) {
    return _firestore.collection(_collectionName).doc(branchId).snapshots().map(
      (doc) {
        if (!doc.exists) return null;
        return Branch.fromMap(doc.data()!, doc.id);
      },
    );
  }

  /// Create branch
  Future<String> createBranch(Branch branch) async {
    try {
      final docRef = await _firestore
          .collection(_collectionName)
          .add(branch.toMap());
      return docRef.id;
    } catch (e) {
      throw 'Error creating branch: $e';
    }
  }

  /// Update branch
  Future<void> updateBranch(String branchId, Branch branch) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(branchId)
          .set(branch.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw 'Error updating branch: $e';
    }
  }

  /// Delete branch
  Future<void> deleteBranch(String branchId) async {
    try {
      await _firestore.collection(_collectionName).doc(branchId).delete();
    } catch (e) {
      throw 'Error deleting branch: $e';
    }
  }

  /// Get total active branches
  Future<int> getTotalActiveBranches() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('status', isEqualTo: BranchStatus.active.key)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw 'Error counting active branches: $e';
    }
  }

  /// Get main branch
  Future<Branch?> getMainBranch() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('type', isEqualTo: BranchType.main.key)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return Branch.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    } catch (e) {
      throw 'Error fetching main branch: $e';
    }
  }

  /// Get franchise branches
  Future<List<Branch>> getFranchiseBranches() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('type', isEqualTo: BranchType.franchise.key)
          .get();
      return snapshot.docs
          .map((doc) => Branch.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Error fetching franchise branches: $e';
    }
  }
}
