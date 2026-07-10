import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../rsvp_reader/presentation/providers/display_settings_provider.dart';

const _kThemeModeKey = 'settings_theme_mode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;

  ThemeModeNotifier(this._ref) : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kThemeModeKey);
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
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode.name);

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
