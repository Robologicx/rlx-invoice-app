import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/finance/presentation/finance_screen.dart';
import '../../features/history/presentation/invoice_history_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/invoices/presentation/invoices_screen.dart';
import '../../features/projects/presentation/projects_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/team/presentation/team_screen.dart';
import '../../shared/presentation/widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const AppShell(currentIndex: 0, child: DashboardScreen()),
      ),
      GoRoute(
        path: '/projects',
        builder: (context, state) =>
            const AppShell(currentIndex: 1, child: ProjectsScreen()),
      ),
      GoRoute(
        path: '/invoices',
        builder: (context, state) =>
            const AppShell(currentIndex: 2, child: InvoicesScreen()),
      ),
      GoRoute(
        path: '/inventory',
        builder: (context, state) =>
            const AppShell(currentIndex: 3, child: InventoryScreen()),
      ),
      GoRoute(
        path: '/finance',
        builder: (context, state) =>
            const AppShell(currentIndex: 4, child: FinanceScreen()),
      ),
      GoRoute(
        path: '/team',
        builder: (context, state) =>
            const AppShell(currentIndex: 5, child: TeamScreen()),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) =>
            const AppShell(currentIndex: 6, child: InvoiceHistoryScreen()),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            const AppShell(currentIndex: 7, child: SettingsScreen()),
      ),
    ],
  );
});
