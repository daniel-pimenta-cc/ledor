import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/voice_label_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../data/services/tts_backend.dart';
import '../providers/display_settings_provider.dart';
import '../providers/tts_backend_provider.dart';
import '../providers/tts_voices_provider.dart';

/// Bottom sheet that lists every voice the TTS backend reports.
///
/// Voice names from the platform engines are mostly useless to humans
/// (`en-gb-x-fis-network` on Android, `Samsung-text-to-speech-engine-en-us-female`
/// on Samsung), so the picker runs each voice through [enrichVoices] to
/// derive a friendly "Language (Region) · Gender N" label. The raw id
/// still shows up as a tiny caption for power users.
///
/// Navigation:
/// - Scope toggle: "Current language" (default — voices matching
///   `settings.ttsLanguage`'s primary language) vs "All languages".
/// - Search field: case-insensitive substring over the friendly label,
///   gender, raw id, and locale.
///
/// Tapping the row commits the voice. Tapping the play icon previews
/// without committing.
class TtsVoicePickerSheet extends ConsumerStatefulWidget {
  const TtsVoicePickerSheet({super.key});

  @override
  ConsumerState<TtsVoicePickerSheet> createState() =>
      _TtsVoicePickerSheetState();
}

enum _VoiceScope { current, all }

class _TtsVoicePickerSheetState extends ConsumerState<TtsVoicePickerSheet> {
  TtsVoice? _previewing;
  _VoiceScope _scope = _VoiceScope.current;
  String _query = '';

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    // If the user closed without committing, stop any in-flight preview so
    // the speech doesn't leak past the sheet's life.
    final backend = ref.read(ttsBackendProvider);
    backend.stop();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(displaySettingsProvider);
    final voicesAsync = ref.watch(ttsVoicesProvider);
    final uiLanguage = Localizations.localeOf(context).languageCode;
    final currentVoiceName = settings.ttsVoiceName;
    final currentLanguage = settings.ttsLanguage
        .split(RegExp(r'[-_]'))
        .first
        .toLowerCase();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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
              _DragHandle(color: settings.wordColor),
              _SheetHeader(
                title: l10n.ttsVoicePickerTitle,
                color: settings.wordColor,
              ),
              _ScopeAndSearch(
                scope: _scope,
                searchController: _searchController,
                hasQuery: _query.isNotEmpty,
                hintText: l10n.ttsVoicePickerSearchHint,
                currentScopeLabel: l10n.ttsVoicePickerScopeCurrent,
                allScopeLabel: l10n.ttsVoicePickerScopeAll,
                wordColor: settings.wordColor,
                orpColor: settings.orpColor,
                onScopeChanged: (s) => setState(() => _scope = s),
                onQueryChanged: (q) => setState(() => _query = q.trim()),
              ),
              const Divider(height: 1),
              Expanded(
                child: voicesAsync.when(
                  loading: () => _Loading(color: settings.wordColor),
                  error: (err, _) =>
                      _ErrorState(error: err.toString(), settings: settings),
                  data: (voices) {
                    if (voices.isEmpty) {
                      return _EmptyState(
                        message: l10n.ttsNoVoicesAvailable,
                        color: settings.wordColor,
                      );
                    }

                    final enriched = enrichVoices(voices, uiLanguage);
                    final filtered = _filter(
                      enriched,
                      scope: _scope,
                      query: _query,
                      currentLanguage: currentLanguage,
                    );

                    if (filtered.isEmpty) {
                      final friendlyLang = localeDisplayName(
                          settings.ttsLanguage, uiLanguage);
                      final message = _query.isNotEmpty
                          ? l10n.ttsVoicePickerNoMatches
                          : (_scope == _VoiceScope.current
                              ? l10n.ttsVoicePickerNoCurrentVoices(friendlyLang)
                              : l10n.ttsNoVoicesAvailable);
                      return _EmptyState(
                        message: message,
                        color: settings.wordColor,
                        actionLabel: _scope == _VoiceScope.current
                            ? l10n.ttsVoicePickerScopeAll
                            : null,
                        onAction: _scope == _VoiceScope.current
                            ? () => setState(() => _scope = _VoiceScope.all)
                            : null,
                      );
                    }

                    return _VoiceList(
                      enriched: filtered,
                      scrollController: scrollController,
                      currentVoiceName: currentVoiceName,
                      previewingName: _previewing?.name,
                      wordColor: settings.wordColor,
                      orpColor: settings.orpColor,
                      onPreview: (voice) => _previewVoice(voice, l10n),
                      onSelect: _selectVoice,
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

  List<EnrichedVoice> _filter(
    List<EnrichedVoice> voices, {
    required _VoiceScope scope,
    required String query,
    required String currentLanguage,
  }) {
    Iterable<EnrichedVoice> it = voices;
    if (scope == _VoiceScope.current) {
      it = it.where((v) => v.primaryLanguage == currentLanguage);
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      it = it.where((v) => v.searchHaystack.contains(q));
    }
    return it.toList();
  }
}

class _DragHandle extends StatelessWidget {
  final Color color;
  const _DragHandle({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: color.withAlpha(60),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _SheetHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ScopeAndSearch extends StatelessWidget {
  final _VoiceScope scope;
  final TextEditingController searchController;
  final bool hasQuery;
  final String hintText;
  final String currentScopeLabel;
  final String allScopeLabel;
  final Color wordColor;
  final Color orpColor;
  final ValueChanged<_VoiceScope> onScopeChanged;
  final ValueChanged<String> onQueryChanged;

  const _ScopeAndSearch({
    required this.scope,
    required this.searchController,
    required this.hasQuery,
    required this.hintText,
    required this.currentScopeLabel,
    required this.allScopeLabel,
    required this.wordColor,
    required this.orpColor,
    required this.onScopeChanged,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScopeToggle(
            scope: scope,
            currentLabel: currentScopeLabel,
            allLabel: allScopeLabel,
            wordColor: wordColor,
            orpColor: orpColor,
            onChanged: onScopeChanged,
          ),
          const SizedBox(height: 10),
          _SearchField(
            controller: searchController,
            hasText: hasQuery,
            hintText: hintText,
            wordColor: wordColor,
            onChanged: onQueryChanged,
          ),
        ],
      ),
    );
  }
}

class _ScopeToggle extends StatelessWidget {
  final _VoiceScope scope;
  final String currentLabel;
  final String allLabel;
  final Color wordColor;
  final Color orpColor;
  final ValueChanged<_VoiceScope> onChanged;

  const _ScopeToggle({
    required this.scope,
    required this.currentLabel,
    required this.allLabel,
    required this.wordColor,
    required this.orpColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Hand-rolled segmented control instead of SegmentedButton so the
    // styling stays consistent with the rest of the reader chrome (which
    // uses settings colours, not the global theme).
    return Container(
      decoration: BoxDecoration(
        color: wordColor.withAlpha(12),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: wordColor.withAlpha(40)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: _ScopeOption(
              label: currentLabel,
              selected: scope == _VoiceScope.current,
              wordColor: wordColor,
              orpColor: orpColor,
              onTap: () => onChanged(_VoiceScope.current),
            ),
          ),
          Expanded(
            child: _ScopeOption(
              label: allLabel,
              selected: scope == _VoiceScope.all,
              wordColor: wordColor,
              orpColor: orpColor,
              onTap: () => onChanged(_VoiceScope.all),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeOption extends StatelessWidget {
  final String label;
  final bool selected;
  final Color wordColor;
  final Color orpColor;
  final VoidCallback onTap;

  const _ScopeOption({
    required this.label,
    required this.selected,
    required this.wordColor,
    required this.orpColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? orpColor : Colors.transparent,
      borderRadius: AppRadius.borderSm,
      child: InkWell(
        borderRadius: AppRadius.borderSm,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : wordColor.withAlpha(220),
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final String hintText;
  final Color wordColor;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.hasText,
    required this.hintText,
    required this.wordColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: wordColor, fontSize: 14),
      cursorColor: wordColor,
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        hintStyle: TextStyle(
          color: wordColor.withAlpha(140),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.search,
          color: wordColor.withAlpha(160),
          size: 18,
        ),
        suffixIcon: !hasText
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                icon: Icon(
                  Icons.close,
                  color: wordColor.withAlpha(180),
                  size: 18,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: wordColor.withAlpha(10),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: wordColor.withAlpha(40)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: wordColor.withAlpha(40)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: wordColor.withAlpha(120)),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  final Color color;
  const _Loading({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: color.withAlpha(160),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.message,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.withAlpha(180),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VoiceList extends StatelessWidget {
  final List<EnrichedVoice> enriched;
  final ScrollController scrollController;
  final String? currentVoiceName;
  final String? previewingName;
  final Color wordColor;
  final Color orpColor;
  final ValueChanged<TtsVoice> onPreview;
  final ValueChanged<TtsVoice> onSelect;

  const _VoiceList({
    required this.enriched,
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
    // Group by localeGroupSortKey while preserving the input order. Items
    // arrive already sorted (locale first, name second) thanks to
    // ttsVoicesProvider, so a single pass with a "lastKey" sentinel is
    // enough.
    final items = <Widget>[];
    String? lastKey;
    for (final v in enriched) {
      if (v.label.localeGroupSortKey != lastKey) {
        items.add(_LocaleHeader(
          label: v.label.localeGroupName,
          color: wordColor,
        ));
        lastKey = v.label.localeGroupSortKey;
      }
      items.add(_VoiceTile(
        enriched: v,
        isCurrent: v.voice.name == currentVoiceName,
        isPreviewing: v.voice.name == previewingName,
        wordColor: wordColor,
        orpColor: orpColor,
        onPreview: () => onPreview(v.voice),
        onTap: () => onSelect(v.voice),
      ));
    }
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: items,
    );
  }
}

class _LocaleHeader extends StatelessWidget {
  final String label;
  final Color color;

  const _LocaleHeader({required this.label, required this.color});

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
        label,
        style: TextStyle(
          color: color.withAlpha(180),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _VoiceTile extends StatelessWidget {
  final EnrichedVoice enriched;
  final bool isCurrent;
  final bool isPreviewing;
  final Color wordColor;
  final Color orpColor;
  final VoidCallback onPreview;
  final VoidCallback onTap;

  const _VoiceTile({
    required this.enriched,
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
    final label = enriched.label;
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
        label.primary,
        style: TextStyle(
          color: fg,
          fontSize: 14,
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      subtitle: _buildSubtitle(label, wordColor),
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

  Widget? _buildSubtitle(FormattedVoiceLabel label, Color wordColor) {
    final secondary = label.secondary;
    final tech = label.techDetail;
    if (secondary == null && tech == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (secondary != null)
            Text(
              secondary,
              style: TextStyle(color: wordColor.withAlpha(180), fontSize: 12),
            ),
          if (tech != null)
            Padding(
              padding: EdgeInsets.only(top: secondary != null ? 2 : 0),
              child: Text(
                tech,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: wordColor.withAlpha(110),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
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
