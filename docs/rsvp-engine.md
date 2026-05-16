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
  multiplier = smartTiming ? word.timingMultiplier : 1.0
  _nextWordAt = _elapsed + baseMs * multiplier
```

## ORP (Optimal Recognition Point)

File: `lib/core/utils/orp_calculator.dart`

Position of the focus letter within the word (~30% from the start). Lookup table for 1-13 chars, formula `floor(len * 0.35)` for longer ones. Unicode-aware (handles PT-BR accents).

| Length | ORP Index | Example |
|---|---|---|
| 1 | 0 | **e** |
| 2-3 | 0 | **o**f |
| 4-5 | 1 | w**o**rld |
| 6-8 | 2 | re**a**ding |
| 9-11 | 3 | exh**a**usted |
| 12-13 | 4 | exha**u**sted! |
| 14+ | floor(len * 0.35) | — |

## Word Timing

File: `lib/core/utils/word_timing.dart`

Multipliers applied on top of `60000ms / WPM`:

| Context | Multiplier |
|---|---|
| Short word (<=3) | 0.9x |
| Long word (>6) | +0.1x per extra char |
| `.` `!` `?` | 2.0x |
| `,` `;` | 1.5x |
| `:` | 1.8x |
| `...` | 2.5x |
| Paragraph start | 1.5x |
| Chapter start | 3.0x |

Final clamp: 0.5x — 5.0x. The `smartTiming` toggle disables all the multipliers.

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

In `RsvpWordDisplay`, if the word does not fit the available width at the configured font size, the font shrinks by 2px at a time (minimum 16px) until it fits. Prevents cropping for long Portuguese words.

## Reading modes

3 modes in the `ReaderMode` enum:

- **`rsvp`**: single word with ORP. Active during play.
- **`scroll`**: full text with a highlight (rounded pill with a soft glow). Active when paused or when opening a book. Supports tap-to-seek on any word.
- **`ereader`**: full text without highlight, no controls. Traditional ebook reading. Toggleable via the top bar icon.

Transitions:
- Play/pause: alternates `rsvp` ↔ `scroll`. `AnimatedSwitcher` with a 200ms fade.
- Toggle ereader (via top bar): `engine.toggleEreaderMode()`. On enter, the ticker pauses and progress is saved. On exit, it returns to `scroll`.
- `RsvpControls` is only rendered when `mode != ereader`.

### Velocity-based scroll tracking

`ContextScrollView` tracks scroll velocity via `ScrollUpdateNotification.scrollDelta` and smooths it with an EMA (`0.7 * previous + 0.3 * new`). 80ms throttle between updates. Granularity depends on `|velocity|`:

| Velocity | Stepping |
|---|---|
| `< 0.3` | dead zone (ignored) |
| `0.3 - 8` | word by word |
| `8 - 25` | sentence by sentence (`.` `!` `?`) |
| `> 25` | paragraph by paragraph |

Paragraph and sentence boundaries are precomputed into `_paragraphBoundaries` and `_sentenceBoundaries` when the list is built (binary search on lookup). Catch-up: if the highlight leaves the viewport, it snaps to the paragraph centred at 40% of the height.

The scroll view uses a local `ValueNotifier<int>` for the highlight (not Riverpod) — avoids the rebuild cascade during scroll. Sync with the engine only happens on `ScrollDirection.idle`.

## Focus line

Optional horizontal line below the word in RSVP mode. Controlled by two flags in `DisplaySettings`:

- `showFocusLine` (default `true`): toggles the line on/off
- `focusLineShowsProgress` (default `true`): track + filled portion (using `orpColor`) proportional to `globalWordIndex / totalWords`

When `focusLineShowsProgress = false`, the line renders as a solid `wordColor.withAlpha(60)` — purely a visual anchor for the eye.

The line spans edge to edge (`left: 0, right: 0`). For that reason `RsvpWordDisplay` applies the full horizontal margin internally for the word (`margin = 32`) — the parent widget MUST NOT add lateral padding, otherwise the line would be visibly inset from the screen edges.
