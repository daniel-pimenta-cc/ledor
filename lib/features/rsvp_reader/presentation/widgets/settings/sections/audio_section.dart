import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../l10n/generated/app_localizations.dart';
import '../../../../data/services/tts_backend.dart';
import '../../../../domain/entities/display_settings.dart';
import '../../../providers/tts_voices_provider.dart';
import '../../tts_engine_picker_sheet.dart';
import '../../tts_voice_picker_sheet.dart';
import '../settings_category.dart';
import '../settings_controls.dart';
import '../settings_section_header.dart';

/// "Audio" section — TTS scope. Engine picker (when ≥2 are available),
/// voice picker, and pitch slider. Speech rate stays on the reader's
/// transport row (the rate capsule) so it's always reachable while listening.
class AudioSection extends ConsumerWidget {
  final String? bookId;
  final DisplaySettings settings;
  final bool isActive;

  const AudioSection({
    required this.bookId,
    required this.settings,
    this.isActive = false,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final enginesAsync = ref.watch(ttsEnginesProvider);
    final engines = enginesAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <TtsEngine>[],
    );
    final showEnginePicker = engines.length >= 2;
    // Skip the label lookup entirely when the row is hidden — saves a
    // for-loop on every panel rebuild (which fires on every slider tick).
    final currentEngineLabel = showEnginePicker
        ? _engineLabel(
            engines: engines,
            currentId: settings.ttsEngineId,
            systemDefault: l10n.ttsEnginePickerSystemDefault,
          )
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(
          category: SettingsCategory.audio,
          label: l10n.settingsSectionAudio,
          wordColor: settings.wordColor,
          orpColor: settings.orpColor,
          isActive: isActive,
        ),

        if (showEnginePicker) ...[
          TtsEngineRow(
            label: l10n.settingsTtsEngine,
            subtitle: l10n.settingsTtsEngineDesc,
            labelColor: settings.wordColor,
            orpColor: settings.orpColor,
            currentLabel: currentEngineLabel,
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const TtsEnginePickerSheet(),
              );
            },
          ),
          const SizedBox(height: 12),
        ],

        TtsVoiceRow(
          label: l10n.settingsTtsVoice,
          subtitle: l10n.settingsTtsVoiceDesc,
          labelColor: settings.wordColor,
          orpColor: settings.orpColor,
          currentVoiceName: settings.ttsVoiceName,
          currentLocale: settings.ttsLanguage,
          fallbackLabelFor: l10n.ttsVoiceFallbackLabel,
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const TtsVoicePickerSheet(),
            );
          },
        ),
        const SizedBox(height: 12),

        MultiplierSliderRow(
          label: l10n.settingsTtsPitch,
          subtitle: l10n.settingsTtsPitchDesc,
          labelColor: settings.wordColor,
          orpColor: settings.orpColor,
          value: settings.ttsPitch,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          labelFor: (v) => '${formatMultiplier(v)}x',
          onChanged: (v) => updateDisplaySetting(
              ref, bookId, (s) => s.copyWith(ttsPitch: v)),
        ),
      ],
    );
  }

  String _engineLabel({
    required List<TtsEngine> engines,
    required String? currentId,
    required String systemDefault,
  }) {
    if (currentId == null) return systemDefault;
    for (final e in engines) {
      if (e.id == currentId) return e.displayName;
    }
    // currentId came from Drive sync but the local device doesn't have
    // that engine installed — the backend will fall back to the system
    // default at speak time, so the label should say so rather than
    // surface the raw package name (e.g. "com.samsung.SMT").
    return systemDefault;
  }
}
