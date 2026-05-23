import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../l10n/generated/app_localizations.dart';
import '../../../../domain/entities/display_settings.dart';
import '../../wpm_selector.dart';
import '../settings_category.dart';
import '../settings_controls.dart';
import '../settings_section_header.dart';

/// "Speed & Timing" section — RSVP scope. Default WPM, smart-timing
/// toggle, ramp-up toggle, and the structural sentence / chapter pause
/// multipliers.
class SpeedTimingSection extends ConsumerWidget {
  final String? bookId;
  final DisplaySettings settings;
  final bool isActive;

  const SpeedTimingSection({
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
          category: SettingsCategory.speedTiming,
          label: l10n.settingsSectionSpeedTiming,
          wordColor: settings.wordColor,
          orpColor: settings.orpColor,
          isActive: isActive,
        ),

        SettingRow(
          label: l10n.settingsDefaultSpeed,
          labelColor: settings.wordColor,
          child: WpmSelector(
            settings: settings,
            currentWpm: settings.wpm,
            labelFormatter: l10n.wordsPerMinute,
            onChanged: (v) => updateDisplaySetting(
                ref, bookId, (s) => s.copyWith(wpm: v)),
          ),
        ),
        const SizedBox(height: 12),

        SwitchRow(
          label: l10n.settingsSmartTiming,
          subtitle: l10n.settingsSmartTimingDesc,
          labelColor: settings.wordColor,
          value: settings.smartTiming,
          onChanged: (v) => updateDisplaySetting(
              ref, bookId, (s) => s.copyWith(smartTiming: v)),
        ),
        const SizedBox(height: 8),

        SwitchRow(
          label: l10n.settingsRampUp,
          subtitle: l10n.settingsRampUpDesc,
          labelColor: settings.wordColor,
          value: settings.rampUp,
          onChanged: (v) => updateDisplaySetting(
              ref, bookId, (s) => s.copyWith(rampUp: v)),
        ),
        const SizedBox(height: 12),

        MultiplierSliderRow(
          label: l10n.settingsSentencePause,
          subtitle: l10n.settingsSentencePauseDesc,
          labelColor: settings.wordColor,
          orpColor: settings.orpColor,
          value: settings.sentencePauseMultiplier,
          min: 1.0,
          max: 4.0,
          divisions: 12,
          labelFor: (v) => l10n.multiplierValue(formatMultiplier(v)),
          onChanged: (v) => updateDisplaySetting(
              ref, bookId, (s) => s.copyWith(sentencePauseMultiplier: v)),
        ),
        const SizedBox(height: 4),

        MultiplierSliderRow(
          label: l10n.settingsChapterPause,
          subtitle: l10n.settingsChapterPauseDesc,
          labelColor: settings.wordColor,
          orpColor: settings.orpColor,
          value: settings.chapterPauseMultiplier,
          min: 1.0,
          max: 4.0,
          divisions: 12,
          labelFor: (v) => l10n.multiplierValue(formatMultiplier(v)),
          onChanged: (v) => updateDisplaySetting(
              ref, bookId, (s) => s.copyWith(chapterPauseMultiplier: v)),
        ),
      ],
    );
  }
}
