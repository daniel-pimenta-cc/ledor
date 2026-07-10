import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/stats_snapshot.dart';
import 'stats_chart_titles.dart';

/// Line chart: weighted avg WPM per day. Days without sessions are skipped
/// (no spot emitted) — the line then connects real reading days directly,
/// which keeps the trendline visible even with sparse reading.
class StatsWpmTrendChart extends StatelessWidget {
  final StatsSnapshot snapshot;
  const StatsWpmTrendChart({required this.snapshot, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spots = <FlSpot>[];
    for (var i = 0; i < snapshot.dailyBuckets.length; i++) {
      final wpm = snapshot.dailyBuckets[i].avgWpm;
      if (wpm != null) spots.add(FlSpot(i.toDouble(), wpm.toDouble()));
    }

    if (spots.isEmpty) {
      return AspectRatio(
        aspectRatio: 1.6,
        child: Center(
          child: Text(
            '—',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final values = spots.map((s) => s.y).toList();
    final minY = (values.min - 30).clamp(0, 2000).toDouble();
    final maxY = values.max + 30;

    return AspectRatio(
      aspectRatio: 1.6,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (snapshot.dailyBuckets.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: scheme.primary,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, xPerc, bar, idx) => FlDotCirclePainter(
                  radius: 3,
                  color: scheme.primary,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: scheme.primary.withValues(alpha: 0.08),
              ),
            ),
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
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.round()} WPM',
                        TextStyle(color: scheme.onInverseSurface),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  FlTitlesData _titlesData(StatsSnapshot snap, ColorScheme scheme) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == meta.min) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                value.round().toString(),
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
