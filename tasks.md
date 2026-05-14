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
- [ ] Bookmarks (named save points inside a book/article)
- [ ] TTS mode (text-to-speech) — alternative audio playback
- [x] Incremental sync (phase 1): sharded manifest in `library/books.json` + `settings.json` + `sessions.json`; push parallelises writes and skips unchanged shards. Phase 2 (per-record + index.json) is parked until it becomes a bottleneck.
- [ ] Improve speed ramp-up (more natural curve? configurable duration/word count?)
- [ ] Bug: investigate imports when the user drops an EPUB straight into the `RSVP Reader/books/` Drive folder (orphan import via `_autoImportOrphanFiles`) — something isn't behaving as expected
- [ ] Image support in books (inline figures from EPUB) — today only text is tokenized and the cover is extracted; inline images are dropped in `HtmlStripper`/tokenizer
