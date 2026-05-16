import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../book_library/data/services/inline_image_storage.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import '../../domain/entities/display_settings.dart';

/// Full-screen image viewer pushed from the scroll/ereader views. The user
/// taps an inline figure, lands here, can pinch-zoom and pan, and pops out
/// with the system back button or the close icon in the top bar.
///
/// Lives in its own [MaterialPageRoute] so the route stack handles dismiss
/// gestures (Android back, iOS swipe) without us having to wire anything.
class FullscreenImageScreen extends StatelessWidget {
  final WordToken word;
  final DisplaySettings settings;

  static const _storage = InlineImageStorage();

  const FullscreenImageScreen({
    required this.word,
    required this.settings,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: settings.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: settings.backgroundColor.withAlpha(180),
        elevation: 0,
        iconTheme: IconThemeData(color: settings.wordColor),
        leading: IconButton(
          tooltip: l10n.imageClose,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _FullscreenContent(
          relativePath: word.imageRelativePath,
          settings: settings,
          fallbackLabel: l10n.imageMissing,
        ),
      ),
    );
  }
}

class _FullscreenContent extends StatefulWidget {
  final String? relativePath;
  final DisplaySettings settings;
  final String fallbackLabel;

  const _FullscreenContent({
    required this.relativePath,
    required this.settings,
    required this.fallbackLabel,
  });

  @override
  State<_FullscreenContent> createState() => _FullscreenContentState();
}

class _FullscreenContentState extends State<_FullscreenContent> {
  Future<String>? _pathFuture;

  @override
  void initState() {
    super.initState();
    final rel = widget.relativePath;
    if (rel != null) {
      _pathFuture =
          FullscreenImageScreen._storage.resolveAbsolutePath(rel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.settings.wordColor;
    if (_pathFuture == null) {
      return _missing(color);
    }
    return FutureBuilder<String>(
      future: _pathFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color.withAlpha(160),
              ),
            ),
          );
        }
        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 8.0,
          clipBehavior: Clip.none,
          child: Center(
            child: Image.file(
              File(snap.data!),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _missing(color),
            ),
          ),
        );
      },
    );
  }

  Widget _missing(Color color) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined,
              color: color.withAlpha(140), size: 48),
          const SizedBox(height: 10),
          Text(
            widget.fallbackLabel,
            style: TextStyle(color: color.withAlpha(170), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
