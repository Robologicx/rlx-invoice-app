import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../database/local_database.dart';
import '../services/firebase_auth_service.dart';
import 'data_migration_service.dart';

const _flatMigrationDonePrefix = 'flat_migration_done_';

/// Runs flat data migration once per authenticated user.
final migrationBootstrapProvider = Provider<void>((ref) {
  ref.listen(currentUserProvider, (previous, next) {
    if (next == null) {
      return;
    }

    unawaited(
      _runMigrationOnce(
        uid: next.uid,
        migrationService: ref.read(flatDataMigrationServiceProvider),
      ),
    );
  });
});

Future<void> _runMigrationOnce({
  required String uid,
  required FlatDataMigrationService migrationService,
}) async {
  if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
    return;
  }

  final key = '$_flatMigrationDonePrefix$uid';
  final box = Hive.box(LocalDatabase.appSettingsBox);
  final alreadyDone = box.get(key, defaultValue: false) as bool? ?? false;
  if (alreadyDone) {
    return;
  }

  final result = await migrationService.migrateUserData(uid);
  if (result.success) {
    await box.put(key, true);
  }
}
