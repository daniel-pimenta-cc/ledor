import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/utils/text_tokenizer.dart';

void main() {
  group('TextTokenizer', () {
    test('tokenizes simple sentence', () {
      final tokens = TextTokenizer.tokenize(
        'Hello world',
        chapterIndex: 0,
        globalOffset: 0,
      );
      expect(tokens.length, 2);
      expect(tokens[0].text, 'Hello');
      expect(tokens[1].text, 'world');
    });

    test('assigns correct global indices', () {
      final tokens = TextTokenizer.tokenize(
        'One two three',
        chapterIndex: 0,
        globalOffset: 100,
      );
      expect(tokens[0].globalIndex, 100);
      expect(tokens[1].globalIndex, 101);
      expect(tokens[2].globalIndex, 102);
    });

    test('assigns correct chapter index', () {
      final tokens = TextTokenizer.tokenize(
        'Hello world',
        chapterIndex: 5,
        globalOffset: 0,
      );
      expect(tokens[0].chapterIndex, 5);
      expect(tokens[1].chapterIndex, 5);
    });

    test('detects paragraph boundaries', () {
      final tokens = TextTokenizer.tokenize(
        'First paragraph.\n\nSecond paragraph.',
        chapterIndex: 0,
        globalOffset: 0,
      );
      // "First" and "Second" should be paragraph starts
      expect(tokens[0].isParagraphStart, true);
      final secondParagraphStart =
          tokens.firstWhere((t) => t.text == 'Second');
      expect(secondParagraphStart.isParagraphStart, true);
    });

    test('marks first word as chapter start', () {
      final tokens = TextTokenizer.tokenize(
        'Chapter begins here.',
        chapterIndex: 0,
        globalOffset: 0,
      );
      expect(tokens[0].isChapterStart, true);
      expect(tokens[1].isChapterStart, false);
    });

    test('handles Portuguese text with accents', () {
      final tokens = TextTokenizer.tokenize(
        'O coração da história',
        chapterIndex: 0,
        globalOffset: 0,
      );
      expect(tokens.length, 4);
      expect(tokens[1].text, 'coração');
      expect(tokens[1].orpIndex, 2); // 7 alpha chars -> ORP 2
    });

    test('preserves punctuation on words', () {
      final tokens = TextTokenizer.tokenize(
        'Hello, world!',
        chapterIndex: 0,
        globalOffset: 0,
      );
      expect(tokens[0].text, 'Hello,');
      expect(tokens[1].text, 'world!');
    });

    test('skips empty content', () {
      final tokens = TextTokenizer.tokenize(
        '',
        chapterIndex: 0,
        globalOffset: 0,
      );
      expect(tokens, isEmpty);
    });

    test('handles multiple paragraph breaks', () {
      final tokens = TextTokenizer.tokenize(
        'A.\n\n\n\nB.',
        chapterIndex: 0,
        globalOffset: 0,
      );
      expect(tokens.length, 2);
      expect(tokens[0].paragraphIndex, 0);
      expect(tokens[1].paragraphIndex, 1);
    });

    test('ORP is pre-calculated for each token', () {
      final tokens = TextTokenizer.tokenize(
        'reading',
        chapterIndex: 0,
        globalOffset: 0,
      );
      expect(tokens[0].orpIndex, 2); // 7 chars -> ORP 2
    });

    test('splits hyphenated compound words keeping hyphen on the left', () {
      final tokens = TextTokenizer.tokenize(
        'guarda-chuva bem-vindo',
        chapterIndex: 0,
        globalOffset: 0,
      );
      expect(tokens.map((t) => t.text).toList(),
          ['guarda-', 'chuva', 'bem-', 'vindo']);
    });

    test('splits multi-hyphen compounds and preserves trailing punctuation',
        () {
      final tokens = TextTokenizer.tokenize(
        'well-being-test, high-quality.',
        chapterIndex: 0,
        globalOffset: 0,
      );
      expect(tokens.map((t) => t.text).toList(),
          ['well-', 'being-', 'test,', 'high-', 'quality.']);
    });

    test('only first sub-word of a hyphenated paragraph-start is marked', () {
      final tokens = TextTokenizer.tokenize(
        'guarda-chuva aberto',
        chapterIndex: 0,
        globalOffset: 0,
      );
      expect(tokens[0].text, 'guarda-');
      expect(tokens[0].isParagraphStart, true);
      expect(tokens[0].isChapterStart, true);
      expect(tokens[1].text, 'chuva');
      expect(tokens[1].isParagraphStart, false);
      expect(tokens[1].isChapterStart, false);
    });

    test('merges standalone hyphen into the following word', () {
      final tokens = TextTokenizer.tokenize(
        'foo - bar',
        chapterIndex: 0,
        globalOffset: 0,
      );
      expect(tokens.map((t) => t.text).toList(), ['foo', '- bar']);
    });

    test('merges standalone em-dash into the following word', () {
      final tokens = TextTokenizer.tokenize(
        'Он сказал — привет всем',
        chapterIndex: 0,
        globalOffset: 0,
      );
      expect(tokens.map((t) => t.text).toList(),
          ['Он', 'сказал', '— привет', 'всем']);
    });

    test('dialogue dash keeps paragraph-start flags on the merged unit', () {
      final tokens = TextTokenizer.tokenize(
        '— Привет',
        chapterIndex: 0,
        globalOffset: 0,
      );
      expect(tokens.map((t) => t.text).toList(), ['— Привет']);
      expect(tokens.single.isParagraphStart, isTrue);
      expect(tokens.single.isChapterStart, isTrue);
    });

    test('highlight of a merged unit lands on a word letter, not the dash',
        () {
      final tokens = TextTokenizer.tokenize(
        '— привет',
        chapterIndex: 0,
        globalOffset: 0,
      );
      final unit = tokens.single;
      final orpChar = unit.text[unit.orpIndex];
      expect(orpChar, isNot(equals('—')));
      expect(orpChar.trim().isNotEmpty, isTrue);
    });

    test('merged dash unit reads longer than the bare word', () {
      final merged = TextTokenizer.tokenize(
        '— привет',
        chapterIndex: 0,
        globalOffset: 0,
      ).single;
      final bare = TextTokenizer.tokenize(
        'привет',
        chapterIndex: 0,
        globalOffset: 0,
      ).single;
      expect(merged.timingMultiplier, greaterThan(bare.timingMultiplier));
    });

    test('collapses consecutive dashes into one unit', () {
      final tokens = TextTokenizer.tokenize(
        '— — ну',
        chapterIndex: 0,
        globalOffset: 0,
      );
      expect(tokens.map((t) => t.text).toList(), ['— — ну']);
    });

    test('trailing dash with no following word stays standalone', () {
      final tokens = TextTokenizer.tokenize(
        'Он замолчал —',
        chapterIndex: 0,
        globalOffset: 0,
      );
      expect(tokens.map((t) => t.text).toList(), ['Он', 'замолчал', '—']);
    });

    test('timing multiplier is pre-calculated', () {
      final tokens = TextTokenizer.tokenize(
        'word.',
        chapterIndex: 0,
        globalOffset: 0,
      );
      // Period should increase timing multiplier
      expect(tokens[0].timingMultiplier, greaterThan(1.0));
    });
  });
}
