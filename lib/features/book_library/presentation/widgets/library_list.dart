import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/selected_book_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../database/app_database.dart';
import '../../../../features/library_sync/presentation/providers/library_sync_provider.dart';
import '../../../../features/library_sync/presentation/providers/sync_config_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/book_library_provider.dart';
import '../widgets/book_card.dart';
import '../widgets/library_empty_state.dart';
import '../widgets/library_section_header.dart';
import '../widgets/library_skeleton.dart';

class LibraryList extends ConsumerWidget {
  final LibraryKind kind;

  const LibraryList({required this.kind, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categorizedAsync = ref.watch(categorizedLibraryProvider(kind));

    // Keep showing the last list while the provider refetches (e.g. because a
    // background sync touched a row and the Drift stream re-emitted). The
    // appbar's thin sync bar signals that something is happening; swapping
    // the whole body back to the skeleton flashes and is jarring.
    final categorized = categorizedAsync.valueOrNull;
    if (categorized == null) {
      if (categorizedAsync.hasError) {
        return Center(child: Text('Error: ${categorizedAsync.error}'));
      }
      return const LibrarySkeleton();
    }

    final syncConfigured = kind == LibraryKind.books &&
        ref.watch(syncConfigProvider).isConfigured;

    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: categorized.isEmpty
          ? [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(kind: kind, l10n: l10n),
              ),
            ]
          : [
              _buildSection(
                context,
                ref,
                l10n,
                title: l10n.librarySectionInProgress,
                books: categorized.inProgress,
              ),
              _buildSection(
                context,
                ref,
                l10n,
                title: l10n.librarySectionNotStarted,
                books: categorized.notStarted,
              ),
              _buildSection(
                context,
                ref,
                l10n,
                title: l10n.librarySectionRead,
                books: categorized.read,
              ),
              const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxl * 2)),
            ],
    );

    if (!syncConfigured) return scroll;
    return RefreshIndicator(
      onRefresh: () => ref.read(librarySyncProvider.notifier).triggerSync(),
      child: scroll,
    );
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n, {
    required String title,
    required List<BooksTableData> books,
  }) {
    if (books.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final selectedId = ref.watch(selectedBookIdProvider);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.lg,
        AppSpacing.base,
        AppSpacing.sm,
      ),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.md,
                left: AppSpacing.xs,
              ),
              child: LibrarySectionHeader(label: title, count: books.length),
            ),
          ),
          SliverGrid(
            // Sizes columns from the *sliver's* width, not the screen's, so
            // the master-detail panel (~440px) doesn't end up cramming the
            // 4-column desktop layout into half the space.
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.68,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final book = books[index];
                return BookCard(
                  book: book,
                  selected: selectedId == book.id,
                  onTap: () => _openBook(context, ref, book.id),
                  onLongPress: () => _showBookActions(
                    context,
                    ref,
                    book.id,
                    book.title,
                    l10n,
                  ),
                );
              },
              childCount: books.length,
            ),
          ),
        ],
      ),
    );
  }

  void _openBook(BuildContext context, WidgetRef ref, String bookId) {
    if (context.isTablet && context.isLandscape) {
      ref.read(selectedBookIdProvider.notifier).state = bookId;
    } else {
      context.push('/reader/$bookId');
    }
  }

  void _showBookActions(
    BuildContext context,
    WidgetRef ref,
    String bookId,
    String title,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Text(
                  title,
                  style: Theme.of(sheetCtx).textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Only books that crossed the "Read" threshold get the
              // completion-screen entry point. Watching the provider here
              // keeps the tile in sync if progress changes while the sheet
              // is open (rare but cheap).
              Consumer(builder: (ctx, ref, _) {
                final progress =
                    ref.watch(bookProgressProvider(bookId)).valueOrNull ?? 0.0;
                if (progress < 0.99) return const SizedBox.shrink();
                return ListTile(
                  leading: const Icon(Icons.emoji_events_outlined),
                  title: Text(l10n.viewCompletion),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    context.push('/books/$bookId/completion');
                  },
                );
              }),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(l10n.markAsRead),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await ref.read(markBookAsReadProvider(bookId))();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text(l10n.markedAsRead(title)),
                        behavior: SnackBarBehavior.floating,
                      ));
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(sheetCtx).colorScheme.error,
                ),
                title: Text(
                  l10n.delete,
                  style: TextStyle(
                    color: Theme.of(sheetCtx).colorScheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _confirmDelete(context, ref, bookId, title, l10n);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String bookId,
    String title,
    AppLocalizations l10n,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteBook),
        content: Text(l10n.deleteBookConfirm(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (ref.read(selectedBookIdProvider) == bookId) {
                ref.read(selectedBookIdProvider.notifier).state = null;
              }
              ref.read(deleteBookProvider(bookId))();
            },
            child: Text(
              l10n.delete,
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final LibraryKind kind;
  final AppLocalizations l10n;

  const _EmptyState({required this.kind, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final isArticles = kind == LibraryKind.articles;
    return LibraryEmptyState(
      icon: isArticles ? Icons.article_outlined : Icons.menu_book_outlined,
      title: isArticles ? l10n.emptyArticles : l10n.emptyLibrary,
      subtitle: isArticles
          ? l10n.emptyArticlesSubtitle
          : l10n.emptyLibrarySubtitle,
    );
  }
}
