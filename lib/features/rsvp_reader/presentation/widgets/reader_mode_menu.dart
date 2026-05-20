import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/platform_capabilities.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/display_settings.dart';
import '../../domain/entities/rsvp_state.dart';
import '../providers/rsvp_engine_provider.dart';

/// Top-bar control that swaps between the four reader modes. Replaces the
/// older two-state IconButton (scroll ↔ ereader) so TTS can join the
/// existing set without growing the chrome.
///
/// Icon reflects the *current* mode at rest; tap opens a popup with a
/// radio-list of the four modes. Colours are derived from
/// `DisplaySettings` (live theme preview), never `Theme.of(context)`.
class ReaderModeMenu extends ConsumerWidget {
  final String bookId;

  const ReaderModeMenu({required this.bookId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rsvpEngineProvider(bookId));
    final settings = state.displaySettings;
    final l10n = AppLocalizations.of(context)!;
    // Map the engine-visible mode to the menu's "logical" mode. `scroll`
    // is the *paused* state of RSVP — to the user the two are one reading
    // experience, so we collapse them under the RSVP entry.
    final menuMode = _menuModeOf(state.mode);

    return PopupMenuButton<ReaderMode>(
      tooltip: l10n.readerModeMenuTooltip,
      icon: Icon(_iconFor(menuMode), color: settings.wordColor),
      color: _menuBackground(settings),
      surfaceTintColor: settings.backgroundColor,
      initialValue: menuMode,
      itemBuilder: (_) => [
        _item(ReaderMode.rsvp, Icons.bolt, l10n.readerModeRsvp, menuMode,
            settings),
        _item(ReaderMode.ereader, Icons.menu_book_outlined,
            l10n.readerModeEreader, menuMode, settings),
        if (PlatformCapabilities.supportsTts)
          _item(ReaderMode.tts, Icons.volume_up_outlined, l10n.readerModeTts,
              menuMode, settings),
      ],
      onSelected: (selected) {
        HapticFeedback.selectionClick();
        final engine = ref.read(rsvpEngineProvider(bookId).notifier);
        _switchTo(engine, state.mode, selected);
      },
    );
  }

  /// Collapses `ReaderMode.scroll` into `ReaderMode.rsvp` for menu display
  /// purposes. The two share a single user-facing identity ("RSVP reading
  /// experience"); `scroll` is just the paused half of it.
  static ReaderMode _menuModeOf(ReaderMode mode) {
    if (mode == ReaderMode.scroll) return ReaderMode.rsvp;
    return mode;
  }

  static IconData _iconFor(ReaderMode mode) {
    switch (mode) {
      case ReaderMode.rsvp:
      case ReaderMode.scroll:
        return Icons.bolt;
      case ReaderMode.ereader:
        return Icons.menu_book_outlined;
      case ReaderMode.tts:
        return Icons.volume_up_outlined;
    }
  }

  static Color _menuBackground(DisplaySettings s) {
    // Lift the reader background by ~6% toward white so the popup reads as
    // a surface above the body, without breaking the editorial palette.
    return Color.lerp(s.backgroundColor, Colors.white, 0.06)!;
  }

  PopupMenuItem<ReaderMode> _item(
    ReaderMode mode,
    IconData icon,
    String label,
    ReaderMode current,
    DisplaySettings settings,
  ) {
    final selected = mode == current;
    final accent = settings.orpColor;
    final ink = settings.wordColor;
    return PopupMenuItem<ReaderMode>(
      value: mode,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? accent : ink.withAlpha(120),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(icon, size: 20, color: selected ? accent : ink),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? accent : ink,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Performs the mode change. Each transition leaves the previous mode
  /// cleanly (engine handles its own bookkeeping) so callers don't need
  /// to micro-manage flushes / save-progress.
  static void _switchTo(
    RsvpEngineNotifier engine,
    ReaderMode from,
    ReaderMode to,
  ) {
    if (_menuModeOf(from) == _menuModeOf(to)) return;

    if (from == ReaderMode.ereader) {
      engine.exitEreaderMode();
    }
    if (from == ReaderMode.tts) {
      engine.exitTtsMode();
    }

    switch (to) {
      case ReaderMode.rsvp:
      case ReaderMode.scroll:
        // Selecting "RSVP" from the menu lands the user on `scroll`
        // (paused, ready to play). Tapping play then starts the ticker
        // — same flow as the previous IconButton.
        break;
      case ReaderMode.ereader:
        engine.enterEreaderMode();
        break;
      case ReaderMode.tts:
        engine.enterTtsMode();
        break;
    }
  }
}
