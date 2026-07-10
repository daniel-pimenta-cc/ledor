class SyncConfig {
  /// Google Drive folder ID of the per-app root folder ("RSVP Reader") that
  /// holds the synced library. Null until the user connects an account and
  /// the folder is resolved or created.
  final String? driveFolderId;
  final bool syncEpubs;
  final bool autoSync;
  final String deviceId;
  final DateTime? lastSyncedAt;

  const SyncConfig({
    this.driveFolderId,
    this.syncEpubs = true,
    this.autoSync = true,
    required this.deviceId,
    this.lastSyncedAt,
  });

  bool get isConfigured => driveFolderId != null && driveFolderId!.isNotEmpty;
  bool get isActive => isConfigured && autoSync;

  SyncConfig copyWith({
    String? driveFolderId,
    bool? clearDriveFolderId,
    bool? syncEpubs,
    bool? autoSync,
    DateTime? lastSyncedAt,
  }) {
    return SyncConfig(
      driveFolderId: (clearDriveFolderId ?? false)
          ? null
          : (driveFolderId ?? this.driveFolderId),
      syncEpubs: syncEpubs ?? this.syncEpubs,
      autoSync: autoSync ?? this.autoSync,
      deviceId: deviceId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
