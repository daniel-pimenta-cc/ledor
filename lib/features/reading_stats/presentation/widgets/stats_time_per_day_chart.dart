import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/stats_snapshot.dart';
import 'stats_chart_titles.dart';

/// Simple bar chart: minutes read per day. Primary-color single bars.
class StatsTimePerDayChart extends StatelessWidget {
  final StatsSnapshot snapshot;
  const StatsTimePerDayChart({required this.snapshot, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final minutesByDay = snapshot.dailyBuckets
        .map((b) => b.totalDurationMs / 60000)
        .toList(growable: false);
    final maxMinutes = minutesByDay.maxOrNull ?? 0;
    final maxY = maxMinutes <= 0 ? 10.0 : _roundUp(maxMinutes);

    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barGroups: [
            for (var i = 0; i < minutesByDay.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: minutesByDay[i],
                  width: 14,
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ]),
          ],
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          titlesData: _titlesData(snapshot, scheme),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (group, groupIdx, rod, rodIdx) => BarTooltipItem(
                '${rod.toY.round()} min',
                TextStyle(color: scheme.onInverseSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _roundUp(double v) {
    if (v <= 10) return 10;
    if (v <= 30) return 30;
    if (v <= 60) return 60;
    if (v <= 120) return 120;
    return ((v / 60).ceil() * 60).toDouble();
  }

  FlTitlesData _titlesData(StatsSnapshot snap, ColorScheme scheme) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 36,
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '${value.round()}m',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10),
              ),
            );
          },
        ),
      ),
      bottomTitles: dayAxisTitles(snap.dailyBuckets, scheme),
    );
  }
}
