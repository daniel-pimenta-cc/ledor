import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cover art for share cards (monthly recap + book completion): the book's
/// cover image if present, else a tinted initial-letter fallback. Fixed
/// "ink on paper" palette (independent of `Theme.of(context)`) so exported
/// PNGs look the same for every user — see `MonthlyRecapCard`/
/// `BookCompletionCard` docs.
class RecapCover extends StatelessWidget {
  final Uint8List? coverImage;
  final String title;
  final BorderRadius radius;
  final EdgeInsetsGeometry fallbackPadding;
  final double fallbackFontSize;
  final double fallbackHeight;
  final int fallbackMaxLines;

  const RecapCover({
    required this.coverImage,
    required this.title,
    required this.radius,
    required this.fallbackPadding,
    required this.fallbackFontSize,
    required this.fallbackHeight,
    required this.fallbackMaxLines,
    super.key,
  });

  static const _ink = Color(0xFF1E1912);
  static const _outline = Color(0xFFD8CCB3);

  @override
  Widget build(BuildContext context) {
    final cover = coverImage;
    if (cover != null && cover.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          cover,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    // Tinted fallback based on the first letter's codepoint — stable per book.
    final seed = title.isNotEmpty ? title.codeUnitAt(0) : 0;
    final hue = (seed * 37) % 360;
    final bg = HSLColor.fromAHSL(1, hue.toDouble(), 0.35, 0.80).toColor();

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(color: _outline),
      ),
      padding: fallbackPadding,
      alignment: Alignment.center,
      child: Text(
        title,
        maxLines: fallbackMaxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: GoogleFonts.lora(
          fontWeight: FontWeight.w600,
          height: fallbackHeight,
          fontSize: fallbackFontSize,
          color: _ink,
        ),
      ),
    );
  }
}
