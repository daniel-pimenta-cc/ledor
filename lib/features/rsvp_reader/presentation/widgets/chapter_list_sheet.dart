import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/rsvp_engine_provider.dart';
import 'chapter_tile.dart';
import 'reader_sheet_shell.dart';

/// Bottom sheet showing a list of chapters for navigation.
class ChapterListSheet extends ConsumerWidget {
  final String bookId;

  const ChapterListSheet({required this.bookId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rsvpEngineProvider(bookId));
    final engine = ref.read(rsvpEngineProvider(bookId).notifier);
    final settings = state.displaySettings;

    return ReaderSheetShell(
      settings: settings,
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.8,
      title: 'Chapters',
      bodyBuilder: (context, scrollController) => Expanded(
        child: ListView.builder(
          controller: scrollController,
          itemCount: state.chapters.length,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemBuilder: (context, index) => ChapterTile(
            index: index,
            chapter: state.chapters[index],
            isCurrent: index == state.currentChapterIndex,
            settings: settings,
            onTap: () {
              engine.jumpToChapter(index);
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }
}
