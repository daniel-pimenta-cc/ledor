import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/routing/selected_book_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../database/app_database.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/bookmark.dart';
import '../providers/reader_side_panel_provider.dart';

/// Global "all bookmarks" screen. Lists every non-tombstoned bookmark
/// across the library, grouped by book. Tapping an entry opens the
/// reader at the bookmarked word (and goes through the master-detail
/// host when on tablet landscape).
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncRows = ref.watch(_bookmarksWithBookProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookmarksTitle)),
      body: asyncRows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rows) {
          if (rows.isEmpty) {
            return _GlobalEmptyState(l10n: l10n);
          }
          return _GroupedList(rows: rows);
        },
      ),
    );
  }
}

/// One bookmark joined with the matching book row, if any. The book may
/// be null if the bookmark was synced from a peer that hasn't uploaded
/// the EPUB yet — the UI still shows the entry, just without a book
/// title.
typedef _Row = ({Bookmark bookmark, BooksTableData? book});

final _bookmarksWithBookProvider =
    StreamProvider.autoDispose<List<_Row>>((ref) {
  final booksDao = ref.watch(booksDaoProvider);
  final bookmarksStream =
      ref.watch(bookmarksDaoProvider).watchAll();
  return bookmarksStream.asyncMap((rows) async {
    final allBooks = await booksDao.getAllBooks();
    final byId = {for (final b in allBooks) b.id: b};
    return [
      for (final r in rows)
        (
          bookmark: Bookmark.fromRow(r),
          book: byId[r.bookId],
        ),
    ];
  });
});

class _GroupedList extends ConsumerWidget {
  final List<_Row> rows;

  const _GroupedList({required this.rows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = <String, List<_Row>>{};
    for (final r in rows) {
      groups.putIfAbsent(r.bookmark.bookId, () => []).add(r);
    }
    final orderedBookIds = groups.keys.toList()
      ..sort((a, b) {
        final ba = groups[a]!.first.book?.title ?? '';
        final bb = groups[b]!.first.book?.title ?? '';
        return ba.toLowerCase().compareTo(bb.toLowerCase());
      });

    return ListView.builder(
      itemCount: orderedBookIds.length,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemBuilder: (context, index) {
        final bookId = orderedBookIds[index];
        final group = groups[bookId]!
          ..sort((a, b) =>
              a.bookmark.globalWordIndex.compareTo(b.bookmark.globalWordIndex));
        final book = group.first.book;
        return _BookGroup(
          bookId: bookId,
          bookTitle: book?.title,
          bookAuthor: book?.author,
          rows: group,
        );
      },
    );
  }
}

class _BookGroup extends ConsumerWidget {
  final String bookId;
  final String? bookTitle;
  final String? bookAuthor;
  final List<_Row> rows;

  const _BookGroup({
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.rows,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.base,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  bookTitle ?? bookId,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (bookAuthor != null && bookAuthor!.isNotEmpty)
                Text(
                  bookAuthor!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        for (final r in rows)
          _BookmarkRow(row: r),
        const Divider(height: AppSpacing.lg),
      ],
    );
  }
}

class _BookmarkRow extends ConsumerWidget {
  final _Row row;

  const _BookmarkRow({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bookmark = row.bookmark;
    final label = bookmark.effectiveLabel;
    final preview = label ?? bookmark.contextSnippet;
    final showsSnippetAsTitle = label == null && preview != null;
    final totalWords = row.book?.totalWords ?? 0;
    final percent = totalWords > 0
        ? ((bookmark.globalWordIndex / totalWords) * 100).round().clamp(0, 100)
        : 0;
    final location =
        l10n.bookmarkLocationLabel(bookmark.chapterIndex + 1, percent);

    return ListTile(
      leading: Icon(
        Icons.bookmark,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        preview ?? location,
        style: TextStyle(
          fontStyle: showsSnippetAsTitle ? FontStyle.italic : FontStyle.normal,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        location,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      onTap: () => _openInReader(context, ref, bookmark),
    );
  }

  void _openInReader(BuildContext context, WidgetRef ref, Bookmark bookmark) {
    // Stage the seek before navigating so the reader picks it up the
    // moment it finishes loading.
    ref.read(readerPendingSeekProvider.notifier).state =
        bookmark.globalWordIndex;
    if (context.isTablet && context.isLandscape) {
      ref.read(selectedBookIdProvider.notifier).state = bookmark.bookId;
      context.pop(); // close /bookmarks; library is behind us
      return;
    }
    context.pushReplacement('/reader/${bookmark.bookId}');
  }
}

class _GlobalEmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  const _GlobalEmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_outline,
            size: 72,
            color: scheme.onSurfaceVariant.withAlpha(120),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.bookmarkEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.bookmarkEmptySubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
