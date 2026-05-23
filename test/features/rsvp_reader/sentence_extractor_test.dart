import 'package:flutter_test/flutter_test.dart';
import 'package:rsvp_reader/features/epub_import/domain/entities/chapter.dart';
import 'package:rsvp_reader/features/epub_import/domain/entities/word_token.dart';
import 'package:rsvp_reader/features/rsvp_reader/domain/utils/sentence_extractor.dart';

void main() {
  group('extractSentenceFrom', () {
    test('returns null on empty chapters', () {
      expect(extractSentenceFrom(const [], 0), isNull);
    });

    test('returns null when startGlobalIndex is past the book', () {
      final chapters = [
        _ch(0, ['Hello', 'world.']),
      ];
      expect(extractSentenceFrom(chapters, 99), isNull);
    });

    test('packs multiple sentences and paragraphs into one chunk', () {
      // Neither sentence terminators nor paragraph boundaries break the
      // chunk; only chapter boundaries and the safety cap do. This keeps
      // the inter-`speak()` IPC latency from being audible.
      final chapters = [
        Chapter(title: 'c0', tokens: [
          _tok('Hello', global: 0, paragraph: 0, isParagraphStart: true),
          _tok('world.', global: 1, paragraph: 0),
          _tok('Second', global: 2, paragraph: 1, isParagraphStart: true),
          _tok('para.', global: 3, paragraph: 1),
        ]),
      ];
      final s = extractSentenceFrom(chapters, 0)!;
      expect(s.startGlobalIndex, 0);
      expect(s.endGlobalIndexExcl, 4);
      expect(s.spokenText, 'Hello world. Second para.');
      expect(s.tokenGlobalIndices, [0, 1, 2, 3]);
    });

    test('starts from the given index (not always 0)', () {
      final chapters = [
        Chapter(title: 'c0', tokens: [
          _tok('Hello', global: 0, paragraph: 0, isParagraphStart: true),
          _tok('world.', global: 1, paragraph: 0),
          _tok('Next', global: 2, paragraph: 1, isParagraphStart: true),
          _tok('sentence.', global: 3, paragraph: 1),
        ]),
      ];
      final s = extractSentenceFrom(chapters, 2)!;
      expect(s.startGlobalIndex, 2);
      expect(s.endGlobalIndexExcl, 4);
      expect(s.spokenText, 'Next sentence.');
      expect(s.tokenGlobalIndices, [2, 3]);
    });

    test('stops before a new chapter starts', () {
      final chapters = [
        _ch(0, ['Tail', 'without', 'period']),
        _ch(1, ['Chapter', 'two', 'starts.'], firstIsChapterStart: true),
      ];
      final s = extractSentenceFrom(chapters, 0)!;
      // Walks to end of chapter 0 but NOT into chapter 1.
      expect(s.endGlobalIndexExcl, 3);
      expect(s.spokenText, 'Tail without period');
    });

    test('caps the segment at maxTokens for runaway paragraphs', () {
      final tokens = List<String>.generate(120, (i) => 'word$i');
      final chapters = [_ch(0, tokens)];
      final s = extractSentenceFrom(chapters, 0, maxTokens: 50)!;
      expect(s.endGlobalIndexExcl, 50);
      expect(s.tokenGlobalIndices.length, 50);
    });

    test('image tokens are silent but consume the range', () {
      final chapters = [
        Chapter(title: 'c0', tokens: [
          _tok('Look', global: 0, paragraph: 0, isParagraphStart: true),
          _img(global: 1, paragraph: 0),
          _tok('there.', global: 2, paragraph: 0),
        ]),
      ];
      final s = extractSentenceFrom(chapters, 0)!;
      expect(s.spokenText, 'Look there.');
      expect(s.tokenGlobalIndices, [0, 2]); // image at index 1 skipped
      expect(s.tokenCharOffsets, [0, 5]);
      expect(s.endGlobalIndexExcl, 3); // image still counts in range
    });

    test('starting on an image walks to the next speakable token', () {
      final chapters = [
        Chapter(title: 'c0', tokens: [
          _img(global: 0, paragraph: 0),
          _tok('First.', global: 1, paragraph: 0, isParagraphStart: true),
        ]),
      ];
      final s = extractSentenceFrom(chapters, 0)!;
      expect(s.startGlobalIndex, 0);
      expect(s.spokenText, 'First.');
      expect(s.tokenGlobalIndices, [1]);
      expect(s.endGlobalIndexExcl, 2);
    });

    test('does not break on punctuation or paragraph boundaries', () {
      // EPUBs converted from PDFs often use one <p> per line, so each
      // sentence comes through with `isParagraphStart=true`. The
      // extractor still has to keep them together — otherwise the engine
      // would issue one `speak()` per sentence and the IPC latency would
      // be audible.
      final chapters = [
        Chapter(title: 'c0', tokens: [
          _tok('A.', global: 0, paragraph: 0, isParagraphStart: true),
          _tok('B!', global: 1, paragraph: 1, isParagraphStart: true),
          _tok('C?', global: 2, paragraph: 2, isParagraphStart: true),
          _tok('D…', global: 3, paragraph: 3, isParagraphStart: true),
        ]),
      ];
      final s = extractSentenceFrom(chapters, 0)!;
      expect(s.spokenText, 'A. B! C? D…');
      expect(s.endGlobalIndexExcl, 4);
    });
  });

  group('charOffsetToTokenIndex', () {
    test('returns -1 when offsets is empty', () {
      expect(charOffsetToTokenIndex(const [], 5), -1);
    });

    test('returns -1 when target is before the first offset', () {
      expect(charOffsetToTokenIndex(const [3, 8, 12], 0), -1);
    });

    test('finds exact match', () {
      expect(charOffsetToTokenIndex(const [0, 6, 14], 6), 1);
    });

    test('finds the floor when target is between offsets', () {
      expect(charOffsetToTokenIndex(const [0, 6, 14], 8), 1);
    });

    test('returns last index when target is past the last offset', () {
      expect(charOffsetToTokenIndex(const [0, 6, 14], 999), 2);
    });

    test('first offset', () {
      expect(charOffsetToTokenIndex(const [0, 6, 14], 0), 0);
    });
  });
}

