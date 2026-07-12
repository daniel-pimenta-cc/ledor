import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../rsvp_reader/domain/entities/display_settings.dart';
import '../../../rsvp_reader/presentation/providers/display_settings_provider.dart';
import '../providers/drive_auth_provider.dart';
import '../providers/library_sync_provider.dart';
import '../providers/sync_config_provider.dart';

class SyncSettingsSection extends ConsumerWidget {
  const SyncSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(displaySettingsProvider);
    final config = ref.watch(syncConfigProvider);
    final syncState = ref.watch(librarySyncProvider);
    final auth = ref.watch(driveAuthProvider);

    final textColor = settings.wordColor;
    final mutedColor = textColor.withAlpha(160);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.settingsSync.toUpperCase(),
          style: TextStyle(
            color: textColor.withAlpha(140),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.syncHelp,
          style: TextStyle(color: mutedColor, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),
        _DriveAccountRow(settings: settings, l10n: l10n),
        if (auth.errorMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            l10n.syncFailed(auth.errorMessage!),
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        _SyncStatusRow(settings: settings, l10n: l10n, state: syncState),
        if (auth.isSignedIn && config.isConfigured) ...[
          const SizedBox(height: 8),
          _toggleTile(
            context: context,
            settings: settings,
            title: l10n.syncAutoSync,
            subtitle: l10n.syncAutoSyncDesc,
            value: config.autoSync,
            onChanged: (v) =>
                ref.read(syncConfigProvider.notifier).setAutoSync(v),
          ),
          _toggleTile(
            context: context,
            settings: settings,
            title: l10n.syncEpubFiles,
            subtitle: l10n.syncEpubFilesDesc,
            value: config.syncEpubs,
            onChanged: (v) =>
                ref.read(syncConfigProvider.notifier).setSyncEpubs(v),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: textColor,
              side: BorderSide(color: textColor.withAlpha(80)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: syncState.stage == SyncStage.syncing
                ? null
                : () =>
                    ref.read(librarySyncProvider.notifier).triggerSync(),
            icon: syncState.stage == SyncStage.syncing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor,
                    ),
                  )
                : const Icon(Icons.sync, size: 18),
            label: Text(syncState.stage == SyncStage.syncing
                ? l10n.syncInProgress
                : l10n.syncNow),
          ),
          _FailedImportsSection(settings: settings, l10n: l10n),
        ],
      ],
    );
  }

  Widget _toggleTile({
    required BuildContext context,
    required DisplaySettings settings,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      onChanged: onChanged,
      activeThumbColor: settings.orpColor,
      title: Text(title, style: TextStyle(color: settings.wordColor)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
            color: settings.wordColor.withAlpha(160), fontSize: 12),
      ),
    );
  }
}

class _DriveAccountRow extends ConsumerWidget {
  final DisplaySettings settings;
  final AppLocalizations l10n;

  const _DriveAccountRow({required this.settings, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(driveAuthProvider);
    final textColor = settings.wordColor;
    final mutedColor = textColor.withAlpha(160);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: textColor.withAlpha(60)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            auth.isSignedIn
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            color: auth.isSignedIn ? settings.orpColor : mutedColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              auth.isSignedIn
                  ? l10n.syncConnectedAs(auth.email ?? '')
                  : (auth.isBusy
                      ? l10n.syncConnectingDrive
                      : l10n.syncConnectDrive),
              style: TextStyle(color: textColor, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          if (auth.isSignedIn)
            TextButton(
              onPressed: auth.isBusy
                  ? null
                  : () => _disconnect(context, ref),
              style: TextButton.styleFrom(foregroundColor: mutedColor),
              child: Text(l10n.syncDisconnect),
            )
          else
            TextButton(
              onPressed: auth.isBusy ? null : () => _connect(context, ref),
              style: TextButton.styleFrom(foregroundColor: settings.orpColor),
              child: Text(l10n.syncConnectDrive),
            ),
        ],
      ),
    );
  }

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(driveAuthProvider.notifier).signIn();
    if (!ok) return;

    // Resolve (or create) the app's root folder on Drive and persist its id.
    try {
      final gateway = ref.read(driveSyncFolderGatewayProvider);
      final folderId = await gateway.ensureRootFolder();
      await ref.read(syncConfigProvider.notifier).setDriveFolderId(folderId);
    } catch (e) {
      // A silent signOut here reads as "nothing happened" in the UI —
      // surface the failure (e.g. Drive API disabled on the project).
      debugPrint('[auth] ensureRootFolder failed after sign-in: $e');
      if (!context.mounted) return;
      await ref.read(driveAuthProvider.notifier).signOut();
      ref.read(driveAuthProvider.notifier).reportError(e.toString());
      return;
    }

    if (!context.mounted) return;
    await ref.read(librarySyncProvider.notifier).triggerSync();
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    await ref.read(driveAuthProvider.notifier).signOut();
    await ref.read(syncConfigProvider.notifier).setDriveFolderId(null);
    ref.read(driveSyncFolderGatewayProvider).clearCache();
    // Queued delete tombstones belong to the disconnected account; never
    // replay them against whichever account connects next.
    await ref.read(librarySyncProvider.notifier).clearPendingDeletes();
  }
}

class _FailedImportsSection extends ConsumerWidget {
  final DisplaySettings settings;
  final AppLocalizations l10n;

  const _FailedImportsSection({required this.settings, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failuresAsync = ref.watch(syncImportFailuresProvider);
    return failuresAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (failures) {
        if (failures.isEmpty) return const SizedBox.shrink();
        final textColor = settings.wordColor;
        final mutedColor = textColor.withAlpha(160);
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    l10n.syncFailedImportsTitle(failures.length),
                    style: TextStyle(
                      color: textColor.withAlpha(200),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.syncFailedImportsHelp,
                style:
                    TextStyle(color: mutedColor, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 8),
              for (final f in failures)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.redAccent.withAlpha(80)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.fileName,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              f.errorMessage,
                              style: TextStyle(
                                color: mutedColor,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref
                              .read(librarySyncProvider.notifier)
                              .retryFailedImport(f.fileName);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: settings.orpColor,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: Text(l10n.syncRetry),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SyncStatusRow extends StatelessWidget {
  final DisplaySettings settings;
  final AppLocalizations l10n;
  final LibrarySyncState state;

  const _SyncStatusRow({
    required this.settings,
    required this.l10n,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor = settings.wordColor.withAlpha(160);

    if (state.stage == SyncStage.error && state.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          l10n.syncFailed(state.errorMessage!),
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      );
    }

    final lastLabel = state.lastSyncedAt != null
        ? DateFormat.yMMMd().add_Hm().format(state.lastSyncedAt!.toLocal())
        : l10n.syncNever;

    return Text(
      l10n.syncLastSyncedAt(lastLabel),
      style: TextStyle(color: mutedColor, fontSize: 12),
    );
  }
}
