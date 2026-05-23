import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/display_settings_provider.dart';
import '../providers/tts_voices_provider.dart';

/// Bottom sheet that lists the TTS engines the backend reports and lets
/// the user pick one. Selecting commits to [DisplaySettings.ttsEngineId]
/// and closes the sheet.
///
/// Engine lists are typically short (1–4 entries on Android, ~3 on
/// Linux), so a single scrollable list is plenty — no locale grouping
/// like the voice picker.
class TtsEnginePickerSheet extends ConsumerWidget {
  const TtsEnginePickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(displaySettingsProvider);
    final enginesAsync = ref.watch(ttsEnginesProvider);
    final currentEngine = settings.ttsEngineId;

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.25,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Color.lerp(settings.backgroundColor, Colors.white, 0.08),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: settings.wordColor.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.ttsEnginePickerTitle,
                    style: TextStyle(
                      color: settings.wordColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.ttsEnginePickerSubtitle,
                    style: TextStyle(
                      color: settings.wordColor.withAlpha(160),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: enginesAsync.when(
                  loading: () => Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: settings.wordColor.withAlpha(160),
                      ),
                    ),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        err.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: settings.wordColor.withAlpha(180),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  data: (engines) {
                    if (engines.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.ttsEnginePickerEmpty,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: settings.wordColor.withAlpha(180),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [
                        _EngineTile(
                          title: l10n.ttsEnginePickerSystemDefault,
                          subtitle: null,
                          isSelected: currentEngine == null,
                          wordColor: settings.wordColor,
                          orpColor: settings.orpColor,
                          onTap: () => _select(ref, null),
                        ),
                        for (final engine in engines)
                          _EngineTile(
                            title: engine.displayName,
                            subtitle: engine.id == engine.displayName
                                ? null
                                : engine.id,
                            isSelected: currentEngine == engine.id,
                            wordColor: settings.wordColor,
                            orpColor: settings.orpColor,
                            onTap: () => _select(ref, engine.id),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _select(WidgetRef ref, String? engineId) {
    ref.read(displaySettingsProvider.notifier).update(
          (s) => s.copyWith(ttsEngineId: engineId),
        );
    Navigator.of(ref.context).pop();
  }
}

class _EngineTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isSelected;
  final Color wordColor;
  final Color orpColor;
  final VoidCallback onTap;

  const _EngineTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.wordColor,
    required this.orpColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isSelected ? orpColor : wordColor;
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: orpColor.withAlpha(28),
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        size: 18,
        color: isSelected ? orpColor : wordColor.withAlpha(120),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: fg,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: TextStyle(
                  color: wordColor.withAlpha(140),
                  fontSize: 11,
                ),
              ),
            ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 2,
      ),
      onTap: onTap,
    );
  }
}
