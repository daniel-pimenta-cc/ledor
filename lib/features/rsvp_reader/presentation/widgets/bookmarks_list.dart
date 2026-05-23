import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/display_settings.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/rsvp_engine_provider.dart';
import 'bookmark_create_dialog.dart';

/// Live list of bookmarks for a book. Used by both the tablet-landscape
/// side panel and the mobile bottom sheet, so colours come from
/// [DisplaySettings] (reader chrome, follows the reader's theme) and the
/// host decides the surrounding decoration / header.
class BookmarksList extends ConsumerWidget {
  final String bookId;
  final DisplaySettings settings;
  final ScrollController? scrollController;

  /// Called after a bookmark is tapped (seek already issued) so the host
  /// can dismiss its sheet / collapse its panel. Null when the host wants
  /// to stay open after navigation.
  final VoidCallback? onAfterSeek;

  const BookmarksList({
    required this.bookId,
    required this.settings,
    this.scrollController,
    this.onAfterSeek,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBookmarks = ref.watch(bookmarksProvider(bookId));
    final state = ref.watch(rsvpEngineProvider(bookId));

    return asyncBookmarks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _EmptyState(settings: settings),
      data: (bookmarks) {
        if (bookmarks.isEmpty) {
          return _EmptyState(settings: settings);
        }
        return ListView.builder(
          controller: scrollController,
          itemCount: bookmarks.length,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          itemBuilder: (context, index) {
            final bookmark = bookmarks[index];
            final isCurrent = _isClose(
              bookmark.globalWordIndex,
              state.globalWordIndex,
            );
            return _BookmarkTile(
              bookId: bookId,
              bookmark: bookmark,
              settings: settings,
              isCurrent: isCurrent,
              totalWords: state.totalWords,
              onAfterSeek: onAfterSeek,
            );
          },
        );
      },
    );
  }

  /// Within 5 words counts as "current" — protects against off-by-one
  /// drift between the cursor and the bookmarked anchor.
  static bool _isClose(int a, int b) => (a - b).abs() <= 5;
}

class _BookmarkTile extends ConsumerWidget {
  final String bookId;
  final Bookmark bookmark;
  final DisplaySettings settings;
  final bool isCurrent;
  final int totalWords;
  final VoidCallback? onAfterSeek;

  const _BookmarkTile({
    required this.bookId,
    required this.bookmark,
    required this.settings,
    required this.isCurrent,
    required this.totalWords,
    required this.onAfterSeek,
  });

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showBookmarkDialog(
      context: context,
      snippet: bookmark.contextSnippet,
      initialLabel: bookmark.label,
      isEdit: true,
    );
    if (result == null) return;
    await ref
        .read(bookmarksControllerProvider(bookId))
        .updateLabel(bookmark.id, result.label);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.bookmarkDeleteConfirmTitle),
        content: Text(l10n.bookmarkDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.bookmarkActionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(bookmarksControllerProvider(bookId))
        .delete(bookmark.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final label = bookmark.effectiveLabel;
    final preview = label ?? bookmark.contextSnippet;
    final showsSnippetAsTitle = label == null && preview != null;

    final percent = totalWords > 0
        ? ((bookmark.globalWordIndex / totalWords) * 100).round().clamp(0, 100)
        : 0;
    final location = l10n.bookmarkLocationLabel(
      bookmark.chapterIndex + 1,
      percent,
    );

    return ListTile(
      dense: true,
      selected: isCurrent,
      selectedTileColor: settings.orpColor.withAlpha(30),
      leading: Icon(
        Icons.bookmark,
        color: isCurrent
            ? settings.orpColor
            : settings.orpColor.withAlpha(180),
      ),
      title: Text(
        preview ?? location,
        style: TextStyle(
          color: isCurrent ? settings.orpColor : settings.wordColor,
          fontSize: 14,
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
          fontStyle: showsSnippetAsTitle ? FontStyle.italic : FontStyle.normal,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        location,
        style: TextStyle(
          color: settings.wordColor.withAlpha(120),
          fontSize: 12,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      trailing: PopupMenuButton<_Action>(
        icon: Icon(Icons.more_vert, color: settings.wordColor.withAlpha(160)),
        onSelected: (action) {
          switch (action) {
            case _Action.edit:
              _edit(context, ref);
            case _Action.delete:
              _confirmDelete(context, ref);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _Action.edit,
            child: Text(l10n.bookmarkActionEdit),
          ),
          PopupMenuItem(
            value: _Action.delete,
            child: Text(l10n.bookmarkActionDelete),
          ),
        ],
      ),
      onTap: () {
        ref
            .read(rsvpEngineProvider(bookId).notifier)
            .seekToWord(bookmark.globalWordIndex);
        onAfterSeek?.call();
      },
    );
  }
}

enum _Action { edit, delete }

class _EmptyState extends StatelessWidget {
  final DisplaySettings settings;

  const _EmptyState({required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_outline,
            size: 64,
            color: settings.wordColor.withAlpha(80),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.bookmarkEmptyTitle,
            style: TextStyle(
              color: settings.wordColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.bookmarkEmptySubtitle,
            style: TextStyle(
              color: settings.wordColor.withAlpha(160),
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
