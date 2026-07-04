import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/utils/word_timing.dart';

void main() {
  group('WordTiming', () {
    test('normal word (4-6 chars) has multiplier ~1.0', () {
      final m = WordTiming.calculateMultiplier('hello');
      expect(m, closeTo(1.0, 0.01));
    });

    test('short word (<= 3 chars) is faster', () {
      final m = WordTiming.calculateMultiplier('is');
      expect(m, lessThan(1.0));
    });

    test('long word (> 6 chars) is slower', () {
      final m = WordTiming.calculateMultiplier('important');
      expect(m, greaterThan(1.0));
    });

    test('period doubles the time', () {
      final normal = WordTiming.calculateMultiplier('word');
      final withPeriod = WordTiming.calculateMultiplier('word.');
      expect(withPeriod, greaterThan(normal * 1.5));
    });

    test('question/exclamation mark doubles the time', () {
      final withQuestion = WordTiming.calculateMultiplier('what?');
      final withExclam = WordTiming.calculateMultiplier('wow!');
      expect(withQuestion, greaterThan(1.5));
      expect(withExclam, greaterThan(1.5));
    });

    test('comma adds moderate pause', () {
      final withComma = WordTiming.calculateMultiplier('however,');
      final without = WordTiming.calculateMultiplier('however');
      expect(withComma, greaterThan(without));
    });

    test('ellipsis adds longest pause', () {
      final m = WordTiming.calculateMultiplier('wait...');
      expect(m, greaterThan(2.0));
    });

    test('paragraph start adds pause', () {
      final normal = WordTiming.calculateMultiplier('The');
      final paragraphStart =
          WordTiming.calculateMultiplier('The', isParagraphStart: true);
      expect(paragraphStart, greaterThan(normal));
    });

    test('chapter start adds large pause', () {
      final m = WordTiming.calculateMultiplier('Chapter',
          isChapterStart: true);
      expect(m, greaterThan(2.5));
    });

    test('multiplier is clamped to 0.5-5.0', () {
      // Even extreme combinations should clamp
      final m = WordTiming.calculateMultiplier(
        'internationalization...',
        isChapterStart: true,
      );
      expect(m, lessThanOrEqualTo(5.0));
      expect(m, greaterThanOrEqualTo(0.5));
    });

    test('closing quote adds slight pause', () {
      final withQuote = WordTiming.calculateMultiplier('end"');
      final without = WordTiming.calculateMultiplier('end');
      expect(withQuote, greaterThan(without));
    });
  });
}
