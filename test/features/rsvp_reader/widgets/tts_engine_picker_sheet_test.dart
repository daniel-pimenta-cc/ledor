import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/features/rsvp_reader/data/services/tts_backend.dart';
import 'package:ledor/features/rsvp_reader/presentation/providers/display_settings_provider.dart';
import 'package:ledor/features/rsvp_reader/presentation/providers/tts_voices_provider.dart';
import 'package:ledor/features/rsvp_reader/presentation/widgets/tts_engine_picker_sheet.dart';
import 'package:ledor/l10n/generated/app_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The sheet's opaque Container sits between its ListTiles and the modal's
/// Material, so every tile build reports the debug-only "ListTile background
/// color or ink splashes may be invisible" warning — console noise in the
/// app, hard failure in widget tests. Filter just that one.
void _ignoreListTileInkWarning() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details
        .exceptionAsString()
        .contains('ListTile background color or ink splashes')) {
      return;
    }
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

const _engines = [
  TtsEngine(
    id: 'com.google.android.tts',
    displayName: 'Speech Services by Google',
  ),
  // id == displayName: the tile should NOT render a subtitle for this one.
  TtsEngine(id: 'espeak-ng', displayName: 'espeak-ng'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<ProviderContainer> pumpSheet(
    WidgetTester tester, {
    List<TtsEngine> engines = _engines,
  }) async {
    _ignoreListTileInkWarning();

    final container = ProviderContainer(overrides: [
      ttsEnginesProvider.overrideWith((ref) async => engines),
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
                    builder: (_) => const TtsEnginePickerSheet(),
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

  ListTile tileFor(WidgetTester tester, String title) {
    return tester.widget<ListTile>(
      find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
    );
  }

  testWidgets('renders System default plus reported engines', (tester) async {
    await pumpSheet(tester);

    expect(find.text('Choose an engine'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
    expect(find.text('Speech Services by Google'), findsOneWidget);
    expect(find.text('espeak-ng'), findsOneWidget);

    // Technical id as subtitle only when it differs from the display name.
    expect(find.text('com.google.android.tts'), findsOneWidget);

    // Default settings have no engine picked -> System default is selected.
    expect(tileFor(tester, 'System default').selected, isTrue);
    expect(tileFor(tester, 'Speech Services by Google').selected, isFalse);
  });

  testWidgets('tapping an engine commits ttsEngineId and closes the sheet',
      (tester) async {
    final container = await pumpSheet(tester);

    await tester.tap(find.text('Speech Services by Google'));
    await tester.pumpAndSettle();

    expect(find.byType(TtsEnginePickerSheet), findsNothing);
    expect(
      container.read(displaySettingsProvider).ttsEngineId,
      'com.google.android.tts',
    );
  });

  testWidgets('empty engine list shows the empty message', (tester) async {
    await pumpSheet(tester, engines: const []);

    expect(find.text('No alternative engines installed'), findsOneWidget);
    expect(find.text('System default'), findsNothing);
  });
}
