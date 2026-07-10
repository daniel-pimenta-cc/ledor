import 'package:flutter/material.dart';

import '../../../epub_import/domain/entities/chapter.dart';
import '../../domain/entities/display_settings.dart';

/// A single chapter row — index number, title, and word count. Shared by the
/// chapter bottom sheet and the tablet-landscape side panel. Colours come from
/// [settings] for live-preview parity with the reader.
class ChapterTile extends StatelessWidget {
  final int index;
  final Chapter chapter;
  final bool isCurrent;
  final DisplaySettings settings;
  final VoidCallback onTap;

  const ChapterTile({
    required this.index,
    required this.chapter,
    required this.isCurrent,
    required this.settings,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
      onTap: onTap,
    );
  }
}
