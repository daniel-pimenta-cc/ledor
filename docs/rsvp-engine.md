# RSVP Engine

## Ticker vs Timer

Uses `Ticker` (not `Timer.periodic`). Advantages:
- Synced to the screen refresh rate (60fps)
- Automatically paused when the app goes to the background
- Higher precision at 600+ WPM (~100ms per word)

## Main loop

```
_onTick(elapsed):
  if elapsed >= _nextWordAt:
    _advanceWord()        // move to the next word
    _wordsInSession++     // counts toward ramp-up
    _scheduleNext()       // computes when to show the next one

_scheduleNext():
  effectiveWpm = _effectiveWpm()          // with ramp-up
  baseMs = 60000 / effectiveWpm
  multiplier = computeWordIntervalMultiplier(currentWord, nextWord, settings)
  _nextWordAt = _elapsed + baseMs * multiplier
```

`computeWordIntervalMultiplier` multiplies three sources and clamps the product to `[0.5, 10.0]`:
1. the token's import-time `timingMultiplier` (see Word Timing), or 1.0 when `smartTiming` is off;
2. `DisplaySettings.sentencePauseMultiplier` when the current word ends a sentence (`wordEndsSentence`);
3. `DisplaySettings.chapterPauseMultiplier` when the next word starts a new chapter, so the pause sits at the seam.

## ORP (Optimal Recognition Point)

File: `lib/core/utils/orp_calculator.dart`

Position of the focus letter within the word (~30% from the start). Only letters and digits count toward the length (leading quotes/brackets are skipped, but the returned index is into the full string). Lookup table for 1-13 chars, formula `floor(len * 0.35)` for longer ones. Unicode-aware (handles PT-BR accents).

| Length | ORP Index | Example |
|---|---|---|
| 1-2 | 0 | **o**f |
| 3-5 | 1 | w**o**rld |
| 6-8 | 2 | re**a**ding |
| 9-11 | 3 | exh**a**usted |
| 12-13 | 4 | acco**m**plished |
| 14+ | floor(len * 0.35) | — |

## Word Timing

File: `lib/core/utils/word_timing.dart`

Multipliers applied on top of `60000ms / WPM`:

| Context | Multiplier |
|---|---|
| Short word (<=3 letters/digits) | 0.9x |
| Long word (>6) | 1.0 + 0.1x per extra char, capped at 2.0x |
| `.` `!` `?` | 2.0x |
| `,` `;` | 1.5x |
| Leading dash (`— word` unit, see Dialogue dashes) | 1.5x |
| `:` | 1.8x |
| `...` / `…` | 2.5x |
| Closing quote or `)` | 1.3x |
| Paragraph start | 1.5x |
| Chapter start | 3.0x |

Length, punctuation, dash and structural factors multiply together. Final clamp: 0.5x — 5.0x. The `smartTiming` toggle disables these per-word multipliers (the sentence/chapter pauses above still apply).

## Ramp-Up

Optional (toggle in settings, default ON). On play:
- Starts at `rampUpStartFraction` (70%) of the target WPM
- Follows an ease-out cubic curve over `rampUpWords` (30) words
- Resets on every play

```
t          = wordsInSession / rampUpWords
eased      = 1 - (1 - t)^3
effectiveWpm = startWpm + (targetWpm - startWpm) * eased
```

The eased curve spends most of the window near the target (at the
midpoint it is already 87.5% of the way there), so the final convergence
is gentle instead of a hard linear hand-off — used to feel abrupt at
high target WPMs.

Constants live in `AppConstants`.

## Play pre-roll

When `play()` fires, the engine arms `_nextWordAt` to
`AppConstants.playPreRollDelay` (500ms) instead of `Duration.zero`. The
first word stays on screen long enough for the scroll → rsvp
`AnimatedSwitcher` fade (`AppDurations.slow`, 320ms) to finish and for
the eyes to settle before the engine starts advancing. The pre-roll is
unconditional — every play, including a quick play after a pause, gets
the same head-start.

## Auto-Scale for long words

