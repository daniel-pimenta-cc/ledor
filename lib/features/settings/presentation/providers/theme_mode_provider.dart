import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../rsvp_reader/presentation/providers/display_settings_provider.dart';

const _kThemeModeKey = 'settings_theme_mode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;
  // Must be SharedPreferencesAsync like every other settings store: the legacy
  // SharedPreferences API keeps its own in-memory copy of the JSON file, so on
  // Linux it and the async API overwrite each other's keys.
  final _prefs = SharedPreferencesAsync();
  bool _chosen = false;

  ThemeModeNotifier(this._ref) : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    // Up to 0.3.0 this key lived in the legacy store, which is separate on
    // Android/iOS. Read-only on purpose: a legacy write clobbers the async
    // keys on Linux/Windows.
    final raw = await _prefs.getString(_kThemeModeKey) ??
        (await SharedPreferences.getInstance()).getString(_kThemeModeKey);
    // A pick made while the stored value was still loading wins.
    if (_chosen) return;
    state = ThemeMode.values.asNameMap()[raw] ?? ThemeMode.system;
  }

  /// Actual brightness that [mode] resolves to right now. Used to detect
  /// whether a mode change really flips the theme (for example, going from
  /// system→light when the system is already light is a no-op).
  Brightness _resolve(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return PlatformDispatcher.instance.platformBrightness;
    }
  }

  Future<void> set(ThemeMode mode) async {
    final oldBrightness = _resolve(state);
    final newBrightness = _resolve(mode);
    _chosen = true;
    state = mode;
    await _prefs.setString(_kThemeModeKey, mode.name);

    // Only invert the reader's word/background when the effective brightness
    // actually changes — picking the same theme back-to-back shouldn't rewrite
    // the user's last-used colours.
    if (oldBrightness != newBrightness) {
      await _ref
          .read(displaySettingsProvider.notifier)
          .applyBrightness(newBrightness);
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref);
});
