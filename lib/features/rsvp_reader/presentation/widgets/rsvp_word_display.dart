import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/responsive_defaults.dart';
import '../../../../core/utils/font_mapper.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import '../../domain/entities/display_settings.dart';

/// Keys used to find each ORP indicator subtree in tests. notch and
/// lineAbove each produce a single subtree above the word; linesAround
/// produces two short vertical ticks (above + below) centered on the ORP
/// letter.
@visibleForTesting
const orpIndicatorNotchKey = Key('rsvp.orpIndicator.notch');
@visibleForTesting
const orpIndicatorTopLineKey = Key('rsvp.orpIndicator.topLine');
@visibleForTesting
const orpIndicatorTopTickKey = Key('rsvp.orpIndicator.topTick');
@visibleForTesting
const orpIndicatorBottomTickKey = Key('rsvp.orpIndicator.bottomTick');

/// Renders a single word with the ORP letter highlighted.
///
/// The ORP letter is anchored at [horizontalPosition] of the available width.
/// If the word is too wide to fit, font size is scaled down automatically.
class RsvpWordDisplay extends StatelessWidget {
  final WordToken? word;
  final DisplaySettings settings;

  /// Reading progress (0..1). Used by the focus line when
  /// [DisplaySettings.focusLineShowsProgress] is enabled.
  final double progress;

