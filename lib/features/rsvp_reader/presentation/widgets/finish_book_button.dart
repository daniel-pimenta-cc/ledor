import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../book_library/presentation/providers/book_library_provider.dart';
import '../../domain/entities/display_settings.dart';
import '../providers/rsvp_engine_provider.dart';

/// Reader-only action that lets the user declare a book finished without
/// scrolling through acknowledgments/refs/colophon at the tail of an EPUB.
/// On confirm, the book's progress is jumped to the end (via
/// [markBookAsReadProvider]) and the user is taken to the completion
/// screen to rate and optionally share.
///
/// Hosted by [ReaderSettingsSheet] (bottom sheet) and [ReaderSidePanel]
/// (tablet) — kept out of [DisplaySettingsPanel] so the standalone
/// Settings screen stays purely about display options.
class FinishBookButton extends ConsumerWidget {
  final String bookId;
  final DisplaySettings settings;

  /// Invoked right after the user confirms but before navigation. The host
  /// uses this to close the sheet/panel that surfaced the button.
  final VoidCallback? onBeforeNavigate;

  const FinishBookButton({
    required this.bookId,
    required this.settings,
    this.onBeforeNavigate,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accent = settings.orpColor;
    final ink = settings.wordColor;

    return OutlinedButton.icon(
      onPressed: () => _confirmAndFinish(context, ref, l10n),
      icon: Icon(Icons.emoji_events_outlined, size: 20, color: accent),
      label: Text(
        l10n.finishBook,
        style: TextStyle(
          color: ink,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: settings.backgroundColor,
        side: BorderSide(color: accent.withAlpha(120), width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _confirmAndFinish(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.finishBookConfirmTitle),
        content: Text(l10n.finishBookConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l10n.finishBookConfirmCta),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Pause the engine first so a half-second of background play doesn't
    // race the upcoming progress write.
    final engine = ref.read(rsvpEngineProvider(bookId).notifier);
    final state = ref.read(rsvpEngineProvider(bookId));
    if (state.isPlaying) engine.pause();

    await ref.read(markBookAsReadProvider(bookId))();

    onBeforeNavigate?.call();
    if (!context.mounted) return;
    unawaited(context.push('/books/$bookId/completion'));
  }
}
