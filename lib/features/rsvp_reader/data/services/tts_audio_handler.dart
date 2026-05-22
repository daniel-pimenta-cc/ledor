import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:audio_service/audio_service.dart';

/// Callback bundle the engine notifier registers with the [TtsAudioHandler]
/// when it enters TTS mode. The handler forwards lockscreen / notification
/// taps to these closures so the platform media controls drive the active
/// engine without the handler needing to know about Riverpod or the engine
/// itself.
///
/// `skipForward` / `skipBackward` are arg-less — the engine decides how
/// many words to jump (currently `AppConstants.skipWordCount`). Keeping
/// the policy in one place avoids the handler having to know what a
/// "skip" means for this app.
class TtsAudioSource {
  final VoidCallback play;
  final VoidCallback pause;
  final VoidCallback skipForward;
  final VoidCallback skipBackward;

  const TtsAudioSource({
    required this.play,
    required this.pause,
    required this.skipForward,
    required this.skipBackward,
  });
}

/// Bridges TTS playback to the platform's media session.
///
/// `AudioService.init` constructs a single instance for the app's life,
/// regardless of which book the user is reading. The engine notifier
/// claims the handler via [bindSource] when it enters TTS mode and
/// releases it via [unbindSource] when it exits — control flow stays in
/// the engine; this handler is just the OS-facing facade.
///
/// On Android this runs in a foreground service (declared in the manifest)
/// so the OS doesn't kill the TTS engine while the app is backgrounded.
/// On iOS the AVAudioSession category=playback (set on the flutter_tts
/// backend) plus the `audio` background mode in Info.plist achieve the
/// same effect.
class TtsAudioHandler extends BaseAudioHandler {
  TtsAudioSource? _source;
  bool _hasMediaItem = false;

  /// Registers [source] as the active set of callbacks. A previously-bound
  /// source is replaced silently — typical when the user closes one book
  /// and opens another.
  void bindSource(TtsAudioSource source) {
    _source = source;
  }

  /// Releases the current source. Called when the user exits TTS mode or
  /// closes the reader. Clears the media item so the lockscreen
  /// notification doesn't keep showing a stale title.
  void unbindSource() {
    _source = null;
    _hasMediaItem = false;
    mediaItem.add(null);
    playbackState.add(PlaybackState(
      controls: const [],
      systemActions: const {},
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  /// Releases the source only if [source] is the one currently bound.
  /// Engine notifiers call this on dispose so they don't accidentally
  /// clobber a handler that was already re-bound by a different reader
  /// (rare today — autoDispose serialises notifiers — but cheap defence).
  void unbindIfActive(TtsAudioSource source) {
    if (identical(_source, source)) {
      unbindSource();
    }
  }

  /// Updates the media metadata shown on the lockscreen / notification.
  /// Distinct name (`setActiveBook`) from `BaseAudioHandler.updateMediaItem`,
  /// which already exists with a `(MediaItem)` signature we'd be hiding by
  /// overloading here.
  void setActiveBook({
    required String bookId,
    required String title,
    String? author,
  }) {
    _hasMediaItem = true;
    mediaItem.add(MediaItem(
      id: bookId,
      title: title,
      artist: author ?? '',
      playable: true,
    ));
  }

  /// Updates the play / pause state shown in the notification + lockscreen.
  void updatePlaybackState({required bool playing}) {
    if (!_hasMediaItem) return;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.rewind,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.play,
        MediaAction.pause,
        MediaAction.rewind,
        MediaAction.fastForward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: playing,
      // Position fields kept at 0 — TTS doesn't have a meaningful elapsed
      // duration we can stream (the engine tracks word index, not time).
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1.0,
    ));
  }

  @override
  Future<void> play() async {
    _source?.play();
  }

  @override
  Future<void> pause() async {
    _source?.pause();
  }

  @override
  Future<void> stop() async {
    _source?.pause();
    await super.stop();
  }

  @override
  Future<void> fastForward() async {
    _source?.skipForward();
  }

  @override
  Future<void> rewind() async {
    _source?.skipBackward();
  }

  @override
  Future<void> seek(Duration position) async {
    // No seek support: TTS position is in words, not Duration. The fast-
    // forward / rewind buttons are the primitive instead. We accept the
    // call to satisfy the AudioHandler contract but no-op it.
  }
}
