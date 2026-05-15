import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/reader_side_panel_provider.dart';
import '../providers/rsvp_engine_provider.dart';
import 'chapter_list_sheet.dart';
import 'controls_meta_row.dart';
import 'controls_progress_row.dart';
import 'controls_shell.dart';
import 'controls_transport_row.dart';
import 'seek_slider.dart';
import 'wpm_selector.dart';

/// Reader playback dock.
class RsvpControls extends ConsumerStatefulWidget {
  final String bookId;

  const RsvpControls({required this.bookId, super.key});

  @override
  ConsumerState<RsvpControls> createState() => _RsvpControlsState();
}

class _RsvpControlsState extends ConsumerState<RsvpControls> {
  bool _wpmPickerOpen = false;

  void _toggleWpmPicker() {
    HapticFeedback.selectionClick();
    setState(() => _wpmPickerOpen = !_wpmPickerOpen);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rsvpEngineProvider(widget.bookId));
    final engine = ref.read(rsvpEngineProvider(widget.bookId).notifier);
    final l10n = AppLocalizations.of(context)!;
    final settings = state.displaySettings;

    return ControlsShell(
      backgroundColor: settings.backgroundColor,
      borderColor: settings.wordColor.withAlpha(24),
      child: AnimatedSize(
        duration: AppDurations.base,
        curve: AppCurves.emphasized,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ControlsMetaRow(state: state, l10n: l10n),
            if (settings.showProgressSlider) ...[
              const SizedBox(height: AppSpacing.xs),
              SeekSlider(
                state: state,
                onChanged: engine.seekToWord,
              ),
            ],
            ControlsProgressRow(
              state: state,
              l10n: l10n,
              onOpenChapters: () => _openChapters(context),
            ),
            const SizedBox(height: AppSpacing.md),
            ControlsTransportRow(
              state: state,
              l10n: l10n,
              wpmPickerOpen: _wpmPickerOpen,
              onPlayPause: () {
                HapticFeedback.mediumImpact();
                engine.togglePlayPause();
              },
              onSkipBack: () {
                HapticFeedback.lightImpact();
                engine.skipBackward();
              },
              onSkipForward: () {
                HapticFeedback.lightImpact();
                engine.skipForward();
              },
              onWpmDown: () {
                HapticFeedback.selectionClick();
                engine.decreaseWpm();
              },
              onWpmUp: () {
                HapticFeedback.selectionClick();
                engine.increaseWpm();
              },
              onWpmLabelTap: _toggleWpmPicker,
            ),
            if (_wpmPickerOpen)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: WpmPresetRow(
                  settings: settings,
                  currentWpm: state.wpm,
                  presets: buildWpmPresets(state.wpm),
                  formatLabel: l10n.wordsPerMinute,
                  onSelect: (value) {
                    HapticFeedback.selectionClick();
                    engine.setWpm(value);
                    setState(() => _wpmPickerOpen = false);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openChapters(BuildContext context) {
    if (context.isTablet && context.isLandscape) {
      final current = ref.read(readerSidePanelProvider);
      ref.read(readerSidePanelProvider.notifier).state =
          current == ReaderSidePanelMode.chapters
              ? ReaderSidePanelMode.none
              : ReaderSidePanelMode.chapters;
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ChapterListSheet(bookId: widget.bookId),
      );
    }
  }
}
