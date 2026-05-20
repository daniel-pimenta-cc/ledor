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
  TtsBackend (abstract)            ← lib/features/rsvp_reader/data/services/tts_backend.dart
        │
        ├── FlutterTtsBackend       ← Android / iOS / macOS / Windows / Web
        │    (flutter_tts package)
        │
        └── SpeechDispatcherBackend ← Linux desktop
             (Process.start('spd-say', …))
```

Backend selection happens in `ttsBackendProvider`
(`lib/features/rsvp_reader/presentation/providers/tts_backend_provider.dart`):
Linux falls through to `SpeechDispatcherBackend`; every other supported
platform uses `FlutterTtsBackend`.

## Engine integration

`RsvpEngineNotifier` keeps the RSVP path (Ticker-driven) and the TTS path
in the same notifier so reading sessions, progress saves, and the
end-of-book `finishTicket` semantics fire uniformly. Key methods:

- `enterTtsMode()` — flushes any in-flight RSVP session, lazy-initialises
  the backend, applies persisted voice/pitch/language/rate. Doesn't play.
- `play()` — branches on `state.mode`. In TTS mode it calls
  `_startTtsSpeak()` instead of starting the ticker. The "already at the
  last word" guard from the RSVP path is *not* applied — the last
  sentence still needs to be spoken; the completion callback bumps
  `finishTicket`.
- `pause()` — in TTS mode it stops the backend, keeps `mode == tts`
  (so the UI stays on the scroll-with-highlight view), and runs the
  same `_flushSession()` + `_saveProgress()` that the RSVP path uses.
- `seekToWord()` — when called while TTS is playing, stops the current
  utterance, bumps the generation counter, and re-starts speak from the
  new index.
- `_startTtsSpeak()` — extracts a `SentenceSegment`
  (`sentence_extractor.dart`) starting at `globalWordIndex`, skipping
  image tokens silently, and hands the spoken string to the backend.
- `_onTtsProgress(charOffset, charEnd, word)` — translates the engine's
  reported char position back to a global word index via the
  `tokenCharOffsets` precomputed by the extractor. Only advances forward
  (callbacks can arrive slightly out of order on some engines).
- `_onTtsCompletion()` — either queues the next sentence or, when the
  segment closed the book, bumps `finishTicket` once.

### Race safety: `_ttsSpeakGeneration`

Every action that should cancel an in-flight speak — `pause`, `stop`,
`exitTtsMode`, `seekToWord`, `enterEreaderMode`, `dispose` — bumps
`_ttsSpeakGeneration`. The `_startTtsSpeak` body captures the counter
before any `await`; if the value changes while it was suspended, the
caller bails before issuing further side effects.

Without this, an awaited `setRate` finishing after the user paused would
race the engine's `_flushSession` cleanup.

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

## Limitations and follow-ups

- **Background playback** (lockscreen MediaSession, Android foreground
  service, iOS `AVAudioSession`) is out of scope for this pass. Tracked
  as a separate item in `tasks.md`.
- **Sentence-level skip controls** are out of scope; the existing
  10-word skip buttons remain the only fast-skip primitive.
- **Multi-byte text** (CJK, emoji) may drift on Android because
  `flutter_tts` reports `charOffset` in UTF-16 code units while iOS uses
  characters. For latin scripts the two coincide; if multi-byte support
  becomes a need, normalise in `_onTtsProgress`.
- **Linux pause/resume** does not preserve mid-sentence position —
  `spd-say` has no real pause. The engine re-speaks the current
  sentence from `globalWordIndex` on resume.
