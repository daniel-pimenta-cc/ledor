import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../providers/rsvp_engine_provider.dart';
import 'bookmarks_list.dart';
import 'reader_sheet_shell.dart';

/// Mobile bottom-sheet host for the bookmarks list. The tablet-landscape
/// equivalent lives in [ReaderSidePanel] so the user keeps the reader
/// surface visible while browsing.
class BookmarksListSheet extends ConsumerWidget {
  final String bookId;

  const BookmarksListSheet({required this.bookId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rsvpEngineProvider(bookId));
    final settings = state.displaySettings;
    final l10n = AppLocalizations.of(context)!;

    return ReaderSheetShell(
      settings: settings,
      title: l10n.bookmarksTitle,
      bodyBuilder: (context, scrollController) => Expanded(
        child: BookmarksList(
          bookId: bookId,
          settings: settings,
          scrollController: scrollController,
          onAfterSeek: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
