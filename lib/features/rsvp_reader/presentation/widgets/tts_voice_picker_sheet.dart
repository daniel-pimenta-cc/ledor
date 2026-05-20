import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../data/services/tts_backend.dart';
import '../providers/display_settings_provider.dart';
import '../providers/tts_backend_provider.dart';
import '../providers/tts_voices_provider.dart';

/// Bottom sheet that lists every voice the TTS backend reports, grouped by
/// locale. Tapping a row selects the voice; tapping the small play icon
/// auditions the voice without committing the change.
///
/// Carries a small "preview" responsibility: it speaks a sample phrase
/// directly through the backend (not through the engine), so the user can
/// audition a voice before locking it in. The temporary voice change is
/// rolled back to the persisted selection on close.
class TtsVoicePickerSheet extends ConsumerStatefulWidget {
  const TtsVoicePickerSheet({super.key});

  @override
  ConsumerState<TtsVoicePickerSheet> createState() =>
      _TtsVoicePickerSheetState();
}

class _TtsVoicePickerSheetState extends ConsumerState<TtsVoicePickerSheet> {
  /// Voice the picker is currently auditioning. Resets when the user
  /// commits (taps a row) or dismisses the sheet.
  TtsVoice? _previewing;

  @override
  void dispose() {
    // If the user closed without committing, stop any in-flight preview so
    // the speech doesn't leak past the sheet's life.
    final backend = ref.read(ttsBackendProvider);
    backend.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(displaySettingsProvider);
    final voicesAsync = ref.watch(ttsVoicesProvider);
    final currentVoiceName = settings.ttsVoiceName;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
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
                    l10n.ttsVoicePickerTitle,
                    style: TextStyle(
                      color: settings.wordColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: voicesAsync.when(
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
                  error: (err, _) =>
                      _ErrorState(error: err.toString(), settings: settings),
                  data: (voices) {
                    if (voices.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.ttsNoVoicesAvailable,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: settings.wordColor.withAlpha(180),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }
                    return _VoiceList(
                      voices: voices,
                      scrollController: scrollController,
                      currentVoiceName: currentVoiceName,
                      previewingName: _previewing?.name,
                      wordColor: settings.wordColor,
                      orpColor: settings.orpColor,
                      onPreview: (voice) => _previewVoice(voice, l10n),
                      onSelect: (voice) => _selectVoice(voice),
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

  Future<void> _previewVoice(TtsVoice voice, AppLocalizations l10n) async {
    setState(() => _previewing = voice);
    final backend = ref.read(ttsBackendProvider);
    try {
      await backend.stop();
      await backend.setLanguage(voice.locale);
      await backend.setVoice(voice);
      await backend.speak(l10n.ttsVoicePreviewSample);
    } catch (_) {
      // Backend will emit an error via its callback chain; we don't need
      // to surface twice.
    }
  }

  void _selectVoice(TtsVoice voice) {
    ref.read(displaySettingsProvider.notifier).update(
          (s) => s.copyWith(
            ttsVoiceName: voice.name,
            ttsLanguage: voice.locale,
          ),
        );
    Navigator.of(context).pop();
  }
}

class _VoiceList extends StatelessWidget {
  final List<TtsVoice> voices;
  final ScrollController scrollController;
  final String? currentVoiceName;
  final String? previewingName;
  final Color wordColor;
  final Color orpColor;
  final ValueChanged<TtsVoice> onPreview;
  final ValueChanged<TtsVoice> onSelect;

  const _VoiceList({
    required this.voices,
    required this.scrollController,
    required this.currentVoiceName,
    required this.previewingName,
    required this.wordColor,
    required this.orpColor,
    required this.onPreview,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Voices arrive already sorted by locale, then name (see voices provider).
    // Insert a header before each new locale.
    final items = <Widget>[];
    String? lastLocale;
    for (final voice in voices) {
      if (voice.locale != lastLocale) {
        items.add(_LocaleHeader(locale: voice.locale, color: wordColor));
        lastLocale = voice.locale;
      }
      items.add(
        _VoiceTile(
          voice: voice,
          isCurrent: voice.name == currentVoiceName,
          isPreviewing: voice.name == previewingName,
          wordColor: wordColor,
          orpColor: orpColor,
          onPreview: () => onPreview(voice),
          onTap: () => onSelect(voice),
        ),
      );
    }
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: items,
    );
  }
}

class _LocaleHeader extends StatelessWidget {
  final String locale;
  final Color color;

  const _LocaleHeader({required this.locale, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        AppSpacing.md,
        20,
        AppSpacing.xs,
      ),
      child: Text(
        locale.toUpperCase(),
        style: TextStyle(
          color: color.withAlpha(140),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _VoiceTile extends StatelessWidget {
  final TtsVoice voice;
  final bool isCurrent;
  final bool isPreviewing;
  final Color wordColor;
  final Color orpColor;
  final VoidCallback onPreview;
  final VoidCallback onTap;

  const _VoiceTile({
    required this.voice,
    required this.isCurrent,
    required this.isPreviewing,
    required this.wordColor,
    required this.orpColor,
    required this.onPreview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fg = isCurrent ? orpColor : wordColor;
    return ListTile(
      dense: true,
      selected: isCurrent,
      selectedTileColor: orpColor.withAlpha(28),
      leading: Icon(
        isCurrent ? Icons.radio_button_checked : Icons.radio_button_off,
        size: 18,
        color: isCurrent ? orpColor : wordColor.withAlpha(120),
      ),
      title: Text(
        voice.name,
        style: TextStyle(
          color: fg,
          fontSize: 14,
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: voice.gender == null
          ? null
          : Text(
              voice.gender!,
              style: TextStyle(
                color: wordColor.withAlpha(140),
                fontSize: 11,
              ),
            ),
      trailing: IconButton(
        tooltip: l10n.ttsVoicePreviewTooltip,
        icon: Icon(
          isPreviewing ? Icons.graphic_eq : Icons.play_circle_outline,
          size: 22,
          color: isPreviewing ? orpColor : wordColor.withAlpha(180),
        ),
        onPressed: onPreview,
      ),
      onTap: onTap,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final dynamic settings;

  const _ErrorState({required this.error, required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ink = settings.wordColor as Color;
    // Spd-say not installed is the only error we have a canned UI for;
    // anything else gets the raw message so the user can paste it into
    // a bug report.
    final detail = error.contains('spd-say')
        ? l10n.ttsLinuxRequiresSpeechDispatcher
        : error;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: ink.withAlpha(160),
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(color: ink.withAlpha(200), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
