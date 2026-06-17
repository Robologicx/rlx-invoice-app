import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_mode_service.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../features/auth/presentation/login_screen.dart';
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
  final authState = ref.watch(authStateProvider);
  final offlineMode = ref.watch(appModeProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (offlineMode) {
        if (state.matchedLocation == '/login' ||
            state.matchedLocation == '/invoices') {
          return null;
        }
        return '/invoices';
      }

      final isLoggedIn = authState.maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );

      final isLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLogin) {
        return '/login';
      }

      if (isLoggedIn && isLogin) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
