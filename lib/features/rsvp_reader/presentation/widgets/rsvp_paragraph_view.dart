import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/font_mapper.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import '../../domain/entities/display_settings.dart';

/// Renders a paragraph of [WordToken]s. Backed by [SelectableText.rich] so
/// the OS-native text-selection toolbar (with handles on mobile) appears on
/// long-press — that's the path we use to create a bookmark over a range
/// of words.
///
/// Why `SelectableText.rich` instead of a `WidgetSpan` per token: the
/// per-token widget tree was prohibitively expensive in long paragraphs
/// (visible lag while scrolling on Android). With a single `RenderParagraph`
/// the layout is back to free.
///
/// When [onWordTap] is null the rendered text is non-interactive on tap
/// (used by ereader mode). When [onBookmarkRange] is non-null we expose a
/// "Save bookmark" entry in the system text-selection toolbar.
class RsvpParagraphView extends StatelessWidget {
  final List<WordToken> tokens;
  final int currentGlobalIndex;
  final DisplaySettings settings;
  final ValueChanged<WordToken>? onWordTap;
  final void Function(WordToken first, WordToken last)? onBookmarkRange;

  /// Attached to the highlighted token's render container so a parent
  /// [State] can measure its on-screen position (used by recenter).
  final GlobalKey? highlightKey;

  const RsvpParagraphView({
    required this.tokens,
    required this.currentGlobalIndex,
    required this.settings,
    required this.onWordTap,
    this.onBookmarkRange,
    this.highlightKey,
    super.key,
  });

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

    final ranges = <_TokenRange>[];
    int offset = 0;
    final children = <InlineSpan>[];
    for (final token in tokens) {
      final isHighlighted = token.globalIndex == currentGlobalIndex;
      // Sub-tokens of a hyphenated compound (e.g. "guarda-") are glued to
      // the next token instead of followed by a space.
      final joinsNext = token.text.endsWith('-');

      if (isHighlighted) {
        // WidgetSpan for the highlighted token only — keeps the pill +
        // glow visual AND lets recenter() measure its on-screen position
        // via highlightKey. A single WidgetSpan per paragraph is cheap.
        children.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: onWordTap == null ? null : () => onWordTap!(token),
            child: Container(
              key: highlightKey,
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              margin: EdgeInsets.only(right: joinsNext ? 0 : 4),
              decoration: BoxDecoration(
                color: settings.highlightColor.withAlpha((settings
                            .highlightColor.a *
                        255.0 *
                        0.7)
                    .round()
                    .clamp(0, 255)),
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
        ));
        // WidgetSpan counts as a single placeholder character (U+FFFC) in
        // the flattened text used by selection offsets.
        ranges.add(_TokenRange(start: offset, end: offset + 1, token: token));
        offset += 1;
        continue;
      }

      final piece = joinsNext ? token.text : '${token.text} ';
      children.add(TextSpan(
        text: piece,
        style: baseStyle,
        recognizer: onWordTap == null
            ? null
            : (TapGestureRecognizer()..onTap = () => onWordTap!(token)),
      ));
      ranges.add(
        _TokenRange(start: offset, end: offset + piece.length, token: token),
      );
      offset += piece.length;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SelectableText.rich(
        TextSpan(children: children),
        enableInteractiveSelection: onBookmarkRange != null,
        contextMenuBuilder: onBookmarkRange == null
            ? null
            : (context, state) => _buildContextMenu(context, state, ranges),
      ),
    );
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState state,
    List<_TokenRange> ranges,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final selection = state.textEditingValue.selection;
    final items = <ContextMenuButtonItem>[];
    if (selection.isValid && !selection.isCollapsed) {
      items.add(ContextMenuButtonItem(
        label: l10n.bookmarkSave,
        onPressed: () {
          final first = _tokenAt(selection.start, ranges);
          // selection.end is exclusive; look up the last char inside it.
          final last = _tokenAt(selection.end - 1, ranges);
          if (first != null && last != null) {
            onBookmarkRange!(first, last);
          }
          ContextMenuController.removeAny();
        },
      ));
    }
    // Keep the default Copy / Share / Select all entries so we don't strip
    // a familiar OS-level capability when we add ours.
    items.addAll(state.contextMenuButtonItems);
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: items,
    );
  }

  WordToken? _tokenAt(int charOffset, List<_TokenRange> ranges) {
    if (ranges.isEmpty) return null;
    if (charOffset < 0) return ranges.first.token;
    if (charOffset >= ranges.last.end) return ranges.last.token;
    // Linear scan — paragraphs typically hold a few hundred tokens, so the
    // O(n) cost is well below a frame budget.
    for (final r in ranges) {
      if (charOffset >= r.start && charOffset < r.end) return r.token;
    }
    return null;
  }
}

class _TokenRange {
  final int start;
  final int end;
  final WordToken token;

  const _TokenRange({
    required this.start,
    required this.end,
    required this.token,
  });
}
