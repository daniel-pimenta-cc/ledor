import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/utils/orp_calculator.dart';

void main() {
  group('OrpCalculator', () {
    test('empty string returns 0', () {
      expect(OrpCalculator.calculate(''), 0);
    });

    test('single char returns 0', () {
      expect(OrpCalculator.calculate('I'), 0);
      expect(OrpCalculator.calculate('a'), 0);
    });

    test('2 char word returns 0', () {
      expect(OrpCalculator.calculate('of'), 0);
      expect(OrpCalculator.calculate('is'), 0);
    });

    test('3 char word returns 1', () {
      expect(OrpCalculator.calculate('the'), 1);
      expect(OrpCalculator.calculate('can'), 1);
    });

    test('4-5 char words return 1', () {
      expect(OrpCalculator.calculate('word'), 1);
      expect(OrpCalculator.calculate('about'), 1);
      expect(OrpCalculator.calculate('world'), 1);
    });

    test('6-8 char words return 2', () {
      expect(OrpCalculator.calculate('simple'), 2);
      expect(OrpCalculator.calculate('reading'), 2);
      expect(OrpCalculator.calculate('complete'), 2);
    });

    test('9-11 char words return 3', () {
      expect(OrpCalculator.calculate('important'), 3);
      expect(OrpCalculator.calculate('beautiful'), 3);
      expect(OrpCalculator.calculate('programming'), 3);
    });

    test('12-13 char words return 4', () {
      expect(OrpCalculator.calculate('independence'), 4);
      expect(OrpCalculator.calculate('communication'), 4);
    });

    test('very long words use 35% formula', () {
      // 20 chars -> floor(20 * 0.35) = 7
      expect(OrpCalculator.calculate('internationalization'), 7);
    });

    test('handles Portuguese accented characters', () {
      // "coração" = 7 alpha chars -> ORP at index 2
      expect(OrpCalculator.calculate('coração'), 2);
      // "ação" = 4 alpha chars -> ORP at index 1
      expect(OrpCalculator.calculate('ação'), 1);
      // "português" = 9 alpha chars -> ORP at index 3
      expect(OrpCalculator.calculate('português'), 3);
    });

    test('skips leading punctuation', () {
      // '"hello' -> alpha is "hello" (5 chars -> ORP 1), but offset by 1 for quote
      expect(OrpCalculator.calculate('"hello'), 2); // index 2 in full string
      expect(OrpCalculator.calculate('(test)'), 2); // 't' at index 2
    });

    test('handles trailing punctuation', () {
      // "world." -> alpha is "world" (5 chars -> ORP 1)
      expect(OrpCalculator.calculate('world.'), 1);
      expect(OrpCalculator.calculate('done!'), 1);
    });

    test('all punctuation returns 0', () {
      expect(OrpCalculator.calculate('...'), 0);
      expect(OrpCalculator.calculate('---'), 0);
    });

    test('handles contractions', () {
      // "don't" has 4 alpha chars (d,o,n,t) -> ORP 1
      expect(OrpCalculator.calculate("don't"), 1);
    });
  });
}
