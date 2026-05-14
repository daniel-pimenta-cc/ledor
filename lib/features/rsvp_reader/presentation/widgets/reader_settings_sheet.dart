import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/display_settings_provider.dart';
import 'display_settings_panel.dart';
import 'finish_book_button.dart';

/// Bottom sheet wrapper around [DisplaySettingsPanel], shown from the reader.
class ReaderSettingsSheet extends ConsumerWidget {
  final String bookId;

  const ReaderSettingsSheet({required this.bookId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(displaySettingsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Color.lerp(settings.backgroundColor, Colors.white, 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: settings.wordColor.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                DisplaySettingsPanel(bookId: bookId),
                const SizedBox(height: 24),
                FinishBookButton(
                  bookId: bookId,
                  settings: settings,
                  onBeforeNavigate: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
