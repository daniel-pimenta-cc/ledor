import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/selected_book_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../article_import/presentation/providers/article_import_provider.dart';
import '../../../article_import/presentation/widgets/import_article_dialog.dart';
import '../../../epub_import/presentation/providers/epub_import_provider.dart';
import '../../../library_sync/presentation/providers/library_sync_provider.dart';
import '../../../rsvp_reader/presentation/screens/rsvp_reader_screen.dart';
import '../providers/book_library_provider.dart';
import '../widgets/library_appbar_bottom.dart';
import '../widgets/library_fab.dart';
import '../widgets/library_list.dart';
import '../widgets/reader_placeholder.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _masterDetailEnabled(BuildContext context) =>
      context.isTablet && context.isLandscape;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final importState = ref.watch(epubImportProvider);
    final articleImportState = ref.watch(articleImportProvider);

    ref.listen<LibrarySyncState>(librarySyncProvider, (prev, next) {
      if (next.stage == SyncStage.error &&
          prev?.stage != SyncStage.error &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.syncFailed(next.errorMessage!)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
      }
    });

    ref.listen(epubImportProvider, (prev, next) {
      if (next.status == ImportStatus.done && next.importedBookId != null) {
        if (_masterDetailEnabled(context)) {
          ref.read(selectedBookIdProvider.notifier).state =
              next.importedBookId;
        } else {
          context.push('/reader/${next.importedBookId}');
        }
        ref.read(epubImportProvider.notifier).reset();
      } else if (next.status == ImportStatus.error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.importError),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        ref.read(epubImportProvider.notifier).reset();
      }
    });

    final syncState = ref.watch(librarySyncProvider);
    final onArticlesTab = _tabController.index == 1;
    final masterDetail = _masterDetailEnabled(context);

    final libraryContent = Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: l10n.bookmarksTooltip,
            onPressed: () => context.push('/bookmarks'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: l10n.statsTitle,
            onPressed: () => context.push('/stats'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: LibraryAppBarBottom(
          tabController: _tabController,
          l10n: l10n,
          syncState: syncState,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          LibraryList(kind: LibraryKind.books),
          LibraryList(kind: LibraryKind.articles),
        ],
      ),
      floatingActionButton: LibraryFab(
        l10n: l10n,
        importState: importState,
        articleImportState: articleImportState,
        onArticlesTab: onArticlesTab,
        onImportEpub: () =>
            ref.read(epubImportProvider.notifier).importFromFilePicker(),
        onImportArticle: () => showDialog<void>(
          context: context,
          builder: (_) => const ImportArticleDialog(),
        ),
      ),
    );

    if (!masterDetail) return libraryContent;

    final selectedId = ref.watch(selectedBookIdProvider);
    // The library can only be hidden while a book is open — there's nothing
    // to fall back to otherwise.
    final libraryVisible = selectedId == null
        ? true
        : ref.watch(libraryPanelVisibleProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Row(
        children: [
          if (libraryVisible) ...[
            SizedBox(width: 440, child: libraryContent),
            VerticalDivider(width: 1, color: scheme.outlineVariant),
          ],
          Expanded(
            child: selectedId == null
                ? const ReaderPlaceholder()
                : RsvpReaderScreen(
                    key: ValueKey(selectedId),
                    bookId: selectedId,
                    onClose: () =>
                        ref.read(selectedBookIdProvider.notifier).state = null,
                  ),
          ),
        ],
      ),
    );
  }
}
