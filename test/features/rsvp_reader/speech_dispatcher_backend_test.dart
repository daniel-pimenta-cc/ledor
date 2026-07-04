import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/features/rsvp_reader/data/services/speech_dispatcher_backend.dart';

void main() {
  group('SpeechDispatcherBackend.wordCharOffsetsForTest', () {
    test('returns empty list for an empty string', () {
      expect(SpeechDispatcherBackend.wordCharOffsetsForTest(''), isEmpty);
    });

    test('returns offset 0 for a single word with no surrounding whitespace',
        () {
      expect(SpeechDispatcherBackend.wordCharOffsetsForTest('hello'), [0]);
    });

    test('records the start of each whitespace-delimited word', () {
      expect(
        SpeechDispatcherBackend.wordCharOffsetsForTest('Hello world.'),
        [0, 6],
      );
    });

    test('collapses runs of whitespace into a single boundary', () {
      expect(
        SpeechDispatcherBackend.wordCharOffsetsForTest('Hello   world'),
        [0, 8],
      );
    });

    test('handles tabs and newlines as whitespace', () {
      expect(
        SpeechDispatcherBackend.wordCharOffsetsForTest('a\tb\nc'),
        [0, 2, 4],
      );
    });

    test('does not emit a boundary for leading whitespace before the first word',
        () {
      expect(
        SpeechDispatcherBackend.wordCharOffsetsForTest('  hello'),
        [2],
      );
    });
  });

  group('SpeechDispatcherBackend.parseVoiceListForTest', () {
    test('returns empty for empty input', () {
      expect(SpeechDispatcherBackend.parseVoiceListForTest(''), isEmpty);
    });

    test('skips header lines and parses 3-column rows', () {
      // Approximates the real `spd-say -L` output format.
      const stdout = '''
Name        Language   Variant
----        --------   -------
Andrea      en         female
Antonio     it         male
''';
      final voices = SpeechDispatcherBackend.parseVoiceListForTest(stdout);
      expect(voices.length, 2);
      expect(voices[0].name, 'Andrea');
      expect(voices[0].locale, 'en');
      expect(voices[0].gender, 'female');
      expect(voices[1].name, 'Antonio');
      expect(voices[1].locale, 'it');
      expect(voices[1].gender, 'male');
    });

    test('tolerates rows without a gender column', () {
      const stdout = '''
Name        Language
Charles     fr
''';
      final voices = SpeechDispatcherBackend.parseVoiceListForTest(stdout);
      expect(voices.length, 1);
      expect(voices[0].name, 'Charles');
      expect(voices[0].locale, 'fr');
      expect(voices[0].gender, isNull);
    });

    test('skips header sentinel lines', () {
      const stdout = '''
There are 2 voices available:
output module: espeak-ng
Name        Language   Variant
Andrea      en         female
Antonio     it         male
''';
      final voices = SpeechDispatcherBackend.parseVoiceListForTest(stdout);
      expect(voices.length, 2);
    });

    test('skips malformed rows silently', () {
      const stdout = '''
Andrea      en         female
single-column-garbage
Antonio     it         male
''';
      final voices = SpeechDispatcherBackend.parseVoiceListForTest(stdout);
      expect(voices.length, 2);
    });
  });
}
