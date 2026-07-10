import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/stats_snapshot.dart';

/// Bottom-axis day labels shared by the stats charts: shows the first, last,
/// and a handful of evenly-spaced days in between as `d/m`.
AxisTitles dayAxisTitles(List<DailyBucket> buckets, ColorScheme scheme) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 24,
      getTitlesWidget: (value, meta) {
        final idx = value.toInt();
        if (idx < 0 || idx >= buckets.length) {
          return const SizedBox.shrink();
        }
        final n = buckets.length;
        final step = n <= 7 ? 1 : (n ~/ 5);
        if (idx != 0 && idx != n - 1 && idx % step != 0) {
          return const SizedBox.shrink();
        }
        final day = buckets[idx].day;
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${day.day}/${day.month}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10),
          ),
        );
      },
    ),
  );
}
