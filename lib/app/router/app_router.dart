import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_mode_service.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/super_admin_login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/finance/presentation/finance_screen.dart';
import '../../features/history/presentation/invoice_history_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/invoices/presentation/invoices_screen.dart';
import '../../features/projects/presentation/projects_screen.dart';
import '../../features/super_admin/presentation/super_admin_shell.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/team/presentation/team_screen.dart';
import '../../shared/presentation/widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final offlineMode = ref.watch(appModeProvider);
  final authService = ref.watch(firebaseAuthServiceProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/super_admin_login';
      final isSuperAdminRoute = state.matchedLocation == '/super_admin';

      if (offlineMode) {
        if (isAuthRoute || state.matchedLocation == '/invoices') {
          return null;
        }
        return '/invoices';
      }

      final isLoggedIn = authState.maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );
      final isKnownSuperAdmin = authService.isKnownSuperAdminEmail;

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // Keep super admin and franchise experiences strictly separated.
      if (isLoggedIn && isKnownSuperAdmin && !isSuperAdminRoute) {
        return '/super_admin';
      }

      if (isLoggedIn && isSuperAdminRoute && !isKnownSuperAdmin) {
        return '/';
      }

      if (isLoggedIn && state.matchedLocation == '/super_admin_login') {
        return isKnownSuperAdmin ? '/super_admin' : '/';
      }

      if (isLoggedIn && state.matchedLocation == '/login') {
        return isKnownSuperAdmin ? '/super_admin' : '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/super_admin_login',
        builder: (context, state) => const SuperAdminLoginScreen(),
      ),
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
      GoRoute(
        path: '/super_admin',
        builder: (context, state) => const SuperAdminShell(),
      ),
    ],
  );
});
