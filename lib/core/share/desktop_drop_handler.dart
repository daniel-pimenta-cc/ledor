import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/article_import/presentation/providers/article_import_provider.dart';
import '../../features/epub_import/presentation/providers/epub_import_provider.dart';
import '../utils/platform_capabilities.dart';
import '../utils/url_utils.dart';

/// Wraps [child] in a [DropTarget] that funnels dropped EPUB files into the
/// EPUB import pipeline and dropped URLs/text into the article import
/// pipeline. On non-desktop platforms it returns [child] untouched.
class DesktopDropHandler extends ConsumerStatefulWidget {
  final Widget child;
  const DesktopDropHandler({required this.child, super.key});

  @override
  ConsumerState<DesktopDropHandler> createState() => _DesktopDropHandlerState();
}

class _DesktopDropHandlerState extends ConsumerState<DesktopDropHandler> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    if (!PlatformCapabilities.isDesktop) return widget.child;

    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: _onDragDone,
      child: Stack(
        children: [
          widget.child,
          if (_hovering)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onDragDone(DropDoneDetails details) async {
    setState(() => _hovering = false);
    if (details.files.isEmpty) return;

    final epubPaths = [
      for (final file in details.files)
        if (file.path.toLowerCase().endsWith('.epub')) file.path,
    ];
    if (epubPaths.isNotEmpty) {
      await ref.read(epubImportProvider.notifier).importFromPaths(epubPaths);
      return;
    }

    // Anything that isn't an EPUB: treat as a URL drop. Some platforms
    // surface dropped text as an XFile whose contents are the text/URI; we
    // try to read each in turn and stop at the first valid http(s) URL.
    for (final file in details.files) {
      try {
        final content = await file.readAsString();
        final url = UrlUtils.extractHttpUrl(content);
        if (url != null) {
          await ref.read(articleImportProvider.notifier).importFromUrl(url);
          return;
        }
      } catch (_) {
        // Not readable as text — skip.
      }
    }
  }
}
