import 'package:flutter/material.dart';

import '../../domain/entities/display_settings.dart';

/// Shared scaffold for the reader's bottom sheets: a [DraggableScrollableSheet]
/// with the reader-palette background, a fixed drag handle, an optional title,
/// optional header widgets (subtitle, search…), and an optional divider before
/// the body. Colours come from [settings] so every sheet matches the live
/// reader preview instead of the global theme.
class ReaderSheetShell extends StatelessWidget {
  final DisplaySettings settings;

  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;

  /// Left-aligned header title. Null renders no title row.
  final String? title;

  /// Extra widgets between the title and the divider (subtitle, search bar).
  final List<Widget> headerExtras;

  /// Whether to draw a hairline divider below the header.
  final bool showDivider;

  /// Builds the body from the sheet's drag scroll controller. Return an
  /// [Expanded] (fills the sheet) or a bounded scrollable that owns the
  /// controller.
  final Widget Function(BuildContext context, ScrollController controller)
      bodyBuilder;

  const ReaderSheetShell({
    required this.settings,
    required this.bodyBuilder,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.25,
    this.maxChildSize = 0.85,
    this.title,
    this.headerExtras = const [],
    this.showDivider = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
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
              _DragHandle(color: settings.wordColor),
              if (title != null)
                _SheetTitle(title: title!, color: settings.wordColor),
              ...headerExtras,
              if (showDivider) const Divider(height: 1),
              bodyBuilder(context, scrollController),
            ],
          ),
        );
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  final Color color;
  const _DragHandle({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: color.withAlpha(60),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final String title;
  final Color color;
  const _SheetTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
