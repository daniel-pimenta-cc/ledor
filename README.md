<p align="center">
  <img src="assets/icon/icon_final_transparent.png" width="110" alt="Ledor app icon">
</p>

<h1 align="center">Ledor</h1>

<p align="center"><strong>Words come to you.</strong></p>

<p align="center">
  <a href="https://github.com/daniel-pimenta-cc/ledor/actions/workflows/ci.yml"><img src="https://github.com/daniel-pimenta-cc/ledor/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/daniel-pimenta-cc/ledor/releases/latest"><img src="https://img.shields.io/github/v/release/daniel-pimenta-cc/ledor" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/daniel-pimenta-cc/ledor" alt="License: MIT"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter 3.x"></a>
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20Linux%20%7C%20iOS-4c8b5e" alt="Platforms: Android, Linux, iOS">
  <a href="https://ledor.app"><img src="https://img.shields.io/badge/site-ledor.app-E55324" alt="Website"></a>
</p>

*Ledor* is Portuguese for someone who reads aloud to another person — and that's what this app does: instead of your eyes chasing the words, the words come to your eyes.

An open-source RSVP reader for EPUB and web articles, built with Flutter and running on **Android, Linux desktop, and iOS**. Words are displayed one at a time at a configurable WPM, with the **Optimal Recognition Point (ORP)** highlighted so your eye doesn't need to saccade — letting you read faster while preserving comprehension. Formerly known as *RSVP Reader*.

## Download

