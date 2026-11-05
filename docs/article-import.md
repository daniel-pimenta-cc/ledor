# Web article import

Lets the user read any web article with the same reader used for EPUBs. The
user pastes a URL into the dialog on the library's "Articles" tab, shares a
URL from a browser via the Android share sheet, or drops a URL onto the
desktop window. In every case the app downloads the page, extracts the
article body and creates a synthetic one-chapter "book" that flows through
the same reading pipeline as EPUBs.

## Why

- Word-by-word RSVP works for long-form text from any source, not just books.
- Articles are short and disposable; a separate tab keeps them out of the
  book list.
- Reusing the existing pipeline (`WordToken`, token cache, RSVP engine,
  reader modes) costs almost nothing.

## Pipeline

```
URL
  ↓
UrlUtils.parseWithHttpsFallback (adds https:// when the scheme is missing)
  ↓
http.get with 20s timeout + desktop User-Agent
  ↓  non-2xx → ArticleExtractionException
utf8.decode(bodyBytes, allowMalformed: true)
  ↓
ReadabilityExtractor.extract
  ├─ title:  og:title → twitter:title → first <h1> → <title>
  ├─ byline: meta[name=author] → meta[property=article:author] → [rel=author]
  ├─ siteName: og:site_name
  ├─ _stripNoise: drops _stripTags (script/style/nav/aside/header/footer/form/…)
  │   and elements whose class/id matches _negativePatterns and have no <p>
  └─ _findBestCandidate:
       1. exactly one <article> (then <main>) with >200 chars of text → wins
       2. else [role="main"] with >200 chars → wins
       3. else score every div/section/article:
            per <p> with ≥25 chars: +1, +1 per comma, +len/100 (clamped 0-3)
            +25 if class/id matches _positivePatterns
            −25 if class/id matches _negativePatterns
            score *= (1 − link density)
          no positive score → whole <body>
  ↓
contentHtml (inner HTML of the winner)
  ↓
HtmlStripper.strip → clean text with paragraphs (empty → exception)
  ↓
TextTokenizer.tokenize(chapterIndex: 0, globalOffset: 0) → List<WordToken>
  ↓
ParsedBook(title, author: byline ?? '', 1 Chapter, totalWords)
  (title falls back to the last URL path segment, then the host)
  ↓
persistParsedBook(source: BookSource.article, sourceUrl, siteName)
  ↓
SQLite: books row + cached_tokens (1 chapter)
```

## Components

### `lib/core/utils/readability_extractor.dart`

Pure-Dart, simplified port of Mozilla Readability (no native deps). Input:
HTML string. Output: `ExtractedArticle {title?, byline?, siteName?, contentHtml}`.

- `_stripTags`: tags that are always noise.
- `_negativePatterns` elements are removed only when they have no `<p>`
  descendants, so sidebars holding real pull quotes survive.
- `_positivePatterns` / `_negativePatterns`: case-insensitive class/id
  substrings worth ±25 points.
- Link density penalty: `score *= (1 − link_text_len / text_len)` zeroes
  link-heavy blocks (navs that survived stripping).

Tests: `test/core/utils/readability_extractor_test.dart`.

### `lib/features/article_import/data/services/article_extraction_service.dart`

`ArticleExtractionService` orchestrates HTTP + extraction:
- `extractFromUrl(String url) → ArticleExtractionResult`: fetches, then calls
  `extractFromHtml`.
- `extractFromHtml(String html, {required String url})`: pure, no network;
  used by `test/features/article_import/article_extraction_service_test.dart`.

Hardening:
- 20s timeout on the request.
- Desktop `User-Agent`, so sites don't redirect to mobile landing pages that
  often carry less content.
- `utf8.decode(bodyBytes, allowMalformed: true)`: many sites serve UTF-8 but
  declare the wrong charset; trusting the header (`response.body`) produces
  mojibake.

### `lib/features/article_import/presentation/providers/article_import_provider.dart`

`ArticleImportNotifier` (StateNotifier) with statuses
`idle | fetching | processing | done | error`. `importFromUrl(String)` runs the
whole pipeline and ends in `done` with `importedBookId`. It does not navigate;
the app-level coordinator does.

### `lib/features/article_import/presentation/widgets/import_article_dialog.dart`

Dialog with a URL `TextField`, pre-filled when the clipboard holds an http(s)
URL. Submit calls `ArticleImportNotifier.importFromUrl`.

### `lib/core/share/share_intent_handler.dart`

`ShareIntentHandler` wraps the app and listens to `ReceiveSharingIntent`
(cold start via `getInitialMedia`, warm start via `getMediaStream`). It is a
no-op unless `PlatformCapabilities.supportsShareIntent`. It accepts
`SharedMediaType.url` or `.text` containing an http(s) URL
(`UrlUtils.extractHttpUrl` handles the "Title\nhttps://…" payload some
browsers send) and calls `importFromUrl`.

### `lib/core/share/desktop_drop_handler.dart`

On desktop, dropped files that aren't `.epub` are read as text and the first
http(s) URL found is passed to `importFromUrl`. See
[linux-desktop.md](linux-desktop.md#drag-and-drop).

### `_ArticleImportCoordinator` in `lib/app.dart`

`ref.listen(articleImportProvider)` at app level. Shows a persistent progress
snackbar (fetching / processing), pushes `/reader/:id` on `done`, shows an
error snackbar on `error`, then `reset()`s the notifier. Uses
`rootMessengerKey` because it sits above `MaterialApp`.

## Schema

Article rows in `books` have:
- `source = BookSource.article`
- `sourceUrl`: original URL
- `siteName`: from `og:site_name`, when present
- `filePath = ''`: no file on disk (sentinel)
- `coverImage = null`

`BookCard` shows `siteName` as the subtitle, falling back to `author`, then
the URL host.

## Sync

`LibrarySyncService._buildLocalShards` keeps only `source == BookSource.epub`,
so articles never sync through Google Drive: there is no file to upload, the
shards describe EPUB libraries, and articles are short-lived.

## iOS share sheet

Android works through the `SEND` / `text/plain` intent-filter in
`android/app/src/main/AndroidManifest.xml`. iOS needs a Share Extension
target created in Xcode on a Mac, which is not set up yet; see
[share-extension-ios.md](share-extension-ios.md).

## Import entry points

| Source            | Entry point                            | Platform        |
|-------------------|----------------------------------------|-----------------|
| EPUB file picker  | FAB on the Books tab                   | all             |
| Google Drive sync | auto-import in `LibrarySyncService`    | Android, Linux  |
| URL dialog        | FAB on the Articles tab                | all             |
| Drag-and-drop     | `DesktopDropHandler` (EPUB or URL)     | desktop         |
| Share sheet       | `ShareIntentHandler` via intent-filter | Android         |
| Share extension   | `ShareIntentHandler` via App Group     | iOS (not set up)|