/// Helper that builds a Chapter with N tokens. Only the first token of the
/// chapter is marked `isParagraphStart` — callers that need multi-paragraph
/// chapters should build them with the longer form (see [_tok]).
Chapter _ch(int chapterIdx, List<String> words,
    {bool firstIsChapterStart = false}) {
  return Chapter(
    title: 'Chapter $chapterIdx',
    tokens: [
      for (var i = 0; i < words.length; i++)
        _tok(
          words[i],
          global: i,
          paragraph: 0,
          isParagraphStart: i == 0,
          isChapterStart: i == 0 && firstIsChapterStart,
          chapterIndex: chapterIdx,
        ),
    ],
  );
}

WordToken _tok(
  String text, {
  required int global,
  required int paragraph,
  bool isParagraphStart = false,
  bool isChapterStart = false,
  int chapterIndex = 0,
}) {
  return WordToken(
    text: text,
    orpIndex: 0,
    timingMultiplier: 1.0,
    globalIndex: global,
    chapterIndex: chapterIndex,
    paragraphIndex: paragraph,
    isParagraphStart: isParagraphStart,
    isChapterStart: isChapterStart,
  );
}

WordToken _img({required int global, required int paragraph}) {
  return WordToken(
    text: '',
    orpIndex: 0,
    timingMultiplier: 1.0,
    globalIndex: global,
    chapterIndex: 0,
    paragraphIndex: paragraph,
    isImage: true,
    imageRelativePath: 'fake/path.png',
  );
}
