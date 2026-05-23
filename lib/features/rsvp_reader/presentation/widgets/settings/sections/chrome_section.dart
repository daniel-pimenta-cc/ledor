import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../l10n/generated/app_localizations.dart';
import '../../../../domain/entities/display_settings.dart';
import '../settings_category.dart';
import '../settings_controls.dart';
import '../settings_section_header.dart';

/// "Reader Chrome" section — all modes. Controls that affect the reader's
/// surrounding UI (progress slider, time-remaining badge) rather than the
/// reading surface itself.
class ChromeSection extends ConsumerWidget {
  final String? bookId;
  final DisplaySettings settings;
  final bool isActive;

  const ChromeSection({
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
          category: SettingsCategory.chrome,
          label: l10n.settingsSectionChrome,
          wordColor: settings.wordColor,
          orpColor: settings.orpColor,
          isActive: isActive,
        ),

        SwitchRow(
          label: l10n.settingsProgressSlider,
          subtitle: l10n.settingsProgressSliderDesc,
          labelColor: settings.wordColor,
          value: settings.showProgressSlider,
          onChanged: (v) => updateDisplaySetting(
              ref, bookId, (s) => s.copyWith(showProgressSlider: v)),
        ),
        const SizedBox(height: 12),

        TimeRemainingRow(
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
          onChanged: (v) => updateDisplaySetting(
              ref, bookId, (s) => s.copyWith(timeRemainingMode: v)),
        ),
      ],
    );
  }
}
