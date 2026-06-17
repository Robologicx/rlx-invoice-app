import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../database/local_database.dart';

const _offlineInvoiceModeKey = 'offline_invoice_mode';

class AppModeController extends StateNotifier<bool> {
  AppModeController() : super(_readSavedOfflineMode());

  static bool _readSavedOfflineMode() {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return false;
    }

    return Hive.box(
              LocalDatabase.appSettingsBox,
            ).get(_offlineInvoiceModeKey, defaultValue: false)
            as bool? ??
        false;
  }

  Future<void> setOfflineInvoiceMode(bool enabled) async {
    state = enabled;

    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return;
    }

    await Hive.box(
      LocalDatabase.appSettingsBox,
    ).put(_offlineInvoiceModeKey, enabled);
  }
}

final appModeProvider = StateNotifierProvider<AppModeController, bool>((ref) {
  return AppModeController();
});
