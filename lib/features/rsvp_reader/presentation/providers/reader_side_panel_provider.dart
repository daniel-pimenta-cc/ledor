import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which auxiliary panel is visible in the reader's tablet-landscape layout.
/// On compact / portrait layouts this is unused — settings, chapters, and
/// bookmarks still come up as bottom sheets.
enum ReaderSidePanelMode { none, settings, chapters, bookmarks }

final readerSidePanelProvider =
    StateProvider<ReaderSidePanelMode>((ref) => ReaderSidePanelMode.none);