  const RsvpWordDisplay({
    required this.word,
    required this.settings,
    this.progress = 0.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (word == null) return const SizedBox.shrink();

    final text = word!.text;
    final orpIdx = word!.orpIndex.clamp(0, text.length - 1);

    final beforeOrp = text.substring(0, orpIdx);
    final orpChar = text.substring(orpIdx, orpIdx + 1);
    final afterOrp = text.substring(orpIdx + 1);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final margin = ResponsiveDefaults.rsvpWordMargin(context);
          final usableWidth = maxWidth - margin * 2;
          final anchorX = margin + usableWidth * settings.horizontalPosition;

          // Find the right font size — start at configured (device-scaled
          // when the user hasn't customized), scale down if needed.
          final scale = settings.fontSize == AppConstants.defaultFontSize
              ? ResponsiveDefaults.rsvpFontScale(context)
              : 1.0;
          var fontSize = settings.fontSize * scale;
          _Measurement m;
          while (true) {
            m = _measure(beforeOrp, orpChar, afterOrp, fontSize);
            if (m.totalWidth <= usableWidth ||
                fontSize <= AppConstants.rsvpMinFontSize) {
              break;
            }
            fontSize -= AppConstants.rsvpFontShrinkStep;
          }

          // Position word so ORP center aligns with anchorX
          final idealOffset = anchorX - m.beforeWidth - (m.orpWidth / 2);
          // Clamp so full word stays within margins
          final minOffset = margin;
          final maxOffset = maxWidth - m.totalWidth - margin;
          final offsetX = maxOffset >= minOffset
              ? idealOffset.clamp(minOffset, maxOffset)
              : max(margin, (maxWidth - m.totalWidth) / 2); // center fallback

          const notchHeight = AppConstants.rsvpNotchHeight;
          const notchGap = AppConstants.rsvpNotchGap;
          const focusLineGap = AppConstants.rsvpFocusLineGap;
          const focusLineHeight = AppConstants.rsvpFocusLineHeight;
          const orpLineWidth = AppConstants.rsvpOrpLineWidth;
          const orpLineHeight = AppConstants.rsvpOrpLineHeight;
          const orpTickLength = AppConstants.rsvpOrpTickLength;
          const orpTickThickness = AppConstants.rsvpOrpTickThickness;
          const orpTickGap = AppConstants.rsvpOrpTickGap;

          final style = settings.orpIndicator;
          // notch/lineAbove use only a top slot; linesAround pads top AND
          // bottom for a vertical tick on each side of the ORP letter; off
          // collapses both.
          final hasTopIndicator = style == OrpIndicatorStyle.notch ||
              style == OrpIndicatorStyle.lineAbove ||
              style == OrpIndicatorStyle.linesAround;
          final hasBottomTick = style == OrpIndicatorStyle.linesAround;

          final topSpace = hasTopIndicator ? notchHeight + notchGap : 0.0;
          final bottomTickSpace =
              hasBottomTick ? orpTickGap + orpTickLength : 0.0;

          final showLine = settings.showFocusLine;
          final lineTotalSpace =
              showLine ? focusLineGap + focusLineHeight : 0.0;

          final wordTop = topSpace;
          final focusLineTop =
              wordTop + m.textHeight + bottomTickSpace + focusLineGap;

          // Horizontal center of the ORP letter inside the laid-out word —
          // used to anchor the vertical ticks in `linesAround`.
          final orpCenterX = offsetX + m.beforeWidth + m.orpWidth / 2;

          // Thin marks need more opacity than the notch (which is a chunky
          // triangle at 40%) — otherwise they almost disappear at 1.5px.
          final indicatorColor = settings.orpColor.withAlpha(210);

          return SizedBox(
            width: maxWidth,
            height: m.textHeight + topSpace + bottomTickSpace + lineTotalSpace,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (style == OrpIndicatorStyle.notch)
                  Positioned(
                    left: anchorX - 4,
                    top: 0,
                    child: CustomPaint(
                      key: orpIndicatorNotchKey,
                      size: const Size(8, notchHeight),
                      painter:
                          _NotchPainter(settings.orpColor.withAlpha(102)),
                    ),
                  ),
                if (style == OrpIndicatorStyle.lineAbove)
                  Positioned(
                    left: anchorX - orpLineWidth / 2,
                    top: notchHeight - orpLineHeight,
                    child: CustomPaint(
                      key: orpIndicatorTopLineKey,
                      size: const Size(orpLineWidth, orpLineHeight),
                      painter: _OrpLinePainter(indicatorColor),
                    ),
                  ),
                if (style == OrpIndicatorStyle.linesAround) ...[
                  Positioned(
                    left: orpCenterX - orpTickThickness / 2,
                    top: wordTop - orpTickGap - orpTickLength,
                    child: CustomPaint(
                      key: orpIndicatorTopTickKey,
                      size: const Size(orpTickThickness, orpTickLength),
                      painter: _OrpLinePainter(indicatorColor),
                    ),
                  ),
                  Positioned(
                    left: orpCenterX - orpTickThickness / 2,
                    top: wordTop + m.textHeight + orpTickGap,
                    child: CustomPaint(
                      key: orpIndicatorBottomTickKey,
                      size: const Size(orpTickThickness, orpTickLength),
                      painter: _OrpLinePainter(indicatorColor),
                    ),
                  ),
                ],
                Positioned(
                  left: offsetX,
                  top: wordTop,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(text: beforeOrp, style: m.baseStyle),
                        TextSpan(text: orpChar, style: m.orpStyle),
                        TextSpan(text: afterOrp, style: m.baseStyle),
                      ],
                    ),
                  ),
                ),
                if (showLine)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: focusLineTop,
                    height: focusLineHeight,
                    // Thin line below the word. When progress display is on it
                    // fills to `progress` in the accent; otherwise value 0 keeps
                    // the whole track in restColor as a plain focus aid.
                    child: LinearProgressIndicator(
                      value: settings.focusLineShowsProgress
                          ? progress.clamp(0.0, 1.0)
                          : 0.0,
                      minHeight: focusLineHeight,
                      color: settings.orpColor,
                      backgroundColor: settings.wordColor.withAlpha(60),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  _Measurement _measure(
    String before,
    String orp,
    String after,
    double fontSize,
  ) {
    final baseStyle = GoogleFonts.getFont(
      mapFontFamily(settings.fontFamily),
      fontSize: fontSize,
      color: settings.wordColor,
      fontWeight: FontWeight.w400,
      letterSpacing: 2.0,
    );
    final orpStyle = baseStyle.copyWith(
      color: settings.showOrpHighlight ? settings.orpColor : settings.wordColor,
      fontWeight: settings.showOrpHighlight ? FontWeight.w700 : FontWeight.w400,
    );

    final bP = TextPainter(
      text: TextSpan(text: before, style: baseStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final oP = TextPainter(
      text: TextSpan(text: orp, style: orpStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final aP = TextPainter(
      text: TextSpan(text: after, style: baseStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    return _Measurement(
      beforeWidth: bP.width,
      orpWidth: oP.width,
      afterWidth: aP.width,
      totalWidth: bP.width + oP.width + aP.width,
      textHeight: bP.height,
      baseStyle: baseStyle,
      orpStyle: orpStyle,
    );
  }

}

class _Measurement {
  final double beforeWidth;
  final double orpWidth;
  final double afterWidth;
  final double totalWidth;
  final double textHeight;
  final TextStyle baseStyle;
  final TextStyle orpStyle;

  const _Measurement({
    required this.beforeWidth,
    required this.orpWidth,
    required this.afterWidth,
    required this.totalWidth,
    required this.textHeight,
    required this.baseStyle,
    required this.orpStyle,
  });
}

class _NotchPainter extends CustomPainter {
  final Color color;
  _NotchPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_NotchPainter oldDelegate) => oldDelegate.color != color;
}

class _OrpLinePainter extends CustomPainter {
  final Color color;
  _OrpLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_OrpLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
