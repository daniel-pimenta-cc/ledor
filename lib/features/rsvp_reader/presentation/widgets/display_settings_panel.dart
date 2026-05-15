import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/display_settings.dart';
import '../providers/display_settings_provider.dart';
import '../providers/rsvp_engine_provider.dart';
import 'wpm_selector.dart';

part 'display_settings_widgets.dart';

/// All display + reading settings rendered as a single Column.
///
/// Used by both [ReaderSettingsSheet] (bottom sheet) and [SettingsScreen]
/// (full screen). When [bookId] is provided, edits also propagate to the
/// running engine for live preview; otherwise only persisted settings update.
class DisplaySettingsPanel extends ConsumerWidget {
  final String? bookId;

  const DisplaySettingsPanel({this.bookId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(displaySettingsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildReadingSection(ref, l10n, settings),
        const SizedBox(height: 16),
        _buildDisplaySection(ref, l10n, settings),
      ],
    );
  }

  /// Reading-behavior section: speed, ORP highlight, smart timing, ramp-up,
  /// focus line.
  Widget _buildReadingSection(
    WidgetRef ref,
    AppLocalizations l10n,
    DisplaySettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(label: l10n.settingsReading, color: settings.wordColor),

        // Default WPM — same capsule + preset drawer used in the reader
        // transport row, so the muscle memory carries over.
        _SettingRow(
          label: l10n.settingsDefaultSpeed,
          labelColor: settings.wordColor,
          child: WpmSelector(
            settings: settings,
            currentWpm: settings.wpm,
            labelFormatter: l10n.wordsPerMinute,
            onChanged: (v) =>
                _update(ref, bookId, (s) => s.copyWith(wpm: v)),
          ),
        ),
        const SizedBox(height: 12),

        _SwitchRow(
          label: l10n.settingsOrpHighlight,
          subtitle: l10n.settingsOrpHighlightDesc,
          labelColor: settings.wordColor,
          value: settings.showOrpHighlight,
          onChanged: (v) => _update(
              ref, bookId, (s) => s.copyWith(showOrpHighlight: v)),
        ),
        const SizedBox(height: 8),

        _SwitchRow(
          label: l10n.settingsSmartTiming,
          subtitle: l10n.settingsSmartTimingDesc,
          labelColor: settings.wordColor,
          value: settings.smartTiming,
          onChanged: (v) =>
              _update(ref, bookId, (s) => s.copyWith(smartTiming: v)),
        ),
        const SizedBox(height: 8),

        _SwitchRow(
          label: l10n.settingsRampUp,
          subtitle: l10n.settingsRampUpDesc,
          labelColor: settings.wordColor,
          value: settings.rampUp,
          onChanged: (v) =>
              _update(ref, bookId, (s) => s.copyWith(rampUp: v)),
        ),
        const SizedBox(height: 8),

        _SwitchRow(
          label: l10n.settingsFocusLine,
          subtitle: l10n.settingsFocusLineDesc,
          labelColor: settings.wordColor,
          value: settings.showFocusLine,
          onChanged: (v) =>
              _update(ref, bookId, (s) => s.copyWith(showFocusLine: v)),
        ),
        if (settings.showFocusLine) ...[
          const SizedBox(height: 8),
          _SwitchRow(
            label: l10n.settingsFocusLineProgress,
            subtitle: l10n.settingsFocusLineProgressDesc,
            labelColor: settings.wordColor,
            value: settings.focusLineShowsProgress,
            onChanged: (v) => _update(ref, bookId,
                (s) => s.copyWith(focusLineShowsProgress: v)),
          ),
        ],
        const SizedBox(height: 12),

        _OrpIndicatorRow(
          label: l10n.settingsOrpIndicator,
          subtitle: l10n.settingsOrpIndicatorDesc,
          labelColor: settings.wordColor,
          orpColor: settings.orpColor,
          backgroundColor: settings.backgroundColor,
          value: settings.orpIndicator,
          labelFor: (style) => switch (style) {
            OrpIndicatorStyle.notch => l10n.orpIndicatorNotch,
            OrpIndicatorStyle.lineAbove => l10n.orpIndicatorLineAbove,
            OrpIndicatorStyle.linesAround => l10n.orpIndicatorLinesAround,
            OrpIndicatorStyle.off => l10n.orpIndicatorOff,
          },
          onChanged: (v) =>
              _update(ref, bookId, (s) => s.copyWith(orpIndicator: v)),
        ),
        const SizedBox(height: 8),

        _SwitchRow(
          label: l10n.settingsProgressSlider,
          subtitle: l10n.settingsProgressSliderDesc,
          labelColor: settings.wordColor,
          value: settings.showProgressSlider,
          onChanged: (v) => _update(
              ref, bookId, (s) => s.copyWith(showProgressSlider: v)),
        ),
        const SizedBox(height: 12),

        _TimeRemainingRow(
          label: l10n.settingsTimeRemaining,
          subtitle: l10n.settingsTimeRemainingDesc,
          labelColor: settings.wordColor,
          orpColor: settings.orpColor,
          value: settings.timeRemainingMode,
          labelFor: (mode) => switch (mode) {
            TimeRemainingMode.total => l10n.timeRemainingTotal,
            TimeRemainingMode.chapter => l10n.timeRemainingChapter,
            TimeRemainingMode.off => l10n.timeRemainingOff,
          },
          onChanged: (v) =>
              _update(ref, bookId, (s) => s.copyWith(timeRemainingMode: v)),
        ),
      ],
    );
  }

  /// Appearance section: font sizes, positions, colors, font family.
  Widget _buildDisplaySection(
    WidgetRef ref,
    AppLocalizations l10n,
    DisplaySettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(label: l10n.settingsDisplay, color: settings.wordColor),

        _SettingRow(
          label: l10n.settingsFontSizeRsvp,
          labelColor: settings.wordColor,
          child: _PlusMinusControl(
            value: settings.fontSize.round(),
            color: settings.wordColor,
            onDecrease: () => _update(
                ref,
                bookId,
                (s) => s.copyWith(
                    fontSize: (s.fontSize - 2).clamp(
                        AppConstants.minFontSize, AppConstants.maxFontSize))),
            onIncrease: () => _update(
                ref,
                bookId,
                (s) => s.copyWith(
                    fontSize: (s.fontSize + 2).clamp(
                        AppConstants.minFontSize, AppConstants.maxFontSize))),
          ),
        ),
        const SizedBox(height: 12),

        _SettingRow(
          label: l10n.settingsFontSizeContext,
          labelColor: settings.wordColor,
          child: _PlusMinusControl(
            value: settings.contextFontSize.round(),
            color: settings.wordColor,
            onDecrease: () => _update(
                ref,
                bookId,
                (s) => s.copyWith(
                    contextFontSize: (s.contextFontSize - 1).clamp(
                        AppConstants.minContextFontSize,
                        AppConstants.maxContextFontSize))),
            onIncrease: () => _update(
                ref,
                bookId,
                (s) => s.copyWith(
                    contextFontSize: (s.contextFontSize + 1).clamp(
                        AppConstants.minContextFontSize,
                        AppConstants.maxContextFontSize))),
          ),
        ),
        const SizedBox(height: 16),

        _SettingRow(
          label: l10n.settingsVerticalPosition,
          labelColor: settings.wordColor,
          child: SizedBox(
            width: 160,
            child: Slider(
              value: settings.verticalPosition,
              min: 0.1,
              max: 0.9,
              onChanged: (v) => _update(
                  ref, bookId, (s) => s.copyWith(verticalPosition: v)),
            ),
          ),
        ),
        const SizedBox(height: 8),

        _SettingRow(
          label: l10n.settingsHorizontalPosition,
          labelColor: settings.wordColor,
          child: SizedBox(
            width: 160,
            child: Slider(
              value: settings.horizontalPosition,
              min: 0.2,
              max: 0.8,
              onChanged: (v) => _update(
                  ref, bookId, (s) => s.copyWith(horizontalPosition: v)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        _ColorRow(
          label: l10n.settingsWordColor,
          labelColor: settings.wordColor,
          color: settings.wordColor,
          onChanged: (c) => _update(
              ref, bookId, (s) => s.copyWith(wordColorValue: c.toARGB32())),
        ),
        const SizedBox(height: 12),
        _ColorRow(
          label: l10n.settingsOrpColor,
          labelColor: settings.wordColor,
          color: settings.orpColor,
          onChanged: (c) => _update(
              ref, bookId, (s) => s.copyWith(orpColorValue: c.toARGB32())),
        ),
        const SizedBox(height: 12),
        _ColorRow(
          label: l10n.settingsBackgroundColor,
          labelColor: settings.wordColor,
          color: settings.backgroundColor,
          onChanged: (c) => _update(ref, bookId,
              (s) => s.copyWith(backgroundColorValue: c.toARGB32())),
        ),
        const SizedBox(height: 12),
        _ColorRow(
          label: l10n.settingsHighlightColor,
          labelColor: settings.wordColor,
          color: settings.highlightColor,
          onChanged: (c) => _update(ref, bookId,
              (s) => s.copyWith(highlightColorValue: c.toARGB32())),
        ),
        const SizedBox(height: 16),

        _FontSelector(
          label: l10n.settingsFont,
          currentValue: settings.fontFamily,
          labelColor: settings.wordColor,
          backgroundColor: settings.backgroundColor,
          onChanged: (v) =>
              _update(ref, bookId, (s) => s.copyWith(fontFamily: v)),
        ),
      ],
    );
  }

  /// Updates persisted settings; if [bookId] is set, also pushes the new
  /// settings to the running engine so the change is visible immediately.
  static void _update(
    WidgetRef ref,
    String? bookId,
    DisplaySettings Function(DisplaySettings) updater,
  ) {
    ref.read(displaySettingsProvider.notifier).update(updater);
    if (bookId != null) {
      final newSettings = ref.read(displaySettingsProvider);
      ref
          .read(rsvpEngineProvider(bookId).notifier)
          .updateDisplaySettings((_) => newSettings);
    }
  }
}
