import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user's collection reference
  CollectionReference<Map<String, dynamic>> userCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('data');
  }

  /// Save invoice
  Future<String> saveInvoice(
    String userId, {
    required String? id,
    required Map<String, dynamic> invoiceData,
  }) async {
    try {
      final collection = userCollection(userId);
      if (id != null) {
        await collection.doc(id).set(invoiceData, SetOptions(merge: true));
        return id;
      } else {
        final docRef = await collection.add(invoiceData);
        return docRef.id;
      }
    } catch (e) {
      throw 'Error saving invoice: $e';
    }
  }

  /// Get single invoice
  Future<Map<String, dynamic>?> getInvoice(
    String userId,
    String invoiceId,
  ) async {
    try {
      final doc = await userCollection(userId).doc(invoiceId).get();
      return doc.data();
    } catch (e) {
      throw 'Error fetching invoice: $e';
    }
  }

  /// Get all invoices
  Future<List<Map<String, dynamic>>> getInvoices(String userId) async {
    try {
      final snapshot = await userCollection(userId)
          .where('type', isEqualTo: 'invoice')
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw 'Error fetching invoices: $e';
    }
  }

  /// Delete invoice
  Future<void> deleteInvoice(String userId, String invoiceId) async {
    try {
      await userCollection(userId).doc(invoiceId).delete();
    } catch (e) {
      throw 'Error deleting invoice: $e';
    }
  }

  /// Stream invoices
  Stream<List<Map<String, dynamic>>> streamInvoices(String userId) {
    return userCollection(userId)
        .where('type', isEqualTo: 'invoice')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  /// Save settings
  Future<void> saveSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'settings': settings,
      }, SetOptions(merge: true));
    } catch (e) {
      throw 'Error saving settings: $e';
    }
  }

  /// Get settings
  Future<Map<String, dynamic>?> getSettings(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      return data?['settings'] as Map<String, dynamic>?;
    } catch (e) {
      throw 'Error fetching settings: $e';
    }
  }

  /// Stream settings
  Stream<Map<String, dynamic>?> streamSettings(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      final data = doc.data();
      return data?['settings'] as Map<String, dynamic>?;
    });
  }

  /// Save service catalog
  Future<void> saveServiceCatalog(
    String userId,
    Map<String, dynamic> catalog,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'catalog': catalog,
      }, SetOptions(merge: true));
    } catch (e) {
      throw 'Error saving catalog: $e';
    }
  }

  /// Get service catalog
  Future<Map<String, dynamic>?> getServiceCatalog(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      return data?['catalog'] as Map<String, dynamic>?;
    } catch (e) {
      throw 'Error fetching catalog: $e';
    }
  }

  /// Stream service catalog
  Stream<Map<String, dynamic>?> streamServiceCatalog(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      final data = doc.data();
      return data?['catalog'] as Map<String, dynamic>?;
    });
  }

  /// Save inventory
  Future<void> saveInventory(
    String userId,
    List<Map<String, dynamic>> inventory,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'inventory': inventory,
      }, SetOptions(merge: true));
    } catch (e) {
      throw 'Error saving inventory: $e';
    }
  }

  /// Get inventory
  Future<List<Map<String, dynamic>>> getInventory(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      final inventory = data?['inventory'] as List?;
      return inventory?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      throw 'Error fetching inventory: $e';
    }
  }

  /// Stream inventory
  Stream<List<Map<String, dynamic>>> streamInventory(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      final data = doc.data();
      final inventory = data?['inventory'] as List?;
      return inventory?.cast<Map<String, dynamic>>() ?? [];
    });
  }

  /// Batch write documents
  Future<void> batchWrite(
    String userId,
    List<({String id, Map<String, dynamic> data})> updates,
  ) async {
    try {
      final batch = _firestore.batch();
      final collection = userCollection(userId);

      for (final update in updates) {
        batch.set(
          collection.doc(update.id),
          update.data,
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    } catch (e) {
      throw 'Error in batch write: $e';
    }
  }

  /// Save expenses
  Future<void> saveExpenses(
    String userId,
    List<Map<String, dynamic>> expenses,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'expenses': expenses,
      }, SetOptions(merge: true));
    } catch (e) {
      throw 'Error saving expenses: $e';
    }
  }

  /// Get expenses
  Future<List<Map<String, dynamic>>> getExpenses(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      final expenses = data?['expenses'] as List?;
      return expenses?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      throw 'Error fetching expenses: $e';
    }
  }

  /// Save team members
  Future<void> saveTeamMembers(
    String userId,
    List<Map<String, dynamic>> teamMembers,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'teamMembers': teamMembers,
      }, SetOptions(merge: true));
    } catch (e) {
      throw 'Error saving team members: $e';
    }
  }

  /// Get team members
  Future<List<Map<String, dynamic>>> getTeamMembers(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      final teamMembers = data?['teamMembers'] as List?;
      return teamMembers?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      throw 'Error fetching team members: $e';
    }
  }

  /// Save a single client
  Future<String> saveClient(
    String userId, {
    required String? id,
    required Map<String, dynamic> clientData,
  }) async {
    try {
      final collection = _firestore
          .collection('users')
          .doc(userId)
          .collection('clients');
      if (id != null) {
        await collection.doc(id).set(clientData, SetOptions(merge: true));
        return id;
      } else {
        final docRef = await collection.add(clientData);
        return docRef.id;
      }
    } catch (e) {
      throw 'Error saving client: $e';
    }
  }

  /// Get all clients for a user
  Future<List<Map<String, dynamic>>> getClients(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('clients')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw 'Error fetching clients: $e';
    }
  }

  /// Stream clients for a user
  Stream<List<Map<String, dynamic>>> streamClients(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('clients')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  /// Delete a client
  Future<void> deleteClient(String userId, String clientId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('clients')
          .doc(clientId)
          .delete();
    } catch (e) {
      throw 'Error deleting client: $e';
    }
  }
}

final firestoreServiceProvider = Provider((ref) => FirestoreService());
