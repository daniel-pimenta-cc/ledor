import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/display_settings_provider.dart';
import 'display_settings_panel.dart';
import 'finish_book_button.dart';
import 'reader_sheet_shell.dart';

/// Bottom sheet wrapper around [DisplaySettingsPanel], shown from the reader.
class ReaderSettingsSheet extends ConsumerWidget {
  final String bookId;

  const ReaderSettingsSheet({required this.bookId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(displaySettingsProvider);

    return ReaderSheetShell(
      settings: settings,
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      showDivider: false,
      bodyBuilder: (context, scrollController) => Expanded(
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            children: [
              DisplaySettingsPanel(bookId: bookId),
              const SizedBox(height: 24),
              FinishBookButton(
                bookId: bookId,
                settings: settings,
                onBeforeNavigate: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
