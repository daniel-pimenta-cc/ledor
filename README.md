# Ledor

**Words come to you.** *Ledor* is Portuguese for someone who reads aloud to another person — and that's what this app does: instead of your eyes chasing the words, the words come to your eyes.

An open-source EPUB and web-article speed reader built with Flutter, running on **Android, iOS, and Linux desktop**. Formerly known as *RSVP Reader*.

Words are displayed one at a time at a configurable WPM, with the **Optimal Recognition Point (ORP)** highlighted so your eye doesn't need to saccade — letting you read faster while preserving comprehension.

## Features

- **Three reading modes**
  - `rsvp` — single-word display with ORP highlight, active during playback
  - `scroll` — full text with current-word highlight; pauses and supports tap-to-seek
  - `ereader` — traditional continuous reading without highlights or controls
- **Two content sources, one pipeline** — import EPUB files or save any web article by URL (or share sheet on Android); both end up as the same tokenized read
- **Smart timing** — longer pauses on punctuation, paragraph starts, chapter starts, and long words (all pre-computed at import, zero work in the hot loop)
- **Ramp-up** — starts at 70% of target WPM and accelerates over the first 30 words to help your eyes warm up
- **Chapter-aware progress slider** with visual chapter markers and title tooltips while dragging
- **Velocity-based scroll tracking** — slow scroll moves word-by-word, faster scroll steps by sentence or paragraph
- **Lock + recenter overlay** in scroll mode — pin the highlighted word in place so the engine keeps advancing without your hand reaching for it; tap to recenter when you scrolled away
- **Configurable focus line** below the word (plain anchor or progress-bar style)
- **Fully customizable theme** — colors, fonts (Google Fonts), sizes, and layout positions, with live preview
- **Reading stats** — local per-session telemetry feeds a weekly/monthly dashboard (fl_chart) with words-per-day, time, and WPM trend charts
- **Shareable monthly recap** — last.fm-style 9:16 image with finished + in-progress books, exported as PNG via share sheet
- **Book completion celebration** — automatic recap on the last word of a book with time/words/sessions/WPM stats, a 0-5 star rating, and an optional shareable card. Also reachable manually from the library (long-press a finished book) and from the reader's "Finish book" button for in-progress books where the tail is acknowledgements
- **Bilingual UI** — English and Brazilian Portuguese (PT-BR)
- **Offline-first** — books and progress stored locally in SQLite via Drift
- **Google Drive sync (optional)** — library, reading progress, display settings, ratings, and reading sessions sync across devices through a user-owned `RSVP Reader/` folder on Drive (`drive.file` scope, so the app only sees files it created). Sharded manifest pushes only the shards that changed. Available on Android and Linux desktop
- **Linux desktop support** — full GTK build with drag-and-drop for EPUB/URL imports and keyboard shortcuts (`Space`/`←→`/`↑↓`/`Esc`)
- **Unicode-aware ORP calculation** — handles Portuguese accents and punctuation correctly

## Screenshots

| Library | RSVP mode | Scroll mode | Settings |
|---|---|---|---|
| ![Library](screenshots/library.jpg) | ![RSVP mode](screenshots/rsvp-mode.jpg) | ![Scroll mode](screenshots/scroll-mode.jpg) | ![Settings](screenshots/settings.jpg) |

## Getting Started

### Requirements

- Flutter SDK `^3.10.1`
- Android Studio / Xcode for device builds
- On Linux, `lld` must be installed to run tests (`sudo apt install lld`)

### Install & run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # generate Drift + Freezed code
flutter gen-l10n                                          # generate i18n bindings
flutter run                                               # run on device/emulator
```

### Other useful commands

```bash
flutter analyze                   # static analysis
flutter test test/                # unit tests
flutter build apk --release       # release Android build
flutter build ios --release       # release iOS build
```

### Google Drive sync (optional)

The app syncs the library manifest, reading progress, display settings, ratings,
and per-session reading stats through a `RSVP Reader/` folder it creates in your
own Google Drive. The reading features all work without it — this is only if
you want the sync button on the Settings screen to actually connect.

Available on **Android** (via `google_sign_in` + Google Play Services) and on
**Linux desktop** (via a loopback OAuth flow opened in the system browser).
Both platforms hit the same Drive folder when wired to the same OAuth client.

Because Google OAuth ties the credentials to a specific Cloud project + Android
signing key, if you clone this repo and try to sign in, you'll get
`PlatformException(sign_in_failed, …ApiException: 10)` (DEVELOPER_ERROR). Fix by
provisioning your own OAuth client:

1. Create a project at https://console.cloud.google.com/ and enable the **Google
   Drive API**.
2. **OAuth consent screen** → External → Testing. Add yourself as a Test User.
3. **Credentials → Create OAuth 2.0 Client ID → Web application**. Add
   `http://127.0.0.1` to **Authorized redirect URIs** (no port — Google ignores
   it for loopback IPs). This client_id is what desktop uses directly, and what
   Android passes to `google_sign_in` as `serverClientId` so both platforms see
   the same Drive folder.
