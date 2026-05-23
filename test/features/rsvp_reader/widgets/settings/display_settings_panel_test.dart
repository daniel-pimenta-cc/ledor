import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsvp_reader/core/utils/platform_capabilities.dart';
import 'package:rsvp_reader/features/rsvp_reader/data/services/tts_backend.dart';
import 'package:rsvp_reader/features/rsvp_reader/domain/entities/rsvp_state.dart';
import 'package:rsvp_reader/features/rsvp_reader/presentation/providers/rsvp_engine_provider.dart';
import 'package:rsvp_reader/features/rsvp_reader/presentation/providers/tts_voices_provider.dart';
import 'package:rsvp_reader/features/rsvp_reader/presentation/widgets/display_settings_panel.dart';
import 'package:rsvp_reader/features/rsvp_reader/presentation/widgets/settings/settings_category.dart';
import 'package:rsvp_reader/features/rsvp_reader/presentation/widgets/settings/settings_section_header.dart';
import 'package:rsvp_reader/l10n/generated/app_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Pumps a [DisplaySettingsPanel] inside a scroll view (the panel itself
/// renders ~6 sections of dense controls — without scroll wrapping it
/// overflows the default 600x600 test surface), with the providers most
/// likely to throw stubbed out:
///   - `displaySettingsProvider` reads SharedPreferences (the async
///     variant); platform set to in-memory so the loader resolves to
///     defaults instead of `MissingPluginException`.
///   - `ttsEnginesProvider` / `ttsVoicesProvider` touch the real backend
///     on first read; both overridden to return empty.
///   - When [mode] is supplied, `readerModeProvider(bookId)` is short-
///     circuited so the test bypasses the full RsvpEngineNotifier wiring.
Future<void> pumpPanel(
  WidgetTester tester, {
  String? bookId,
  ReaderMode? mode,
}) async {
  // Either pass both or pass neither — without an override of
  // readerModeProvider(bookId), passing bookId alone falls through to the
  // real provider chain (RsvpEngineNotifier → real DAOs) and crashes with
  // an unrelated-looking Riverpod plumbing error. Fail loudly here instead.
  assert(
    (bookId == null) == (mode == null),
    'pumpPanel: bookId and mode must both be provided or both be null',
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ttsEnginesProvider
            .overrideWith((ref) async => const <TtsEngine>[]),
        ttsVoicesProvider
            .overrideWith((ref) async => const <TtsVoice>[]),
        if (bookId != null && mode != null)
          readerModeProvider(bookId).overrideWith((ref) => mode),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: DisplaySettingsPanel(bookId: bookId),
          ),
        ),
      ),
    ),
  );

  // Let the async providers (displaySettings load, tts engine list, etc.)
  // settle so the headers render with their final state.
  await tester.pumpAndSettle();
}

List<SettingsCategory> categoryOrder(WidgetTester tester) {
  return tester
      .widgetList<SettingsSectionHeader>(find.byType(SettingsSectionHeader))
      .map((h) => h.category)
      .toList();
}