- **Android APK** and **Linux tarball**: grab the latest from [Releases](https://github.com/daniel-pimenta-cc/ledor/releases/latest).
- **iOS**: build from source (no App Store release yet).
- Try the interactive RSVP demo on the website: [ledor.app](https://ledor.app).

## Features

- **Three reading modes**
  - `rsvp` — single-word display with ORP highlight, active during playback
  - `ereader` — traditional continuous reading without highlights or controls
  - `tts` — text-to-speech narration with word-synced highlighting; keeps playing in the background with lockscreen media controls
  - The last mode used is remembered per book
- **Pause into the full text** — pausing RSVP or TTS drops you into a scrollable full-text view with the current word highlighted; tap any word to seek and continue from there
- **TTS that feels like an audiobook player** — system voices with human-friendly names ("English (UK) · Female 1" instead of `en-gb-x-fis-network`), engine and voice pickers, and playback speed from 0.5× to 3× independent of the RSVP WPM. On Linux it speaks through `speech-dispatcher` (e.g. Piper voices)
- **Two content sources, one pipeline** — import EPUB files or save any web article by URL (or share sheet on Android); both end up as the same tokenized read
- **Bookmarks** — long-press any word in any mode to bookmark it with a context snippet; synced across devices
- **Smart timing** — longer pauses on punctuation, paragraph starts, chapter starts, and long words (all pre-computed at import, zero work in the hot loop)
- **Ramp-up** — starts at 70% of target WPM and accelerates over the first 30 words to help your eyes warm up
- **Chapter-aware progress slider** with visual chapter markers and title tooltips while dragging
- **Velocity-based scroll tracking** — in the paused full-text view, slow scrolling moves word-by-word while faster scrolling steps by sentence or paragraph
- **Lock + recenter overlay** in the full-text view — pin the highlighted word in place so the engine keeps advancing without your hand reaching for it; tap to recenter when you scrolled away
- **Light + dark editorial themes** — warm "ink on paper" palettes with a system/light/dark toggle
- **Fully customizable reader** — colors, fonts (Google Fonts), sizes, layout positions, and a configurable focus line, all with live preview
- **Reading stats** — local per-session tracking feeds a weekly/monthly dashboard with words-per-day, time, and WPM trend charts
- **Shareable monthly recap** — last.fm-style 9:16 image with finished + in-progress books, exported as PNG via share sheet
- **Book completion celebration** — automatic recap on the last word of a book with time/words/sessions/WPM stats, a 0–5 star rating, and an optional shareable card. Also reachable manually from the library (long-press a finished book) and from the reader's "Finish book" button for in-progress books where the tail is acknowledgements
- **Bilingual UI** — English and Brazilian Portuguese (PT-BR)
- **Offline-first** — books and progress stored locally in SQLite via Drift
- **Google Drive sync (optional)** — library, reading progress, bookmarks, display settings, ratings, and reading sessions sync across devices through a user-owned `Ledor/` folder on Drive (`drive.file` scope, so the app only sees files it created). Sharded manifest pushes only the shards that changed. Available on Android and Linux desktop
- **Linux desktop support** — full GTK build with drag-and-drop for EPUB/URL imports and keyboard shortcuts (`Space`/`←→`/`↑↓`/`Esc`)
- **Unicode-aware ORP calculation** — handles Portuguese accents and punctuation correctly

## Screenshots

| Library | RSVP mode | Paused reader | Settings |
|---|---|---|---|
| ![Library](screenshots/library.jpg) | ![RSVP mode](screenshots/rsvp-mode.jpg) | ![Paused reader](screenshots/scroll-mode.jpg) | ![Settings](screenshots/settings.jpg) |

## Getting Started

### Requirements

- Flutter SDK `^3.10.1`
- Android Studio / Xcode for device builds
- On Linux, `lld` must be installed to run tests (`sudo apt install lld`)

### Install & run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # generate Drift code
flutter gen-l10n                                          # generate i18n bindings
flutter run                                               # run on device/emulator
```

### Other useful commands

```bash
flutter analyze                   # static analysis
flutter test test/                # unit tests
flutter test --coverage test/ && python3 tool/check_coverage.py --min 72  # coverage (CI gate)
flutter build apk --release       # release Android build
flutter build linux --release     # release Linux build
```

Releases are cut by pushing a `vX.Y.Z` tag — CI builds the signed APK and the Linux tar.gz.

### Google Drive sync (optional)

The app syncs the library manifest, reading progress, bookmarks, display settings,
ratings, and per-session reading stats through a `Ledor/` folder it creates in your
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
                # bookmarks, sync_import_failures
  features/
    book_library/    # book grid + import FAB, master-detail on tablet landscape
    epub_import/     # EPUB parsing pipeline -> WordToken[] cached in SQLite
    article_import/  # URL fetch -> readability -> WordToken[] (same persistence as EPUB)
    library_sync/    # Drive sync gateway, auth backends, sharded manifest service
    rsvp_reader/     # RSVP engine (Ticker), TTS player + backends, display widgets,
                     # controls, bookmarks, settings sheet
    reading_stats/   # session aggregations, weekly/monthly dashboards, share cards
    settings/        # full-screen settings wrapping the shared display panel
  l10n/         # ARB files (en, pt) + generated
```

**Key concept — `WordToken`:** every word of every book is pre-processed at import time with its ORP index and timing multiplier already calculated. The RSVP engine does *no* computation inside the per-word tick, keeping playback smooth at 600+ WPM.

See [docs/architecture.md](docs/architecture.md) and [docs/rsvp-engine.md](docs/rsvp-engine.md) for detailed documentation on the data flow, state management, ORP math, smart timing multipliers, ramp-up, and velocity-based scroll stepping. [docs/tts-mode.md](docs/tts-mode.md) covers the cross-platform TTS pipeline (flutter_tts + a speech-dispatcher socket backend on Linux). [docs/reading-stats.md](docs/reading-stats.md) covers the reading-session model, stats dashboard, and the monthly recap + completion share pipelines. [docs/library-sync.md](docs/library-sync.md) documents the Drive sync pipeline — manifest format, merge rules, tombstone handling, and the DateTime / cache invariants. [docs/linux-desktop.md](docs/linux-desktop.md) covers the desktop build, shortcuts, and drag-and-drop.

## Tech stack

- **Flutter 3.x** / **Dart**
- **Riverpod 2** (state, no codegen — avoids conflict with `drift_dev` / `source_gen`)
- **Drift** over SQLite for persistent storage
- **SharedPreferences** for display/theme settings
- **epub_pro** for EPUB parsing
- **go_router** for navigation
- **flutter_tts** + a speech-dispatcher (SSIP socket) backend for TTS, **audio_service** for background playback
- **google_sign_in** / **googleapis** (+ loopback OAuth on desktop) for Drive sync
- **fl_chart** for the stats dashboards, **share_plus** for PNG export
- **google_fonts** + **flex_color_picker** for theming

## Credits

- RSVP and ORP concepts are based on established speed-reading research (e.g. Spritz-style presentation). This project implements them with its own ORP lookup table, tokenizer, and timing heuristics tuned for Portuguese and English.
- Open-source libraries listed in [pubspec.yaml](pubspec.yaml).

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, conventions, and PR guidelines.

## License

[MIT](LICENSE) © 2026 Daniel Pimenta
