import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/data/demo_data.dart';
import '../../../shared/presentation/widgets/glass_panel.dart';

class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsProvider);
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Client Management', style: textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Track payment status, service history, and client communications in one panel.',
            style: textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 24),
          clientsAsync.when(
            data: (clients) {
              if (clients.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No clients yet. Create a new client to get started.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  ...clients.map(
                    (client) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    client.name,
                                    style: textTheme.titleLarge,
                                  ),
                                ),
                                Chip(label: Text(client.paymentStatus)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              client.projectType,
                              style: textTheme.bodyLarge,
                            ),
                            Text(
                              client.phone,
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppTheme.muted,
                              ),
                            ),
                            Text(
                              client.address,
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Previous history',
                              style: textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              client.previousHistory,
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                    const SizedBox(height: 16),
                    Text('Failed to load clients', style: textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