List<bool> activeFlags(WidgetTester tester) {
  return tester
      .widgetList<SettingsSectionHeader>(find.byType(SettingsSectionHeader))
      .map((h) => h.isActive)
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('DisplaySettingsPanel ordering', () {
    testWidgets('without bookId renders pedagogical order, no active section',
        (tester) async {
      await pumpPanel(tester);

      // The panel filters the audio section out on platforms where
      // PlatformCapabilities.supportsTts is false (web), so build the
      // expected order the same way the panel does instead of asserting
      // a fixed list that would break under `flutter test -d chrome`.
      final expected = [
        SettingsCategory.typography,
        SettingsCategory.speedTiming,
        SettingsCategory.rsvpDisplay,
        SettingsCategory.readerView,
        if (PlatformCapabilities.supportsTts) SettingsCategory.audio,
        SettingsCategory.chrome,
      ];
      expect(categoryOrder(tester), expected);
      expect(activeFlags(tester).every((a) => a == false), isTrue,
          reason: 'no active mode → no chip should light up');
    });

    testWidgets('RSVP mode floats Speed & Timing to the top', (tester) async {
      await pumpPanel(tester, bookId: 'book-1', mode: ReaderMode.rsvp);

      final order = categoryOrder(tester);
      expect(order.first, SettingsCategory.speedTiming);
      expect(order[1], SettingsCategory.rsvpDisplay);
      if (PlatformCapabilities.supportsTts) {
        expect(order.last, SettingsCategory.audio,
            reason: 'audio sinks to the bottom when not in TTS mode');
      }
    });

    testWidgets('TTS mode floats Audio to the top', (tester) async {
      if (!PlatformCapabilities.supportsTts) return;
      await pumpPanel(tester, bookId: 'book-1', mode: ReaderMode.tts);

      final order = categoryOrder(tester);
      expect(order.first, SettingsCategory.audio);
      expect(order.sublist(order.length - 2), const [
        SettingsCategory.speedTiming,
        SettingsCategory.rsvpDisplay,
      ]);
    });

    testWidgets('ereader mode floats Reader View first, Audio last',
        (tester) async {
      await pumpPanel(tester, bookId: 'book-1', mode: ReaderMode.ereader);

      final order = categoryOrder(tester);
      expect(order.first, SettingsCategory.readerView);
      if (PlatformCapabilities.supportsTts) {
        expect(order.last, SettingsCategory.audio);
      }
    });
  });

  group('DisplaySettingsPanel active chip', () {
    testWidgets('RSVP mode lights up everything except audio', (tester) async {
      await pumpPanel(tester, bookId: 'book-1', mode: ReaderMode.rsvp);

      final activeByCategory = <SettingsCategory, bool>{};
      for (final header in tester.widgetList<SettingsSectionHeader>(
          find.byType(SettingsSectionHeader))) {
        activeByCategory[header.category] = header.isActive;
      }

      expect(activeByCategory[SettingsCategory.speedTiming], isTrue);
      expect(activeByCategory[SettingsCategory.rsvpDisplay], isTrue);
      expect(activeByCategory[SettingsCategory.readerView], isTrue,
          reason: 'context-scroll view is reachable from RSVP (pause)');
      expect(activeByCategory[SettingsCategory.typography], isTrue);
      expect(activeByCategory[SettingsCategory.chrome], isTrue);
      expect(activeByCategory[SettingsCategory.audio], isFalse);
    });

    testWidgets('TTS mode lights up audio + reader + allModes sections',
        (tester) async {
      await pumpPanel(tester, bookId: 'book-1', mode: ReaderMode.tts);

      final activeByCategory = <SettingsCategory, bool>{};
      for (final header in tester.widgetList<SettingsSectionHeader>(
          find.byType(SettingsSectionHeader))) {
        activeByCategory[header.category] = header.isActive;
      }

      expect(activeByCategory[SettingsCategory.audio], isTrue);
      expect(activeByCategory[SettingsCategory.readerView], isTrue);
      expect(activeByCategory[SettingsCategory.typography], isTrue);
      expect(activeByCategory[SettingsCategory.chrome], isTrue);
      expect(activeByCategory[SettingsCategory.speedTiming], isFalse);
      expect(activeByCategory[SettingsCategory.rsvpDisplay], isFalse);
    });

    testWidgets('ereader mode only lights up readerView + typography',
        (tester) async {
      await pumpPanel(tester, bookId: 'book-1', mode: ReaderMode.ereader);

      final activeByCategory = <SettingsCategory, bool>{};
      for (final header in tester.widgetList<SettingsSectionHeader>(
          find.byType(SettingsSectionHeader))) {
        activeByCategory[header.category] = header.isActive;
      }

      expect(activeByCategory[SettingsCategory.readerView], isTrue);
      expect(activeByCategory[SettingsCategory.typography], isTrue);
      // chrome is gated to controlsModes; the dock isn't shown in e-reader.
      expect(activeByCategory[SettingsCategory.chrome], isFalse,
          reason: 'controls dock is hidden in e-reader');
      expect(activeByCategory[SettingsCategory.audio], isFalse);
      expect(activeByCategory[SettingsCategory.speedTiming], isFalse);
      expect(activeByCategory[SettingsCategory.rsvpDisplay], isFalse);
    });
  });

  group('SettingsSectionHeader chip rendering', () {
    testWidgets('header tooltips describe each section scope', (tester) async {
      await pumpPanel(tester);

      final tooltipMessages = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((t) => t.message)
          .whereType<String>()
          .toSet();

      expect(tooltipMessages, contains('Applies to RSVP mode only'));
      expect(tooltipMessages, contains('Applies to audio playback (TTS)'));
      expect(
        tooltipMessages,
        contains('Applies to RSVP, e-reader, and audio modes'),
      );
      expect(tooltipMessages, contains('Applies to all reading modes'));
      expect(
        tooltipMessages,
        contains(
            'Applies wherever the playback controls are visible (not e-reader)'),
      );
    });
  });
}
