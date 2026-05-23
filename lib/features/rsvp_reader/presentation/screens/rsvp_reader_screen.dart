import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/selected_book_provider.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../core/utils/bookmark_snippet.dart';
import '../../../../core/utils/platform_capabilities.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import '../../domain/entities/rsvp_state.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/display_settings_provider.dart';
import '../providers/reader_side_panel_provider.dart';
import '../providers/rsvp_engine_provider.dart';
import '../widgets/bookmark_create_dialog.dart';
import '../widgets/bookmarks_list_sheet.dart';
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

  /// Set to true after we drained [readerPendingSeekProvider] /
  /// [readerPendingActionProvider]. Subsequent rebuilds skip the
  /// post-frame consume so we don't try to mutate a provider that's
  /// already null/none.
  bool _pendingConsumed = false;

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
    // Snapshot the notifier before super.dispose() — `ref` becomes
    // invalid the moment the element is unmounted, so reading it inside
    // the microtask below would throw "Cannot use ref after disposed".
    final sidePanelNotifier =
        ref.read(readerSidePanelProvider.notifier);
    // Defer the reset so a replacement reader (e.g. master-detail
    // selection flip) has a chance to set its own panel mode first —
    // the microtask still runs before the next frame.
    Future.microtask(() {
      sidePanelNotifier.state = ReaderSidePanelMode.none;
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

    // Consume any deferred action (set by the library long-press menu /
    // global bookmarks screen before navigating to the reader). The work
    // is scheduled in a post-frame callback so we don't mutate providers
    // during build (Riverpod forbids that). _pendingConsumed gates this
    // to a single run per mount so subsequent rebuilds don't re-schedule.
    if (!_pendingConsumed) {
      _pendingConsumed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final pendingSeek = ref.read(readerPendingSeekProvider);
        if (pendingSeek != null) {
          ref.read(readerPendingSeekProvider.notifier).state = null;
          ref
              .read(rsvpEngineProvider(widget.bookId).notifier)
              .seekToWord(pendingSeek);
        }
        final pending = ref.read(readerPendingActionProvider);
        if (pending == ReaderPendingAction.openBookmarks) {
          ref.read(readerPendingActionProvider.notifier).state =
              ReaderPendingAction.none;
          // _openBookmarks reads the latest state itself.
          final latestState =
              ref.read(rsvpEngineProvider(widget.bookId));
          final engineNotifier =
              ref.read(rsvpEngineProvider(widget.bookId).notifier);
          _openBookmarks(latestState, engineNotifier);
        }
      });
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
      // The reader doesn't host a text field of its own — when the IME
      // appears it's coming from the bookmark-create dialog (an Overlay),
      // and we don't want every `SelectableText.rich` paragraph in the
      // ScrollablePositionedList to reflow underneath it. Reflowing is
      // expensive enough to feel like jank on Android.
      resizeToAvoidBottomInset: false,
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
    void onRange(WordToken first, WordToken last) =>
        _onBookmarkRange(state, engine, first, last);
    switch (state.mode) {
      case ReaderMode.rsvp:
        return _buildRsvpArea(state, engine);
      case ReaderMode.scroll:
        return ContextScrollView(
          key: const ValueKey('scroll'),
          bookId: widget.bookId,
          onBookmarkRange: onRange,
        );
      case ReaderMode.ereader:
        return ContextScrollView(
          key: const ValueKey('ereader'),
          bookId: widget.bookId,
          showHighlight: false,
          onBookmarkRange: onRange,
        );
      case ReaderMode.tts:
        // TTS uses the same scroll-with-highlight surface as ReaderMode.scroll.
        // The engine's onProgress callback drives the highlight position.
        return ContextScrollView(
          key: const ValueKey('tts'),
          bookId: widget.bookId,
          onBookmarkRange: onRange,
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
      onLongPress: () {
        final word = state.currentWord;
        if (word == null || word.isImage) return;
        _onBookmarkRange(state, engine, word, word);
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

  void _openBookmarks(RsvpState state, RsvpEngineNotifier engine) {
    if (state.isPlaying) engine.pause();
    if (_useSidePanel(context)) {
      final current = ref.read(readerSidePanelProvider);
      ref.read(readerSidePanelProvider.notifier).state =
          current == ReaderSidePanelMode.bookmarks
              ? ReaderSidePanelMode.none
              : ReaderSidePanelMode.bookmarks;
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookmarksListSheet(bookId: widget.bookId),
    );
  }

  /// Called when the user confirms a bookmark — either through the OS
  /// text-selection toolbar (range / single word in scroll/ereader/TTS)
  /// or via a direct long-press on the focused word in RSVP mode (single
  /// word, [first] == [last]).
  ///
  /// Pauses playback so the bookmark anchors to the word the user
  /// actually targeted, builds a snippet from the surrounding context,
  /// and persists it via [BookmarksController].
  Future<void> _onBookmarkRange(
    RsvpState state,
    RsvpEngineNotifier engine,
    WordToken first,
    WordToken last,
  ) async {
    if (state.isPlaying) engine.pause();

    final chapterIdx = first.chapterIndex;
    String? snippet;
    if (chapterIdx >= 0 && chapterIdx < state.chapters.length) {
      final chapter = state.chapters[chapterIdx];
      final firstLocal = chapter.tokens
          .indexWhere((t) => t.globalIndex == first.globalIndex);
      final lastLocal = chapter.tokens
          .indexWhere((t) => t.globalIndex == last.globalIndex);
      if (firstLocal >= 0) {
        snippet = lastLocal > firstLocal
            ? buildBookmarkRangeSnippet(
                tokens: chapter.tokens,
                firstLocalIndex: firstLocal,
                lastLocalIndex: lastLocal,
              )
            : buildBookmarkSnippet(
                tokens: chapter.tokens,
                targetLocalIndex: firstLocal,
              );
      }
    }

    final result = await showBookmarkDialog(
      context: context,
      snippet: snippet,
    );
    if (result == null) return;
    if (!mounted) return;

    final isRange = last.globalIndex != first.globalIndex;
    await ref.read(bookmarksControllerProvider(widget.bookId)).create(
          globalWordIndex: first.globalIndex,
          chapterIndex: chapterIdx,
          endGlobalWordIndex: isRange ? last.globalIndex : null,
          endChapterIndex: isRange ? last.chapterIndex : null,
          label: result.label,
          contextSnippet: snippet,
        );

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(l10n.bookmarkCreatedToast),
        duration: const Duration(seconds: 2),
      ),
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
            onPressed: () => _openBookmarks(state, engine),
            tooltip: l10n.bookmarksTooltip,
            icon: Icon(
              Icons.bookmark_outline,
              color: state.displaySettings.wordColor,
            ),
          ),
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
