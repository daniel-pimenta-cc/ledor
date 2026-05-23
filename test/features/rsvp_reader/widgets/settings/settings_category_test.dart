import 'package:flutter_test/flutter_test.dart';
import 'package:rsvp_reader/features/rsvp_reader/domain/entities/rsvp_state.dart';
import 'package:rsvp_reader/features/rsvp_reader/presentation/widgets/settings/settings_category.dart';

void main() {
  group('SettingsCategoryScope.scope', () {
    test('groups RSVP-only categories under rsvpOnly scope', () {
      expect(SettingsCategory.speedTiming.scope, SettingsScope.rsvpOnly);
      expect(SettingsCategory.rsvpDisplay.scope, SettingsScope.rsvpOnly);
    });

    test('audio category has its own scope', () {
      expect(SettingsCategory.audio.scope, SettingsScope.audioOnly);
    });

    test('readerView covers scroll/ereader/TTS', () {
      expect(SettingsCategory.readerView.scope, SettingsScope.readerModes);
    });

    test('typography applies to all modes (font/background used by every mode)',
        () {
      expect(SettingsCategory.typography.scope, SettingsScope.allModes);
    });

    test('chrome is gated to modes that host the controls dock (not e-reader)',
        () {
      // RsvpControls (which owns the progress slider and time-remaining
      // badge) is omitted in e-reader mode, so chrome settings have no
      // visible effect there.
      expect(SettingsCategory.chrome.scope, SettingsScope.controlsModes);
    });
  });

  group('orderedCategoriesFor', () {
    test('without a mode returns the pedagogical default order', () {
      final order = orderedCategoriesFor(null);
      expect(order, [
        SettingsCategory.typography,
        SettingsCategory.speedTiming,
        SettingsCategory.rsvpDisplay,
        SettingsCategory.readerView,
        SettingsCategory.audio,
        SettingsCategory.chrome,
      ]);
    });

    test('RSVP mode floats Speed & Timing to the top', () {
      final order = orderedCategoriesFor(ReaderMode.rsvp);
      expect(order.first, SettingsCategory.speedTiming);
      expect(order[1], SettingsCategory.rsvpDisplay);
      expect(order.last, SettingsCategory.audio);
    });

    test('scroll mode behaves the same as RSVP (collapsed identity)', () {
      expect(
        orderedCategoriesFor(ReaderMode.scroll),
        orderedCategoriesFor(ReaderMode.rsvp),
      );
    });

    test('ereader mode floats Reader View to the top, Audio last', () {
      final order = orderedCategoriesFor(ReaderMode.ereader);
      expect(order.first, SettingsCategory.readerView);
      expect(order.last, SettingsCategory.audio);
    });

    test('TTS mode floats Audio to the top, RSVP-only categories last', () {
      final order = orderedCategoriesFor(ReaderMode.tts);
      expect(order.first, SettingsCategory.audio);
      expect(order.sublist(order.length - 2), [
        SettingsCategory.speedTiming,
        SettingsCategory.rsvpDisplay,
      ]);
    });

    test('every ordering contains every category exactly once', () {
      for (final mode in <ReaderMode?>[null, ...ReaderMode.values]) {
        final order = orderedCategoriesFor(mode);
        expect(order.toSet().length, SettingsCategory.values.length,
            reason: 'duplicate categories for mode=$mode');
        expect(order.length, SettingsCategory.values.length,
            reason: 'missing categories for mode=$mode');
      }
    });
  });

  group('isCategoryActiveFor', () {
    test('null mode marks no category as active', () {
      for (final c in SettingsCategory.values) {
        expect(isCategoryActiveFor(c, null), isFalse);
      }
    });

    test('RSVP mode activates RSVP, readerView, typography and chrome', () {
      expect(isCategoryActiveFor(SettingsCategory.speedTiming, ReaderMode.rsvp),
          isTrue);
      expect(isCategoryActiveFor(SettingsCategory.rsvpDisplay, ReaderMode.rsvp),
          isTrue);
      expect(isCategoryActiveFor(SettingsCategory.audio, ReaderMode.rsvp),
          isFalse);
      // RSVP-paused (scroll) surfaces the context-scroll view, so the
      // readerView settings are useful in RSVP too — keep both modes
      // consistent so pausing/resuming doesn't shuffle the chip state.
      expect(isCategoryActiveFor(SettingsCategory.readerView, ReaderMode.rsvp),
          isTrue);
      expect(isCategoryActiveFor(SettingsCategory.typography, ReaderMode.rsvp),
          isTrue);
      expect(isCategoryActiveFor(SettingsCategory.chrome, ReaderMode.rsvp),
          isTrue);
    });

    test('scroll behaves the same as RSVP (collapsed identity)', () {
      for (final c in SettingsCategory.values) {
        expect(
          isCategoryActiveFor(c, ReaderMode.scroll),
          isCategoryActiveFor(c, ReaderMode.rsvp),
          reason: 'category $c diverged between rsvp and scroll',
        );
      }
    });

    test('TTS mode activates audio + reader categories, not RSVP', () {
      expect(isCategoryActiveFor(SettingsCategory.audio, ReaderMode.tts),
          isTrue);
      expect(isCategoryActiveFor(SettingsCategory.readerView, ReaderMode.tts),
          isTrue);
      expect(isCategoryActiveFor(SettingsCategory.speedTiming, ReaderMode.tts),
          isFalse);
      expect(isCategoryActiveFor(SettingsCategory.rsvpDisplay, ReaderMode.tts),
          isFalse);
    });

    test('ereader mode activates only readerView + typography (chrome off)',
        () {
      expect(
          isCategoryActiveFor(SettingsCategory.readerView, ReaderMode.ereader),
          isTrue);
      expect(isCategoryActiveFor(SettingsCategory.audio, ReaderMode.ereader),
          isFalse);
      expect(
          isCategoryActiveFor(SettingsCategory.speedTiming, ReaderMode.ereader),
          isFalse);
      expect(
          isCategoryActiveFor(SettingsCategory.typography, ReaderMode.ereader),
          isTrue);
      // chrome is gated to controlsModes — e-reader hides the dock, so the
      // chip stays neutral instead of falsely claiming "all modes".
      expect(isCategoryActiveFor(SettingsCategory.chrome, ReaderMode.ereader),
          isFalse);
    });
  });
}
