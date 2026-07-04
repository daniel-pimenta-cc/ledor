# Contributing to Ledor

Thanks for your interest in contributing. This document explains how to set up the project, the conventions the codebase follows, and the PR workflow.

## Development setup

### Prerequisites

- Flutter SDK `^3.10.1`
- Android Studio and/or Xcode if building for a physical device
- On Linux, install `lld` to run the test suite: `sudo apt install lld`

### First-time setup

```bash
git clone https://github.com/<your-fork>/ledor.git  # replace <your-fork> with your GitHub username
cd ledor
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter run
```

### Code generation

Some files are generated — **do not edit `.g.dart` or `.freezed.dart` files by hand**. After changing any of the following, re-run the corresponding generator:

| You changed... | Run |
|---|---|
| A Drift table or DAO | `dart run build_runner build --delete-conflicting-outputs` |
| A class annotated with `@freezed` | `dart run build_runner build --delete-conflicting-outputs` |
| An ARB file in `lib/l10n/` | `flutter gen-l10n` |

## Project conventions

### Architecture

The project follows **feature-based Clean Architecture**. Every feature lives under `lib/features/<feature>/` with its own `domain/`, `data/`, and `presentation/` layers. Shared utilities go in `lib/core/`; database code lives in `lib/database/`.

Before adding new code, read [docs/architecture.md](docs/architecture.md) and [docs/rsvp-engine.md](docs/rsvp-engine.md) to understand the data flow.

### State management

- **Riverpod 2 without code generation** (we avoid `riverpod_generator` because `source_gen` conflicts with `drift_dev`).
- Providers are declared manually (`StateNotifierProvider`, `StreamProvider`, etc).
- Keep providers near the feature that owns them; only promote to `lib/core/` if truly shared.

### Internationalization (i18n)

- **Never hardcode user-facing strings** in Portuguese or English.
- All UI text must live in `lib/l10n/app_en.arb` and `lib/l10n/app_pt.arb` (both must be kept in sync).
- Access strings via `AppLocalizations.of(context)!.yourKey`.
- After editing ARB files, run `flutter gen-l10n`.

### Theming and display settings

- Colors, fonts, and sizes inside the reader come from `DisplaySettings` (persisted via `SharedPreferences`), **not** from `ThemeData` constants. This lets users see a live preview of their choices.
- To add a new display or reading option:
  1. Add the field to `DisplaySettings` + its `copyWith` + the `load`/`save` in `DisplaySettingsNotifier`.
  2. Add the UI row to `display_settings_panel.dart` (used by both the reader bottom sheet and the full-screen settings screen).
  3. Add ARB strings in both `app_en.arb` and `app_pt.arb`.

### RSVP engine invariants

- Anything that would run per-word during playback must be **pre-computed at import time** and stored on the `WordToken`. The engine's hot loop (`_onTick`) must remain arithmetic-only.
- Do not use `Timer.periodic` for playback — the engine uses a `Ticker` for frame sync and background pausing.

### Code style

- Run `flutter analyze` before submitting — it must pass cleanly.
- Prefer `const` constructors whenever possible.
- Always `dispose()` controllers, `Ticker`s, `ValueNotifier`s, and stream subscriptions.
- Avoid `print` / `debugPrint` in committed code.
- Keep widgets focused; extract sub-widgets when a build method exceeds ~80 lines.

## Testing

- Unit tests for `lib/core/utils/` are **mandatory** for any change touching ORP, timing, tokenizer, or HTML stripping.
- The `HtmlStripper` must keep full coverage of the `_skipTags` set to prevent regressions where CSS/JS leak into the rendered text.
- Run tests with:
  ```bash
  flutter test test/
  ```
- Widget and integration tests are encouraged for new screens.

## Pull request workflow

1. **Fork** the repo and create a branch from `main`: `git checkout -b feat/short-description` or `fix/short-description`.
2. Make your change with focused commits. Commit messages in English, imperative mood (e.g. `Add chapter markers to progress slider`).
3. Run before pushing:
   ```bash
   flutter analyze
   flutter test test/
   ```
4. Open a PR with:
   - **What** the change does and **why**.
   - Screenshots or a short screen recording for UI changes.
   - Note any ARB keys added (reviewer will verify both PT and EN are present).
5. Keep the PR scoped to one concern — split larger work into multiple PRs when possible.

## Reporting bugs and requesting features

- **Bugs:** open a GitHub issue with steps to reproduce, expected vs. actual behavior, device/OS, and a sample EPUB if the issue depends on a specific file.
- **Feature requests:** describe the use case before proposing a specific implementation. Small ideas can also be added to [tasks.md](tasks.md) via PR.

## Code of conduct

Be respectful. Assume good intent. Review code, not people. Report abusive behavior by opening a private issue to the maintainer.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
