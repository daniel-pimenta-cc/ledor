import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/features/rsvp_reader/presentation/providers/rsvp_engine_provider.dart';

void main() {
  group('computeSessionAvgWpm', () {
    test('drops sessions shorter than 3 seconds', () {
      expect(computeSessionAvgWpm(0, 100), isNull);
      expect(computeSessionAvgWpm(1500, 20), isNull);
      expect(computeSessionAvgWpm(2999, 50), isNull);
    });

    test('drops sessions with fewer than 5 words', () {
      expect(computeSessionAvgWpm(10000, 0), isNull);
      expect(computeSessionAvgWpm(10000, 4), isNull);
    });

    test('keeps sessions that meet both thresholds', () {
      expect(computeSessionAvgWpm(3000, 5), isNotNull);
      expect(computeSessionAvgWpm(60000, 300), isNotNull);
    });

    test('300 words in 60s rounds to 300 wpm', () {
      expect(computeSessionAvgWpm(60000, 300), 300);
    });

    test('50 words in 10s rounds to 300 wpm', () {
      expect(computeSessionAvgWpm(10000, 50), 300);
    });

    test('avoids integer division — fractional wpm rounds correctly', () {
      // 7 words in 3s = 140 wpm exact
      expect(computeSessionAvgWpm(3000, 7), 140);
      // 10 words in 3s = 200 wpm exact
      expect(computeSessionAvgWpm(3000, 10), 200);
      // 100 words in 23s = ~260.87 wpm -> 261
      expect(computeSessionAvgWpm(23000, 100), 261);
    });
  });
}
