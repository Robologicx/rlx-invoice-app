import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'glass_panel.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.delta,
    required this.icon,
  });

  final String title;
  final String value;
  final String delta;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppTheme.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  delta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(value, style: textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            title,
            style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}
