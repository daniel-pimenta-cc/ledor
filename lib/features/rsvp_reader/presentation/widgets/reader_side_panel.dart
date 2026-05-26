import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/display_settings.dart';
import '../providers/reader_side_panel_provider.dart';
import '../providers/rsvp_engine_provider.dart';
import 'bookmarks_list.dart';
import 'display_settings_panel.dart';
import 'finish_book_button.dart';

/// Tablet-landscape auxiliary panel hosted inside the reader's body. Renders
/// either the display-settings panel or a chapter list. Colours are derived
/// from [DisplaySettings] like the rest of the reader — not from the global
/// theme — so the live preview remains consistent.
class ReaderSidePanel extends ConsumerWidget {
  final String bookId;
  final DisplaySettings settings;
  final double width;

  const ReaderSidePanel({
    required this.bookId,
    required this.settings,
    this.width = 380,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = ref.watch(readerSidePanelProvider);
    if (panel == ReaderSidePanelMode.none) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(settings.backgroundColor, Colors.white, 0.06),
          border: Border(
            left: BorderSide(color: settings.wordColor.withAlpha(30)),
          ),
        ),
        child: Column(
          children: [
            _Header(
              settings: settings,
              onClose: () => ref
                  .read(readerSidePanelProvider.notifier)
                  .state = ReaderSidePanelMode.none,
              title: switch (panel) {
                ReaderSidePanelMode.settings => 'Settings',
                ReaderSidePanelMode.chapters => 'Chapters',
                ReaderSidePanelMode.bookmarks => l10n.bookmarksTitle,
                ReaderSidePanelMode.none => '',
              },
            ),
            Expanded(child: _bodyFor(panel)),
          ],
        ),
      ),
    );
  }

  Widget _bodyFor(ReaderSidePanelMode panel) {
    switch (panel) {
      case ReaderSidePanelMode.settings:
        return Consumer(builder: (context, ref, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.base,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DisplaySettingsPanel(bookId: bookId),
                const SizedBox(height: AppSpacing.lg),
                FinishBookButton(
                  bookId: bookId,
                  settings: settings,
                  onBeforeNavigate: () => ref
                      .read(readerSidePanelProvider.notifier)
                      .state = ReaderSidePanelMode.none,
                ),
              ],
            ),
          );
        });
      case ReaderSidePanelMode.chapters:
        return _ChapterList(bookId: bookId, settings: settings);
      case ReaderSidePanelMode.bookmarks:
        return BookmarksList(bookId: bookId, settings: settings);
      case ReaderSidePanelMode.none:
        return const SizedBox.shrink();
    }
  }
}

class _Header extends StatelessWidget {
  final DisplaySettings settings;
  final VoidCallback onClose;
  final String title;

  const _Header({
    required this.settings,
    required this.onClose,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: settings.wordColor.withAlpha(24)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: settings.wordColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close,
              color: settings.wordColor.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterList extends ConsumerWidget {
  final String bookId;
  final DisplaySettings settings;

  const _ChapterList({required this.bookId, required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rsvpEngineProvider(bookId));
    final engine = ref.read(rsvpEngineProvider(bookId).notifier);

    return ListView.builder(
      itemCount: state.chapters.length,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemBuilder: (context, index) {
        final chapter = state.chapters[index];
        final isCurrent = index == state.currentChapterIndex;

        return ListTile(
          dense: true,
          selected: isCurrent,
          selectedTileColor: settings.orpColor.withAlpha(30),
          leading: Text(
            '${index + 1}',
            style: TextStyle(
              color: isCurrent
                  ? settings.orpColor
                  : settings.wordColor.withAlpha(120),
              fontSize: 14,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          title: Text(
            chapter.title,
            style: TextStyle(
              color: isCurrent ? settings.orpColor : settings.wordColor,
              fontSize: 14,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            '${chapter.wordCount}',
            style: TextStyle(
              color: settings.wordColor.withAlpha(100),
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          onTap: () => engine.jumpToChapter(index),
        );
      },
    );
  }
}
