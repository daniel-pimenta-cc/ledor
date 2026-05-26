# Tasks

## Bugs
- [x] Context-mode scroll feels stuck — needs to glide
- [x] On pause, the text jumps back to the beginning instead of focusing on the current word (fixed alongside the scroll fix)
- [x] Settings button in the reader doesn't open anything
- [x] EPUB style tags leaking into the text (CSS visible between chapters with images) — `HtmlStripper._skipTags`

## Features
- [x] Speed ramp-up — when pressing play, start slower and gradually accelerate to the target WPM instead of hitting full speed instantly
- [x] Chapter navigation — a clear way to view the chapter list and jump between chapters
- [x] Ereader mode — third reading mode without highlight or controls (traditional ebook)
- [x] Chapter markers on the progress slider (with chapter-title tooltip via value indicator)
- [x] Focus line below the word (focus-only or focus + progress, configurable)

## Polish
- [x] Polish the context-mode scroll — velocity-based stepping (word/sentence/paragraph), highlight pill with subtle glow, dead zone for fine selection
- [x] Font preview in settings (each dropdown item rendered in its own font, plus a sample line)
- [x] Consolidate settings screens (shared `DisplaySettingsPanel` between the bottom sheet and the full-screen page)

## In flight
- [x] Import web articles by URL (pure-Dart readability extractor, Books/Articles tabs in the library)
- [x] Android share sheet (intent-filter + `receive_sharing_intent`, global navigation/snackbar coordinator in `app.dart`)
- [ ] iOS share sheet — the Xcode target needs to be created on a Mac, steps in [docs/share-extension-ios.md](docs/share-extension-ios.md)
- [x] Tablet layout pass (landscape unlocked, adaptive grid 2/3/4, master-detail on tablet landscape)
- [x] Reading stats: reading sessions (`reading_session` table v5) + `/stats` dashboard with weekly/monthly charts (fl_chart)
- [x] Monthly recap: shareable 9:16 image of the month with finished + in-progress books, rendered via `RepaintBoundary -> PNG -> share_plus`
- [x] Book completion: screen triggered at end-of-book with detailed stats, 0-5 star rating (column `books.rating` v6), shareable 9:16 card with a "include stats" toggle
- [x] Entry point in the library to reopen the completion screen for already-finished books — long-press a Read book to show "View completion screen"; the reader settings sheet / side panel gained a "Finish book" button for in-progress books (bumps progress to the end and opens completion)
- [ ] Yearly recap — reuse the monthly pipeline with a different layout
- [ ] GitHub issue triage

