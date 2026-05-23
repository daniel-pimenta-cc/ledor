import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/constants/app_constants.dart';
import '../../../../../../l10n/generated/app_localizations.dart';
import '../../../../domain/entities/display_settings.dart';
import '../settings_category.dart';
import '../settings_controls.dart';
import '../settings_section_header.dart';

/// "RSVP Display" section — RSVP scope. Focus letter highlight + indicator
/// style, focus line, RSVP font size, word position on screen, and word/orp
/// colours.
class RsvpDisplaySection extends ConsumerWidget {
  final String? bookId;
  final DisplaySettings settings;
  final bool isActive;

  const RsvpDisplaySection({
    required this.bookId,
    required this.settings,
    this.isActive = false,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(
          category: SettingsCategory.rsvpDisplay,
          label: l10n.settingsSectionRsvpDisplay,
          wordColor: settings.wordColor,
          orpColor: settings.orpColor,
          isActive: isActive,
        ),

        SwitchRow(
          label: l10n.settingsOrpHighlight,
          subtitle: l10n.settingsOrpHighlightDesc,
          labelColor: settings.wordColor,
          value: settings.showOrpHighlight,
          onChanged: (v) => updateDisplaySetting(
              ref, bookId, (s) => s.copyWith(showOrpHighlight: v)),
        ),
        const SizedBox(height: 12),

        OrpIndicatorRow(
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
          onChanged: (v) => updateDisplaySetting(
              ref, bookId, (s) => s.copyWith(orpIndicator: v)),
        ),
        const SizedBox(height: 12),

        SwitchRow(
          label: l10n.settingsFocusLine,
          subtitle: l10n.settingsFocusLineDesc,
          labelColor: settings.wordColor,
          value: settings.showFocusLine,
          onChanged: (v) => updateDisplaySetting(
              ref, bookId, (s) => s.copyWith(showFocusLine: v)),
        ),
        if (settings.showFocusLine) ...[
          const SizedBox(height: 8),
          SwitchRow(
            label: l10n.settingsFocusLineProgress,
            subtitle: l10n.settingsFocusLineProgressDesc,
            labelColor: settings.wordColor,
            value: settings.focusLineShowsProgress,
            onChanged: (v) => updateDisplaySetting(ref, bookId,
                (s) => s.copyWith(focusLineShowsProgress: v)),
          ),
        ],
        const SizedBox(height: 12),

        SettingRow(
          label: l10n.settingsFontSizeRsvp,
          labelColor: settings.wordColor,
          child: PlusMinusControl(
            value: settings.fontSize.round(),
            color: settings.wordColor,
            onDecrease: () => updateDisplaySetting(
                ref,
                bookId,
                (s) => s.copyWith(
                    fontSize: (s.fontSize - 2).clamp(
                        AppConstants.minFontSize, AppConstants.maxFontSize))),
            onIncrease: () => updateDisplaySetting(
                ref,
                bookId,
                (s) => s.copyWith(
                    fontSize: (s.fontSize + 2).clamp(
                        AppConstants.minFontSize, AppConstants.maxFontSize))),
          ),
        ),
        const SizedBox(height: 12),

        SettingRow(
          label: l10n.settingsVerticalPosition,
          labelColor: settings.wordColor,
          child: SizedBox(
            width: 160,
            child: Slider(
              value: settings.verticalPosition,
              min: 0.1,
              max: 0.9,
              onChanged: (v) => updateDisplaySetting(
                  ref, bookId, (s) => s.copyWith(verticalPosition: v)),
            ),
          ),
        ),
        const SizedBox(height: 4),

        SettingRow(
          label: l10n.settingsHorizontalPosition,
          labelColor: settings.wordColor,
          child: SizedBox(
            width: 160,
            child: Slider(
              value: settings.horizontalPosition,
              min: 0.2,
              max: 0.8,
              onChanged: (v) => updateDisplaySetting(
                  ref, bookId, (s) => s.copyWith(horizontalPosition: v)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        ColorRow(
          label: l10n.settingsWordColor,
          labelColor: settings.wordColor,
          color: settings.wordColor,
          onChanged: (c) => updateDisplaySetting(ref, bookId,
              (s) => s.copyWith(wordColorValue: c.toARGB32())),
        ),
        const SizedBox(height: 12),
        ColorRow(
          label: l10n.settingsOrpColor,
          labelColor: settings.wordColor,
          color: settings.orpColor,
          onChanged: (c) => updateDisplaySetting(ref, bookId,
              (s) => s.copyWith(orpColorValue: c.toARGB32())),
        ),
      ],
    );
  }
}
