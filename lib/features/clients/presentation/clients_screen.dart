import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/data/demo_data.dart';
import '../../../shared/presentation/widgets/glass_panel.dart';

class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);
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
                          child: Text(client.name, style: textTheme.titleLarge),
                        ),
                        Chip(label: Text(client.paymentStatus)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(client.projectType, style: textTheme.bodyLarge),
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
                    Text('Previous history', style: textTheme.titleLarge),
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
      ),
    );
  }
}