## New backlog
- [x] Context mode: lock + recenter on the floating overlay (measures the word's real `RenderBox` via a `GlobalKey` to centre precisely in long paragraphs)
- [x] Splash screen on app start (flutter_native_splash with light/dark palette, icon without the navy background)
- [ ] Bug: returning to the app in context mode breaks the sync — while paused; not reproduced in the latest session
- [x] Sync stats (`reading_session` + `books.rating`) across devices via Drive (together with the shard refactor — sessions append-only, rating with a dedicated timestamp)
- [x] Bookmarks (named save points inside a book/article) — schema v10 `bookmarks` table (single word + multi-word range via `endGlobalWordIndex`) + DAO, `BookmarksController` (create/edit/delete with sync push), long-press in any reader mode triggers the native Android selection toolbar with a "Salvar marcador" entry (third-party `PROCESS_TEXT` entries filtered out), `BookmarksList` shared between `ReaderSidePanel` (new `ReaderSidePanelMode.bookmarks`) and a mobile `BookmarksListSheet`, top-bar `bookmark_outline` icon toggles them. Per-book count badge on the book card + long-press menu entry. Global `/bookmarks` screen grouped by book, reachable from the library AppBar. Sync via new `library/bookmarks.json` shard (LWW per id, tombstones on `deletedAt`).
  - Known: a small visual lag remains while the IME slides in/out for the bookmark-create dialog on MIUI (Xiaomi). The reader tree was hardened against IME reflow (`removeViewInsets`, `MediaQuery.sizeOf`/`orientationOf` in `ResponsiveContext`, `resizeToAvoidBottomInset: false`) and the bookmark UI no longer rebuilds during the animation, but the MIUI ROM itself paints the keyboard with noticeable jank in debug builds (`RenderInspector QueueBuffer time out` warnings in logcat). Acceptable — revisit if a release-build measurement also shows it.
- [x] TTS mode (text-to-speech) — fourth reader mode alongside RSVP/scroll/ereader; `flutter_tts` on mobile + desktop (Android/iOS/macOS/Windows), custom `SpeechDispatcherBackend` on top of `spd-say` for Linux. Voice/rate/pitch in settings; sessions log to `reading_session` like every other mode. See [docs/tts-mode.md](docs/tts-mode.md).
- [x] TTS pipeline refactor: extract `TtsPlayer` from the engine notifier. The player keeps a small queue and uses `TtsQueueMode.add` to enqueue lookahead segments — the platform engine plays them back to back with no audible gap (no more ~200–500ms IPC pause at chunk boundaries). On Linux the gap-free path needs the `speech-dispatcher` daemon socket (`SpeechdSocketBackend`); legacy `spd-say` is kept as a fallback when the socket is absent.
- [x] TTS background playback (`audio_service`: Android foreground service with media notification, iOS AVAudioSession=playback + `audio` background mode, macOS/Windows lockscreen). `MainActivity` extends `AudioServiceActivity` for media-button intents. `TtsAudioHandler` bridges Riverpod-owned engine to the OS-facing facade.
- [x] Reader: lembrar o último ReaderMode usado por livro e reabrir nele. Nova coluna `readerMode` no `reading_progress` (schema v8). Engine restaura no `_loadBook` (mode síncrono pra ereader, async via `enterTtsMode` pra TTS — fica em `isLoading` até o player estar pronto). Auto-restore não dispara save (compara com `_lastSavedReaderMode`). Sincroniza via Drive no `SyncLibraryProgress.readerMode`. `scroll` colapsa em `'rsvp'` no formato persistido (mesma identidade no menu).
- [ ] Reader: o modo scroll do RSVP e o modo TTS usam configs de tamanho/tipografia diferentes — unificar ou deixar explícito o porquê
- [ ] Reader: atalho rápido pra mudar voz TTS sem precisar entrar em settings (talvez chip no transport row em modo TTS, ou opção no `ReaderModeMenu`)
- [x] Settings: reformular o painel pra separar opções por modo (RSVP-specific, TTS-specific, comuns) — hoje sentence/chapter pause aparece pra todos os modos sem indicar que é RSVP-only
- [x] TTS: engine picker no Android (`flutter_tts.getEngines` + `setEngine`) + output module no Linux (via SSIP `LIST OUTPUT_MODULES` ou `spd-say -O`). UI em `TtsEnginePickerSheet`; campo `DisplaySettings.ttsEngineId` sincronizado via Drive. Row escondida quando o backend reporta ≤1 engine.
- [x] TTS: melhorar labels do voice picker — `voice_label_formatter` (em `lib/core/utils/`) converte nomes técnicos em "Inglês (Reino Unido) · Feminina 1", com tech id como caption discreta. Sheet ganhou search bar e segmented toggle "Idioma atual" (default) / "Todos os idiomas".
- [x] Incremental sync (phase 1): sharded manifest in `library/books.json` + `settings.json` + `sessions.json`; push parallelises writes and skips unchanged shards. Phase 2 (per-record + index.json) is parked until it becomes a bottleneck.
- [ ] Improve speed ramp-up (more natural curve? configurable duration/word count?)
- [ ] Bug: investigate imports when the user drops an EPUB straight into the `RSVP Reader/books/` Drive folder (orphan import via `_autoImportOrphanFiles`) — something isn't behaving as expected
- [ ] Image support in books (inline figures from EPUB) — today only text is tokenized and the cover is extracted; inline images are dropped in `HtmlStripper`/tokenizer
