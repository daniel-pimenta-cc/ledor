import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../library_sync/presentation/providers/library_sync_provider.dart';
import '../../domain/entities/display_settings.dart';

const _prefix = 'display_';

class DisplaySettingsNotifier extends StateNotifier<DisplaySettings> {
  final SharedPreferencesAsync _prefs;
  final Ref? _ref;
  Future<void>? _loading;

  DisplaySettingsNotifier(this._prefs, [this._ref])
      : super(const DisplaySettings()) {
    load();
  }

  /// Reads every persisted key once and caches the resulting [Future] so
  /// subsequent callers (e.g. each reader open) piggyback on the first load
  /// instead of re-running 15 serial platform-channel calls.
  Future<void> load() {
    return _loading ??= _loadImpl();
  }

  Future<void> _loadImpl() async {
    final results = await Future.wait<Object?>([
      _prefs.getInt('${_prefix}wpm'),
      _prefs.getDouble('${_prefix}fontSize'),
      _prefs.getDouble('${_prefix}ctxFontSize'),
      _prefs.getInt('${_prefix}wordColor'),
      _prefs.getInt('${_prefix}orpColor'),
      _prefs.getInt('${_prefix}bgColor'),
      _prefs.getInt('${_prefix}hlColor'),
      _prefs.getDouble('${_prefix}vPos'),
      _prefs.getDouble('${_prefix}hPos'),
      _prefs.getString('${_prefix}font'),
      _prefs.getBool('${_prefix}showOrp'),
      _prefs.getBool('${_prefix}smartTiming'),
      _prefs.getBool('${_prefix}rampUp'),
      _prefs.getBool('${_prefix}showFocusLine'),
      _prefs.getBool('${_prefix}focusLineProgress'),
      _prefs.getString('${_prefix}orpIndicator'),
    ]);
    state = DisplaySettings(
      wpm: results[0] as int? ?? AppConstants.defaultWpm,
      fontSize: results[1] as double? ?? AppConstants.defaultFontSize,
      contextFontSize:
          results[2] as double? ?? AppConstants.defaultContextFontSize,
      wordColorValue: results[3] as int? ?? AppConstants.defaultWordColor,
      orpColorValue: results[4] as int? ?? AppConstants.defaultOrpColor,
      backgroundColorValue:
          results[5] as int? ?? AppConstants.defaultBackgroundColor,
      highlightColorValue:
          results[6] as int? ?? AppConstants.defaultHighlightColor,
      verticalPosition:
          results[7] as double? ?? AppConstants.defaultVerticalPosition,
      horizontalPosition: results[8] as double? ?? 0.5,
      fontFamily: results[9] as String? ?? AppConstants.defaultFontFamily,
      showOrpHighlight: results[10] as bool? ?? true,
      smartTiming: results[11] as bool? ?? true,
      rampUp: results[12] as bool? ?? true,
      showFocusLine: results[13] as bool? ?? true,
      focusLineShowsProgress: results[14] as bool? ?? true,
      orpIndicator: _parseOrpIndicator(results[15] as String?),
    );
  }

  static OrpIndicatorStyle _parseOrpIndicator(String? raw) {
    if (raw == null) return OrpIndicatorStyle.notch;
    for (final s in OrpIndicatorStyle.values) {
      if (s.name == raw) return s;
    }
    return OrpIndicatorStyle.notch;
  }

  Future<void> update(DisplaySettings Function(DisplaySettings) updater) async {
    state = updater(state);
    await _save();
    _notifySyncChanged();
  }

  /// Apply settings coming from a sync pull. Persists to SharedPreferences
  /// without re-triggering a sync push (the remote already has these values).
  Future<void> applyFromRemote(DisplaySettings synced) async {
    state = synced;
    await _save();
  }

  /// Flip the reader's word + background colours to match [brightness]. Called
  /// from [ThemeModeNotifier] when the resolved theme brightness changes so
  /// the reader palette stays consistent with the app chrome. Other colours
  /// (ORP accent, highlight) stay put — those are intentional choices that
  /// aren't tied to light/dark.
  Future<void> applyBrightness(Brightness brightness) async {
    final palette =
        brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
    state = state.copyWith(
      wordColorValue: palette.onSurface.toARGB32(),
      backgroundColorValue: palette.background.toARGB32(),
    );
    await _save();
    _notifySyncChanged();
  }

  void _notifySyncChanged() {
    final ref = _ref;
    if (ref == null) return;
    final notifier = ref.read(librarySyncProvider.notifier);
    notifier.markSettingsDirty();
    notifier.schedulePush();
  }

  Future<void> _save() async {
    await Future.wait([
      _prefs.setInt('${_prefix}wpm', state.wpm),
      _prefs.setDouble('${_prefix}fontSize', state.fontSize),
      _prefs.setDouble('${_prefix}ctxFontSize', state.contextFontSize),
      _prefs.setInt('${_prefix}wordColor', state.wordColorValue),
      _prefs.setInt('${_prefix}orpColor', state.orpColorValue),
      _prefs.setInt('${_prefix}bgColor', state.backgroundColorValue),
      _prefs.setInt('${_prefix}hlColor', state.highlightColorValue),
      _prefs.setDouble('${_prefix}vPos', state.verticalPosition),
      _prefs.setDouble('${_prefix}hPos', state.horizontalPosition),
      _prefs.setString('${_prefix}font', state.fontFamily),
      _prefs.setBool('${_prefix}showOrp', state.showOrpHighlight),
      _prefs.setBool('${_prefix}smartTiming', state.smartTiming),
      _prefs.setBool('${_prefix}rampUp', state.rampUp),
      _prefs.setBool('${_prefix}showFocusLine', state.showFocusLine),
      _prefs.setBool(
          '${_prefix}focusLineProgress', state.focusLineShowsProgress),
      _prefs.setString('${_prefix}orpIndicator', state.orpIndicator.name),
    ]);
  }
}

final displaySettingsProvider =
    StateNotifierProvider<DisplaySettingsNotifier, DisplaySettings>((ref) {
  return DisplaySettingsNotifier(SharedPreferencesAsync(), ref);
});