4. **Credentials → Create OAuth 2.0 Client ID → Android** (in the same project):
   - Package name: `com.pimenta.ledor` (or your fork's `applicationId`
     from `android/app/build.gradle.kts`).
   - SHA-1: your debug keystore fingerprint. Get it with:
     ```bash
     keytool -list -v -keystore ~/.android/debug.keystore \
       -alias androiddebugkey -storepass android -keypass android | grep SHA1
     ```
   - No client secret needed.
5. For Linux desktop: copy `.env.example` → `.env` and paste the Web client_id +
   client secret. The file is gitignored; `flutter_dotenv` loads it at startup.
   Without both values present, the Sync section is hidden in Settings.

Scope used: `https://www.googleapis.com/auth/drive.file` (the app only sees
files it created — never your other Drive contents).

Android needs Google Play Services on the device/emulator (use a Play-image
emulator, not AOSP). See [docs/linux-desktop.md](docs/linux-desktop.md#google-drive-sync)
for the desktop-side details and [docs/library-sync.md](docs/library-sync.md)
for the sync pipeline + merge rules.

## Architecture

Feature-based **Clean Architecture** with Riverpod state management. Each feature owns its own `domain/`, `data/`, and `presentation/` folders.

```
lib/
  core/         # theme, routing, constants, utils, platform_capabilities, share handlers
  database/     # Drift/SQLite: books, reading_progress, reading_session, cached_tokens,
                # sync_import_failures
  features/
    book_library/    # book grid + import FAB, master-detail on tablet landscape
    epub_import/     # EPUB parsing pipeline -> WordToken[] cached in SQLite
    article_import/  # URL fetch -> readability -> WordToken[] (same persistence as EPUB)
    library_sync/    # Drive sync gateway, auth backends, sharded manifest service
    rsvp_reader/     # RSVP engine (Ticker), display widgets, controls, settings sheet
    reading_stats/   # session aggregations, weekly/monthly dashboards, share cards
    settings/        # full-screen settings wrapping the shared display panel
  l10n/         # ARB files (en, pt) + generated
```

**Key concept — `WordToken`:** every word of every book is pre-processed at import time with its ORP index and timing multiplier already calculated. The RSVP engine does *no* computation inside the per-word tick, keeping playback smooth at 600+ WPM.

See [docs/architecture.md](docs/architecture.md) and [docs/rsvp-engine.md](docs/rsvp-engine.md) for detailed documentation on the data flow, state management, ORP math, smart timing multipliers, ramp-up, and velocity-based scroll stepping. [docs/reading-stats.md](docs/reading-stats.md) covers the reading-session model, stats dashboard, and the monthly recap + completion share pipelines. [docs/library-sync.md](docs/library-sync.md) documents the Drive sync pipeline — manifest format, merge rules, tombstone handling, and the DateTime / cache invariants.

## Tech stack

- **Flutter 3.x** / **Dart**
- **Riverpod 2** (state, no codegen — avoids conflict with `drift_dev` / `source_gen`)
- **Drift** over SQLite for persistent storage
- **SharedPreferences** for display/theme settings
- **epub_pro** for EPUB parsing
- **go_router** for navigation
- **google_fonts** + **flex_color_picker** for theming
- **freezed** for immutable data classes

## Credits

- RSVP and ORP concepts are based on established speed-reading research (e.g. Spritz-style presentation). This project implements them with its own ORP lookup table, tokenizer, and timing heuristics tuned for Portuguese and English.
- Open-source libraries listed in [pubspec.yaml](pubspec.yaml).

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, conventions, and PR guidelines.

## License

[MIT](LICENSE) © 2026 Daniel Pimenta
