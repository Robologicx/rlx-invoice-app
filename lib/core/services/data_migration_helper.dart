import 'package:hive_flutter/hive_flutter.dart';

import '../services/firestore_service.dart';

/// Helper class to migrate data from Hive to Firestore
class DataMigrationHelper {
  static Future<void> migrateUserData({
    required String userId,
    required FirestoreService firestoreService,
  }) async {
    try {
      // Migrate app settings
      await _migrateSettings(userId, firestoreService);

      // Migrate invoice policy sections
      await _migrateInvoicePolicySections(userId, firestoreService);

      // Migrate service catalog
      await _migrateServiceCatalog(userId, firestoreService);

      // Migrate invoices
      await _migrateInvoices(userId, firestoreService);

      // Migrate inventory
      await _migrateInventory(userId, firestoreService);

      // Migrate expenses
      await _migrateExpenses(userId, firestoreService);

      // Migrate team members
      await _migrateTeamMembers(userId, firestoreService);

      print('Data migration completed successfully');
    } catch (e) {
      print('Error during migration: $e');
      rethrow;
    }
  }

  static Future<void> _migrateSettings(
    String userId,
    FirestoreService firestoreService,
  ) async {
    try {
      final appSettingsBox = Hive.box('app_settings_box');

      final settings = {
        'geminiApiKey': appSettingsBox.get('gemini_api_key', defaultValue: ''),
        'invoiceLogoBytes': appSettingsBox.get('invoice_logo_bytes'),
        'businessDetails': appSettingsBox.get(
          'invoice_business_details',
          defaultValue: {},
        ),
        'migratedAt': DateTime.now().toIso8601String(),
      };

      await firestoreService.saveSettings(userId, settings);
    } catch (e) {
      print('Error migrating settings: $e');
    }
  }

  static Future<void> _migrateInvoicePolicySections(
    String userId,
    FirestoreService firestoreService,
  ) async {
    try {
      final appSettingsBox = Hive.box('app_settings_box');

      final policySections = appSettingsBox.get(
        'invoice_policy_sections',
        defaultValue: {},
      );

      if (policySections.isNotEmpty) {
        await firestoreService.saveSettings(userId, {
          'policySections': policySections,
        });
      }
    } catch (e) {
      print('Error migrating policy sections: $e');
    }
  }

  static Future<void> _migrateServiceCatalog(
    String userId,
    FirestoreService firestoreService,
  ) async {
    try {
      final appSettingsBox = Hive.box('app_settings_box');

      final catalog = appSettingsBox.get(
        'service_catalog_edits',
        defaultValue: {},
      );

      if (catalog.isNotEmpty) {
        await firestoreService.saveServiceCatalog(userId, catalog);
      }
    } catch (e) {
      print('Error migrating service catalog: $e');
    }
  }

  static Future<void> _migrateInvoices(
    String userId,
    FirestoreService firestoreService,
  ) async {
    try {
      final invoicesBox = Hive.box('invoices_box');

      final updates = <({String id, Map<String, dynamic> data})>[];

      for (final key in invoicesBox.keys) {
        final invoice = invoicesBox.get(key);
        if (invoice != null) {
          updates.add((
            id: key.toString(),
            data: {
              ...invoice,
              'type': 'invoice',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'migratedFrom': 'hive',
            },
          ));
        }
      }

      if (updates.isNotEmpty) {
        await firestoreService.batchWrite(userId, updates);
      }
    } catch (e) {
      print('Error migrating invoices: $e');
    }
  }

  static Future<void> _migrateInventory(
    String userId,
    FirestoreService firestoreService,
  ) async {
    try {
      final inventoryBox = Hive.box('inventory_items_box');

      final inventory = <Map<String, dynamic>>[];

      for (final key in inventoryBox.keys) {
        final item = inventoryBox.get(key);
        if (item != null) {
          inventory.add({...item, 'id': key.toString()});
        }
      }

      if (inventory.isNotEmpty) {
        await firestoreService.saveInventory(userId, inventory);
      }
    } catch (e) {
      print('Error migrating inventory: $e');
    }
  }

  static Future<void> _migrateExpenses(
    String userId,
    FirestoreService firestoreService,
  ) async {
    try {
      final expensesBox = Hive.box('expenses_box');
      final fixedExpensesBox = Hive.box('fixed_monthly_expenses_box');

      final expenses = <Map<String, dynamic>>[];

      // Migrate variable expenses
      for (final key in expensesBox.keys) {
        final expense = expensesBox.get(key);
        if (expense != null) {
          expenses.add({...expense, 'id': key.toString(), 'type': 'variable'});
        }
      }

      // Migrate fixed expenses
      for (final key in fixedExpensesBox.keys) {
        final expense = fixedExpensesBox.get(key);
        if (expense != null) {
          expenses.add({...expense, 'id': key.toString(), 'type': 'fixed'});
        }
      }

      if (expenses.isNotEmpty) {
        // Save as a single document instead of individual items
        await firestoreService.saveExpenses(userId, expenses);
      }
    } catch (e) {
      print('Error migrating expenses: $e');
    }
  }

  static Future<void> _migrateTeamMembers(
    String userId,
    FirestoreService firestoreService,
  ) async {
    try {
      final teamBox = Hive.box('team_members_box');

      final teamMembers = <Map<String, dynamic>>[];

      for (final key in teamBox.keys) {
        final member = teamBox.get(key);
        if (member != null) {
          teamMembers.add({...member, 'id': key.toString()});
        }
      }

      if (teamMembers.isNotEmpty) {
        await firestoreService.saveTeamMembers(userId, teamMembers);
      }
    } catch (e) {
      print('Error migrating team members: $e');
    }
  }
}
