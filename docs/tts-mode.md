# TTS mode (text-to-speech)

`ReaderMode.tts`, alongside `rsvp`, `scroll` (paused RSVP) and `ereader`. The
engine drives narration through a TTS backend; the scroll view's existing
highlight tracks the spoken word so users see what they hear.

## Architecture overview

```
  RsvpEngineNotifier
        │
        │  enterTtsMode() / play() / pause() / seekToWord()
        ▼
  TtsPlayer                        ← lib/features/rsvp_reader/data/services/tts_player.dart
        │   (queue, pipeline, segment lookahead)
        ▼
  TtsBackend (abstract)            ← lib/features/rsvp_reader/data/services/tts_backend.dart
        │
        ├── FlutterTtsBackend       ← Android / iOS / macOS / Windows
        │    (flutter_tts package, setQueueMode(1) for pipelined chunks)
        │
        └── SpeechdSocketBackend    ← Linux desktop
             (persistent Unix socket to speech-dispatcher; the daemon queues.
              Autospawns the daemon when the socket is absent.
              Helpers in _linux_tts_shared.dart)

  TtsAudioHandler                  ← lib/features/rsvp_reader/data/services/tts_audio_handler.dart
        (audio_service bridge: foreground service + lockscreen controls)
```

Backend selection happens in `ttsBackendProvider`
(`lib/features/rsvp_reader/presentation/providers/tts_backend_provider.dart`):
Linux → `SpeechdSocketBackend`, everything else → `FlutterTtsBackend`. Web has
no TTS (`PlatformCapabilities.supportsTts` is false).

