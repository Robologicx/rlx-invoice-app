import 'package:hive_flutter/hive_flutter.dart';

class LocalDatabase {
  static const templatesBox = 'templates_box';
  static const invoicesBox = 'invoices_box';
  static const productsBox = 'products_box';
  static const appSettingsBox = 'app_settings_box';
  static const inventoryItemsBox = 'inventory_items_box';
  static const inventoryMovementsBox = 'inventory_movements_box';
  static const expensesBox = 'expenses_box';
  static const fixedMonthlyExpensesBox = 'fixed_monthly_expenses_box';
  static const teamMembersBox = 'team_members_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<Map>(templatesBox),
      Hive.openBox<Map>(invoicesBox),
      Hive.openBox<Map>(productsBox),
      Hive.openBox(appSettingsBox),
      Hive.openBox<Map>(inventoryItemsBox),
      Hive.openBox<Map>(inventoryMovementsBox),
      Hive.openBox<Map>(expensesBox),
      Hive.openBox<Map>(fixedMonthlyExpensesBox),
      Hive.openBox<Map>(teamMembersBox),
    ]);
  }
}
