import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/responsive_defaults.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../core/utils/font_mapper.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../book_library/data/services/inline_image_storage.dart';
import '../../../epub_import/domain/entities/chapter.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import '../../domain/entities/display_settings.dart';
import '../providers/rsvp_engine_provider.dart';
import '../screens/fullscreen_image_screen.dart';
import 'rsvp_paragraph_view.dart';

/// A scroll item is one of: a chapter header, a paragraph of words, or an
/// inline image (occupies its own row, taps to fullscreen).
class _ScrollItem {
  final String? chapterTitle; // non-null → header item
  final List<WordToken>? tokens; // non-null → paragraph item
  final WordToken? image; // non-null → image item

  const _ScrollItem.header(this.chapterTitle)
      : tokens = null,
        image = null;
  const _ScrollItem.paragraph(this.tokens)
      : chapterTitle = null,
        image = null;
  const _ScrollItem.image(this.image)
      : chapterTitle = null,
        tokens = null;

  bool get isHeader => chapterTitle != null;
  bool get isImage => image != null;
}

/// Shows the full book text across all chapters.
///
/// When [showHighlight] is true (default), the current word is highlighted and
/// users can tap any word to seek. When false, renders plain text only — used
/// for the "ereader" reading mode.
class ContextScrollView extends ConsumerStatefulWidget {
  final String bookId;
  final bool showHighlight;

  const ContextScrollView({
    required this.bookId,
    this.showHighlight = true,
    super.key,
  });

  @override
  ConsumerState<ContextScrollView> createState() => _ContextScrollViewState();
}

class _ContextScrollViewState extends ConsumerState<ContextScrollView> {
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();

  late final ValueNotifier<int> _highlightIndex;

  List<_ScrollItem> _items = [];
  bool _didInitialScroll = false;
  bool _isUserScrolling = false;
  int _lastBuiltChapterCount = 0;

  // Lock pins the focused word in place: scrolling moves the viewport but
  // doesn't advance the highlight, and releasing the scroll doesn't seek
  // the engine. Recenter (right-side overlay) jumps the viewport back to
  // the pinned word.
  bool _isLocked = false;
  bool _isHighlightVisible = true;

  // Attached to the highlighted word's container in [_ParagraphWidget]. Used
  // by [_scrollToHighlight] to measure the word's true on-screen position and
  // center it precisely — avoids fraction estimates that drift in long
  // paragraphs with uneven line wrapping.
  final GlobalKey _highlightedWordKey = GlobalKey();

  // Smooth scroll tracking
  List<WordToken> _allTokens = [];
  Map<int, int> _tokenPositionMap = {}; // globalIndex → index in _allTokens
  List<int> _paragraphBoundaries = []; // indices in _allTokens (sorted)
  List<int> _sentenceBoundaries = []; // indices in _allTokens (sorted)
  double _smoothedVelocity = 0.0;
  DateTime _lastHighlightUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final state = ref.read(rsvpEngineProvider(widget.bookId));
    _highlightIndex = ValueNotifier(state.globalWordIndex);
    _buildItems(state.chapters);
    _positionsListener.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void dispose() {
    _positionsListener.itemPositions.removeListener(_onPositionsChanged);
    _highlightIndex.dispose();
    super.dispose();
  }

