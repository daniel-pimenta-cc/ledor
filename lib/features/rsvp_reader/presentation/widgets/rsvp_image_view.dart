import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../book_library/data/services/inline_image_storage.dart';
import '../../../epub_import/domain/entities/word_token.dart';
import '../../domain/entities/display_settings.dart';

/// Renders an inline figure in the RSVP area when the engine pauses on an
/// [WordToken] that has `isImage: true`.
///
/// The image fills the available space inside an [InteractiveViewer], so
/// the reader can pinch-zoom and pan to inspect details. A floating
/// "Continue" button at the bottom advances past the image and resumes
/// playback through [onContinue] (wired to `engine.dismissImage`).
class RsvpImageView extends StatelessWidget {
  final WordToken word;
  final DisplaySettings settings;
  final VoidCallback onContinue;

  static const _storage = InlineImageStorage();

  const RsvpImageView({
    required this.word,
    required this.settings,
    required this.onContinue,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final relPath = word.imageRelativePath;

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: relPath == null
              ? _MissingImagePlaceholder(
                  label: l10n.imageMissing,
                  color: settings.wordColor,
                )
              : _ImageFromDocs(
                  storage: _storage,
                  relativePath: relPath,
                  fallbackLabel: l10n.imageMissing,
                  wordColor: settings.wordColor,
                ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: _ContinuePill(
              label: l10n.imageContinue,
              wordColor: settings.wordColor,
              backgroundColor: settings.backgroundColor,
              orpColor: settings.orpColor,
              onTap: () {
                HapticFeedback.mediumImpact();
                onContinue();
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Resolves [relativePath] against the app documents dir and renders the
/// underlying file inside an [InteractiveViewer]. Falls back to a
/// "missing image" placeholder if the file can't be read — that should
/// only happen if storage was tampered with after import.
class _ImageFromDocs extends StatefulWidget {
  final InlineImageStorage storage;
  final String relativePath;
  final String fallbackLabel;
  final Color wordColor;

  const _ImageFromDocs({
    required this.storage,
    required this.relativePath,
    required this.fallbackLabel,
    required this.wordColor,
  });

  @override
  State<_ImageFromDocs> createState() => _ImageFromDocsState();
}

class _ImageFromDocsState extends State<_ImageFromDocs> {
  late Future<String> _pathFuture;

  @override
  void initState() {
    super.initState();
    _pathFuture = widget.storage.resolveAbsolutePath(widget.relativePath);
  }

  @override
  void didUpdateWidget(covariant _ImageFromDocs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.relativePath != widget.relativePath) {
      _pathFuture = widget.storage.resolveAbsolutePath(widget.relativePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _pathFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.wordColor.withAlpha(160),
              ),
            ),
          );
        }
        final file = File(snap.data!);
        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          clipBehavior: Clip.none,
          child: Center(
            child: Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _MissingImagePlaceholder(
                label: widget.fallbackLabel,
                color: widget.wordColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MissingImagePlaceholder extends StatelessWidget {
  final String label;
  final Color color;

  const _MissingImagePlaceholder({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined,
              color: color.withAlpha(140), size: 40),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: color.withAlpha(170), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ContinuePill extends StatelessWidget {
  final String label;
  final Color wordColor;
  final Color backgroundColor;
  final Color orpColor;
  final VoidCallback onTap;

  const _ContinuePill({
    required this.label,
    required this.wordColor,
    required this.backgroundColor,
    required this.orpColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor.withAlpha(230),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: orpColor.withAlpha(110)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(48),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.skip_next_rounded, color: orpColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: wordColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
