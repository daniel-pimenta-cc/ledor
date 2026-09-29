import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../article_import/presentation/providers/article_import_provider.dart';
import '../../../epub_import/presentation/providers/epub_import_provider.dart';

class LibraryFab extends StatelessWidget {
  final AppLocalizations l10n;
  final ImportState importState;
  final ArticleImportState articleImportState;
  final bool onArticlesTab;
  final VoidCallback onImportEpub;
  final VoidCallback onImportArticle;

  const LibraryFab({
    required this.l10n,
    required this.importState,
    required this.articleImportState,
    required this.onArticlesTab,
    required this.onImportEpub,
    required this.onImportArticle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool busy;
    final VoidCallback? onPressed;
    final String label;
    final IconData idleIcon;

    if (onArticlesTab) {
      busy = articleImportState.status == ArticleImportStatus.fetching ||
          articleImportState.status == ArticleImportStatus.processing;
      onPressed = busy ? null : onImportArticle;
      label = switch (articleImportState.status) {
        ArticleImportStatus.fetching => l10n.importArticleFetching,
        ArticleImportStatus.processing => l10n.importing,
        _ => l10n.importArticle,
      };
      idleIcon = Icons.link;
    } else {
      busy = importState.status == ImportStatus.processing;
      onPressed = busy ? null : onImportEpub;
      label = !busy
          ? l10n.importBook
          : importState.totalCount > 1
              ? l10n.importingProgress(
                  importState.currentIndex,
                  importState.totalCount,
                )
              : l10n.importing;
      idleIcon = Icons.add;
    }

    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(idleIcon),
      label: Text(label),
    );
  }
}