  /// Single-pass build of scroll items + flat token index.
  ///
  /// Walks every token exactly once and, as it goes, splits paragraphs via
  /// [WordToken.paragraphIndex], appends to `_allTokens`, records sentence
  /// boundaries, and emits `_ScrollItem.paragraph` whenever a paragraph
  /// closes. The previous implementation grouped paragraphs into a throwaway
  /// `List<List<WordToken>>` first and then walked the tokens a second time
  /// to fill the index — two passes and an extra allocation per paragraph.
  void _buildItems(List<Chapter> chapters) {
    final items = <_ScrollItem>[];
    final allTokens = <WordToken>[];
    final tokenPositionMap = HashMap<int, int>();
    final paragraphBoundaries = <int>[];
    final sentenceBoundaries = <int>[];

    for (final chapter in chapters) {
      items.add(_ScrollItem.header(chapter.title));
      final tokens = chapter.tokens;
      if (tokens.isEmpty) continue;

      List<WordToken>? currentParagraph;
      int currentParaIdx = -1;

      for (final token in tokens) {
        if (token.isImage) {
          // Close the text paragraph first so the image gets its own
          // scroll row. Reset paragraph state — the next text token starts
          // a fresh paragraph.
          if (currentParagraph != null && currentParagraph.isNotEmpty) {
            items.add(_ScrollItem.paragraph(currentParagraph));
          }
          currentParagraph = null;
          currentParaIdx = -1;
          items.add(_ScrollItem.image(token));

          final pos = allTokens.length;
          paragraphBoundaries.add(pos);
          sentenceBoundaries.add(pos);
          tokenPositionMap[token.globalIndex] = pos;
          allTokens.add(token);
          continue;
        }

        if (token.paragraphIndex != currentParaIdx) {
          if (currentParagraph != null) {
            items.add(_ScrollItem.paragraph(currentParagraph));
          }
          currentParagraph = <WordToken>[];
          currentParaIdx = token.paragraphIndex;
          final paraStart = allTokens.length;
          paragraphBoundaries.add(paraStart);
          sentenceBoundaries.add(paraStart);
        }
        final pos = allTokens.length;
        if (currentParagraph!.isNotEmpty &&
            _isSentenceEnd(currentParagraph.last.text)) {
          sentenceBoundaries.add(pos);
        }
        currentParagraph.add(token);
        tokenPositionMap[token.globalIndex] = pos;
        allTokens.add(token);
      }
      if (currentParagraph != null) {
        items.add(_ScrollItem.paragraph(currentParagraph));
      }
    }

    _items = items;
    _allTokens = allTokens;
    _tokenPositionMap = tokenPositionMap;
    _paragraphBoundaries = paragraphBoundaries;
    _sentenceBoundaries = sentenceBoundaries;
    _lastBuiltChapterCount = chapters.length;
  }

  void _onPositionsChanged() {
    // Always recompute visibility of the highlight so the recenter overlay
    // can react even while locked (locked scrolls don't run the rest).
    _refreshHighlightVisibility();

    if (_isLocked) return;
    if (!_isUserScrolling || _items.isEmpty || _allTokens.isEmpty) return;

    // Throttle updates for smooth movement
    final now = DateTime.now();
    if (now.difference(_lastHighlightUpdate).inMilliseconds < 80) return;
    _lastHighlightUpdate = now;

    final velocity = _smoothedVelocity.abs();
    if (velocity < 0.3) return;

    // Check if highlight is still in visible area; catch up if not
    final visiblePositions = _positionsListener.itemPositions.value;
    final highlightItemIdx = _findItemIndex(_highlightIndex.value);
    final highlightVisible =
        visiblePositions.any((p) => p.index == highlightItemIdx);

    if (!highlightVisible) {
      _catchUpToVisible(visiblePositions);
      return;
    }

    final direction = _smoothedVelocity > 0 ? 1 : -1;
    final currentPos = _tokenPositionMap[_highlightIndex.value] ?? 0;
    int newPos;

    if (velocity > 25) {
      // Fast scroll → jump by paragraph
      newPos =
          _findNextBoundary(currentPos, direction, _paragraphBoundaries);
    } else if (velocity > 8) {
      // Medium scroll → jump by sentence
      newPos =
          _findNextBoundary(currentPos, direction, _sentenceBoundaries);
    } else {
      // Slow scroll → word by word
      newPos = currentPos + direction;
    }

    newPos = newPos.clamp(0, _allTokens.length - 1);
    _highlightIndex.value = _allTokens[newPos].globalIndex;
  }

  void _syncToEngine() {
    if (_isLocked) return;
    ref
        .read(rsvpEngineProvider(widget.bookId).notifier)
        .seekToWord(_highlightIndex.value);
  }

  void _refreshHighlightVisibility() {
    if (_items.isEmpty) return;
    final highlightItemIdx = _findItemIndex(_highlightIndex.value);
    final visible = _positionsListener.itemPositions.value
        .any((p) => p.index == highlightItemIdx);
    if (visible != _isHighlightVisible) {
      setState(() => _isHighlightVisible = visible);
    }
  }

  void _toggleLock() {
    setState(() => _isLocked = !_isLocked);
  }

  void _recenter() {
    _scrollToHighlight(_highlightIndex.value, animate: true);
  }

