import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'analytics_repository.dart';

class RoyaltyRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AnalyticsRepository _analyticsRepository = AnalyticsRepository();

  static const String _collectionName = 'royalties';

  /// Get all royalties
  Future<List<Royalty>> getAllRoyalties() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      final items = snapshot.docs
          .map((doc) => Royalty.fromMap(doc.data(), doc.id))
          .toList();
      items.sort((a, b) {
        final byYear = b.year.compareTo(a.year);
        if (byYear != 0) return byYear;
        return b.month.compareTo(a.month);
      });
      return items;
    } catch (e) {
      throw 'Error fetching royalties: $e';
    }
  }

  /// Stream all royalties
  Stream<List<Royalty>> streamAllRoyalties() {
    return _firestore.collection(_collectionName).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => Royalty.fromMap(doc.data(), doc.id))
          .toList();
      items.sort((a, b) {
        final byYear = b.year.compareTo(a.year);
        if (byYear != 0) return byYear;
        return b.month.compareTo(a.month);
      });
      return items;
    });
  }

  /// Get royalties for a branch
  Future<List<Royalty>> getBranchRoyalties(String branchId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('branchId', isEqualTo: branchId)
          .get();
      final items = snapshot.docs
          .map((doc) => Royalty.fromMap(doc.data(), doc.id))
          .toList();
      items.sort((a, b) {
        final byYear = b.year.compareTo(a.year);
        if (byYear != 0) return byYear;
        return b.month.compareTo(a.month);
      });
      return items;
    } catch (e) {
      throw 'Error fetching branch royalties: $e';
    }
  }

  /// Stream royalties for a branch
  Stream<List<Royalty>> streamBranchRoyalties(String branchId) {
    return _firestore
        .collection(_collectionName)
        .where('branchId', isEqualTo: branchId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => Royalty.fromMap(doc.data(), doc.id))
              .toList();
          items.sort((a, b) {
            final byYear = b.year.compareTo(a.year);
            if (byYear != 0) return byYear;
            return b.month.compareTo(a.month);
          });
          return items;
        });
  }

  /// Real-time due amount computed from current month analytics and branch royalty percentages.
  Stream<double> streamCurrentMonthRoyaltiesDue() {
    final now = DateTime.now();
    return _firestore
        .collection('branch_analytics')
        .snapshots()
        .asyncMap((snapshot) async {
          var monthDocs = snapshot.docs.where((doc) {
            final data = doc.data();
            return data['month'] == now.month && data['year'] == now.year;
          }).toList();

          if (monthDocs.isEmpty) {
            // Ensure analytics exists by triggering repository fallback computation.
            await _analyticsRepository.getCurrentMonthAnalytics();
            final refreshed = await _firestore
                .collection('branch_analytics')
                .where('month', isEqualTo: now.month)
                .where('year', isEqualTo: now.year)
                .get();
            monthDocs = refreshed.docs;
          }

          final branchesSnap = await _firestore.collection('branches').get();
          final branchRate = <String, double>{
            for (final b in branchesSnap.docs)
              b.id: (b.data()['royaltyPercentage'] as num?)?.toDouble() ?? 0.0,
          };

          // Load saved royalty payment docs so we can subtract already-paid amounts.
          final royaltySnap = await _firestore
              .collection(_collectionName)
              .get();
          final paidByBranch = <String, double>{};
          for (final r in royaltySnap.docs) {
            final d = r.data();
            if (d['month'] == now.month && d['year'] == now.year) {
              final bid = d['branchId'] as String? ?? '';
              if (bid.isNotEmpty) {
                paidByBranch[bid] =
                    (d['paidAmount'] as num?)?.toDouble() ?? 0.0;
              }
            }
          }

          double due = 0.0;
          for (final doc in monthDocs) {
            final data = doc.data();
            final branchId = data['branchId'] as String? ?? '';
            if (branchId.isEmpty) continue;
            final sales = (data['totalSales'] as num?)?.toDouble() ?? 0.0;
            final rate = branchRate[branchId] ?? 0.0;
            final royaltyAmount = (sales * rate) / 100.0;
            final paid = paidByBranch[branchId] ?? 0.0;
            final remaining = (royaltyAmount - paid).clamp(
              0.0,
              double.infinity,
            );
            due += remaining;
          }
          return due;
        })
        .handleError((_) => 0.0);
  }

  /// Real-time collected amount from explicit royalty payment records.
  Stream<double> streamTotalRoyaltiesCollected() {
    return _firestore
        .collection(_collectionName)
        .where('status', isEqualTo: RoyaltyStatus.paid.key)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.fold<double>(0.0, (total, doc) {
            final data = doc.data();
            return total + ((data['paidAmount'] as num?)?.toDouble() ?? 0.0);
          });
        })
        .handleError((_) => 0.0);
  }

  /// Real-time royalty table calculated from current month sales.
  Stream<List<Royalty>> streamCurrentMonthComputedRoyalties() {
    final now = DateTime.now();
    return _firestore
        .collection('branch_analytics')
        .snapshots()
        .asyncMap((analyticsSnap) async {
          var monthAnalytics = analyticsSnap.docs.where((doc) {
            final data = doc.data();
            return data['month'] == now.month && data['year'] == now.year;
          }).toList();

          if (monthAnalytics.isEmpty) {
            await _analyticsRepository.getCurrentMonthAnalytics();
            final refreshed = await _firestore
                .collection('branch_analytics')
                .where('month', isEqualTo: now.month)
                .where('year', isEqualTo: now.year)
                .get();
            monthAnalytics = refreshed.docs;
          }

          final branchesSnap = await _firestore.collection('branches').get();
          final royaltiesSnap = await _firestore
              .collection(_collectionName)
              .get();

          final branchById = {
            for (final b in branchesSnap.docs) b.id: b.data(),
          };
          final existingByBranch = <String, Map<String, dynamic>>{};
          for (final r in royaltiesSnap.docs) {
            final data = r.data();
            if (data['month'] == now.month && data['year'] == now.year) {
              final branchId = data['branchId'] as String? ?? '';
              if (branchId.isNotEmpty) {
                existingByBranch[branchId] = data;
              }
            }
          }

          final rows = <Royalty>[];
          for (final doc in monthAnalytics) {
            final data = doc.data();
            final branchId = data['branchId'] as String? ?? '';
            if (branchId.isEmpty) continue;

            final branch = branchById[branchId];
            final branchName =
                data['branchName'] as String? ??
                branch?['name'] as String? ??
                '';
            final sales = (data['totalSales'] as num?)?.toDouble() ?? 0.0;
            final rate =
                (branch?['royaltyPercentage'] as num?)?.toDouble() ?? 0.0;
            final royaltyAmount = (sales * rate) / 100.0;

            final existing = existingByBranch[branchId];
            final paidAmount =
                (existing?['paidAmount'] as num?)?.toDouble() ?? 0.0;
            final status = paidAmount <= 0
                ? RoyaltyStatus.pending
                : (paidAmount >= royaltyAmount
                      ? RoyaltyStatus.paid
                      : RoyaltyStatus.partiallyPaid);

            rows.add(
              Royalty(
                id: '${branchId}_${now.year}_${now.month.toString().padLeft(2, '0')}',
                branchId: branchId,
                branchName: branchName,
                month: now.month,
                year: now.year,
                totalSales: sales,
                royaltyPercentage: rate,
                royaltyAmount: royaltyAmount,
                paidAmount: paidAmount,
                status: status,
                paymentDate: (existing?['paymentDate'] as Timestamp?)?.toDate(),
                notes: existing?['notes'] as String?,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
          }

          rows.sort((a, b) => b.totalSales.compareTo(a.totalSales));
          return rows;
        })
        .handleError((_) => <Royalty>[]);
  }

  /// Get royalties for a specific month
  Future<List<Royalty>> getMonthlyRoyalties(int month, int year) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('month', isEqualTo: month)
          .where('year', isEqualTo: year)
          .get();
      return snapshot.docs
          .map((doc) => Royalty.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Error fetching monthly royalties: $e';
    }
  }

  /// Get pending royalties
  Future<List<Royalty>> getPendingRoyalties() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('status', isEqualTo: RoyaltyStatus.pending.key)
          .get();
      return snapshot.docs
          .map((doc) => Royalty.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Error fetching pending royalties: $e';
    }
  }

  /// Get single royalty
  Future<Royalty?> getRoyalty(String royaltyId) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(royaltyId)
          .get();
      if (!doc.exists) return null;
      return Royalty.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw 'Error fetching royalty: $e';
    }
  }

  /// Create royalty
  Future<String> createRoyalty(Royalty royalty) async {
    try {
      final docRef = await _firestore
          .collection(_collectionName)
          .add(royalty.toMap());
      return docRef.id;
    } catch (e) {
      throw 'Error creating royalty: $e';
    }
  }

  /// Update royalty
  Future<void> updateRoyalty(String royaltyId, Royalty royalty) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(royaltyId)
          .set(royalty.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw 'Error updating royalty: $e';
    }
  }

  /// Record payment
  Future<void> recordPayment({
    required String royaltyId,
    required double amount,
    String? notes,
  }) async {
    try {
      final royalty = await getRoyalty(royaltyId);
      if (royalty == null) throw 'Royalty not found';

      final newPaidAmount = royalty.paidAmount + amount;
      final status = newPaidAmount >= royalty.royaltyAmount
          ? RoyaltyStatus.paid
          : RoyaltyStatus.partiallyPaid;

      final updated = royalty.copyWith(
        paidAmount: newPaidAmount,
        status: status,
        paymentDate: status == RoyaltyStatus.paid
            ? DateTime.now()
            : royalty.paymentDate,
        notes: notes ?? royalty.notes,
      );

      await updateRoyalty(royaltyId, updated);
    } catch (e) {
      throw 'Error recording payment: $e';
    }
  }

  /// Record payment against a computed or saved monthly royalty row.
  Future<void> recordRoyaltyRowPayment(
    Royalty royalty, {
    required double amount,
    String? notes,
  }) async {
    try {
      if (amount <= 0) {
        throw 'Payment amount must be greater than zero';
      }

      final docRef = _firestore.collection(_collectionName).doc(royalty.id);
      final existingDoc = await docRef.get();

      final existing = existingDoc.exists
          ? Royalty.fromMap(existingDoc.data()!, existingDoc.id)
          : royalty;

      final newPaidAmount = existing.paidAmount + amount;
      final isFullyPaid = newPaidAmount >= existing.royaltyAmount;
      final updated = existing.copyWith(
        paidAmount: newPaidAmount,
        status: isFullyPaid ? RoyaltyStatus.paid : RoyaltyStatus.partiallyPaid,
        paymentDate: DateTime.now(),
        notes: notes ?? existing.notes,
      );

      await docRef.set(updated.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw 'Error recording royalty payment: $e';
    }
  }

  /// Get total royalties due
  Future<double> getTotalRoyaltiesDue() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('status', isEqualTo: RoyaltyStatus.pending.key)
          .get();

      return snapshot.docs.fold<double>(0.0, (sum, doc) {
        final data = doc.data();
        return sum + ((data['royaltyAmount'] as num?)?.toDouble() ?? 0.0);
      });
    } catch (e) {
      throw 'Error calculating total royalties due: $e';
    }
  }

  /// Get total royalties collected
  Future<double> getTotalRoyaltiesCollected() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('status', isEqualTo: RoyaltyStatus.paid.key)
          .get();

      return snapshot.docs.fold<double>(0.0, (sum, doc) {
        final data = doc.data();
        return sum + ((data['paidAmount'] as num?)?.toDouble() ?? 0.0);
      });
    } catch (e) {
      throw 'Error calculating total royalties collected: $e';
    }
  }
}
