import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/data/demo_data.dart';
import 'glass_panel.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.currentIndex, required this.child});

  final int currentIndex;
  final Widget child;

  static const _routes = <String>[
    '/',
    '/projects',
    '/invoices',
    '/inventory',
    '/clients',
    '/history',
    '/settings',
  ];
  static const _destinations = <({String label, IconData icon})>[
    (label: 'Dashboard', icon: Icons.space_dashboard_rounded),
    (label: 'Services', icon: Icons.precision_manufacturing_rounded),
    (label: 'Invoices', icon: Icons.request_quote_rounded),
    (label: 'Products', icon: Icons.inventory_2_rounded),
    (label: 'Clients', icon: Icons.groups_rounded),
    (label: 'History', icon: Icons.history_rounded),
    (label: 'Settings', icon: Icons.tune_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logoBytes = ref.watch(invoiceLogoBytesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF050505),
                    Color(0xFF121212),
                    Color(0xFF1B120D),
                  ]
                : const [
                    Color(0xFFFDFDFD),
                    Color(0xFFF4F4F4),
                    Color(0xFFFFF6ED),
                  ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1100;
              final content = Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  children: [
                    const _HeaderBar(),
                    const SizedBox(height: 20),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: child,
                      ),
                    ),
                  ],
                ),
              );

              if (wide) {
                return Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: GlassPanel(
                        child: NavigationRail(
                          selectedIndex: currentIndex,
                          onDestinationSelected: (index) =>
                              context.go(_routes[index]),
                          extended: true,
                          leading: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppTheme.accent,
                                        AppTheme.accentSoft,
                                      ],
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: logoBytes == null
                                      ? const Text(
                                          'RLX',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        )
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: Image.memory(
                                            logoBytes,
                                            fit: BoxFit.cover,
                                            width: 56,
                                            height: 56,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'RLX Invoice',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                          ),
                          destinations: _destinations
                              .map(
                                (item) => NavigationRailDestination(
                                  icon: Icon(item.icon),
                                  label: Text(item.label),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    Expanded(child: content),
                  ],
                );
              }

              return Column(
                children: [
                  Expanded(child: content),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: NavigationBar(
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysHide,
                        selectedIndex: currentIndex,
                        onDestinationSelected: (index) =>
                            context.go(_routes[index]),
                        height: 64,
                        destinations: _destinations
                            .map(
                              (item) => NavigationDestination(
                                icon: Icon(item.icon, size: 24),
                                label: '',
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RLX INVOICE', style: textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Premium quotation, inventory, and invoice operations control.',
                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.notifications_active_rounded,
                color: AppTheme.accent,
              ),
              tooltip: 'Notifications',
            ),
          ),
        ],
      ),
    );
  }
}
