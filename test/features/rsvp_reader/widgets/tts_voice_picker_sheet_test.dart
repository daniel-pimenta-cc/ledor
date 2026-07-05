import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/features/rsvp_reader/data/services/tts_backend.dart';
import 'package:ledor/features/rsvp_reader/presentation/providers/display_settings_provider.dart';
import 'package:ledor/features/rsvp_reader/presentation/providers/tts_backend_provider.dart';
import 'package:ledor/features/rsvp_reader/presentation/providers/tts_voices_provider.dart';
import 'package:ledor/features/rsvp_reader/presentation/widgets/tts_voice_picker_sheet.dart';
import 'package:ledor/l10n/generated/app_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// No-op backend so the sheet's dispose (`backend.stop()`) and the preview
/// path never touch the real platform TTS stack in tests.
class _FakeTtsBackend implements TtsBackend {
  @override
  bool get canPipeline => true;

  @override
  Future<void> init() async {}

  @override
  Future<List<TtsVoice>> getVoices() async => const [];

  @override
  Future<List<String>> getLanguages() async => const [];

  @override
  Future<List<TtsEngine>> getEngines() async => const [];

  @override
  Future<void> setEngine(String engineId) async {}

  @override
  Future<void> setVoice(TtsVoice? voice) async {}

  @override
  Future<void> setLanguage(String iso) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> speak(String text,
      {TtsQueueMode mode = TtsQueueMode.flush}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  set onProgress(TtsProgressHandler? cb) {}

  @override
  set onCompletion(VoidCallback? cb) {}

  @override
  set onError(void Function(String error)? cb) {}

  @override
  set onStart(VoidCallback? cb) {}
}

/// Android-style technical voice ids across three locales. With the default
/// `DisplaySettings.ttsLanguage` of `en-US` and UI locale `en`, the
/// "Current language" scope should show the two English voices and hide the
/// Portuguese one. `enrichVoices` renders them as "English (UK)" /
/// "English (US)" / "Portuguese (Brazil)" with the raw id as tech caption.
const _voices = [
  TtsVoice(name: 'en-gb-x-fis-network', locale: 'en-GB', gender: 'female'),
  TtsVoice(name: 'en-us-x-sfg-network', locale: 'en-US', gender: 'female'),
  TtsVoice(name: 'pt-br-x-afs-network', locale: 'pt-BR', gender: 'female'),
];

/// Filters one debug-only warning the sheet reports on its own in the real
/// app (console noise there; hard test failure here). Everything else is
/// forwarded and still fails the test.
///
/// "ListTile background color or ink splashes may be invisible": the
/// sheet's opaque Container sits between its ListTiles and the modal's
/// Material, so every tile build reports this debug-only warning.
void _ignoreKnownSheetErrors() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (message.contains('ListTile background color or ink splashes')) {
      return;
    }
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  /// Opens the sheet the same way the app does (showModalBottomSheet) so
  /// `Navigator.pop` on selection has a real route to pop. Returns the
  /// container so tests can read provider state after interactions.
  Future<ProviderContainer> pumpSheet(
    WidgetTester tester, {
    List<TtsVoice> voices = _voices,
  }) async {
    _ignoreKnownSheetErrors();

    // Tall surface so every locale group renders inside the sheet's 0.7
    // initial extent — the ListView is lazy and finders can't see tiles
    // below the fold on the default 800x600 surface.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: [
      ttsVoicesProvider.overrideWith((ref) async => voices),
      ttsBackendProvider.overrideWithValue(_FakeTtsBackend()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const TtsVoicePickerSheet(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return container;
  }

  /// The voice tile for [label] — scoped to ListTile because the locale
  /// group header renders the same text as the tile title.
  Finder voiceTile(String label) => find.descendant(
        of: find.byType(ListTile),
        matching: find.text(label),
      );

  group('scope toggle', () {
    testWidgets('defaults to current language: only English voices listed',
        (tester) async {
      await pumpSheet(tester);

      expect(find.text('Current language'), findsOneWidget);
      expect(find.text('All languages'), findsOneWidget);
      expect(voiceTile('English (UK)'), findsOneWidget);
      expect(voiceTile('English (US)'), findsOneWidget);
      expect(find.text('Portuguese (Brazil)'), findsNothing);
    });

    testWidgets('switching to All languages reveals other locales',
        (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('All languages'));
      await tester.pumpAndSettle();

      expect(voiceTile('Portuguese (Brazil)'), findsOneWidget);
      expect(voiceTile('English (UK)'), findsOneWidget);
      expect(voiceTile('English (US)'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('filters by tech id substring', (tester) async {
      await pumpSheet(tester);

      await tester.enterText(find.byType(TextField), 'en-gb-x-fis');
      await tester.pumpAndSettle();

      expect(voiceTile('English (UK)'), findsOneWidget);
      expect(voiceTile('English (US)'), findsNothing);
    });

    testWidgets('filters by friendly label substring', (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('All languages'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'portuguese');
      await tester.pumpAndSettle();

      expect(voiceTile('Portuguese (Brazil)'), findsOneWidget);
      expect(voiceTile('English (UK)'), findsNothing);
      expect(voiceTile('English (US)'), findsNothing);
    });
  });

  group('empty state', () {
    testWidgets(
        'no matches in current scope shows message with switch-to-All action',
        (tester) async {
      await pumpSheet(tester);

      // 'portuguese' matches the pt-BR voice, but that voice is outside the
      // current-language (en) scope.
      await tester.enterText(find.byType(TextField), 'portuguese');
      await tester.pumpAndSettle();

      expect(find.text('No voices match your search'), findsOneWidget);
      final action = find.widgetWithText(TextButton, 'All languages');
      expect(action, findsOneWidget);

      await tester.tap(action);
      await tester.pumpAndSettle();

      // Scope flipped to All: same query now matches the Portuguese voice.
      expect(voiceTile('Portuguese (Brazil)'), findsOneWidget);
      expect(find.text('No voices match your search'), findsNothing);
    });
  });

  group('tech id caption', () {
    testWidgets('raw voice id renders as monospace caption', (tester) async {
      await pumpSheet(tester);

      final caption = find.text('en-gb-x-fis-network');
      expect(caption, findsOneWidget);
      final text = tester.widget<Text>(caption);
      expect(text.style?.fontFamily, 'monospace');
    });
  });

  group('selection', () {
    testWidgets('tapping a voice commits name + locale and closes the sheet',
        (tester) async {
      final container = await pumpSheet(tester);

      await tester.tap(voiceTile('English (UK)'));
      await tester.pumpAndSettle();

      expect(find.byType(TtsVoicePickerSheet), findsNothing);
      final settings = container.read(displaySettingsProvider);
      expect(settings.ttsVoiceName, 'en-gb-x-fis-network');
      expect(settings.ttsLanguage, 'en-GB');
    });
  });
}
