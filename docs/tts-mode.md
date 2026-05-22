# TTS mode (text-to-speech)

Fourth reader mode alongside RSVP / scroll / ereader. The engine drives the
narration through a TTS backend; the scroll view's existing highlight pill
tracks the spoken word so users see what they hear.

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
        ├── FlutterTtsBackend       ← Android / iOS / macOS / Windows / Web
        │    (flutter_tts package, setQueueMode(1) for pipelined chunks)
        │
        ├── SpeechdSocketBackend    ← Linux desktop (preferred)
        │    (persistent Unix socket to speech-dispatcher; daemon queues)
        │
        └── SpeechDispatcherBackend ← Linux fallback
             (Process.start('spd-say', …) — used when the socket is absent)

  TtsAudioHandler                  ← lib/features/rsvp_reader/data/services/tts_audio_handler.dart
        (audio_service bridge — foreground service + lockscreen controls)
```

Backend selection happens in `ttsBackendProvider`
(`lib/features/rsvp_reader/presentation/providers/tts_backend_provider.dart`):
- Linux with a running `speech-dispatcher` socket → `SpeechdSocketBackend`
- Linux without the socket → `SpeechDispatcherBackend` (spd-say CLI)
- Everywhere else → `FlutterTtsBackend`

`TtsPlayer` is the new orchestration layer. It owns a small queue of
pre-extracted `SentenceSegment`s and uses `TtsQueueMode.add` so the
backend (which on Android/iOS forwards to `flutter_tts.setQueueMode(1)`,
and on Linux forwards to a single open daemon connection) stitches
chunks together with no audible gap. Without this, every chunk
boundary cost ~200–500ms of IPC + engine start-up.

## Engine integration

`RsvpEngineNotifier` keeps the RSVP path (Ticker-driven) and the TTS path
in the same notifier so reading sessions, progress saves, and the
end-of-book `finishTicket` semantics fire uniformly. TTS-specific
playback is delegated to `TtsPlayer`; the engine only manages state
transitions, session bookkeeping, and audio-handler binding.

Key methods:

- `enterTtsMode()` — flushes any in-flight RSVP session, lazy-constructs
  the player, calls `player.init()`, pushes content + settings, fires
  `player.applySettings()` so the backend is ready for previews. Doesn't
  play. Also binds the engine to the lockscreen `TtsAudioHandler` so
  background controls show up.
- `play()` — branches on `state.mode`. In TTS mode it asks the player to
  play from `state.globalWordIndex`. The "already at the last word"
  guard from the RSVP path is *not* applied — the player's
  `onBookFinished` callback handles end-of-book.
- `pause()` — in TTS mode it calls `player.pause()`, keeps `mode == tts`
  (so the UI stays on the scroll-with-highlight view), and runs the
  same `_flushSession()` + `_saveProgress()` that the RSVP path uses.
- `seekToWord()` — forwards to `player.seek(globalIndex)`. The player
  drains its queue and rebuilds the pipeline from the new position.
- Player callbacks (`onWordAdvance`, `onBookFinished`, `onError`) drive
  the engine state and session counters.

### TtsPlayer pipeline

The player extracts up to `_effectiveLookahead` segments (2 when the
backend can pipeline, 1 otherwise) and pushes them onto the backend
with `TtsQueueMode.add`. While segment N plays, segment N+1 is already
queued — the platform engine plays them back to back with no audible
gap.

Backends declare their capability via `TtsBackend.canPipeline`:

- `flutter_tts` → true (`setQueueMode(1)`).
- `SpeechdSocketBackend` → true (daemon queues utterances).
- `SpeechDispatcherBackend` (`spd-say` CLI fallback) → false (each
  speak spawns its own process and a second concurrent call would
  cancel the first).

Race safety: a `_generation` counter is bumped on every action that
should invalidate in-flight callbacks (`pause`, `seek`, `dispose`).
Each queued segment stores the generation in which it was enqueued;
stale progress / completion callbacks compare against the live counter
and bail. `_isPlaying` is set to `true` synchronously *before* any
`await` so a `pause()` issued in the same tick (typical when the user
taps pause right after play) actually stops the backend.

Settings dedup: the player tracks `_appliedEngineId` / `_appliedLanguage`
/ `_appliedVoiceName` / `_appliedPitch` / `_appliedRate` per-field, so
a slider that re-emits the same value (or `applySettings()` called
back-to-back during init + first speak) doesn't burn IPC re-pushing
unchanged settings. Each field advances *after* its individual `await`
succeeds, so a half-applied snapshot (when `pause` cancels mid-stream)
still leaves the backend coherent on the next push.

Stall detection: every `onProgress` callback updates `_lastProgressAt`.
`restartIfStalled()` (called from the screen's
`didChangeAppLifecycleState(resumed)`) fires a full restart only when
the last heartbeat is older than `_stallThreshold` (10s). A null
heartbeat (paused or never started) is treated as healthy — no
spurious restarts when the user just opened the reader.

## Sentence extraction

`extractSentenceFrom(chapters, startGlobalIndex)`
(`domain/utils/sentence_extractor.dart`) walks tokens linearly and stops
on:

1. A speakable token ending with `.`, `!`, `?`, or `…` (terminator
   included in the segment).
2. The next token starting a new chapter (the chapter title's first word
   belongs to the *next* segment so the pause lands at the seam).
3. A safety cap (`kSentenceMaxTokens = 80`) — protects against bullet
   lists without terminal punctuation.

Image tokens are part of the range (`endGlobalIndexExcl` includes them)
but never enter the spoken string. The highlight skips silently.

## Speech rate

TTS uses an independent audiobook-style rate scale rather than mapping
the user's RSVP WPM target onto a synth rate. The two never converted
intuitively — WPM is fundamentally an RSVP concept (a deterministic
frame interval), while TTS rate scales the synth's natural cadence,
which varies by voice. Users intuit "1.0x / 1.25x / 1.5x" instantly;
"300 WPM" was an awkward translation.

```
rate = DisplaySettings.ttsRate, clamped to [0.5, 3.0]
```

The engine forwards this directly to `TtsBackend.setRate(rate)` on every
`speak()` call. Backends translate to native units:

- `flutter_tts.setSpeechRate(rate)` — clamped to `[0.1, 2.0]` internally
  (some platforms cap below 3.0; rates above the cap saturate).
- `spd-say -r <int>` — `((rate - 1.0) * 50).clamp(-100, +100)`.

The transport row swaps the `WpmCapsule` (RSVP/scroll modes) for the
`TtsRateCapsule` (TTS mode) so the speed control always shows the
appropriate scale. Preset chips: `0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 1.75
/ 2.0 / 2.5 / 3.0`. The `WpmCapsule` step (+/- 25 WPM) becomes 0.25x for
the rate capsule.

`setWpm` does **not** propagate to the TTS backend — only `setTtsRate`
does. Switching modes preserves both settings independently.

## Linux backend (`SpeechDispatcherBackend`)

Uses the `spd-say` CLI that ships with `speech-dispatcher` (default on
almost every Linux desktop distro). Each `speak()` spawns a process:

```
spd-say -w -r <int -100..+100> -p <int -100..+100> -l <iso> [-y <voice>] "text"
```

`-w` keeps the process alive until the audio finishes; we await its
`exitCode` to detect completion. Rate and pitch are mapped from the
engine-agnostic `[0.3, 2.5]` and `[0.5, 2.0]` ranges respectively.

### Emulated word boundaries

`spd-say` does not expose progress callbacks. We approximate them with a
`Timer.periodic` running at the cadence implied by the configured WPM:

```
periodMs = 60000 / (200 * rate)
```

For a target of 300 WPM (rate ≈ 1.5), the timer fires every ~133 ms.
Drift accumulates ±200 ms across long sentences — acceptable for a
visual highlight, audible side-by-side comparison shows reasonable sync.

### Detection

`init()` calls `which spd-say` and throws `TtsUnavailableException` when
the binary is missing. The reader surfaces this via a localised snackbar
pointing the user to `sudo apt install speech-dispatcher` (or the
equivalent on their distro).

## UI summary

| Surface | Widget | Notes |
|---|---|---|
| Top-bar mode toggle | `ReaderModeMenu` | `PopupMenuButton` with radio-list of three options (RSVP / E-reader / TTS). `ReaderMode.scroll` collapses under "RSVP" since it's just the paused state of the RSVP reading experience. |
| Mode area in TTS | `ContextScrollView(showHighlight: true)` | Same surface used by `ReaderMode.scroll`; the engine's progress callback drives the highlight. |
| Transport row | `RsvpControls` | `ControlsTransportRow` takes a `speedControl` widget; the parent swaps `WpmCapsule` for `TtsRateCapsule` based on `state.mode`. |
| Settings sheet | `DisplaySettingsPanel._buildTtsSection` | Voice picker (opens `TtsVoicePickerSheet`) and pitch slider. (The rate lives in the transport row, not here — same as the WPM selector.) |
| Voice picker | `TtsVoicePickerSheet` | `DraggableScrollableSheet` listing voices grouped by locale; each row has a preview button that speaks `ttsVoicePreviewSample` through the backend without committing. |

## Persistence and sync

Four new fields on `DisplaySettings`:

- `ttsLanguage` (`String`, default `'en-US'`)
- `ttsVoiceName` (`String?`, default `null` — falls back to first voice
  of the locale)
- `ttsPitch` (`double`, default `1.0`)
- `ttsRate` (`double`, default `1.0`, range `[0.5, 3.0]`)

All four persist to `SharedPreferences` via `DisplaySettingsNotifier`
and propagate through Drive sync via the existing
`displaySettingsToMap` / `displaySettingsFromMap` in
`LibrarySyncService`. When a synced `ttsVoiceName` doesn't exist on the
local device, the engine falls back to the locale's default voice but
preserves the name in storage so a round-trip to the original device
restores it.

## Reading sessions

TTS sessions log to `reading_session` exactly like RSVP sessions —
`_sessionStartedAt`, `_sessionStartWordIndex`, and `_wordsInSession` are
the same fields, and the threshold filters
(`computeSessionAvgWpm` requires ≥ 5 words and ≥ 3 s) apply uniformly.
The stats dashboard, monthly recap, and book completion screens pick
them up automatically.

## Background playback

`audio_service` hosts the TTS playback in a foreground service on
Android and in an `AVAudioSession(category=playback)` on iOS so the OS
doesn't kill the synthesiser when the user backgrounds the app. The
notification + lockscreen controls (rewind / play-pause / fastForward)
are driven by `TtsAudioHandler`:

- `main.dart` calls `AudioService.init(builder: TtsAudioHandler.new, …)`
  on platforms that report `PlatformCapabilities.supportsBackgroundAudio`
  (everywhere except Linux + Web). The result is injected via the
  Riverpod override `ttsAudioHandlerProvider`.
- `RsvpEngineNotifier._bindAudioHandler` registers a callback bundle
  (`TtsAudioSource`) on `enterTtsMode`, calls `setActiveBook` with the
  book title / author for the notification, and pushes
  `updatePlaybackState(playing: …)` on every play/pause/error/finish.
- The handler forwards play/pause/skip from the OS controls back to
  those same callbacks, so headphone clicks, bluetooth play/pause, and
  the lockscreen UI all drive the actual engine.
- `MainActivity` extends `AudioServiceActivity` (not plain
  `FlutterActivity`) so `MEDIA_BUTTON` intents reach the plugin. The
  manifest declares `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`,
  the `AudioService` service, and the `MediaButtonReceiver`.
- iOS adds `UIBackgroundModes: audio` in `Info.plist`. The flutter_tts
  backend also calls `setIosAudioCategory(playback, …, spokenAudio)`
  during `init()` so the audio routes correctly through the shared
  AVAudioSession.

Linux and Web don't run the audio handler — the engine still works on
those platforms but TTS pauses when the OS suspends the app.

## TTS engine picker

`TtsBackend.getEngines()` lists every alternative engine the backend
knows about; `setEngine(id)` switches which one new utterances use:

- **Android**: `flutter_tts.getEngines` enumerates installed
  `TTS_SERVICE` providers (Google TTS, Samsung TTS, Pico, …).
- **Linux**: `LIST OUTPUT_MODULES` via the SSIP socket (or `spd-say -O`
  on the legacy backend) — these are speech-dispatcher's output modules
  (`espeak-ng`, `festival`, `flite`, `rhvoice`).
- **iOS / macOS / Windows / Web**: returns an empty list — the OS
  bundles a single synthesiser.

UI:
- `TtsEnginePickerSheet` lists engines + a "System default" option.
  Selecting commits to `DisplaySettings.ttsEngineId` and the engine
  applies it on the next utterance.
- The row is hidden when the backend reports ≤1 engine, so iOS users
  don't see an empty picker.

`ttsEngineId` syncs through Drive like the other TTS settings; the
backend ignores an unknown id (falls back to the system default)
without losing the stored value, so a round-trip to the original
device restores it.

## Limitations and follow-ups

- **Sentence-level skip controls** are out of scope; the existing
  10-word skip buttons remain the only fast-skip primitive.
- **Multi-byte text** (CJK, emoji) may drift on Android because
  `flutter_tts` reports `charOffset` in UTF-16 code units while iOS uses
  characters. For latin scripts the two coincide; if multi-byte support
  becomes a need, normalise in `_onProgress`.
- **Linux pause/resume** does not preserve mid-sentence position —
  speech-dispatcher's `CANCEL` drops the current utterance. The player
  re-speaks the current sentence from `globalWordIndex` on resume.
- **SSML index marks on Linux**: word-boundary callbacks are still
  timer-emulated. Future work: insert `<mark name="wN"/>` between
  tokens and listen for `703 INDEX_MARK` events for true accuracy.
