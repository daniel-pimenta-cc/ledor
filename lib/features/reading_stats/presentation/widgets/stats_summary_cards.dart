import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/stats_snapshot.dart';
import 'stats_duration_label.dart';

class StatsSummaryCards extends StatelessWidget {
  final StatsSnapshot snapshot;
  const StatsSummaryCards({required this.snapshot, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timeLabel = formatDuration(l10n, snapshot.totalDurationMs);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.9,
      children: [
        _SummaryTile(
          label: l10n.statsSummaryWordsRead,
          value: NumberFormat.compact(locale: l10n.localeName)
              .format(snapshot.totalWords),
        ),
        _SummaryTile(
          label: l10n.statsSummaryTimeSpent,
          value: timeLabel,
        ),
        _SummaryTile(
          label: l10n.statsSummaryAvgWpm,
          value: snapshot.avgWpm.toString(),
        ),
        _SummaryTile(
          label: l10n.statsSummaryBooksTouched,
          value: snapshot.booksTouched.toString(),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTypography.sectionHeader(scheme),
            ),
            const SizedBox(height: AppSpacing.xs),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: scheme.onSurface,
                      ),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
