import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/constants/app_constants.dart';
import '../../../../../../l10n/generated/app_localizations.dart';
import '../../../../domain/entities/display_settings.dart';
import '../settings_category.dart';
import '../settings_controls.dart';
import '../settings_section_header.dart';

/// "Reader View" section — scroll / ereader / TTS scope. Font size for the
/// flowing-text views and the highlight colour used by scroll & TTS.
class ReaderViewSection extends ConsumerWidget {
  final String? bookId;
  final DisplaySettings settings;
  final bool isActive;

  const ReaderViewSection({
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
          category: SettingsCategory.readerView,
          label: l10n.settingsSectionReaderView,
          wordColor: settings.wordColor,
          orpColor: settings.orpColor,
          isActive: isActive,
        ),

        SettingRow(
          label: l10n.settingsFontSizeContext,
          labelColor: settings.wordColor,
          child: PlusMinusControl(
            value: settings.contextFontSize.round(),
            color: settings.wordColor,
            onDecrease: () => updateDisplaySetting(
                ref,
                bookId,
                (s) => s.copyWith(
                    contextFontSize: (s.contextFontSize - 1).clamp(
                        AppConstants.minContextFontSize,
                        AppConstants.maxContextFontSize))),
            onIncrease: () => updateDisplaySetting(
                ref,
                bookId,
                (s) => s.copyWith(
                    contextFontSize: (s.contextFontSize + 1).clamp(
                        AppConstants.minContextFontSize,
                        AppConstants.maxContextFontSize))),
          ),
        ),
        const SizedBox(height: 12),

        ColorRow(
          label: l10n.settingsHighlightColor,
          labelColor: settings.wordColor,
          color: settings.highlightColor,
          onChanged: (c) => updateDisplaySetting(ref, bookId,
              (s) => s.copyWith(highlightColorValue: c.toARGB32())),
        ),
      ],
    );
  }
}