  void _onWordTap(WordToken token) {
    _highlightIndex.value = token.globalIndex;
    ref
        .read(rsvpEngineProvider(widget.bookId).notifier)
        .seekToWord(token.globalIndex);
  }

  void _openImageFullscreen(WordToken image, DisplaySettings settings) {
    // Move the engine cursor to the image we're inspecting so the reader
    // resumes from the right spot after closing the viewer.
    ref
        .read(rsvpEngineProvider(widget.bookId).notifier)
        .seekToWord(image.globalIndex);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FullscreenImageScreen(word: image, settings: settings),
    ));
  }

  /// Find the item index in _items that contains globalWordIndex.
  int _findItemIndex(int globalWordIndex) {
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.isImage) {
        if (item.image!.globalIndex == globalWordIndex) return i;
        continue;
      }
      if (!item.isHeader &&
          item.tokens != null &&
          item.tokens!.isNotEmpty &&
          globalWordIndex >= item.tokens!.first.globalIndex &&
          globalWordIndex <= item.tokens!.last.globalIndex) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rsvpEngineProvider(widget.bookId));

    // Rebuild item cache if chapters loaded or changed
    if (state.chapters.length != _lastBuiltChapterCount) {
      _buildItems(state.chapters);
      _didInitialScroll = false;
    }

    // Sync highlight from engine when not scrolling. Locked state pins the
    // visible word, so we ignore engine advances until the user unlocks.
    if (!_isUserScrolling && !_isLocked) {
      final newHighlight = state.globalWordIndex;
      if (_highlightIndex.value != newHighlight) {
        _highlightIndex.value = newHighlight;
        if (_didInitialScroll && _scrollController.isAttached) {
          _scrollToHighlight(newHighlight, animate: true);
        }
      }
    }

    final settings = state.displaySettings;

    if (_items.isEmpty) return const SizedBox.shrink();

    if (!_didInitialScroll) {
      _didInitialScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToHighlight(state.globalWordIndex, animate: false);
      });
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final maxReadableWidth = ResponsiveDefaults.readableMaxWidth(context);
    final sidePadding = context.deviceType == DeviceType.compact ? 24.0 : 32.0;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification) {
          if (notification.direction != ScrollDirection.idle) {
            _isUserScrolling = true;
          } else {
            _isUserScrolling = false;
            _smoothedVelocity = 0.0;
            _snapToEndIfAtBottom();
            _syncToEngine();
          }
        } else if (notification is ScrollUpdateNotification &&
            _isUserScrolling) {
          final delta = notification.scrollDelta ?? 0.0;
          _smoothedVelocity = _smoothedVelocity * 0.7 + delta * 0.3;
        }
        return false;
      },
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxReadableWidth),
              child: ScrollablePositionedList.builder(
        itemCount: _items.length,
        itemScrollController: _scrollController,
        itemPositionsListener: _positionsListener,
        initialScrollIndex: _findItemIndex(state.globalWordIndex),
        initialAlignment: AppConstants.contextFocusAlignment,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          top: screenHeight * (context.isTablet && context.isLandscape
              ? 0.22
              : 0.35),
          bottom: screenHeight *
              (context.isTablet && context.isLandscape ? 0.35 : 0.5),
          left: sidePadding,
          right: sidePadding,
        ),
        itemBuilder: (context, index) {
          final item = _items[index];

          if (item.isHeader) {
            return Padding(
              padding: const EdgeInsets.only(top: 32, bottom: 16),
              child: Text(
                item.chapterTitle!,
                style: GoogleFonts.getFont(
                  mapFontFamily(settings.fontFamily),
                  fontSize: settings.contextFontSize * 1.2,
                  color: settings.orpColor.withAlpha(200),
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          if (item.isImage) {
            return _InlineImageTile(
              word: item.image!,
              settings: settings,
              onTap: () => _openImageFullscreen(item.image!, settings),
            );
          }

          if (!widget.showHighlight) {
            return RsvpParagraphView(
              tokens: item.tokens!,
              currentGlobalIndex: -1,
              settings: settings,
              onWordTap: null,
            );
          }

          return ValueListenableBuilder<int>(
            valueListenable: _highlightIndex,
            builder: (context, currentHighlight, _) {
              return RsvpParagraphView(
                tokens: item.tokens!,
                currentGlobalIndex: currentHighlight,
                settings: settings,
                onWordTap: _onWordTap,
                highlightKey: _highlightedWordKey,
              );
            },
          );
        },
              ),
            ),
          ),
          if (widget.showHighlight)
            Positioned(
              right: 12,
              bottom: 12,
              child: _LockOverlay(
                isLocked: _isLocked,
                showRecenter: _isLocked && !_isHighlightVisible,
                wordColor: settings.wordColor,
                backgroundColor: settings.backgroundColor,
                onToggleLock: _toggleLock,
                onRecenter: _recenter,
              ),
            ),
        ],
      ),
    );
  }

  bool _isSentenceEnd(String word) {
    final trimmed = word.trimRight();
    return trimmed.endsWith('.') ||
        trimmed.endsWith('!') ||
        trimmed.endsWith('?');
  }

  /// Binary search for the next boundary in [direction] from [currentPos].
  int _findNextBoundary(
      int currentPos, int direction, List<int> boundaries) {
    if (boundaries.isEmpty) {
      return (currentPos + direction).clamp(0, _allTokens.length - 1);
    }

    // Find first boundary > currentPos
    int lo = 0, hi = boundaries.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (boundaries[mid] <= currentPos) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    if (direction > 0) {
      return lo < boundaries.length ? boundaries[lo] : _allTokens.length - 1;
    } else {
      final prevIdx = lo - 1;
      if (prevIdx >= 0 && boundaries[prevIdx] < currentPos) {
        return boundaries[prevIdx];
      } else if (prevIdx > 0) {
        return boundaries[prevIdx - 1];
      }
      return 0;
    }
  }

  /// Centers the highlighted word at [AppConstants.contextFocusAlignment] of
  /// the viewport.
  ///
  /// Strategy: ensure the target paragraph is in the render tree via the
  /// item-based scroll controller, then measure the highlighted word's
  /// actual render-box position (via [_highlightedWordKey]) and shift the
  /// underlying scroll offset so the word's centerline lands exactly on
  /// [focus]. We bypass [Scrollable.ensureVisible] because [WidgetSpan]
  /// placeholders interact unreliably with viewport reveal math — the
  /// fraction-based estimate was off in long paragraphs, and ensureVisible
  /// also missed the mark. Using the word's real bounds is the most direct.
  Future<void> _scrollToHighlight(int globalWordIndex,
      {required bool animate}) async {
    if (!_scrollController.isAttached) return;
    final targetItem = _findItemIndex(globalWordIndex);
    final focus = AppConstants.contextFocusAlignment;

    // Step 1: bring the paragraph into the render tree if it isn't already.
    // Aligning at `focus` keeps the visible jump small for nearby recenters.
    final inTree = _positionsListener.itemPositions.value
        .any((p) => p.index == targetItem);
    if (!inTree) {
      _scrollController.jumpTo(index: targetItem, alignment: focus);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scrollController.isAttached) return;
    }

    // Step 2: measure the word's true on-screen position and offset the
    // scroll by exactly the delta needed. The GlobalKey context is read
    // fresh here (after the mounted check) — the lints below cover the
    // async-gap analysis the analyzer can't follow.
    final ctx = _highlightedWordKey.currentContext;
    if (ctx != null) {
      // ignore: use_build_context_synchronously
      final wordBox = ctx.findRenderObject() as RenderBox?;
      final viewport =
          wordBox == null ? null : RenderAbstractViewport.maybeOf(wordBox);
      // ignore: use_build_context_synchronously
      final scrollable = Scrollable.maybeOf(ctx);
      if (wordBox != null &&
          wordBox.attached &&
          viewport != null &&
          scrollable != null) {
        final transform = wordBox.getTransformTo(viewport);
        final wordRect = MatrixUtils.transformRect(
          transform,
          Offset.zero & wordBox.size,
        );
        final viewportHeight = viewport.semanticBounds.height;
        final delta = wordRect.center.dy - viewportHeight * focus;
        final position = scrollable.position;
        final target = (position.pixels + delta)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
        if (animate) {
          await position.animateTo(
            target,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
          );
        } else {
          position.jumpTo(target);
        }
        return;
      }
    }

    // Fallback: render tree didn't yield a usable render box (rare). Plain
    // SPL scroll to the paragraph at [focus] is "close enough".
    if (animate) {
      await _scrollController.scrollTo(
        index: targetItem,
        duration: const Duration(milliseconds: 280),
        alignment: focus,
      );
    } else {
      _scrollController.jumpTo(index: targetItem, alignment: focus);
    }
  }

  void _snapToEndIfAtBottom() {
    if (_allTokens.isEmpty || _items.isEmpty) return;
    final lastGlobal = _allTokens.last.globalIndex;
    if (_highlightIndex.value == lastGlobal) return;
    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final lastItemIdx = _items.length - 1;
    final atBottom = positions.any(
      (p) => p.index == lastItemIdx && p.itemTrailingEdge <= 1.0,
    );
    if (atBottom) {
      _highlightIndex.value = lastGlobal;
    }
  }

  /// When the highlight falls off-screen, snap it to the visible area center.
  void _catchUpToVisible(Iterable<ItemPosition> visiblePositions) {
    const focusFraction = 0.4;
    final sorted = visiblePositions.toList()
      ..sort((a, b) {
        final aMid = (a.itemLeadingEdge + a.itemTrailingEdge) / 2;
        final bMid = (b.itemLeadingEdge + b.itemTrailingEdge) / 2;
        return (aMid - focusFraction)
            .abs()
            .compareTo((bMid - focusFraction).abs());
      });

    if (sorted.isNotEmpty && sorted.first.index < _items.length) {
      final item = _items[sorted.first.index];
      if (!item.isHeader && item.tokens != null && item.tokens!.isNotEmpty) {
        _highlightIndex.value = item.tokens!.first.globalIndex;
      }
    }
  }

}

