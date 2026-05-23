import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/font_mapper.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import '../../domain/entities/display_settings.dart';

/// Renders a paragraph of [WordToken]s as a wrapped run of text with an
/// optional pill around the [currentGlobalIndex] word. Pulled out of
/// [ContextScrollView] so the rendering can be exercised without spinning
/// up the engine provider in tests.
///
/// When [onWordTap] is null the rendered text is non-interactive on tap —
/// used by the ereader mode that disables seek-on-tap. When [onWordLongPress]
/// is non-null we switch every token to a [WidgetSpan] so each word has its
/// own gesture detector (a single [TextSpan] only accepts one recognizer,
/// so we can't otherwise mix tap and long-press independently).
class RsvpParagraphView extends StatelessWidget {
  final List<WordToken> tokens;
  final int currentGlobalIndex;
  final DisplaySettings settings;
  final ValueChanged<WordToken>? onWordTap;
  final ValueChanged<WordToken>? onWordLongPress;

  /// Attached to the highlighted token's render container so a parent
  /// [State] can measure its on-screen position (used by recenter). Null
  /// when there's no highlighted-word picker active.
  final GlobalKey? highlightKey;

  const RsvpParagraphView({
    required this.tokens,
    required this.currentGlobalIndex,
    required this.settings,
    required this.onWordTap,
    this.onWordLongPress,
    this.highlightKey,
    super.key,
  });

  void _fireLongPress(WordToken token) {
    HapticFeedback.mediumImpact();
    onWordLongPress!(token);
  }

  @override
  Widget build(BuildContext context) {
    final baseFontSize = settings.contextFontSize;
    final baseStyle = GoogleFonts.getFont(
      mapFontFamily(settings.fontFamily),
      fontSize: baseFontSize,
      color: settings.wordColor.withAlpha(180),
      height: 1.8,
    );
    final highlightTextStyle = GoogleFonts.getFont(
      mapFontFamily(settings.fontFamily),
      fontSize: baseFontSize,
      color: settings.wordColor,
      fontWeight: FontWeight.w600,
    );

    final useWidgetSpans = onWordLongPress != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text.rich(
        TextSpan(
          children: tokens.map((token) {
            final isHighlighted = token.globalIndex == currentGlobalIndex;
            // Sub-tokens of a hyphenated compound (e.g. "guarda-") are
            // glued to the next token instead of followed by a space.
            final joinsNext = token.text.endsWith('-');
            if (isHighlighted) {
              return WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: onWordTap == null ? null : () => onWordTap!(token),
                  onLongPress: onWordLongPress == null
                      ? null
                      : () => _fireLongPress(token),
                  child: Container(
                    key: highlightKey,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    margin: EdgeInsets.only(right: joinsNext ? 0 : 4),
                    decoration: BoxDecoration(
                      color: settings.highlightColor.withAlpha(
                          (settings.highlightColor.a * 255.0 * 0.7).round().clamp(0, 255)),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: settings.highlightColor.withAlpha(40),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(token.text, style: highlightTextStyle),
                  ),
                ),
              );
            }

            if (useWidgetSpans) {
              return WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: onWordTap == null ? null : () => onWordTap!(token),
                  onLongPress: () => _fireLongPress(token),
                  child: Padding(
                    padding: EdgeInsets.only(right: joinsNext ? 0 : 4),
                    child: Text(token.text, style: baseStyle),
                  ),
                ),
              );
            }

            return TextSpan(
              text: joinsNext ? token.text : '${token.text} ',
              style: baseStyle,
              recognizer: onWordTap == null
                  ? null
                  : (TapGestureRecognizer()..onTap = () => onWordTap!(token)),
            );
          }).toList(),
        ),
      ),
    );
  }
}
