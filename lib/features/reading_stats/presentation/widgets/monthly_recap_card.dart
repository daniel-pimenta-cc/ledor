import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/monthly_recap.dart';
import 'recap_cover.dart';

/// 9:16 portrait recap card (360×640 dp — renders ~1080×1920 at pixelRatio 3).
/// Visual is palette-independent (fixed editorial "ink on paper") so the
/// exported PNG is consistent regardless of the user's theme.
class MonthlyRecapCard extends StatelessWidget {
  final MonthlyRecap recap;
  const MonthlyRecapCard({required this.recap, super.key});

  // Fixed palette — ink on paper, with the app's accent orange preserved.
  static const _paper = Color(0xFFF4ECDE);
  static const _ink = Color(0xFF1E1912);
  static const _inkSoft = Color(0xFF6B5F4E);
  static const _accent = Color(0xFFE55324);
  static const _outline = Color(0xFFD8CCB3);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final monthName =
        DateFormat.MMMM(l10n.localeName).format(DateTime(recap.year, recap.month));
    final totalMinutes = (recap.totalDurationMs / 60000).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

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
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: DefaultTextStyle(
            style: GoogleFonts.inter(color: _ink),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  wordmark: l10n.recapWordmark,
                  title: l10n.recapTitle,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '$monthName ${recap.year}',
                  style: GoogleFonts.lora(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (recap.finished.isNotEmpty) ...[
                        _SectionLabel(l10n.recapFinished),
                        const SizedBox(height: AppSpacing.sm),
                        _FinishedRow(books: recap.finished.take(3).toList()),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (recap.reading.isNotEmpty) ...[
                        _SectionLabel(l10n.recapReading),
                        const SizedBox(height: AppSpacing.sm),
                        Expanded(
                          child: _ReadingGrid(
                            books: recap.reading.take(6).toList(),
                          ),
                        ),
                      ] else
                        const Spacer(),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(height: 1, color: _outline),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.recapStatsFooter(
                    NumberFormat.compact(locale: l10n.localeName)
                        .format(recap.totalWords),
                    hours,
                    minutes,
                  ),
                  style: GoogleFonts.inter(
                    color: _inkSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
  final String title;
  const _Header({required this.wordmark, required this.title});

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
            color: MonthlyRecapCard._accent,
          ),
        ),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
            color: MonthlyRecapCard._inkSoft,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: MonthlyRecapCard._inkSoft,
      ),
    );
  }
}

class _FinishedRow extends StatelessWidget {
  final List<RecapBook> books;
  const _FinishedRow({required this.books});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < books.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: _FinishedTile(book: books[i])),
        ],
      ],
    );
  }
}

class _FinishedTile extends StatelessWidget {
  final RecapBook book;
  const _FinishedTile({required this.book});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: RecapCover(
            coverImage: book.coverImage,
            title: book.title,
            radius: AppRadius.borderSm,
            fallbackPadding: const EdgeInsets.all(AppSpacing.sm),
            fallbackFontSize: 12,
            fallbackHeight: 1.1,
            fallbackMaxLines: 4,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.lora(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: MonthlyRecapCard._ink,
          ),
        ),
        if (book.author != null && book.author!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            book.author!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MonthlyRecapCard._inkSoft,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReadingGrid extends StatelessWidget {
  final List<RecapBook> books;
  const _ReadingGrid({required this.books});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.55,
      children: [
        for (final b in books) _ReadingTile(book: b),
      ],
    );
  }
}

class _ReadingTile extends StatelessWidget {
  final RecapBook book;
  const _ReadingTile({required this.book});

  @override
  Widget build(BuildContext context) {
    final percent = (book.progressFraction * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: RecapCover(
            coverImage: book.coverImage,
            title: book.title,
            radius: AppRadius.borderSm,
            fallbackPadding: const EdgeInsets.all(AppSpacing.sm),
            fallbackFontSize: 12,
            fallbackHeight: 1.1,
            fallbackMaxLines: 4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          book.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.lora(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: MonthlyRecapCard._ink,
          ),
        ),
        Text(
          '$percent%',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: MonthlyRecapCard._accent,
          ),
        ),
      ],
    );
  }
}


