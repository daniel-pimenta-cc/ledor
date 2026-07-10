import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/image_export_service.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/book_completion_summary.dart';
import '../providers/book_completion_provider.dart';
import '../widgets/book_completion_card.dart';
import '../widgets/star_rating_picker.dart';
import '../widgets/stats_duration_label.dart';

class BookCompletionScreen extends ConsumerStatefulWidget {
  final String bookId;
  const BookCompletionScreen({required this.bookId, super.key});

  @override
  ConsumerState<BookCompletionScreen> createState() =>
      _BookCompletionScreenState();
}

class _BookCompletionScreenState extends ConsumerState<BookCompletionScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _sharing = false;
  bool _includeStats = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(bookCompletionProvider(widget.bookId));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(l10n.completionHeadline)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (summary) => _CompletionBody(
          summary: summary,
          boundaryKey: _boundaryKey,
          sharing: _sharing,
          includeStats: _includeStats,
          onIncludeStatsChanged: (v) => setState(() => _includeStats = v),
          onRatingChanged: (value) => _onRatingChanged(summary, value),
          onShare: () => _onShare(summary),
        ),
      ),
    );
  }

  Future<void> _onRatingChanged(
    BookCompletionSummary summary,
    int? value,
  ) async {
    await ref
        .read(booksDaoProvider)
        .updateRating(summary.bookId, value?.clamp(1, 5));
  }

  Future<void> _onShare(BookCompletionSummary summary) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await shareWidgetAsPng(
        boundaryKey: _boundaryKey,
        filename: 'rsvp-finished-${summary.bookId}',
        shareText: l10n.completionShareText(summary.title),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}

class _CompletionBody extends StatelessWidget {
  final BookCompletionSummary summary;
  final GlobalKey boundaryKey;
  final bool sharing;
  final bool includeStats;
  final ValueChanged<bool> onIncludeStatsChanged;
  final ValueChanged<int?> onRatingChanged;
  final VoidCallback onShare;

  const _CompletionBody({
    required this.summary,
    required this.boundaryKey,
    required this.sharing,
    required this.includeStats,
    required this.onIncludeStatsChanged,
    required this.onRatingChanged,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timeLabel = formatDuration(l10n, summary.totalDurationMs);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: BookCompletionCard(
                    summary: summary,
                    showStats: includeStats,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _RatingBlock(
              rating: summary.rating,
              onChanged: onRatingChanged,
            ),
            const SizedBox(height: AppSpacing.lg),
            _StatsBlock(
              timeLabel: timeLabel,
              summary: summary,
            ),
            if (summary.daysSpan > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Text(
                  l10n.completionStatSpan(summary.daysSpan),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.base),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.completionIncludeStats),
              value: includeStats,
              onChanged: onIncludeStatsChanged,
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: sharing ? null : onShare,
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.completionShareCta),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingBlock extends StatelessWidget {
  final int? rating;
  final ValueChanged<int?> onChanged;
  const _RatingBlock({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          l10n.completionRatingLabel,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        StarRatingPicker(value: rating, onChanged: onChanged),
        if (rating == null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.completionRatingHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

class _StatsBlock extends StatelessWidget {
  final String timeLabel;
  final BookCompletionSummary summary;
  const _StatsBlock({required this.timeLabel, required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          children: [
            _StatRow(
              label: l10n.completionStatTime,
              value: timeLabel,
            ),
            const Divider(height: AppSpacing.lg),
            _StatRow(
              label: l10n.completionStatWords,
              value: NumberFormat.decimalPattern(l10n.localeName)
                  .format(summary.totalWords),
            ),
            const Divider(height: AppSpacing.lg),
            _StatRow(
              label: l10n.completionStatSessions,
              value: summary.sessionCount.toString(),
            ),
            const Divider(height: AppSpacing.lg),
            _StatRow(
              label: l10n.completionStatAvgWpm,
              value: summary.avgWpm.toString(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ],
    );
  }
}