/// Inline image row rendered inside the scroll view at the position where
/// the EPUB had an `<img>`. Tapping pushes the [FullscreenImageScreen] so
/// the reader can pinch-zoom and pan to inspect.
class _InlineImageTile extends StatelessWidget {
  final WordToken word;
  final DisplaySettings settings;
  final VoidCallback onTap;

  static const _storage = InlineImageStorage();
  static const double _maxHeight = 360;

  const _InlineImageTile({
    required this.word,
    required this.settings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rel = word.imageRelativePath;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Material(
          color: settings.backgroundColor.withAlpha(0),
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: _maxHeight,
                minHeight: 80,
              ),
              child: rel == null
                  ? _broken(l10n.imageMissing)
                  : FutureBuilder<String>(
                      future: _storage.resolveAbsolutePath(rel),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: settings.wordColor.withAlpha(140),
                              ),
                            ),
                          );
                        }
                        return Image.file(
                          File(snap.data!),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              _broken(l10n.imageMissing),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _broken(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined,
              color: settings.wordColor.withAlpha(140), size: 36),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
                color: settings.wordColor.withAlpha(160), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Floating pill in the bottom-right of the context view. Houses the lock
/// toggle and (when the focused word is off-screen while locked) the
/// recenter action. Visuals draw from [DisplaySettings] so they stay
/// consistent with the live theme preview, never from `Theme.of(context)`.
class _LockOverlay extends StatelessWidget {
  final bool isLocked;
  final bool showRecenter;
  final Color wordColor;
  final Color backgroundColor;
  final VoidCallback onToggleLock;
  final VoidCallback onRecenter;

  const _LockOverlay({
    required this.isLocked,
    required this.showRecenter,
    required this.wordColor,
    required this.backgroundColor,
    required this.onToggleLock,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pillBg = backgroundColor.withAlpha(220);
    final borderColor = wordColor.withAlpha(38);

    Widget pill(Widget child) => Container(
          decoration: BoxDecoration(
            color: pillBg,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(28),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: showRecenter
              ? Padding(
                  key: const ValueKey('recenter'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: pill(
                    IconButton(
                      tooltip: l10n.recenterHighlight,
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      onPressed: onRecenter,
                      icon: Icon(Icons.my_location, color: wordColor),
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('no-recenter')),
        ),
        pill(
          IconButton(
            tooltip: isLocked ? l10n.unlockHighlight : l10n.lockHighlight,
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            onPressed: onToggleLock,
            icon: Icon(
              isLocked ? Icons.lock : Icons.lock_open,
              color: isLocked ? wordColor : wordColor.withAlpha(170),
            ),
          ),
        ),
      ],
    );
  }
}
