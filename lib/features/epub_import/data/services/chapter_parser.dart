import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../../core/utils/orp_calculator.dart';
import '../../../../core/utils/text_tokenizer.dart';
import '../../../../core/utils/word_timing.dart';
import '../../domain/entities/word_token.dart';

/// Bytes returned by [ImageResolver] for an inline `<img src>` reference
/// inside an EPUB chapter.
class ResolvedImage {
  final Uint8List bytes;

  const ResolvedImage({required this.bytes});
}

/// Maps an `<img src>` (raw attribute value, can be relative) to the bytes
/// of the image inside the EPUB, or `null` when the resource is missing or
/// is in an unsupported format the renderer would not handle.
typedef ImageResolver = ResolvedImage? Function(String src);

/// Walks EPUB chapter XHTML and produces a token stream in which inline
/// images get their own positional slot (`isImage: true`) alongside the
/// regular text words. The text path mirrors [TextTokenizer] so ORP indexes,
/// timing multipliers and paragraph/chapter starts stay byte-identical for
/// books without images.
///
/// Why not bolt this onto `HtmlStripper` + `TextTokenizer`? The stripper
/// erases everything that isn't text, so images vanish before the
/// tokenizer ever sees them. Re-injecting placeholders after the fact would
/// trip on words that happen to contain whatever sentinel we picked.
/// Walking the DOM directly is the only way to keep image positions
/// faithful to the source.
class ChapterParser {
  const ChapterParser._();

  /// Block-level tags whose subtree is its own paragraph.
  static const _blockTags = {
    'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'li', 'blockquote', 'section', 'article', 'header',
    'footer', 'aside', 'figcaption', 'dt', 'dd', 'tr',
    'figure',
  };

  /// Inline break tags — flushed as paragraph boundaries (matches the
  /// behaviour of [HtmlStripper] for the textual side).
  static const _breakTags = {'br', 'hr'};

  /// Subtrees that carry no reader-facing content.
  static const _skipTags = {
    'style', 'script', 'noscript', 'head', 'meta', 'link',
    'title', 'object', 'embed', 'iframe', 'template',
    // SVGs aren't rendered yet — skip rather than emit a broken image.
    'svg',
  };

  static List<WordToken> parse(
    String html, {
    required int chapterIndex,
    required int globalOffset,
    required ImageResolver imageResolver,
  }) {
    if (html.trim().isEmpty) return const [];

    final state = _ParseState(
      chapterIndex: chapterIndex,
      globalIndex: globalOffset,
    );

    final fragment = html_parser.parseFragment(html);
    _walk(fragment, state, imageResolver);
    state.flushTextParagraph();

    return state.tokens;
  }

  static void _walk(Node node, _ParseState state, ImageResolver resolver) {
    for (final child in node.nodes) {
      if (child.nodeType == Node.TEXT_NODE) {
        final text = child.text;
        if (text != null && text.isNotEmpty) state.appendText(text);
        continue;
      }
      if (child.nodeType != Node.ELEMENT_NODE) continue;

      final element = child as Element;
      final tag = element.localName?.toLowerCase();
      if (tag == null) continue;

      if (_skipTags.contains(tag)) continue;

      if (tag == 'img') {
        final src = element.attributes['src'];
        if (src == null || src.isEmpty) continue;
        final resolved = resolver(src);
        if (resolved == null) continue;
        state.flushTextParagraph();
        state.emitImage(resolved);
        continue;
      }

      final block = _blockTags.contains(tag);
      final breakInline = _breakTags.contains(tag);

      if (block || breakInline) state.flushTextParagraph();

      _walk(element, state, resolver);

      if (block) state.flushTextParagraph();
    }
  }
}

class _ParseState {
  _ParseState({required this.chapterIndex, required this.globalIndex});

  final int chapterIndex;
  int globalIndex;
  int paragraphIndex = 0;

  /// True until any token has been emitted in this chapter — the first
  /// real word (or image) we emit gets `isChapterStart`.
  bool chapterStartPending = true;

  /// Set after we close a paragraph; the next emitted token gets
  /// `isParagraphStart`.
  bool paragraphStartPending = true;

  final StringBuffer _paragraphText = StringBuffer();
  final List<WordToken> tokens = [];

  void appendText(String text) => _paragraphText.write(text);

  void flushTextParagraph() {
    final text = _paragraphText.toString();
    _paragraphText.clear();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      // Don't bump paragraphIndex for empty fragments — we only want to
      // count paragraphs that actually carry visible content.
      return;
    }

    bool firstOfParagraph = true;
    final words = trimmed.split(RegExp(r'\s+'));
    for (final raw in words) {
      final word = raw.trim();
      if (word.isEmpty) continue;
      for (final subWord in TextTokenizer.splitHyphenated(word)) {
        final paraStart = firstOfParagraph && paragraphStartPending;
        final chapStart = paraStart && chapterStartPending;
        tokens.add(WordToken(
          text: subWord,
          orpIndex: OrpCalculator.calculate(subWord),
          timingMultiplier: WordTiming.calculateMultiplier(
            subWord,
            isParagraphStart: paraStart,
            isChapterStart: chapStart,
          ),
          globalIndex: globalIndex++,
          chapterIndex: chapterIndex,
          paragraphIndex: paragraphIndex,
          isParagraphStart: paraStart,
          isChapterStart: chapStart,
        ));
        firstOfParagraph = false;
        if (paragraphStartPending) paragraphStartPending = false;
        if (chapterStartPending) chapterStartPending = false;
      }
    }

    paragraphIndex++;
    paragraphStartPending = true;
  }

  void emitImage(ResolvedImage image) {
    final paraStart = paragraphStartPending;
    final chapStart = paraStart && chapterStartPending;

    tokens.add(WordToken(
      text: '',
      orpIndex: 0,
      timingMultiplier: 1.0,
      globalIndex: globalIndex++,
      chapterIndex: chapterIndex,
      paragraphIndex: paragraphIndex,
      isImage: true,
      isParagraphStart: paraStart,
      isChapterStart: chapStart,
      pendingImageBytes: image.bytes,
    ));

    if (paragraphStartPending) paragraphStartPending = false;
    if (chapterStartPending) chapterStartPending = false;

    paragraphIndex++;
    paragraphStartPending = true;
  }
}
