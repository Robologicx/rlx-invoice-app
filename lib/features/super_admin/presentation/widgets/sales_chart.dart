import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/super_admin_providers.dart';

const _kBarColors = [
  Color(0xFF2196F3),
  Color(0xFF4CAF50),
  Color(0xFFF44336),
  Color(0xFFFF9800),
  Color(0xFF9C27B0),
];

class SalesChart extends ConsumerWidget {
  final int month;
  final int year;

  const SalesChart({Key? key, required this.month, required this.year})
    : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(streamCurrentMonthAnalyticsProvider);
    final monthLabel = DateFormat.yMMMM().format(DateTime(year, month));

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: analyticsAsync.when(
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox(
            height: 100,
            child: Center(child: Text('Could not load chart data')),
          ),
          data: (items) {
            if (items.isEmpty) {
              return SizedBox(
                height: 120,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart, size: 40, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text(
                        'No sales data for $monthLabel',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            final pkrFmt = NumberFormat('#,###', 'en_US');
            final maxY =
                items.map((e) => e.totalSales).reduce((a, b) => a > b ? a : b) *
                1.25;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales by Franchise — $monthLabel',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      maxY: maxY == 0 ? 100 : maxY,
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 56,
                            getTitlesWidget: (val, _) => Text(
                              'PKR ${pkrFmt.format(val.toInt())}',
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, _) {
                              final idx = val.toInt();
                              if (idx < 0 || idx >= items.length) {
                                return const Text('');
                              }
                              final label = items[idx].branchName
                                  .split(' ')
                                  .first;
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  label,
                                  style: const TextStyle(fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, _, rod, __) {
                            final name = items[group.x].branchName;
                            return BarTooltipItem(
                              '$name\nPKR ${pkrFmt.format(rod.toY.toInt())}',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      barGroups: items.asMap().entries.map((e) {
                        final color = _kBarColors[e.key % _kBarColors.length];
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.totalSales,
                              color: color,
                              width: 24,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    duration: const Duration(milliseconds: 400),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: items.asMap().entries.map((e) {
                    final color = _kBarColors[e.key % _kBarColors.length];
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          e.value.branchName,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
