import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firestore_service.dart';
import '../services/firebase_auth_service.dart';

// INVOICE MANAGEMENT

final cloudInvoicesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
      final firestoreService = ref.watch(firestoreServiceProvider);
      return firestoreService.streamInvoices(userId);
    });

final saveCloudInvoiceProvider =
    FutureProvider.family<String, ({String? id, Map<String, dynamic> data})>((
      ref,
      params,
    ) async {
      final userId = ref.watch(userIdProvider);
      if (userId == null) throw 'User not authenticated';

      final firestoreService = ref.watch(firestoreServiceProvider);
      return firestoreService.saveInvoice(
        userId,
        id: params.id,
        invoiceData: params.data,
      );
    });

final deleteCloudInvoiceProvider =
    FutureProvider.family<void, ({String userId, String invoiceId})>((
      ref,
      params,
    ) async {
      final firestoreService = ref.watch(firestoreServiceProvider);
      await firestoreService.deleteInvoice(params.userId, params.invoiceId);
    });

// SETTINGS MANAGEMENT

final cloudSettingsProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return const Stream.empty();

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.streamSettings(userId);
});

final saveCloudSettingsProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, settings) async {
      final userId = ref.watch(userIdProvider);
      if (userId == null) throw 'User not authenticated';

      final firestoreService = ref.watch(firestoreServiceProvider);
      await firestoreService.saveSettings(userId, settings);
    });

// SERVICE CATALOG MANAGEMENT

final cloudServiceCatalogProvider = StreamProvider<Map<String, dynamic>?>((
  ref,
) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return const Stream.empty();

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.streamServiceCatalog(userId);
});

final saveCloudServiceCatalogProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, catalog) async {
      final userId = ref.watch(userIdProvider);
      if (userId == null) throw 'User not authenticated';

      final firestoreService = ref.watch(firestoreServiceProvider);
      await firestoreService.saveServiceCatalog(userId, catalog);
    });

// INVENTORY MANAGEMENT

final cloudInventoryProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return const Stream.empty();

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.streamInventory(userId);
});

final saveCloudInventoryProvider =
    FutureProvider.family<void, List<Map<String, dynamic>>>((
      ref,
      inventory,
    ) async {
      final userId = ref.watch(userIdProvider);
      if (userId == null) throw 'User not authenticated';

      final firestoreService = ref.watch(firestoreServiceProvider);
      await firestoreService.saveInventory(userId, inventory);
    });

// CLIENTS MANAGEMENT

final cloudClientsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return const Stream.empty();

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.streamClients(userId);
});

final saveCloudClientProvider =
    FutureProvider.family<String, ({String? id, Map<String, dynamic> data})>((
      ref,
      params,
    ) async {
      final userId = ref.watch(userIdProvider);
      if (userId == null) throw 'User not authenticated';

      final firestoreService = ref.watch(firestoreServiceProvider);
      return firestoreService.saveClient(
        userId,
        id: params.id,
        clientData: params.data,
      );
    });

final deleteCloudClientProvider =
    FutureProvider.family<void, ({String userId, String clientId})>((
      ref,
      params,
    ) async {
      final firestoreService = ref.watch(firestoreServiceProvider);
      await firestoreService.deleteClient(params.userId, params.clientId);
    });

// LOGOUT PROVIDER

final logoutProvider = FutureProvider((ref) async {
  final authService = ref.watch(firebaseAuthServiceProvider);
  await authService.logout();
});
