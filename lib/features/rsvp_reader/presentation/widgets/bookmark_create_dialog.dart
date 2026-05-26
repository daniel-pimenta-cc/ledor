import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// Small modal used both to create a brand-new bookmark and to edit an
/// existing one's label. Returns the entered label (trimmed; empty string
/// is normalised to null), or `null` if the user cancelled.
///
/// Chrome dialog — colours come from [Theme.of(context).colorScheme],
/// NOT from `DisplaySettings`. Same rule the rest of the app's modals
/// follow.
Future<BookmarkDialogResult?> showBookmarkDialog({
  required BuildContext context,
  required String? snippet,
  String? initialLabel,
  bool isEdit = false,
}) {
  return showDialog<BookmarkDialogResult>(
    context: context,
    builder: (context) => _BookmarkDialog(
      snippet: snippet,
      initialLabel: initialLabel,
      isEdit: isEdit,
    ),
  );
}

class BookmarkDialogResult {
  final String? label;
  const BookmarkDialogResult(this.label);
}

class _BookmarkDialog extends StatefulWidget {
  final String? snippet;
  final String? initialLabel;
  final bool isEdit;

  const _BookmarkDialog({
    required this.snippet,
    required this.initialLabel,
    required this.isEdit,
  });

  @override
  State<_BookmarkDialog> createState() => _BookmarkDialogState();
}

class _BookmarkDialogState extends State<_BookmarkDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLabel ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    Navigator.of(context).pop(BookmarkDialogResult(raw.isEmpty ? null : raw));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        widget.isEdit ? l10n.bookmarkEditTitle : l10n.bookmarkCreateTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.snippet != null) ...[
            Text(
              widget.snippet!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(180),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 80,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: l10n.bookmarkLabelHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.bookmarkSave),
        ),
      ],
    );
  }
}
