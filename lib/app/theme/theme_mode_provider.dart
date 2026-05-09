import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../database/local_database.dart';

const _themeModeKey = 'theme_mode';

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(_loadThemeMode());

  void setThemeMode(ThemeMode mode) {
    state = mode;
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return;
    }
    Hive.box(LocalDatabase.appSettingsBox).put(_themeModeKey, mode.name);
  }

  static ThemeMode _loadThemeMode() {
    if (!Hive.isBoxOpen(LocalDatabase.appSettingsBox)) {
      return ThemeMode.dark;
    }
    final saved = Hive.box(LocalDatabase.appSettingsBox).get(_themeModeKey);
    if (saved is! String) {
      return ThemeMode.dark;
    }
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.dark,
    );
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);
