import 'package:hive_flutter/hive_flutter.dart';

class LocalDatabase {
  static const templatesBox = 'templates_box';
  static const invoicesBox = 'invoices_box';
  static const productsBox = 'products_box';
  static const appSettingsBox = 'app_settings_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<Map>(templatesBox),
      Hive.openBox<Map>(invoicesBox),
      Hive.openBox<Map>(productsBox),
      Hive.openBox(appSettingsBox),
    ]);
  }
}
