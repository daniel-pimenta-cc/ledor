import '../../features/epub_import/domain/entities/word_token.dart';
import 'orp_calculator.dart';
import 'word_timing.dart';

/// Converts clean text into a list of [WordToken]s with pre-calculated
/// ORP positions and timing multipliers.
class TextTokenizer {
  const TextTokenizer._();

  /// Tokenize [cleanText] into words.
  ///
  /// [chapterIndex]: which chapter this text belongs to.
  /// [globalOffset]: the starting global word index for this chapter.
  static List<WordToken> tokenize(
    String cleanText, {
    required int chapterIndex,
    required int globalOffset,
  }) {
    final tokens = <WordToken>[];
    final paragraphs = cleanText.split(RegExp(r'\n\s*\n'));
    int globalIndex = globalOffset;
    int paragraphIndex = 0;

    for (final paragraph in paragraphs) {
      final trimmed = paragraph.trim();
      if (trimmed.isEmpty) continue;

      final words = trimmed.split(RegExp(r'\s+'));
      bool firstOfParagraph = true;

      for (final raw in words) {
        final word = raw.trim();
        if (word.isEmpty) continue;

        for (final subWord in splitHyphenated(word)) {
          final bool isParagraphStart = firstOfParagraph;
          final bool isChapterStart =
              (paragraphIndex == 0 && firstOfParagraph);
          firstOfParagraph = false;

          tokens.add(WordToken(
            text: subWord,
            orpIndex: OrpCalculator.calculate(subWord),
            timingMultiplier: WordTiming.calculateMultiplier(
              subWord,
              isParagraphStart: isParagraphStart,
              isChapterStart: isChapterStart,
            ),
            globalIndex: globalIndex,
            chapterIndex: chapterIndex,
            paragraphIndex: paragraphIndex,
            isParagraphStart: isParagraphStart,
            isChapterStart: isChapterStart,
          ));
          globalIndex++;
        }
      }

      paragraphIndex++;
    }

    return tokens;
  }

  /// Split an internal-hyphen compound into sub-words, keeping the hyphen
  /// with the left part so it stays visible as a reading cue
  /// (`guarda-chuva` -> `[guarda-, chuva]`). Falls back to the whole word
  /// when the split would produce nothing (e.g. a lone "-").
  ///
  /// Public so the image-aware [ChapterParser] can share the same splitting
  /// rules without duplicating the regex.
  static Iterable<String> splitHyphenated(String word) sync* {
    if (!word.contains('-')) {
      yield word;
      return;
    }
    final matches = RegExp(r'[^-]+-?').allMatches(word).toList();
    if (matches.isEmpty) {
      yield word;
      return;
    }
    for (final m in matches) {
      yield m.group(0)!;
    }
  }
}