In `RsvpWordDisplay`, the font shrinks by 2px at a time until the ORP letter sits exactly on the anchor, but only down to `rsvpAnchorHoldMinScale` (70%) of the configured size. Past that, it shrinks only until the word fits the width (minimum `rsvpMinFontSize`, 16px) and the word is shifted into the margins, with the indicator marks following the letter instead of staying on the anchor. Keeps long Portuguese/Russian words readable without moving the fixation point for typical words.

## Dialogue dashes

A standalone dialogue dash (`—`, `–`, `-`, `―`, `‒`, `--`) is never flashed on its own in RSVP: `_advanceWord` swaps it and the next word of the same paragraph for one `— word` unit built by `mergeDialogueDash` (ORP and timing recomputed, +1.5x beat) and steps the cursor over both. A next word starting with a digit (`10 - 20`) stays split. This is display-only on purpose: the cached tokens keep the dash as its own index, so progress, bookmarks and Drive sync (global word indices) never shift, and books imported before it get it too. Seeking straight onto a dash still shows it alone for one word.

## Reading modes

`ReaderMode` has four values, three of them user-facing modes:

- **`rsvp`**: single word with ORP. Active during play.
- **`scroll`**: not a separate mode, the paused view of RSVP — full text with a highlight (rounded pill with a soft glow). Default when opening a book. Supports tap-to-seek on any word.
- **`ereader`**: full text without highlight, no controls. Traditional ebook reading.
- **`tts`**: same highlighted full-text view as `scroll`, but play/pause drives the TTS player instead of the ticker (see [tts-mode.md](tts-mode.md)).

Transitions:
- Play/pause: alternates `rsvp` ↔ `scroll`. `AnimatedSwitcher` with a fade (`AppDurations.slow`, 320ms). In `tts`, play/pause keeps `mode == tts`.
- `ReaderModeFab` (bottom-left pill) calls `switchReaderMode`, which exits the current mode (`exitEreaderMode` / `exitTtsMode`) and enters the new one (`enterEreaderMode` / `enterTtsMode`; picking RSVP lands on `scroll`). Entering ereader stops playback, flushes the session, and saves progress.
- The mode is persisted per book (`reading_progress.readerMode`, `scroll` stored as `'rsvp'`) and restored on load.
- `RsvpControls` is only rendered when `mode != ereader`.

### Velocity-based scroll tracking

`ContextScrollView` tracks scroll velocity via `ScrollUpdateNotification.scrollDelta` and smooths it with an EMA (`0.7 * previous + 0.3 * new`). 80ms throttle between updates. Granularity depends on `|velocity|`:

| Velocity | Stepping |
|---|---|
| `< 0.3` | dead zone (ignored) |
| `0.3 - 8` | word by word |
| `8 - 25` | sentence by sentence (`wordEndsSentence`) |
| `> 25` | paragraph by paragraph |

Paragraph and sentence boundaries are precomputed into `_paragraphBoundaries` and `_sentenceBoundaries` when the list is built (binary search on lookup). Catch-up: if the highlight leaves the viewport, it snaps to the paragraph centred at 40% of the height.

The scroll view uses a local `ValueNotifier<int>` for the highlight (not Riverpod) — avoids the rebuild cascade during scroll. Sync with the engine only happens on `ScrollDirection.idle`. While the lock overlay is on (and during TTS playback, an implicit lock), scrolling only moves the viewport: no stepping, no seek. In ereader (no highlight) every scroll stop derives the position from the viewport instead.

## Focus line

Optional horizontal line below the word in RSVP mode. Controlled by two flags in `DisplaySettings`:

- `showFocusLine` (default `true`): toggles the line on/off
- `focusLineShowsProgress` (default `true`): track + filled portion (using `orpColor`) proportional to `globalWordIndex / totalWords`

When `focusLineShowsProgress = false`, the line renders as a solid `wordColor.withAlpha(60)` — purely a visual anchor for the eye.

The line spans edge to edge (`left: 0, right: 0`). For that reason `RsvpWordDisplay` applies the full horizontal margin internally for the word (`ResponsiveDefaults.rsvpWordMargin`: 32px on phones, 48/64px on larger screens) — the parent widget MUST NOT add lateral padding, otherwise the line would be visibly inset from the screen edges.
