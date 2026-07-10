import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/book_completion_summary.dart';
import 'recap_cover.dart';
import 'star_rating_picker.dart';
import 'stats_duration_label.dart';

/// 9:16 shareable card for "I finished this book". Palette matches the
/// monthly recap card so both feel like they belong to the same line.
///
/// [showStats] toggles the bottom stats panel — without it, the card is
/// minimalist (cover + title + rating + completion date).
class BookCompletionCard extends StatelessWidget {
  final BookCompletionSummary summary;
  final bool showStats;
  const BookCompletionCard({
    required this.summary,
    this.showStats = true,
    super.key,
  });

  static const _paper = Color(0xFFF4ECDE);
  static const _ink = Color(0xFF1E1912);
  static const _inkSoft = Color(0xFF6B5F4E);
  static const _accent = Color(0xFFE55324);
  static const _outline = Color(0xFFD8CCB3);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      width: 360,
      height: 640,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8F1E2), _paper],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.base,
          ),
          child: DefaultTextStyle(
            style: GoogleFonts.inter(color: _ink),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(wordmark: l10n.recapWordmark, badge: l10n.completionCardHeadline),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: SizedBox(
                    // Minimal layout (no stats) can afford a larger hero cover.
                    width: showStats ? 220 : 260,
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: RecapCover(
                        coverImage: summary.coverImage,
                        title: summary.title,
                        radius: AppRadius.borderMd,
                        fallbackPadding: const EdgeInsets.all(AppSpacing.md),
                        fallbackFontSize: 16,
                        fallbackHeight: 1.15,
                        fallbackMaxLines: 6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  summary.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lora(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: _ink,
                  ),
                ),
                if (summary.author != null && summary.author!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    summary.author!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _inkSoft,
                    ),
                  ),
                ],
                if (summary.rating != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: StarRatingRow(
                      value: summary.rating!,
                      filledColor: _accent,
                      emptyColor: _outline,
                      size: 22,
                    ),
                  ),
                ],
                const Spacer(),
                if (showStats)
                  _StatsPanel(summary: summary)
                else
                  _MinimalFooter(summary: summary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String wordmark;
  final String badge;
  const _Header({required this.wordmark, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          wordmark.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: BookCompletionCard._accent,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: BookCompletionCard._accent,
            borderRadius: AppRadius.borderSm,
          ),
          child: Text(
            badge.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsPanel extends StatelessWidget {
  final BookCompletionSummary summary;
  const _StatsPanel({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timeLabel = formatDuration(l10n, summary.totalDurationMs);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: BookCompletionCard._outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(label: l10n.completionStatTime, value: timeLabel),
          ),
          _Divider(),
          Expanded(
            child: _StatTile(
              label: l10n.completionStatWords,
              value: NumberFormat.compact(locale: l10n.localeName)
                  .format(summary.totalWords),
            ),
          ),
          _Divider(),
          Expanded(
            child: _StatTile(
              label: l10n.completionStatAvgWpm,
              value: summary.avgWpm.toString(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: BookCompletionCard._outline,
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.lora(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: BookCompletionCard._ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: BookCompletionCard._inkSoft,
          ),
        ),
      ],
    );
  }
}

class _MinimalFooter extends StatelessWidget {
  final BookCompletionSummary summary;
  const _MinimalFooter({required this.summary});

  @override
  Widget build(BuildContext context) {
    final date = summary.lastSessionAt;
    if (date == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final formatted = DateFormat.yMMMd(l10n.localeName).format(date);
    return Center(
      child: Text(
        l10n.completionFinishedOn(formatted),
        style: GoogleFonts.inter(
          color: BookCompletionCard._inkSoft,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}


