import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which auxiliary panel is visible in the reader's tablet-landscape layout.
/// On compact / portrait layouts this is unused — settings, chapters, and
/// bookmarks still come up as bottom sheets.
enum ReaderSidePanelMode { none, settings, chapters, bookmarks }

final readerSidePanelProvider =
    StateProvider<ReaderSidePanelMode>((ref) => ReaderSidePanelMode.none);

/// Deferred action the reader should run as soon as it finishes loading a
/// book. Set by callers from outside the reader (e.g. the library
/// long-press menu, the global bookmarks list) so the action survives the
/// navigation transition. The reader consumes it once and resets to
/// [ReaderPendingAction.none].
enum ReaderPendingAction { none, openBookmarks }

final readerPendingActionProvider =
    StateProvider<ReaderPendingAction>((ref) => ReaderPendingAction.none);

/// Word index the reader should seek to right after it loads. Sibling of
/// [readerPendingActionProvider] — kept separate so the two can be set
/// independently (e.g. "open bookmarks panel" without seeking, or "seek
/// only" from the global bookmarks list).
final readerPendingSeekProvider = StateProvider<int?>((ref) => null);
