import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/selected_book_provider.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../core/utils/platform_capabilities.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/rsvp_state.dart';
import '../providers/display_settings_provider.dart';
import '../providers/reader_side_panel_provider.dart';
import '../providers/rsvp_engine_provider.dart';
import '../widgets/context_scroll_view.dart';
import '../widgets/reader_mode_menu.dart';
import '../widgets/reader_settings_sheet.dart';
import '../widgets/reader_side_panel.dart';
import '../widgets/rsvp_controls.dart';
import '../widgets/rsvp_image_view.dart';
import '../widgets/rsvp_word_display.dart';

class RsvpReaderScreen extends ConsumerStatefulWidget {
  final String bookId;

  /// Optional override for the back button. When null, the reader uses
  /// `context.pop()` (standard route-based navigation). When provided, the
  /// reader calls this instead — used by the tablet-landscape master-detail
  /// host so the back button clears the selection in place instead of
  /// popping a non-existent route.
  final VoidCallback? onClose;

  const RsvpReaderScreen({
    required this.bookId,
    this.onClose,
    super.key,
  });

  @override
  ConsumerState<RsvpReaderScreen> createState() => _RsvpReaderScreenState();
}

class _RsvpReaderScreenState extends ConsumerState<RsvpReaderScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final FocusNode _shortcutsFocusNode = FocusNode(debugLabel: 'RsvpShortcuts');

  @override
  void initState() {
    super.initState();
    ref
        .read(rsvpEngineProvider(widget.bookId).notifier)
        .attachVsync(this);
    // Observer is only used to recover a stalled TTS stream when the OS
    // backgrounded the app. Cheap to register unconditionally — the
    // callback is a no-op for the RSVP/scroll/ereader path.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(rsvpEngineProvider(widget.bookId).notifier)
          .restartTtsIfStalled();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shortcutsFocusNode.dispose();
    // Reset side-panel state so switching between books doesn't keep a
    // panel open for an unrelated book.
    Future.microtask(() {
      if (mounted) return; // still mounted → another reader may need it
      ref.read(readerSidePanelProvider.notifier).state = ReaderSidePanelMode.none;
    });
    super.dispose();
  }

  bool _useSidePanel(BuildContext context) =>
      context.isTablet && context.isLandscape;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rsvpEngineProvider(widget.bookId));
    final engine = ref.read(rsvpEngineProvider(widget.bookId).notifier);

    ref.listen<RsvpState>(rsvpEngineProvider(widget.bookId), (prev, next) {
      if (prev != null && next.finishTicket > prev.finishTicket) {
        // Let the final frame settle (RSVP word display shows "last word")
        // before pushing the celebratory screen — feels less abrupt.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.push('/books/${widget.bookId}/completion');
        });
      }
    });

    // Surface TTS errors as a snackbar. The engine writes to ttsErrorProvider
    // when the backend reports a problem (e.g. spd-say missing on Linux).
    ref.listen<String?>(ttsErrorProvider, (prev, next) {
      if (next == null || next == prev) return;
      final l10n = AppLocalizations.of(context)!;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.ttsErrorPrefix(next)),
          duration: const Duration(seconds: 5),
        ),
      );
      // Clear the error so a future identical message still triggers.
      ref.read(ttsErrorProvider.notifier).state = null;
    });

    if (state.isLoading) {
      final settings = ref.watch(displaySettingsProvider);
      return Scaffold(backgroundColor: settings.backgroundColor);
    }

    final readerBody = SafeArea(
      child: Column(
        children: [
          _buildTopBar(state, engine),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppDurations.slow,
              switchInCurve: AppCurves.standard,
              switchOutCurve: AppCurves.standard,
              child: _buildModeArea(state, engine),
            ),
          ),
          if (state.mode != ReaderMode.ereader)
            RsvpControls(bookId: widget.bookId),
        ],
      ),
    );

    final wrappedReaderBody = PlatformCapabilities.isDesktop
        ? _wrapWithShortcuts(state, engine, readerBody)
        : readerBody;

    final useSidePanel = _useSidePanel(context);

    return Scaffold(
      backgroundColor: state.displaySettings.backgroundColor,
      body: useSidePanel
          ? Row(
              children: [
                Expanded(child: wrappedReaderBody),
                ReaderSidePanel(
                  bookId: widget.bookId,
                  settings: state.displaySettings,
                ),
              ],
            )
          : wrappedReaderBody,
    );
  }

  Widget _wrapWithShortcuts(
    RsvpState state,
    RsvpEngineNotifier engine,
    Widget child,
  ) {
    // CallbackShortcuts must be an ancestor of the focused Focus node:
    // key events bubble up from the primary focus through its ancestors, and
    // Shortcuts only fires when the event passes through it on the way up.
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space): engine.togglePlayPause,
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            () => engine.skipForward(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            () => engine.skipBackward(1),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
            () => engine.skipForward(AppConstants.skipWordCount),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
            () => engine.skipBackward(AppConstants.skipWordCount),
        const SingleActivator(LogicalKeyboardKey.arrowUp): engine.increaseWpm,
        const SingleActivator(LogicalKeyboardKey.arrowDown): engine.decreaseWpm,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (state.isPlaying) engine.pause();
          if (widget.onClose != null) {
            widget.onClose!();
          } else if (mounted) {
            context.pop();
          }
        },
        if (widget.onClose != null)
          const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
              ref.read(libraryPanelVisibleProvider.notifier).update((v) => !v),
      },
      child: Focus(
        focusNode: _shortcutsFocusNode,
        autofocus: true,
        child: child,
      ),
    );
  }

  Widget _buildModeArea(RsvpState state, RsvpEngineNotifier engine) {
    switch (state.mode) {
      case ReaderMode.rsvp:
        return _buildRsvpArea(state, engine);
      case ReaderMode.scroll:
        return ContextScrollView(
          key: const ValueKey('scroll'),
          bookId: widget.bookId,
        );
      case ReaderMode.ereader:
        return ContextScrollView(
          key: const ValueKey('ereader'),
          bookId: widget.bookId,
          showHighlight: false,
        );
      case ReaderMode.tts:
        // TTS uses the same scroll-with-highlight surface as ReaderMode.scroll.
        // The engine's onProgress callback drives the highlight position.
        return ContextScrollView(
          key: const ValueKey('tts'),
          bookId: widget.bookId,
        );
    }
  }

  Widget _buildRsvpArea(RsvpState state, RsvpEngineNotifier engine) {
    final word = state.currentWord;
    if (word != null && word.isImage) {
      return RsvpImageView(
        key: const ValueKey('rsvp-image'),
        word: word,
        settings: state.displaySettings,
        onContinue: engine.dismissImage,
      );
    }

    return GestureDetector(
      key: const ValueKey('rsvp'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.mediumImpact();
        engine.togglePlayPause();
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -200) {
          engine.skipForward();
        } else if (details.primaryVelocity! > 200) {
          engine.skipBackward();
        }
      },
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -200) {
          engine.increaseWpm();
        } else if (details.primaryVelocity! > 200) {
          engine.decreaseWpm();
        }
      },
      child: SizedBox.expand(
        child: Align(
          alignment:
              Alignment(0, (state.displaySettings.verticalPosition - 0.5) * 2),
          child: RsvpWordDisplay(
            word: state.currentWord,
            settings: state.displaySettings,
            progress: state.progress,
          ),
        ),
      ),
    );
  }

  void _openSettings(RsvpState state, RsvpEngineNotifier engine) {
    if (state.isPlaying) engine.pause();
    if (_useSidePanel(context)) {
      final current = ref.read(readerSidePanelProvider);
      ref.read(readerSidePanelProvider.notifier).state =
          current == ReaderSidePanelMode.settings
              ? ReaderSidePanelMode.none
              : ReaderSidePanelMode.settings;
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReaderSettingsSheet(bookId: widget.bookId),
    );
  }

  Widget _buildTopBar(RsvpState state, RsvpEngineNotifier engine) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // `onClose` is only injected by the master-detail host, so its presence
    // doubles as a "we're in the split-view" signal.
    final inMasterDetail = widget.onClose != null;
    final libraryVisible = inMasterDetail
        ? ref.watch(libraryPanelVisibleProvider)
        : false;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (state.isPlaying) engine.pause();
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                context.pop();
              }
            },
            icon:
                Icon(Icons.arrow_back, color: state.displaySettings.wordColor),
          ),
          if (inMasterDetail)
            IconButton(
              onPressed: () => ref
                  .read(libraryPanelVisibleProvider.notifier)
                  .update((v) => !v),
              tooltip: libraryVisible
                  ? l10n.hideLibraryPanel
                  : l10n.showLibraryPanel,
              icon: Icon(
                libraryVisible ? Icons.menu_open : Icons.menu,
                color: state.displaySettings.wordColor,
              ),
            ),
          Expanded(
            child: Text(
              state.currentChapterTitle ?? '',
              style: theme.textTheme.titleSmall?.copyWith(
                color: state.displaySettings.wordColor.withAlpha(200),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ReaderModeMenu(bookId: widget.bookId),
          IconButton(
            onPressed: () => _openSettings(state, engine),
            icon:
                Icon(Icons.tune, color: state.displaySettings.wordColor),
          ),
        ],
      ),
    );
  }
}