`TtsPlayer` owns a small queue of pre-extracted `SentenceSegment`s and uses
`TtsQueueMode.add` so the backend (`flutter_tts.setQueueMode(1)` on
Android/iOS, the daemon's queue on Linux) stitches chunks together with no
audible gap. Without this, every chunk boundary cost ~200–500 ms of IPC +
engine start-up.

## Engine integration

`RsvpEngineNotifier` keeps the RSVP path (Ticker-driven) and the TTS path in
the same notifier so reading sessions, progress saves and the end-of-book
`finishTicket` fire uniformly. Playback is delegated to `TtsPlayer`; the engine
only manages state transitions, session bookkeeping and audio-handler binding.

Key methods:

- `enterTtsMode()`: flushes any open session, sets `mode = tts` **before**
  awaiting so a play tapped during init doesn't fall into the RSVP path, then
  lazily constructs the player and awaits `player.init()`. On failure it writes
  the error to `ttsErrorProvider` (the screen shows a snackbar), reverts to
  `scroll` and saves. On success it pushes content + settings, fires
  `player.applySettings()` so previews and the first play use the chosen
  voice, binds the `TtsAudioHandler` and saves progress. Doesn't play.
  `_loadBook` calls it when the book's persisted `readerMode` is `'tts'`.
- `exitTtsMode()`: pauses the player if playing, flushes the session, returns
  to `scroll`, unbinds the audio handler and saves.
- `play()`: in TTS mode starts a session and asks the player to play from
  `state.globalWordIndex`. The RSVP "already at the last word" guard is
  *not* applied; the player's `onBookFinished` handles end-of-book.
- `pause()`: in TTS mode calls `player.pause()`, keeps `mode == tts` (the UI
  stays on the scroll-with-highlight view) and runs the same
  `_flushSession()` + `_saveProgress()` as RSVP.
- `seekToWord()`: forwards to `player.seek(globalIndex)`, which rebuilds the
  pipeline from the new position if playing (or only moves the cursor if
  paused).
- `restartTtsIfStalled()`: called from the screen's
  `didChangeAppLifecycleState(resumed)`; delegates to
  `player.restartIfStalled()`.
- Player callbacks (`onWordAdvance`, `onBookFinished`, `onError`) drive engine
  state and session counters.

### TtsPlayer pipeline

The player keeps a fixed lookahead of 2 segments (`_lookahead`). The first
segment is spoken with `TtsQueueMode.flush`, the next with `add`; each
completion pops the queue and enqueues one more. While segment N plays, N+1 is
already queued in the platform engine. Both backends queue natively; a backend
that cancels the previous utterance on every `speak()` would break this.

Race safety: `_generation` is bumped on every action that should invalidate
in-flight callbacks (`play`, `pause`, `dispose`; `seek` goes through
pause + play). Each queued segment stores the generation it was enqueued in;
stale progress/completion callbacks compare against the live counter and bail.
`_isPlaying` is set to `true` synchronously *before* any `await` so a
`pause()` in the same tick (user taps pause right after play) actually stops
the backend.

Settings dedup: the player tracks `_appliedEngineId` / `_appliedLanguage` /
`_appliedVoiceName` / `_appliedPitch` / `_appliedRate` per field, so a slider
re-emitting the same value (or `applySettings()` back-to-back during init +
first play) doesn't re-push unchanged settings. Each field advances only
*after* its own `await` succeeds, so a half-applied snapshot (`pause` cancelled
mid-way) is completed on the next push. An engine change re-pushes language,
voice, pitch and rate, since the new engine starts from its own defaults.

Stall detection: every `onProgress` callback updates `_lastProgressAt`.
`restartIfStalled()` restarts only when the last heartbeat is older than
`_stallThreshold` (10 s); a null heartbeat (paused, or not speaking yet) counts
as healthy. A restart also clears `_hasAppliedAny` to force a full settings
re-push, because an OS-recreated synth comes back with default
voice/language/rate.

## Segment extraction

`extractSentenceFrom(chapters, startGlobalIndex)`
(`lib/features/rsvp_reader/domain/utils/sentence_extractor.dart`) despite the
name returns a **chunk**, not a sentence. Starting at `startGlobalIndex` it
collects tokens until:

1. the next token starts a new chapter (the chapter title belongs to the next
   segment, so the pause lands at the seam), or
2. `kSentenceMaxTokens` (200) tokens are collected.

Sentence terminators and paragraph breaks are deliberately ignored: the synth
handles prosody between sentences, and splitting there would bring back the
per-`speak()` latency. The cap keeps `stop()` fast and stays far below the
platform limits (Android: 4000 chars).

Image tokens are part of the range (`endGlobalIndexExcl` includes them) but
never enter `spokenText`; an all-image range is skipped silently.
`charOffsetToTokenIndex` maps a backend `charOffset` back to a token via
`tokenCharOffsets`.

## Speech rate

TTS uses an audiobook-style rate (`DisplaySettings.ttsRate`, range
`[AppConstants.minTtsRate, maxTtsRate]` = `[0.5, 3.0]`) independent of the RSVP
WPM. WPM is an RSVP concept (a fixed frame interval); TTS rate scales the
synth's natural cadence, which varies by voice. Users understand "1.25x"
instantly; "300 WPM" didn't translate.

`RsvpEngineNotifier.setTtsRate` clamps, persists to `displaySettingsProvider`
and, in TTS mode, calls `player.setRate` immediately (deduped by
`_appliedRate`). Otherwise the rate is applied with the other settings at
`play()`. Backends translate to native units:

- `FlutterTtsBackend.setRate` → `setSpeechRate(flutterTtsRate(rate))`, i.e.
  `(rate * 0.5).clamp(0.1, 1.5)`. The plugin's scale treats **0.5 as normal
  speed** (Android multiplies by 2 before `TextToSpeech.setSpeechRate`; iOS
  maps 0.5 to `AVSpeechUtteranceDefaultSpeechRate`). Passing the audiobook
  value through unconverted made every Android install speak at 2×; don't
  "simplify" the conversion away.
- SSIP: `SET SELF RATE ((rate - 1.0) * 50).round().clamp(-100, 100)`
  (pitch uses the same mapping with `SET SELF PITCH`).

The transport row reuses `WpmCapsule` in TTS mode with a `formatTtsRate` label
and ± `AppConstants.ttsRateStep` (0.25) instead of ± 25 WPM. The preset drawer
is `TtsRatePresetRow` (`tts_rate_selector.dart`) with a fixed ladder
`0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 1.75 / 2.0 / 2.5 / 3.0`.

`setWpm` does **not** reach the TTS backend; only `setTtsRate` does. Switching
modes preserves both values.

## Linux backend (`SpeechdSocketBackend`)

Speaks SSIP over the Unix socket that `speech-dispatcher` exposes, resolved in
order: `$XDG_RUNTIME_DIR/speech-dispatcher/speechd.sock`,
`/var/run/speech-dispatcher/speechd.sock`, `/tmp/speech-dispatcher/speechd.sock`.
One connection is opened in `init()` and reused for every command; the daemon
queues utterances, so pipelined segments play gap-free. `init()` sends
`SET SELF NOTIFICATION ALL ON`; without it the daemon never emits the
`701 BEGIN` / `702 END` events the word timer depends on. A fresh connection
resets the backend's own applied-settings snapshot, because daemon-side
settings are back to defaults (with Piper and no default model, that means
silence).

### Autospawn

If connecting fails (socket absent, or a stale socket from a dead daemon),
`init()` runs `speech-dispatcher --spawn` once and retries the connect 12 times,
250 ms apart (~3 s). If the daemon never comes up, `init()` throws
`TtsUnavailableException` with distro install hints, which the reader shows as
a snackbar.

### Emulated word boundaries

SSIP `INDEX_MARK` events only fire for explicitly marked text, so word
boundaries are approximated by a timer started on `701 BEGIN` and stopped on
`702 END`. Word offsets come from `wordCharOffsets` (`_linux_tts_shared.dart`).
The per-word period comes from a per-voice WPM baseline (150 at rate 1.0 until
measured) × rate, with longer dwell after punctuation. After each utterance of
≥5 words the backend measures the real WPM and updates that voice's baseline
(70/30 smoothing), so the highlight converges on the voice's actual pace.

## UI summary

| Surface | Widget | Notes |
|---|---|---|
| Mode switcher | `ReaderModeFab` | Floating pill at the bottom-left that expands into RSVP / E-reader / TTS. Hidden during playback and while the user scrolls down. `ReaderMode.scroll` is shown as "RSVP" (it's paused RSVP). |
| Mode area in TTS | `ContextScrollView(showHighlight: true)` | Same surface as `ReaderMode.scroll`; player progress drives the highlight. |
| Transport row | `RsvpControls` → `ControlsTransportRow(speedControl:)` | `RsvpControls` feeds `WpmCapsule` a WPM or TTS-rate label based on `state.mode`. |
| Settings | `AudioSection` (`widgets/settings/sections/audio_section.dart`) | Engine row (full-screen settings only, and only with ≥2 engines), voice row and pitch slider. Rate lives in the transport row. |
| Voice picker | `TtsVoicePickerSheet` | Friendly labels via `enrichVoices`, scope toggle (current language / all), substring search; the play icon previews `ttsVoicePreviewSample` without committing. |
| Engine picker | `TtsEnginePickerSheet` | Engines + "System default". Selecting writes `ttsEngineId` and clears `ttsVoiceName`. |

## Persistence and sync

TTS fields on `DisplaySettings`:

- `ttsLanguage` (`String`, default `'en-US'`)
- `ttsVoiceName` (`String?`, `null` = engine default voice)
- `ttsPitch` (`double`, default `1.0`, slider `[0.5, 2.0]`)
- `ttsRate` (`double`, default `1.0`, range `[0.5, 3.0]`)
- `ttsEngineId` (`String?`, `null` = system default)

All persist to SharedPreferences via `DisplaySettingsNotifier` and sync through
Drive via `displaySettingsToMap` / `displaySettingsFromMap` in
`library_sync_service.dart`. `ttsVoiceName` and `ttsEngineId` are written even
when null so a reset propagates. A synced voice or engine id unknown on this
device is not cleared, so a round-trip to the original device restores it.

The picker sheets write only to the global `displaySettingsProvider` (they
have no bookId). `RsvpEngineNotifier` mirrors that provider into its own
snapshot via a constructor-time `ref.listen` (keeping the per-book WPM), so
the player sees the new engine/voice on the next play without reopening the
book.

## Reading sessions

TTS sessions log to `reading_session` like RSVP sessions, using the same
`_sessionStartedAt` / `_sessionStartWordIndex` / `_wordsInSession` counters and
the `computeSessionAvgWpm` thresholds (≥ 5 words and ≥ 3 s). Stats, monthly
recap and book completion pick them up automatically.

## Background playback

`audio_service` hosts TTS playback in a foreground service on Android and an
`AVAudioSession` with the playback category on iOS, so the OS doesn't kill the
synth when the app is backgrounded. Notification + lockscreen controls
(rewind / play-pause / fastForward) are driven by `TtsAudioHandler`:

- `main.dart` calls `AudioService.init(builder: () => TtsAudioHandler(), …)`
  only when `PlatformCapabilities.supportsBackgroundAudio` (not Linux, not
  Web) and **does not await it** (the MediaSession IPC delayed the first
  frame). The future is injected through `ttsAudioHandlerProvider`
  (`Provider<Future<TtsAudioHandler?>>`, resolving to `null` elsewhere or on
  init failure).
- `RsvpEngineNotifier._bindAudioHandler` awaits that future, bails if the user
  already left TTS, then registers a `TtsAudioSource` (play / pause /
  skipForward / skipBackward, 10 words), calls `setActiveBook` with the book
  title/author for the notification, and pushes `updatePlaybackState` on every
  play/pause/error/finish. The handler is cached in `_audioHandler` so unbind
  works during dispose.
- OS controls (headphones, Bluetooth, lockscreen) call back into those same
  callbacks, so they drive the real engine.
- `MainActivity` extends `AudioServiceActivity` (not `FlutterActivity`) so
  `MEDIA_BUTTON` intents reach the plugin. `AndroidManifest.xml` declares
  `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, the
  `AudioService` service and the `MediaButtonReceiver`.
- iOS has `UIBackgroundModes: audio` in `Info.plist`. `FlutterTtsBackend.init`
  also calls `setSharedInstance(true)` and
  `setIosAudioCategory(playback, [allowBluetooth, allowBluetoothA2DP, mixWithOthers], spokenAudio)`.

On Linux there is no audio handler: TTS works, but without media controls or
a lockscreen notification.

## TTS engine picker

`TtsBackend.getEngines()` lists the alternative engines; `setEngine(id)`
switches which one new utterances use:

- **Android**: `flutter_tts.getEngines` lists installed `TTS_SERVICE`
  providers (Google TTS, Samsung TTS, Pico, …).
- **Linux**: `LIST OUTPUT_MODULES` over SSIP: speech-dispatcher output modules
  (`espeak-ng`, `festival`, `flite`, `rhvoice`, `piper`, …), labelled by
  `humaniseSpeechdModuleId`.
- **iOS / macOS / Windows**: empty list (single OS synth).

The row is hidden when fewer than 2 engines are reported. The backend ignores
an unknown id (falls back to the system default) without losing the stored
value.

### Engine switching is serialised inside `FlutterTtsBackend`

`flutter_tts`'s Android side keeps a **single** pending `Result` slot for
`setEngine` and drains queued method calls against a half-initialised client
when two `setEngine`s overlap: one caller's `await` hangs forever, the other
gets its `Result` answered early, and the plugin's own `onInit` then clobbers
language/voice with the new engine's defaults. It also never stops the
outgoing native client, so the old engine's audio plays over the new one and
its late completion callbacks pop the `TtsPlayer` queue.

`FlutterTtsBackend` defends against this without forking the plugin: every
operation goes through an internal serialising queue (`_enqueue`); internal
calls use `_tts.*` directly (calling a public method from inside the queue
deadlocks). `setEngine` dedups by the active id, calls `stop()` on the
outgoing client first and wraps the plugin call in an 8 s timeout so a wedged
engine init can't freeze the player. This is why `ttsVoicesProvider` can call
`setEngine` before listing voices while the player applies settings
concurrently. `setVoice(null)` calls `clearVoice()` so "no voice" means the
new engine's default after a switch.

## Limitations

- **No sentence-level skip**: the 10-word skip buttons are the only fast-skip.
- **Pause is a stop** on every backend (`player.pause()` → `backend.stop()`,
  `CANCEL ALL` on SSIP). Resume re-extracts a chunk starting at the current
  `globalWordIndex`, i.e. mid-sentence from the highlighted word.
- **Multi-byte text** (CJK, emoji): `_onProgress` assumes backend `charOffset`s
  are Dart string (UTF-16) indices into `spokenText`. Not verified across
  platforms; normalise there if highlights drift.
- **Linux highlights are timer-estimated.** True accuracy would need
  `<mark name="wN"/>` between tokens plus handling `703 INDEX_MARK` (currently
  ignored), which most output modules don't implement.
- **Word-level highlight is effectively Google-TTS-only on Android.** It needs
  the engine to emit `UtteranceProgressListener.onRangeStart`, which is
  optional (the engine must call `SynthesisCallback.rangeStart`). Google TTS
  does; most third-party engines (SherpaTTS included) don't, so the highlight
  only jumps at chunk completions. There's no capability query; a possible
  improvement is a timer-estimated fallback (like Linux) when no
  `onRangeStart` arrives during the first utterance.
- **SherpaTTS (`org.woheller69.ttsengine`)** has structural limits, not bugs
  on our side: no `rangeStart`; no named voices (`setVoice` is a silent no-op,
  selection is per downloaded model); it ignores the app's speech rate unless
  its own "apply system speed" toggle is on; and neural synthesis is blocking,
  so utterances start late (seconds on a cold start). Usable, but the stock
  Google engine is the better default.
