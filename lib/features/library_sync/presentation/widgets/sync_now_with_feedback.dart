import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../providers/library_sync_provider.dart';

/// Sync the user asked for: only says "offline" if the attempt itself
/// found no connection (background retries stay silent).
Future<void> syncNowWithFeedback(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = AppLocalizations.of(context)!.syncOffline;
  await ref.read(librarySyncProvider.notifier).triggerSync();
  if (!context.mounted) return;
  if (ref.read(librarySyncProvider).stage != SyncStage.offline) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
}
