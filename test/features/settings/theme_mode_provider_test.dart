import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/theme/app_colors.dart';
import 'package:ledor/features/library_sync/presentation/providers/library_sync_provider.dart';
import 'package:ledor/features/rsvp_reader/presentation/providers/display_settings_provider.dart';
import 'package:ledor/features/settings/presentation/providers/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _StubLibrarySyncNotifier extends LibrarySyncNotifier {
  _StubLibrarySyncNotifier(super.ref);

  @override
  void schedulePush() {}

  @override
  void markSettingsDirty() {}
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;

    container = ProviderContainer(
      overrides: [
        librarySyncProvider.overrideWith((ref) {
          return _StubLibrarySyncNotifier(ref);
        }),
      ],
    );
    await container.read(displaySettingsProvider.notifier).load();
  });

  tearDown(() {
    container.dispose();
    binding.platformDispatcher.clearPlatformBrightnessTestValue();
  });

  group('DisplaySettingsNotifier.applyBrightness', () {
    test('flips word + background to the palette, keeps ORP and highlight',
        () async {
      final notifier = container.read(displaySettingsProvider.notifier);
      await notifier.update(
        (s) => s.copyWith(orpColorValue: 0xFF123456, highlightColorValue: 0xFF654321),
      );

      await notifier.applyBrightness(Brightness.dark);

      final s = container.read(displaySettingsProvider);
      expect(s.wordColorValue, AppPalette.dark.onSurface.toARGB32());
      expect(s.backgroundColorValue, AppPalette.dark.background.toARGB32());
      expect(s.orpColorValue, 0xFF123456);
      expect(s.highlightColorValue, 0xFF654321);

      await notifier.applyBrightness(Brightness.light);

      final s2 = container.read(displaySettingsProvider);
      expect(s2.wordColorValue, AppPalette.light.onSurface.toARGB32());
      expect(s2.backgroundColorValue, AppPalette.light.background.toARGB32());
    });
  });

  group('ThemeModeNotifier.set', () {
    test('re-picking the same effective brightness keeps custom colours',
        () async {
      final display = container.read(displaySettingsProvider.notifier);
      await display.update((s) => s.copyWith(wordColorValue: 0xFFABCDEF));

      // system resolves to light here, so system → light is a no-op flip.
      await container.read(themeModeProvider.notifier).set(ThemeMode.light);

      expect(
        container.read(displaySettingsProvider).wordColorValue,
        0xFFABCDEF,
      );
    });

    test('a real brightness change inverts the reader palette and persists',
        () async {
      final display = container.read(displaySettingsProvider.notifier);
      await display.update((s) => s.copyWith(wordColorValue: 0xFFABCDEF));

      await container.read(themeModeProvider.notifier).set(ThemeMode.dark);

      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(
        container.read(displaySettingsProvider).wordColorValue,
        AppPalette.dark.onSurface.toARGB32(),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings_theme_mode'), 'dark');
    });
  });
}
