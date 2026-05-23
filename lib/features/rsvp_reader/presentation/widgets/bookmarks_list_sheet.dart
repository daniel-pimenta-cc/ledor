import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../providers/rsvp_engine_provider.dart';
import 'bookmarks_list.dart';

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

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Color.lerp(settings.backgroundColor, Colors.white, 0.08),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: settings.wordColor.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.bookmarksTitle,
                    style: TextStyle(
                      color: settings.wordColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: BookmarksList(
                  bookId: bookId,
                  settings: settings,
                  scrollController: scrollController,
                  onAfterSeek: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
