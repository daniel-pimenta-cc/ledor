import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/features/library_sync/data/services/library_sync_service.dart';
import 'package:ledor/features/rsvp_reader/domain/entities/display_settings.dart';

void main() {
  group('DisplaySettings sync map', () {
    test('focusMode round-trips through the settings shard', () {
      const settings = DisplaySettings(focusMode: false);
      final restored =
          displaySettingsFromMap(displaySettingsToMap(settings));
      expect(restored.focusMode, isFalse);
    });

    test('focusMode defaults to on for old shards without the key', () {
      final map = displaySettingsToMap(const DisplaySettings());
      map.remove('focusMode');
      final restored = displaySettingsFromMap(map);
      expect(restored.focusMode, isTrue);
    });
  });
}
