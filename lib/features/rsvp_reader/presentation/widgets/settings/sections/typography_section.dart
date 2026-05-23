import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../l10n/generated/app_localizations.dart';
import '../../../../domain/entities/display_settings.dart';
import '../settings_category.dart';
import '../settings_controls.dart';
import '../settings_section_header.dart';

/// "Typography & Background" section — all modes. Font family (used by both
/// the RSVP word display and the flowing-text views) and the background
/// colour of the reader surface.
class TypographySection extends ConsumerWidget {
  final String? bookId;
  final DisplaySettings settings;
  final bool isActive;

  const TypographySection({
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
          category: SettingsCategory.typography,
          label: l10n.settingsSectionTypography,
          wordColor: settings.wordColor,
          orpColor: settings.orpColor,
          isActive: isActive,
        ),

        FontSelector(
          label: l10n.settingsFont,
          currentValue: settings.fontFamily,
          labelColor: settings.wordColor,
          backgroundColor: settings.backgroundColor,
          onChanged: (v) => updateDisplaySetting(
              ref, bookId, (s) => s.copyWith(fontFamily: v)),
        ),
        const SizedBox(height: 12),

        ColorRow(
          label: l10n.settingsBackgroundColor,
          labelColor: settings.wordColor,
          color: settings.backgroundColor,
          onChanged: (c) => updateDisplaySetting(ref, bookId,
              (s) => s.copyWith(backgroundColorValue: c.toARGB32())),
        ),
      ],
    );
  }
}
