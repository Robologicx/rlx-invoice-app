import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class AnalyticsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collectionName = 'branch_analytics';

  /// Get analytics for a branch in a specific month
  Future<BranchAnalytics?> getBranchMonthAnalytics(
    String branchId,
    int month,
    int year,
  ) async {
    try {
      final docId = '${branchId}_${year}_${month.toString().padLeft(2, '0')}';
      final doc = await _firestore.collection(_collectionName).doc(docId).get();
      if (!doc.exists) return null;
      return BranchAnalytics.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw 'Error fetching branch analytics: $e';
    }
  }

  /// Get all analytics for a branch
  Future<List<BranchAnalytics>> getBranchAnalytics(String branchId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('branchId', isEqualTo: branchId)
          .orderBy('year', descending: true)
          .orderBy('month', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => BranchAnalytics.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Error fetching branch analytics: $e';
    }
  }

  /// Stream branch analytics
  Stream<List<BranchAnalytics>> streamBranchAnalytics(String branchId) {
    return _firestore
        .collection(_collectionName)
        .where('branchId', isEqualTo: branchId)
        .orderBy('year', descending: true)
        .orderBy('month', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BranchAnalytics.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Get all analytics for current month
  Future<List<BranchAnalytics>> getCurrentMonthAnalytics() async {
    try {
      final now = DateTime.now();
      // Always recompute to keep dashboard real-time and avoid stale zero caches.
      return _computeAndCacheMonthAnalytics(now.month, now.year);
    } catch (e) {
      throw 'Error fetching current month analytics: $e';
    }
  }

  /// Create or update analytics
  Future<void> upsertAnalytics(BranchAnalytics analytics) async {
    try {
      final docId =
          '${analytics.branchId}_${analytics.year}_${analytics.month.toString().padLeft(2, '0')}';
      await _firestore
          .collection(_collectionName)
          .doc(docId)
          .set(analytics.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw 'Error upserting analytics: $e';
    }
  }

  /// Get total sales across all branches for a month
  Future<double> getTotalMonthlySales(int month, int year) async {
    try {
      final analytics = await _getMonthAnalyticsWithFallback(month, year);
      return analytics.fold<double>(0.0, (sum, item) => sum + item.totalSales);
    } catch (e) {
      throw 'Error calculating total monthly sales: $e';
    }
  }

  /// Get total invoices across all branches for a month
  Future<int> getTotalMonthlyInvoices(int month, int year) async {
    try {
      final analytics = await _getMonthAnalyticsWithFallback(month, year);
      return analytics.fold<int>(0, (sum, item) => sum + item.invoiceCount);
    } catch (e) {
      throw 'Error calculating total monthly invoices: $e';
    }
  }

  /// Get top performing branches for a month (no composite-index orderBy; sort in memory)
  Future<List<BranchAnalytics>> getTopBranches(
    int month,
    int year, {
    int limit = 5,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('month', isEqualTo: month)
          .where('year', isEqualTo: year)
          .get();

      List<BranchAnalytics> items = snapshot.docs
          .map((doc) => BranchAnalytics.fromMap(doc.data(), doc.id))
          .toList();

      if (items.isEmpty) {
        items = await _computeAndCacheMonthAnalytics(month, year);
      }

      items.sort((a, b) => b.totalSales.compareTo(a.totalSales));
      return items.take(limit).toList();
    } catch (e) {
      throw 'Error fetching top branches: $e';
    }
  }

  /// Real-time stream of monthly analytics; auto-computes if collection is empty.
  Stream<List<BranchAnalytics>> streamMonthAnalytics(int month, int year) {
    // Recompute whenever invoice data changes so sales stay live.
    return _firestore
        .collection('invoices')
        .snapshots()
        .asyncMap((_) => _computeAndCacheMonthAnalytics(month, year))
        .handleError((_) => <BranchAnalytics>[]);
  }

  /// Get total inventory value across all branches
  Future<double> getTotalInventoryValue() async {
    try {
      final snapshot = await _firestore.collection('products').get();
      return snapshot.docs.fold<double>(0.0, (sum, doc) {
        final data = doc.data();
        final quantity = (data['quantity'] as num?)?.toDouble() ?? 0.0;
        final unitPrice = (data['unitPrice'] as num?)?.toDouble() ?? 0.0;
        return sum + (quantity * unitPrice);
      });
    } catch (e) {
      throw 'Error calculating total inventory value: $e';
    }
  }

  /// Get total profit across all branches for a month
  Future<double> getTotalMonthlyProfit(int month, int year) async {
    try {
      final analytics = await _getMonthAnalyticsWithFallback(month, year);
      return analytics.fold<double>(0.0, (sum, item) => sum + item.profit);
    } catch (e) {
      throw 'Error calculating total monthly profit: $e';
    }
  }

  Future<List<BranchAnalytics>> _getMonthAnalyticsWithFallback(
    int month,
    int year,
  ) async {
    final snapshot = await _firestore
        .collection(_collectionName)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .get();

    final cached = snapshot.docs
        .map((doc) => BranchAnalytics.fromMap(doc.data(), doc.id))
        .toList();
    if (cached.isNotEmpty) {
      return cached;
    }

    return _computeAndCacheMonthAnalytics(month, year);
  }

  Future<List<BranchAnalytics>> _computeAndCacheMonthAnalytics(
    int month,
    int year,
  ) async {
    final start = Timestamp.fromDate(DateTime(year, month, 1));
    final end = Timestamp.fromDate(
      month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1),
    );

    final branchesSnapshot = await _firestore
        .collection('branches')
        .where('status', isEqualTo: 'active')
        .get();

    final computed = <BranchAnalytics>[];

    for (final branchDoc in branchesSnapshot.docs) {
      final branchId = branchDoc.id;
      final branchData = branchDoc.data();
      final branchName = (branchData['name'] as String?) ?? branchId;

      // Some branches store franchiseId as branch doc id, others as auth uid/code/name.
      final franchiseKeys = <String>{
        branchId,
        (branchData['authUid'] as String?) ?? '',
        (branchData['code'] as String?) ?? '',
        (branchData['name'] as String?) ?? '',
      }..removeWhere((k) => k.trim().isEmpty);

      final invoiceDocsById =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final key in franchiseKeys) {
        final snap = await _firestore
            .collection('invoices')
            .where('franchiseId', isEqualTo: key)
            .get();
        for (final d in snap.docs) {
          invoiceDocsById[d.id] = d;
        }
      }
      final allDocs = invoiceDocsById.values.toList();

      double totalSales = 0.0;
      double receivables = 0.0;
      int invoiceCount = 0;
      int quotationCount = 0;

      for (final doc in allDocs) {
        final docCreatedAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        // Only count target month. For legacy docs with no createdAt, include them.
        if (docCreatedAt != null &&
            (docCreatedAt.isBefore(start.toDate()) ||
                !docCreatedAt.isBefore(end.toDate()))) {
          continue;
        }
        final data = doc.data();
        final isInvoice = data['isInvoice'] as bool? ?? true;
        final amount =
            (data['grandTotal'] as num?)?.toDouble() ??
            (data['total'] as num?)?.toDouble() ??
            0.0;

        if (!isInvoice) {
          quotationCount += 1;
          continue;
        }

        invoiceCount += 1;
        totalSales += amount;

        final remaining = (data['remainingPayment'] as num?)?.toDouble() ?? 0.0;
        if (remaining > 0) {
          receivables += remaining;
        }
      }

      final inventoryValue = await _inventoryValueForBranch(branchId);

      final analytics = BranchAnalytics(
        id: '${branchId}_${year}_${month.toString().padLeft(2, '0')}',
        branchId: branchId,
        branchName: branchName,
        month: month,
        year: year,
        totalSales: totalSales,
        invoiceCount: invoiceCount,
        quotationCount: quotationCount,
        projectCount: 0,
        profit: totalSales,
        receivables: receivables,
        inventoryValue: inventoryValue,
        updatedAt: DateTime.now(),
      );

      computed.add(analytics);

      await _firestore
          .collection(_collectionName)
          .doc(analytics.id)
          .set(analytics.toMap(), SetOptions(merge: true));
    }

    return computed;
  }

  Future<double> _inventoryValueForBranch(String branchId) async {
    final snapshot = await _firestore
        .collection('products')
        .where('franchiseId', isEqualTo: branchId)
        .get();

    return snapshot.docs.fold<double>(0.0, (sum, doc) {
      final data = doc.data();
      final quantity = (data['quantity'] as num?)?.toDouble() ?? 0.0;
      final unitPrice = (data['unitPrice'] as num?)?.toDouble() ?? 0.0;
      return sum + (quantity * unitPrice);
    });
  }
}
