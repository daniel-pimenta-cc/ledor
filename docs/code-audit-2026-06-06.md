# Auditoria de Código — RSVP Reader

**Data:** 2026-06-06 · **Método:** 13 revisores multi-agente (8 por área + 5 transversais) + verificação adversarial por finding (3 lentes para critical/high, refutador para medium/low) + crítico de completude. 149 agentes, ~1.700 operações de leitura/análise.

**Baseline mecânica:** `flutter analyze` → 1 warning trivial (unnecessary_cast em teste) · `flutter test` → 290 testes, todos passando.

**Findings:** 103 brutos → 89 após dedup → **84 confirmados** (13 refutados na verificação adversarial).

Severidade final (pós-verificação): **5 high · 26 medium · 53 low**. Nenhum critical.

## Notas por área

| Área | Nota |
|---|---|
| engine | 7.5/10 |
| tts | 7.5/10 |
| sync | 7/10 |
| import | 6.5/10 |
| reader-ui | 7/10 |
| library-stats-ui | 7/10 |
| database | 6.5/10 |
| core-misc | 7.5/10 |
| rules-compliance | 8/10 |
| async-safety | 8/10 |
| test-quality | 7/10 |
| docs-consistency | 8/10 |
| architecture | 7.5/10 |
| **média** | **7.3/10** |

## Avaliações por área

### engine — 7.5/10

Well-built engine with deliberate lifecycle handling matching documented invariants. Session flush wired to every isPlaying exit; finishTicket bumps only on organic end-of-book; persistedReaderMode round-trips consistently. Edge weaknesses: _loadBook can RangeError-crash on stale/cross-device progress indices; seek/skip onto an image during RSVP play skips the image-pause UX; every WPM/rate step rewrites all 25 prefs keys plus a sync push with no debounce; entities lack value equality. The index-bounds crash and image-seek bug are the user-visible ones; overall it holds up well.

### tts — 7.5/10

The TTS stack is, on the whole, unusually well-engineered for a hobby project and will largely survive public scrutiny: the generation-counter invalidation, `_isPlaying`-before-first-await invariant, per-field `_applied*` settings dedup, `canPipeline`/lookahead abstraction, and the dispose/unbind discipline (cached `_audioHandler`, `unbindIfActive`) are all implemented carefully and the design is clearly documented in CLAUDE.md and the doc comments. The two strongest real problems are a user-visible one — flutter_tts silently caps speech rate at 2.0x while the UI advertises and persists presets up to 3.0x — and a test-priority inversion: the 618-line primary Linux SSIP backend (with hand-rolled protocol framing, dot-stuffing, and voice/engine parsers it deliberately exposed for testing) has zero tests, while the legacy fallback it supersedes is tested. Beyond those, the weaknesses are maintainability debt: substantial copy-paste between the two Linux backends (rate mapping, word-timer, flush logic) that `_linux_tts_shared.dart` was created to prevent, settings dirty-tracking that advances on failed/timed-out SSIP commands, and a couple of latent stall-detection edge cases. None are data-corrupting. Net: solid, ship-able code with a real rate bug to fix and a meaningful test gap to close on Linux.

### sync — 7/10

This is a thoughtfully engineered sync layer that handles many hard CRDT-style problems correctly: the sharded layout, the documented DateTime.isAtSameMomentAs discipline (consistently applied in _applyShardsToLocal and bookmark merge), per-field rating LWW with its own timestamp, the _*ShardEquals skip-write optimization, the fileId cache, and the zombie-tombstone compaction with the 'active wins syncFileName' invariant are all real and largely sound. Pure merge functions are clean and partially tested. The weak spots are concentrated in the deletion lifecycle: because books are hard-deleted locally with no local tombstone, the entire delete propagation hangs on a single best-effort pushTombstone that, if it fails or the folder is briefly unreadable, silently drops the deletion AND clears the pending queue — causing the book to be resurrected on the next full sync (the most serious issue). The standalone pushTombstone also does a non-merging read-modify-write that can clobber concurrent device updates. Secondary gaps: existing-book metadata never converges on already-synced devices, a mid-sync settings change can be lost, a narrow bookmark-orphan resurrection path, and a complete absence of tests for the newest (bookmark) code and the service-layer orchestration. None of these corrupt data catastrophically and most self-heal across repeated syncs, but the delete-resurrection bug is user-visible and would surface in a demo. The code is well-commented and would mostly survive public scrutiny, but the delete path and the missing service/bookmark tests are the honest soft underbelly.

### import — 6.5/10

The content-import pipeline is well-architected for a portfolio-grade project: the EPUB and article paths genuinely converge on one ParsedBook -> persistParsedBook -> books + cached_tokens flow (no duplicated insert logic), WordToken pre-computation keeps the RSVP hot loop clean, html_stripper correctly skips style/script subtrees, and image extraction-to-disk is thoughtfully separated from the DB. Core utils have real unit tests. However, several correctness gaps would surface under public scrutiny: a single malformed percent-escape in an EPUB image src crashes the whole import (no try/catch around Uri.decodeFull); the multi-step persist is not wrapped in a transaction, so any mid-fan-out failure leaves an orphaned half-imported book; the ORP calculator only understands Latin scripts, silently breaking the headline feature for Cyrillic/Greek/CJK despite word_timing already doing unicode correctly; table cells concatenate into garbled tokens; and untitled EPUBs leak hardcoded English into a PT UI. None of these are exotic — they are the edge cases real EPUBs and real web pages routinely hit. The code is honest and readable, but input-hostility hardening (unicode, malformed bytes, atomicity) is the weak spot a reviewer notices first.

### reader-ui — 7/10

A UI do leitor e, no geral, bem estruturada e madura: widgets pequenos e focados (controls_* , settings/, capsules), boa disciplina de dispose (FocusNode, TextEditingController, ValueNotifier, ScrollController e listeners de posicao todos liberados), guards de `mounted` corretos nos post-frame callbacks e no fluxo de bookmark, e a logica delicada de auto-scroll/recenter via medicao real de RenderBox (getTransformTo) e genuinamente cuidadosa e bem documentada. A regra de cores via DisplaySettings (e nao Theme.of) e seguida quase em todo lugar. Os pontos fracos sao: varias violacoes de i18n com strings em ingles hardcoded (titulos do side panel, sheet de capitulos com '{n} words', 'OK' do color picker, 'Error: $e') que quebram a experiencia PT-BR e sao exatamente o tipo de coisa que chama atencao num repo publico; efeitos colaterais de estado dentro de build() no ContextScrollView (recomputo de indexacao + mutacao de notifier), que funcionam mas sao frageis; e duplicacao real (duas listas de capitulos, _StepIcon/_PresetChip copiados entre dois selectors). Nada que corrompa dados ou crashe, mas a divida de i18n e a logica de scroll no build merecem limpeza antes de divulgar.

### library-stats-ui — 7/10

A área de biblioteca, stats e chrome é, no geral, de boa qualidade e aguenta escrutínio público: a arquitetura feature-based é consistente, o tema editorial é bem fatorado (AppPalette dual, zero uso de AppColors direto no chrome — regra do CLAUDE.md respeitada), os share cards usam corretamente a paleta fixa em vez de Theme, os providers de progresso evitam N+1 com duas queries agregadas, e os charts fl_chart tratam dados vazios/zero com maxY de fallback e empty-states. Os pontos fracos mais sérios são de lifecycle/navegação em casos de borda que um vídeo de demo provavelmente não atinge mas um usuário real sim: `_loadBook` e `bookCompletionProvider` deixam o usuário preso em tela branca ou spinner infinito quando o bookId é inválido ou o livro foi deletado (deep links e sync multi-device são os gatilhos), e `selectedBookIdProvider` não é limpo quando a deleção vem do sync remoto. Há também um bug funcional silencioso: a nota de estrelas no completion screen nunca dispara push de sync, quebrando a propagação cross-device documentada. Os demais achados (strings de erro hardcoded vazando exceção crua, separador de milhar fixo, busy-loop sem timeout) são polish/bordas. Nada corrompe dados; os dois 'high' são telas que travam sem crash.

### database — 6.5/10

Drift bem desenhada e documentada; DAOs enxutos; evita N+1; invariantes de sync respeitadas. Achados nao listados no array (limite de payload): MEDIO lib/main.dart:43 FK references em cached_tokens/reading_progress nao enforcada (banco abre sem PRAGMA foreign_keys=ON nem beforeOpen, FKs OFF, permite orfaos); MEDIO lib/database/app_database.dart:75 DateTimeColumn gravada como int unixepoch perde ms e isUtc (raiz da regra isAtSameMomentAs); BAIXO lib/database/daos/bookmarks_dao.dart:38 getById nao filtra deletedAt.isNull().

### core-misc — 7.5/10

A area de core utilities e integracao de plataforma esta em bom estado e aguenta escrutinio publico. Fortes: PlatformCapabilities centraliza checks com guarda kIsWeb-first em todos os getters; font_mapper esta em sincronia exata com a lista fontOptions da UI; SkeletonHost dispoe o AnimationController corretamente e o ticker pausa via TickerMode offscreen, sem leak; bookmark_snippet, url_utils e sync_file_name sao puros e defensivos. Fracos: o desktop drop importa so o primeiro arquivo de um drop multiplo e nao da feedback em drops invalidos ou diretorios; o share intent handler nao tem guarda mounted no caminho do stream nem dedup contra entrega dupla cold/warm e engole erros do stream; o ImageExportService usa null-bang no currentContext apos um await e deixa PNGs temporarios sem limpeza. Nenhum corrompe dados nem e critico; o tratamento de erro inconsistente entre pontos de entrada de import e a divida mais relevante.

### rules-compliance — 8/10

O codigo aguenta escrutinio publico bem: a arquitetura feature-based + Riverpod e consistente, e as regras dificeis (DateTime.isAtSameMomentAs no sync, constantes BookSource, cores via DisplaySettings vs Theme no chrome, AppColors nunca no chrome, font_mapper centralizado, persistParsedBook unico, audio handler cacheado no dispose) estao respeitadas com altissima disciplina — varreduras sistematicas acharam zero violacoes nessas areas criticas. O motor RSVP/TTS e notavelmente cuidadoso com lifecycle (generation counter, guards if (!mounted), _applied* dedup field-by-field), e a logica de sync sharded/LWW/tombstones e madura e bem comentada. Os pontos fracos sao localizados: uma violacao real da invariante de TTS (enterEreaderMode esquece _pushPlaybackState(false), deixando o lockscreen 'playing'), indices de progresso restaurados sem clamp (RangeError possivel via sync entre devices), uma reimplementacao de fim-de-sentenca em context_scroll_view que diverge da utility compartilhada (ignora reticencias), e um punhado de strings de UI hardcoded em ingles que destoam do rigor i18n do resto. Nenhum bug e catastrofico, mas o de _pushPlaybackState e o clamp de progresso merecem correcao antes de divulgar.

### async-safety — 8/10

This is a notably well-engineered codebase for a solo project: the TTS player/engine split has explicit generation counters, per-field settings dedup, and disciplined mounted-checks after every await; the sync layer respects the documented isAtSameMomentAs DateTime rule and tombstone invariants; controllers/subscriptions/notifiers are consistently disposed (ValueNotifier, TextEditingController, StreamSubscription, AnimationController, FocusNode). CLAUDE.md rules are largely honored. Weak spots concentrate in the reader engine's lifecycle edges: progress isn't persisted when the reader is torn down mid-playback through the master-detail/back-gesture paths (the most user-visible bug), and rapid unawaited TtsPlayer.seek() calls during a slider drag can settle on a stale position. There's one clear rule-violation (duplicated sentence-end detection that also drops the ellipsis case) plus minor edge/consistency issues. None corrupt data at rest or crash on the happy path, so the repo holds up to public scrutiny, but the close-during-play progress loss is worth fixing before a showcase.

### test-quality — 7/10

A suite de 290 testes (todos verdes, analyzer limpo) e genuinamente boa nas camadas de logica pura e merece confianca la: ORP, word_timing, tokenizer (com unicode/PT), html_stripper (cobre _skipTags), readability, sentence_extractor, stats (bucketing por dia local) e todas as funcoes puras de merge de sync/bookmarks tem assercoes fortes e especificas, nao smoke tests. O teste do RsvpEngineNotifier (1379 linhas) impressiona: cobre finishTicket via TTS, persistencia/restore de readerMode, modos ereader/tts, imagens inline e sessoes, usando mocktail nas DAOs e um stub de sync. Os fixtures (EPUB construido em runtime) sao boa pratica e os testes evitam sleeps, usando microtask pumping. Porem a confianca para refatorar cai bruscamente nas tres areas de maior risco operacional, todas sem cobertura: (1) toda a orquestracao do LibrarySyncService (1107 linhas que escrevem no DB a partir de shards remotos mesclados), sem nem um fake SyncFolderGateway no projeto; (2) as 9 migracoes de schema Drift (v1 a v10), risco direto de corrupcao de DB do usuario em upgrade; (3) o caminho positivo de recuperacao do TtsPlayer (restartIfStalled) e o finishTicket organico do RSVP, ambos inalcancaveis pelos testes atuais por dependerem de DateTime.now()/ticker nao injetaveis. Ha ainda ausencia total de testes do import de artigos (uma das duas fontes de conteudo) e uma nao-comutatividade real (de baixo impacto) nos merges em empates de timestamp. Veredito: a suite protege bem o nucleo algoritmico e da seguranca para mexer em engine/utils/merges puros, mas refatorar o pipeline de sync ou as migracoes sem antes adicionar testes e arriscado, pois e justamente onde um bug corrompe dados silenciosamente e a suite continuaria verde.

### docs-consistency — 8/10

Repositório de qualidade incomum para projeto pessoal e claramente apresentável para divulgação pública. Pontos fortes: flutter analyze praticamente limpo (1 warning trivial em teste); arquitetura feature-based Clean + Riverpod consistente; lifecycle rigoroso (StreamSubscriptions/Timers/Sockets/Tickers dispostos, observers removidos); TtsPlayer e RsvpEngineNotifier com invariantes de concorrência bem pensadas (geração para invalidar callbacks tardios, if !mounted return, refs cacheadas no dispose); sync via Drive respeita isAtSameMomentAs em todos os paths de merge; nenhum secret versionado (só no .env gitignored); README/LICENSE MIT/CONTRIBUTING/.env.example coerentes, screenshots e 8 docs cujos paths foram verificados como existentes; boa cobertura de testes nos core utils, sync, stats, engine e TTS player. Pontos fracos: documentação derivou do código onde um visitante de vídeo notaria — README e dois docs ainda dizem 'três modos' enquanto o TTS (feature maior) existe mas está ausente do README; CLAUDE.md descreve bookmark via onWordLongPress/WidgetSpan que foi substituído por onBookmarkRange/seleção nativa e omite colunas de range do schema v10. No código os achados são menores: reimplementação de fim-de-sentença em context_scroll_view (viola regra e diverge no ellipsis) e duas strings de erro hardcoded em inglês. Nenhum bug crítico de corrupção/crash encontrado. O repo aguenta escrutínio público; resta sobretudo reconciliar doc com o código atual.

### architecture — 7.5/10

This is a well-above-average Flutter codebase that will hold up to public scrutiny. The strongest aspects are genuinely strong: domain entities never import Flutter, there are no presentation->presentation cross-feature data imports beyond the legitimate master-detail host (library_list), the sync layer rigorously follows its own documented invariants (isAtSameMomentAs everywhere, per-field LWW for ratings, tombstone compaction), and the trickiest lifecycle code (engine dispose snapshots, TTS generation counters, audio-handler cached unbind) is carefully reasoned and densely commented. The 'god files' are mostly false alarms — settings_controls.dart and tts_voice_picker_sheet.dart are cohesive collections of small widgets, and the engine provider's size is justified for the app's heart. The real weaknesses are architectural ownership smells rather than bugs: the app's most-shared models (WordToken/Chapter/ParsedBook, DisplaySettings) and shared infrastructure (inline_image_storage, book_persistence) are nested inside arbitrary single features, so 'feature A imports feature B's internals' happens often — a new contributor would be surprised that article_import's core type comes from epub_import. Drift row types also leak straight into widgets, contradicting the 'pure domain models' promise. The few concrete defects are low-severity edge cases (empty-book clamp crash, a shared-backend callback race on tablet flips, ref-read-in-dispose fragility) plus a clear rule violation: context_scroll_view reimplements sentence-end detection and silently diverges from the shared utility on ellipsis. Overall: maintainable, honest documentation, no data-corruption landmines found — but the 'feature owns its domain' claim is aspirational, and the shared-entity placement is the main thing to clean up before holding it up as an architecture exemplar.

## Findings confirmados

### Severidade: HIGH

#### [bug] Migracao v8 para v10 quebra com duplicate column name (crash no boot)

`lib/database/app_database.dart:104` (área: database · verificação 3/3)

from<9 chama m.createTable(bookmarksTable), criando a tabela ja com end_global_word_index e end_chapter_index (gerado em app_database.g.dart 2784-2785). from<10 faz m.addColumn dessas mesmas colunas (ALTER ADD COLUMN sobre colunas existentes), SQLite lanca duplicate column name e o onUpgrade aborta. App nao abre migrando de schema 8 ou anterior direto para 10.

**Correção sugerida:** Guardar os addColumn de v10 com from>=9 && from<10; adicionar teste de migracao v8->v10 com SchemaVerifier.

#### [bug] EPUB import crashes on malformed percent-escape in <img src>

`lib/features/epub_import/data/services/epub_extraction_service.dart:114` (área: import · verificação 3/3)

The image resolver closure begins with `final cleaned = Uri.decodeFull(src.split('#').first.split('?').first);`. Uri.decodeFull throws ArgumentError('Invalid URL encoding') whenever the src contains a literal % not followed by two hex digits (verified: images/a%2.png, cover%.jpg, x%ZZ.png all throw). The resolver is invoked synchronously in ChapterParser._walk (chapter_parser.dart:99 `final resolved = resolver(src);`) with no try/catch anywhere on the path up through _processChapter/extractBook/importFromPath. A single image with an unescaped % in its filename aborts the ENTIRE book import (the catch in epub_import_provider just shows a generic error). Such filenames are unusual but legal and appear in real-world EPUBs.

**Correção sugerida:** Wrap the Uri.decodeFull call (or the whole resolver body) in a try/catch that returns null or falls back on failure, e.g. String cleaned; try { cleaned = Uri.decodeFull(...); } catch (_) { cleaned = src.split('#').first.split('?').first; }. A broken image must degrade to a skipped slot, never kill the import.

#### [bug] Dropped delete-tombstone resurrects the book on next full sync

`lib/features/library_sync/presentation/providers/library_sync_provider.dart:206` (área: sync · verificação 3/3)

Books are HARD-deleted locally (BooksDao.deleteBook does a real `delete`; only bookmarks have a soft-delete `deletedAt` column). The ONLY mechanism that propagates a book deletion to Drive is the explicit `pushTombstone`. In `_flushPendingDeletes` the pending ids are cleared FIRST (`_pendingDeletes.clear()` at line 210) and then `pushTombstone` runs inside `try { ... } catch (_) {/* will be retried on next full sync */}`. The 'retried on next full sync' comment is false: `pushTombstone` returns *silently* (no throw) when `!await _gateway.isReadable(folder)` (library_sync_service.dart:1007), and even when it throws the exception is swallowed and the id is already gone from `_pendingDeletes`. Crucially there is no local tombstone, so the next full `sync()` rebuilds `_buildLocalShards` WITHOUT the deleted book (it's gone from the DB), the merge does a union by id with the remote books shard (which still lists the book as active), and `_applyShardsToLocal` hits `local == null` and re-imports/re-inserts the book (lines 511-534). Net effect: deleting a book during a transient network/auth blip (or any write failure) silently resurrects the book on the following sync.

**Correção sugerida:** On `pushTombstone` failure, re-enqueue the id into `_pendingDeletes` (only clear ids that succeeded), or persist deleted-book tombstones in a local table (mirroring the bookmarks soft-delete) so `_buildLocalShards` can re-derive the tombstone on every sync until the remote confirms it. Do not clear the pending list before the write succeeds.

#### [bug] Closing the reader mid-playback loses reading progress

`lib/features/rsvp_reader/presentation/providers/rsvp_engine_provider.dart:752` (área: async-safety · verificação 3/3)

dispose() persists progress only inside `if (_saveDebounce?.isActive ?? false)`. During active playback no debounce is scheduled: RSVP `_advanceWord` only calls `_saveProgress` at end-of-book, and the TTS `_onPlayerWordAdvance` callback never saves. So if the reader is torn down while `isPlaying==true` without a prior pause, only `_flushSession()` runs and the current word position is NOT written. The top-bar back button and Escape shortcut call `engine.pause()` first (which saves), but the tablet master-detail `onClose` does not: `library_screen.dart:167` wires `onClose: () => ref.read(selectedBookIdProvider.notifier).state = null`, and selecting a different book in the list flips `selectedBookIdProvider` (the reader has `key: ValueKey(selectedId)`, so it disposes) without pausing. The Android system-back gesture / route pop on phones is the same path. Net effect: the user resumes from the last pause/seek, not where they actually stopped.

**Correção sugerida:** In dispose(), call `_flushSession()` and then unconditionally `unawaited(_saveProgress())` (it already dedups on word index + mode, so it is a no-op when nothing changed). Or have `_advanceWord` / `_onPlayerWordAdvance` periodically `_scheduleSaveProgress()` during playback so an active debounce always exists at teardown.

#### [test-gap] LibrarySyncService orchestration (1107 lines) has zero tests

`lib/features/library_sync/data/services/library_sync_service.dart:144` (área: test-quality · verificação 3/3)

Only the pure merge functions in sync_library.dart are tested. The entire orchestration layer (_compactZombieTombstones l365, _applyShardsToLocal l491 with all its isAtSameMomentAs guards, _uploadMissingEpubs l801, _autoImportOrphanFiles l859, pushTombstone l1001, _loadRemoteShards + legacy library.json migration l309) is uncovered. This is the highest-risk code for data corruption (it writes to the local DB based on merged remote shards) yet has no tests. There is no fake SyncFolderGateway in the test tree to drive a round-trip sync. Invariants documented in CLAUDE.md (tombstone-vs-active filename precedence, zombie tombstone compaction, isAtSameMomentAs to avoid per-book write churn, readerMode-only diff at l551) are asserted only by code reading.

**Correção sugerida:** Add an in-memory fake SyncFolderGateway and drive LibrarySyncService.sync() end-to-end with mocktail DAOs: assert (a) a remote tombstone deletes the local book + cascades bookmarks, (b) a zombie tombstone whose filename is claimed by an active book is compacted out of the pushed shard, (c) identical local/remote progress (same instant, different isUtc) produces no upsert, (d) a readerMode-only remote change triggers exactly one upsert, (e) the legacy monolith migrates and is deleted.

### Severidade: MEDIUM

#### [architecture] Drift-generated table types leak into the presentation layer

`lib/features/book_library/presentation/widgets/book_card.dart:15` (área: architecture · verificação 1/1)

architecture.md promises 'domain/entities — pure models', but presentation widgets and providers depend directly on Drift's generated row/companion types. book_card.dart:15 holds `final BooksTableData book;` (and imports database/app_database.dart:8); bookLibraryProvider exposes `StreamProvider<List<BooksTableData>>` and `CategorizedLibrary` is built from `BooksTableData` (book_library_provider.dart:13,20-22). library_list.dart and several stats providers likewise pass TableData/Companion around. This couples the UI directly to the SQLite schema — a column rename forces widget edits, and there is no domain model insulating the view. Pragmatic for a solo app, but it contradicts the stated layering and is a real refactor tax as the schema grows.

**Correção sugerida:** Introduce a thin domain `Book` entity mapped from `BooksTableData` at the provider boundary, so presentation depends on the domain model rather than the persistence schema. At minimum, document this as a deliberate pragmatic shortcut.

#### [architecture] DisplaySettings owned by rsvp_reader but consumed by library_sync and settings

`lib/features/rsvp_reader/domain/entities/display_settings.dart:1` (área: architecture · verificação 1/1)

DisplaySettings is the app-wide config object (colors, fonts, TTS, timing) persisted via SharedPreferences and synced via Drive. It lives under `rsvp_reader/domain/entities/`, but library_sync imports it in data + presentation (library_sync_service.dart:21, library_sync_provider.dart:8, sync_settings_section.dart:6) and settings imports it (settings_screen.dart:8, theme_mode_provider.dart:7). The same arbitrary-ownership smell as the content entities: a cross-cutting settings model is nested inside one feature. This forces library_sync's data layer to reach into another feature's domain to (de)serialize settings.

**Correção sugerida:** Promote DisplaySettings (+ its enums OrpIndicatorStyle/TimeRemainingMode) to a shared `core/domain` or dedicated `display_settings` feature so sync/settings/reader all depend on a neutral module instead of rsvp_reader internals.

#### [bug] ORP calculation broken for all non-Latin scripts (Cyrillic, Greek, CJK, Arabic, Hebrew)

`lib/core/extensions/string_extensions.dart:3` (área: import · verificação 3/3)

OrpCalculator.calculate (orp_calculator.dart:40-46) relies on word[i].isLetterOrDigit, whose definition only accepts ASCII, Latin-1 (0xC0-0xFF) and Latin Extended-A/B (0x100-0x24F). I verified that for Cyrillic and Greek words EVERY character returns false, so alphaCount == 0, firstAlpha == -1, and calculate returns 0 for the whole word. For a reader app that reads arbitrary EPUBs/articles, every non-Latin book gets its ORP focus pinned to the first character (no ~30% recognition point) - the core RSVP feature silently degrades. Tests only cover Portuguese accents (orp_calculator_test.dart:53). Note word_timing.dart uses the correct \p{L}\p{N} unicode regex, making this inconsistency a bug, not a deliberate scope choice.

**Correção sugerida:** Replace the hand-rolled range check with a unicode-aware test matching word_timing's RegExp(r'[\p{L}\p{N}]', unicode: true), and iterate by runes (not UTF-16 code units) so astral-plane letters and combining marks are handled. Add ORP tests for Cyrillic/Greek/CJK.

#### [bug] selectedBookIdProvider vira órfão quando o livro aberto é deletado por sync remoto (tablet landscape)

`lib/core/routing/selected_book_provider.dart:7` (área: library-stats-ui · verificação 1/1)

`selectedBookIdProvider` só é zerado em dois lugares: no diálogo de delete local (library_list.dart:291-293) e no `onClose` do reader (library_screen.dart:168). Quando um peer deleta um livro via sync, a deleção local roda por `_deleteBookLocally` no serviço de sync — NÃO pelo `deleteBookProvider` — então o provider continua apontando pro bookId deletado. No master-detail (library_screen.dart:162-169) o painel direito segue montando `RsvpReaderScreen(bookId: deletedId)`, que (ver finding do _loadBook) cai em tela branca sem saída porque os tokens já foram apagados. Estado órfão sem auto-recuperação.

**Correção sugerida:** Observar a lista de livros (ex: `bookLibraryProvider`) e, quando `selectedBookIdProvider` não estiver mais presente, zerar o provider — seja num listener no `LibraryScreen` ou cascateando a limpeza dentro de `_deleteBookLocally` no serviço de sync.

#### [bug] persistParsedBook is not atomic - partial book rows orphaned on failure

`lib/features/book_library/data/services/book_persistence.dart:41` (área: import · verificação 3/3)

persistParsedBook does await booksDao.insertBook(...) (line 41) followed by await persistChaptersWithImages(...) (line 56), which loops inserting one cached_tokens row per chapter and writes image bytes to disk. None of this runs inside a Drift transaction (grep confirms zero db.transaction( calls in the entire codebase). If any chapter fails mid-fan-out (disk full while imageStorage.writeImage, JSON encode error, I/O error), the book row is already committed but has 0..N-1 of its chapters. The import-provider catch blocks (epub_import_provider.dart:69/82, article_import_provider.dart:80) only set error state - there is no deleteBook/deleteTokensForBook rollback. Result: a corrupt book appears in the library with wrong totalWords/chapterCount and missing tokens.

**Correção sugerida:** Run the insertBook + persistChaptersWithImages sequence inside booksDao.attachedDatabase.transaction(() async { ... }) so a mid-stream failure rolls back the book row. Sequence image file writes so the DB writes commit last in one transaction.

#### [bug] Mudança de rating no completion screen nunca dispara push de sync

`lib/features/reading_stats/presentation/screens/book_completion_screen.dart:57` (área: library-stats-ui · verificação 1/1)

`_onRatingChanged` chama `ref.read(booksDaoProvider).updateRating(summary.bookId, value?.clamp(1, 5))` e nada mais. O `updateRating` (books_dao.dart:58) carimba `ratingUpdatedAt` exatamente para o LWW de sync por-campo, mas nenhum `schedulePush()`/`triggerSync()` é chamado após o write (confirmado: grep por schedulePush/triggerSync em features/reading_stats não retorna nada). Compare com `markBookAsReadProvider` (book_library_provider.dart:198) que chama `ref.read(librarySyncProvider.notifier).schedulePush()` após mexer no progresso. Efeito: a nota de estrelas dada num device só propaga para outros devices quando algum OUTRO evento disparar um sync — a feature de rating cross-device documentada no CLAUDE.md fica silenciosamente quebrada até um sync incidental.

**Correção sugerida:** Após `updateRating`, chamar `ref.read(librarySyncProvider.notifier).schedulePush()` (guardado por `PlatformCapabilities.supportsDriveSync` se necessário), espelhando `markBookAsReadProvider`.

#### [bug] flutter_tts backend caps speech rate at 2.0x, silently breaking documented 2.25x-3.0x presets

`lib/features/rsvp_reader/data/services/flutter_tts_backend.dart:164` (área: tts · verificação 3/3)

`setRate` does `final clamped = rate.clamp(0.1, 2.0); await _tts.setSpeechRate(clamped);`. But the user-facing rate range is `[0.5, 3.0]` (AppConstants.minTtsRate=0.5 / maxTtsRate=3.0) and `TtsRatePresetRow._presets` explicitly offers 2.0, 2.5 and 3.0 (tts_rate_selector.dart:139-141). On Android/iOS/macOS/Windows (the FlutterTtsBackend), selecting any preset above 2.0x produces the SAME audio speed as 2.0x — the slider/capsule moves and DisplaySettings.ttsRate persists & syncs, but the synth never speeds up. The Linux backends map the same rate to spd-say's [-100,100] and DO reach the top, so the behaviour is inconsistent across platforms on the primary mobile platform. The player even records `_appliedRate = rate` (the un-clamped 3.0) so its dedup thinks the value was applied.

**Correção sugerida:** Either raise the clamp ceiling to match the engine's real capability (modern flutter_tts/Android TTS accept ~3.0-4.0; test on device) or narrow the UI presets/maxTtsRate to what flutter_tts honours. If the platform genuinely caps at ~2.0, scale the rate (e.g. map 0.5-3.0 onto the engine's accepted band) or hide the unreachable presets per-backend via a `maxRate` capability.

#### [bug] Concurrent unawaited TtsPlayer.seek() calls can land on a stale position

`lib/features/rsvp_reader/data/services/tts_player.dart:248` (área: async-safety · verificação 1/1)

`SeekSlider.onChanged` is wired directly to `engine.seekToWord` (`rsvp_controls.dart:116`), which in TTS mode runs `unawaited(_ttsPlayer?.seek(clamped))` (rsvp_engine_provider.dart:471). A slider drag fires onChanged many times per second, so multiple `seek()` futures run concurrently. `seek()` does `await pause(); _currentGlobalIndex = clamped; await play(fromGlobalIndex: clamped)`. With two overlapping seeks A(old) and B(new), B can set `_currentGlobalIndex` and then A's `play()` resumes - `play()` reads its own captured `fromGlobalIndex` and re-clamps `_currentGlobalIndex` to A's older value, while B's `play()` is rejected by the `if (_isPlaying) return` guard. Result: playback can resume at an earlier drag value instead of where the finger was released. Generation counters guard callback staleness but not this interleaving of the two awaits.

**Correção sugerida:** Serialize seeks: capture a local generation at the top of `seek()` and bail before `play()` if a newer seek superseded it, or debounce slider seeks in TTS mode (only issue the final value on drag end / after a short idle), matching the non-TTS path which already debounces via `_scheduleSaveProgress`.

#### [bug] Seek/skip onto image during RSVP play never pauses on the image

`lib/features/rsvp_reader/presentation/providers/rsvp_engine_provider.dart:458` (área: engine · verificação 3/3)

seekToWord (skipForward/skipBackward/jumpToChapter, swipe, media skip) moves the cursor but in the RSVP playing path neither stops the ticker nor checks if the new currentWord is an image. Image auto-pause only fires from _advanceWord->_autoPauseOnImage (line 649), not seek. A skip landing on an isImage token during play leaves the ticker running; the next _advanceWord blows past the image without pausing, defeating the pan/zoom UX.

**Correção sugerida:** In seekToWord, if state.mode != tts and currentWord.isImage, call _autoPauseOnImage(); or reschedule and guard against advancing onto an image.

#### [bug] _loadBook indexes chapters/tokens with unvalidated persisted indices (RangeError crash)

`lib/features/rsvp_reader/presentation/providers/rsvp_engine_provider.dart:122` (área: engine · verificação 3/3)

chapterIdx/wordIdx come straight from the progress row and index chapters[chapterIdx].tokens[wordIdx] at line 150 with no bounds check. A re-import with fewer words, or a synced progress row from a device with a different token count, throws RangeError and the reader fails to load.

**Correção sugerida:** Clamp chapterIdx and wordIdx against chapters.length and tokens.length before indexing, or recompute via _globalToLocal on a clamped global index.

#### [bug] Indices de progresso (chapterIndex/wordIndex) usados sem clamp em _loadBook -> RangeError potencial

`lib/features/rsvp_reader/presentation/providers/rsvp_engine_provider.dart:150` (área: rules-compliance · verificação 1/1)

Em _loadBook, chapterIdx = progress?.chapterIndex ?? 0 e wordIdx = progress?.wordIndex ?? 0 (linhas 122-123) sao usados diretamente em chapters[chapterIdx].tokens[wordIdx] (linha 150) e em _calculateGlobalIndex sem validar contra a estrutura de chapters/tokens realmente carregada. O progresso pode vir do sync de um peer (LibrarySyncService linha 553-560 escreve chapterIndex/wordIndex remotos crus na progress row sem validar contra o EPUB local). Se a contagem de chapters/tokens divergir (re-import, versao de parser diferente entre devices, ou EPUB ainda nao baixado no peer), o acesso a chapters[chapterIdx].tokens[wordIdx] lanca RangeError e o reader nao abre. Mesma exposicao na linha 303 (dismissImage).

**Correção sugerida:** Clampar os indices restaurados contra chapters.length e chapters[chapterIdx].tokens.length antes de indexar (ex.: chapterIdx = chapterIdx.clamp(0, chapters.length-1); wordIdx = wordIdx.clamp(0, chapters[chapterIdx].tokens.length-1)), ou reusar _globalToLocal que ja tem fallback seguro.

#### [bug] _saveProgress invocado em dispose() faz _ref.read apos await da StateNotifier descartada

`lib/features/rsvp_reader/presentation/providers/rsvp_engine_provider.dart:766` (área: rules-compliance · verificação 1/1)

Em dispose() (linha 764-767), quando _saveDebounce esta ativo, chama _saveProgress() fire-and-forget. _saveProgress (linhas 705-728) faz await progressDao.upsertProgress(...) e, apos o await, executa _ref.read(booksDaoProvider) e _ref.read(librarySyncProvider.notifier).schedulePush(). Esses _ref.read rodam na continuacao do microtask, depois de super.dispose() ja ter executado, quando o Ref da StateNotifier ja pode estar invalidado -- risco de 'Cannot use ref after disposed'. Note que o screen.dart linha 85-89 documenta exatamente esse cuidado para o side panel, mas o engine nao o aplica aqui.

**Correção sugerida:** Capturar booksDao e librarySyncProvider.notifier em variaveis locais antes de qualquer await (como ja e feito para progressDao), ou guardar o save de dispose num caminho que nao toque _ref apos await (ex.: persistir so a progress row e pular schedulePush no caminho de dispose).

#### [docs] CLAUDE.md descreve implementacao de bookmark long-press que nao existe mais no codigo

`CLAUDE.md:133` (área: docs-consistency · verificação 1/1)

CLAUDE.md:133 (e a entrada de rsvp_paragraph_view na Estrutura) afirma que o widget aceita onWordLongPress -> converte tokens em WidgetSpan pra ter onTap + onLongPress independentes e que scroll/ereader/tts disparam bookmark via RsvpParagraphView.onWordLongPress propagado pelo ContextScrollView abrindo BookmarkCreateDialog. No codigo real onWordLongPress NAO EXISTE (grep -rn onWordLongPress lib/ = vazio). A impl atual usa SelectableText.rich com contextMenuBuilder e callback onBookmarkRange(first,last) (rsvp_paragraph_view.dart:127-172), expondo a acao via toolbar de selecao nativa (item l10n.bookmarkSave) e filtrando PROCESS_TEXT de terceiros. tasks.md:38 documenta a toolbar nativa corretamente, mas CLAUDE.md ficou com a descricao antiga. Doc enganosa para contribuidores.

**Correção sugerida:** Reescrever a descricao de bookmark long-press em CLAUDE.md para refletir onBookmarkRange + SelectableText.rich/contextMenuBuilder (range via selecao), removendo mencoes a onWordLongPress/WidgetSpan.

#### [docs] README e dois docs afirmam Three reading modes mas existem QUATRO (TTS ausente)

`README.md:9` (área: docs-consistency · verificação 3/3)

O enum real e enum ReaderMode { rsvp, scroll, ereader, tts } (lib/features/rsvp_reader/domain/entities/rsvp_state.dart:5). Mas README.md:9 lista Three reading modes, docs/rsvp-engine.md:97 diz 3 modes in the ReaderMode enum e docs/architecture.md:78 diz hosts all 3 modes. O modo TTS e uma feature MAIOR (narracao em audio, background playback via audio_service, controles de lockscreen, voice/engine picker, doc dedicado docs/tts-mode.md de 14KB) e esta COMPLETAMENTE ausente da secao Features do README (grep -niE tts|narrat|audio README.md retorna zero). Para repo divulgado em video e a divergencia mais visivel: o app narra livros mas o README diz que so ha 3 modos visuais.

**Correção sugerida:** Atualizar README (adicionar bullet de TTS + corrigir para Four reading modes), docs/rsvp-engine.md:97 e docs/architecture.md:78 para refletir os 4 modos. Mencionar background playback/lockscreen e voice picker.

#### [maintainability] Release Android assinado com a debug key, sem R8/ProGuard nem minify

`android/app/build.gradle.kts:35` (área: critic · verificação 1/1)

buildTypes.release usa `signingConfig = signingConfigs.getByName("debug")` (com TODO 'Add your own signing config') e nao define isMinifyEnabled/isShrinkResources/proguardFiles. Nao existe nenhum arquivo proguard no projeto (find -iname '*proguard*' vazio). Consequencia: `flutter build apk --release` produz APK assinado com chave de debug (nao publicavel, sem garantia de identidade) e sem ofuscacao/shrink; o codigo fica legivel por reverse engineering, o que combinado com o .env embutido como asset facilita a extracao do client secret OAuth.

**Correção sugerida:** Adicionar signingConfig de release lido de key.properties (gitignored), habilitar minify/shrink no release e incluir proguard-rules.pro com keep rules para drift, audio_service, flutter_tts e google_sign_in. No minimo documentar que o release atual nao e production-ready.

#### [maintainability] Two Linux backends duplicate the rate/pitch mapping and the whole word-timer + flush machinery

`lib/features/rsvp_reader/data/services/speechd_socket_backend.dart:253` (área: tts · verificação 1/1)

`SpeechdSocketBackend` and `SpeechDispatcherBackend` repeat substantial logic verbatim: the rate/pitch mapping `((_rate - 1.0) * 50).round().clamp(-100, 100)` (speechd_socket_backend.dart:254 & 259 vs speech_dispatcher_backend.dart:154-155), the effective-WPM/period computation `(60000.0/wpm).clamp(80,2000)` with `wpm.clamp(60,800)` (speechd_socket_backend.dart:410-411 vs speech_dispatcher_backend.dart:215-216), and near-identical `_flushRemainingWordCallbacks` (speechd_socket_backend.dart:464-472 vs speech_dispatcher_backend.dart:229-237) plus the per-word `_onProgress(offset, offset, '')` emission loop. `_linux_tts_shared.dart` already exists for exactly this purpose but only hosts `wordCharOffsets`/module humanising. A change to the rate mapping or timer cadence must be made in two places and the spd-say copy will silently drift (e.g. it doesn't have the per-word punctuation dwell multipliers the socket backend gained).

**Correção sugerida:** Hoist the rate/pitch→spd-scale mapping and the word-timer/flush helpers into `_linux_tts_shared.dart` (or a small mixin/base class), so both backends share one implementation and the spd-say fallback inherits the punctuation-dwell behaviour for free.

#### [maintainability] context_scroll_view State class is a ~590-line god object with mixed responsibilities

`lib/features/rsvp_reader/presentation/widgets/context_scroll_view.dart:71` (área: architecture · verificação 1/1)

`_ContextScrollViewState` spans lines 71-664 (~593 lines) and bundles: item/paragraph model building (`_buildItems`), scroll position tracking (`_onPositionsChanged`, `_catchUpToVisible`, `_snapToEndIfAtBottom`), engine sync (`_syncToEngine`), lock/recenter overlay control (`_toggleLock`, `_recenter`), RenderBox-based recenter measurement, image fullscreen launching, velocity-stepping boundary search (`_findNextBoundary`, ~120 lines of binary search), and a ~174-line `build`. Unlike the other 'god files' (settings_controls.dart and tts_voice_picker_sheet.dart are cohesive collections of small widgets), this is genuinely one class doing 5+ jobs, making it the hardest file to safely modify.

**Correção sugerida:** Extract the velocity-stepping/boundary logic (sentence-skip math) into a pure helper class (testable in isolation), and pull the scroll-follow + lock/recenter controller into a dedicated object. The widget should orchestrate, not contain all the math.

#### [rule-violation] Strings de erro hardcoded e vazando exception crua para o usuário (viola i18n)

`lib/features/book_library/presentation/widgets/library_list.dart:37` (área: library-stats-ui · verificação 1/1)

Vários estados de erro mostram texto não-i18n e ainda interpolam a exceção crua na UI: library_list.dart:37 `Text('Error: ${categorizedAsync.error}')`; reading_stats_screen.dart:87 `Text('$err')`; monthly_recap_screen.dart:35 `Text('$e')`; book_completion_screen.dart:39 `Text('$e')`. O CLAUDE.md exige que toda string de UI use ARB (i18n) e nunca hardcode PT/EN. Além de violar a regra, expor o `toString()` de uma exceção (stack/detalhes internos) é ruim de UX para um app que vai ser divulgado publicamente.

**Correção sugerida:** Substituir por uma string i18n genérica (ex: `l10n.genericLoadError`) e, no máximo, logar o erro detalhado fora da UI. Adicionar a chave nos ARB e rodar `flutter gen-l10n`.

#### [rule-violation] Hardcoded user-facing strings violate the i18n rule

`lib/features/rsvp_reader/presentation/screens/bookmarks_screen.dart:30` (área: architecture · verificação 1/1)

CLAUDE.md: 'Todas as strings de UI devem usar i18n ... Nunca hardcodar texto PT ou EN.' Violations found: bookmarks_screen.dart:30 `Text('Error: $e')`, library_list.dart:37 `Text('Error: ${categorizedAsync.error}')`, and settings_controls.dart:255 `const Text('OK')` (color-picker dialog confirm button). The error strings are reachable on any DB/stream failure and would show raw English to a pt-BR user; 'OK' is a standard button that should use a localized label. (The About-section 'RSVP Reader' / 'v0.1.0' in settings_screen.dart:65 are brand/version and acceptable.)

**Correção sugerida:** Add ARB keys (e.g. genericError(error), ok) to app_en.arb/app_pt.arb, run flutter gen-l10n, and replace the three literals with AppLocalizations lookups.

#### [rule-violation] Chapter list sheet hardcoda 'Chapters' e '{n} words'

`lib/features/rsvp_reader/presentation/widgets/chapter_list_sheet.dart:104` (área: reader-ui · verificação 3/3)

O bottom sheet de capitulos (mobile/portrait) hardcoda o titulo `'Chapters'` (linha 51) e, pior, o trailing `'${chapter.wordCount} words'` (linha 104) — texto em ingles concatenado com numero, sem pluralizacao nem traducao. Em PT-BR o usuario ve "532 words" em vez de "532 palavras". Note que o equivalente em tablet (`reader_side_panel.dart` `_ChapterList`, linha 195) ja mostra apenas `'${chapter.wordCount}'` sem a palavra, evidenciando inconsistencia entre as duas implementacoes.

**Correção sugerida:** Adicionar chaves ARB (`chaptersTitle`, e um `chapterWordCount(count)` com plural ICU) e usa-las; alinhar o formato com o `_ChapterList` do side panel.

#### [rule-violation] Hardcoded English strings in side panel titles

`lib/features/rsvp_reader/presentation/widgets/reader_side_panel.dart:52` (área: reader-ui · verificação 3/3)

O `_Header` title usa literais em ingles para dois dos tres modos do painel lateral: `ReaderSidePanelMode.settings => 'Settings'` e `ReaderSidePanelMode.chapters => 'Chapters'` (linhas 52-53), enquanto `bookmarks` corretamente usa `l10n.bookmarksTitle`. A chave `l10n.settings` ("Settings") JA existe no ARB (app_en.arb:5). Em PT-BR o painel de configuracoes/capitulos do tablet landscape aparece em ingles. Viola a regra 'Todas as strings de UI devem usar i18n'.

**Correção sugerida:** Trocar por `l10n.settings` (ja existe) e adicionar uma chave `chaptersTitle`/`readerChapters` ao ARB + flutter gen-l10n, usando-a aqui.

#### [test-gap] Drift schema migrations (v1 to v10) are completely untested

`lib/database/app_database.dart:76` (área: test-quality · verificação 3/3)

schemaVersion is 10 with 9 sequential onUpgrade steps (addColumn syncFileName; createTable syncImportFailures; addColumn source/sourceUrl/siteName; createTable readingSession; addColumn rating, ratingUpdatedAt, readerMode; createTable bookmarks; addColumn endGlobalWordIndex/endChapterIndex). There is no migration test and no use of Drift verifySelfIntegrity / schema-test harness. A user upgrading from an old DB version hits these steps in production with no automated proof they apply cleanly or that a partial chain (e.g. from==6) ends in a schema matching current table definitions. A broken migration corrupts the user library DB irrecoverably.

**Correção sugerida:** Adopt drift schema migration tooling: drift_dev schema dump/generate to snapshot each version, then a test that walks every from-version to v10 via SchemaVerifier and asserts the result matches expectedSchema. At minimum open an in-memory DB at each historical version and run the upgrade to confirm no SQL throws.

#### [test-gap] Article import pipeline (fetch -> readability -> tokens -> persist) is entirely untested

`lib/features/article_import/presentation/providers/article_import_provider.dart:0` (área: test-quality · verificação 1/1)

There is no test/features/article_import/ directory. Only the pure ReadabilityExtractor util is tested (readability_extractor_test.dart). The article import provider/service (HTTP fetch, error handling for non-HTML/404/empty body, URL normalization via UrlUtils, source=article persistence, share-sheet entry), one of the two documented content sources, has zero coverage. The EPUB side has a full integration test (epub_import_integration_test.dart) using a runtime-built fixture. The asymmetry leaves article ingestion unverified, including BookSource.article tagging and tokensJson roundtrip for articles.

**Correção sugerida:** Mirror the EPUB integration test: inject a fake http.Client returning canned HTML, drive the article import provider, and assert it produces a ParsedBook with source == BookSource.article, correct tokens, and that fetch failures surface as ImportStatus.error rather than throwing.

#### [test-gap] Sync apply-to-local does not exercise readerMode/rating/lastReadAt write conditions

`lib/features/library_sync/data/services/library_sync_service.dart:546` (área: test-quality · verificação 1/1)

The write-suppression conditions in _applyShardsToLocal are untested: progressDiffers (l546-551) deliberately includes readerMode != localProg.readerMode so a mode-only remote change writes while a same-instant identical progress does not; lastReadDiffers (l562) and the rating-timestamp guard (l569-582 using isAtSameMomentAs) follow the same pattern. CLAUDE.md calls the isAtSameMomentAs invariant load-bearing (mesmo instante registra como diferente, causando um write de DB por livro todo sync). None of these branches has a test, so the exact bug the comment guards against could silently return.

**Correção sugerida:** Add focused tests around _applyShardsToLocal (needs the fake gateway from finding 1): assert no upsert when remote progress equals local at the same instant (different isUtc); exactly one upsert when only readerMode differs; rating preserved across an unrelated metadata bump; lastReadAt written only when strictly newer.

#### [test-gap] SpeechdSocketBackend (primary Linux backend, 618 LOC of SSIP parsing) has zero test coverage

`lib/features/rsvp_reader/data/services/speechd_socket_backend.dart:24` (área: tts · verificação 3/3)

`ttsBackendProvider` prefers `SpeechdSocketBackend` on Linux and only falls back to the legacy `SpeechDispatcherBackend` when the socket is absent (tts_backend_provider.dart:29-31). Yet the socket backend is completely untested: a grep of test/ for `SpeechdSocketBackend`, `parseVoiceLinesForTest`, `parseEngineLinesForTest`, `escapeForSpeakForTest` returns nothing, while the *fallback* spd-say backend has `speech_dispatcher_backend_test.dart`. The untested surface includes the SSIP line framing in `_onLine` (code/separator parsing, 700-range event multiplexing), `_escapeForSpeak` dot-stuffing, `_parseVoiceLines`/`_parseEngineLines` tab/whitespace parsing, and `_computeWordMultipliers` — all non-trivial protocol code the author deliberately exposed via `@visibleForTesting` hooks that are never exercised. CLAUDE.md lists core-util/parsing tests as a priority.

**Correção sugerida:** Add unit tests for the exposed static hooks: `parseVoiceLinesForTest` (tab-separated triples, <2 cols skipped), `parseEngineLinesForTest`, `escapeForSpeakForTest` (a line that is exactly `.` becomes `..`), and `_computeWordMultipliers`/`wordCharOffsets` alignment. Optionally feed canned line sequences through `_onLine` via a test seam to lock down the BEGIN/END event handling and the `-` vs ` ` separator logic.

#### [test-gap] Organic RSVP end-of-book finishTicket (ticker-driven _advanceWord) is never exercised

`lib/features/rsvp_reader/presentation/providers/rsvp_engine_provider.dart:626` (área: test-quality · verificação 1/1)

The flagship completion feature for RSVP/scroll modes is the organic end in _advanceWord (l626-635): on reaching the last token via playback it stops the ticker, bumps finishTicket, flushes the session, and saves. The engine tests use _FakeTickerProvider whose Ticker never receives a frame callback (documented at the fixture l57-66), so _onTick -> _advanceWord never runs. Consequently finishTicket is asserted only for the TTS completion path (test l1095), never for the RSVP path that drives the /books/:id/completion screen for the common case. A regression that stops bumping finishTicket on organic RSVP finish would pass the whole suite.

**Correção sugerida:** Expose a test seam to invoke _advanceWord deterministically (a @visibleForTesting debugAdvanceWord() or a fake Ticker that fires a controllable tick), then assert that advancing past the last word increments finishTicket exactly once, flips isPlaying false, and calls _flushSession/_saveProgress.

### Severidade: LOW

#### [architecture] Inconsistent import-error UX across entry points (share vs desktop drop)

`lib/core/share/desktop_drop_handler.dart:51` (área: core-misc · verificação 1/1)

Article imports route through _ArticleImportCoordinator (app.dart:56) listening to articleImportProvider for global progress/error snackbars. EPUB drops on desktop call epubImportProvider.notifier.importFromPath directly with no equivalent coordinator listening to epubImportProvider, so EPUB drop progress and errors are not surfaced while article drops/shares are.

**Correção sugerida:** Add an epub-import coordinator that listens to epubImportProvider at the app level so EPUB drops get the same snackbars as article imports.

#### [architecture] book_persistence (the mandated import funnel) is owned by book_library but pulled by epub_import, article_import and library_sync

`lib/features/book_library/data/services/book_persistence.dart:1` (área: architecture · verificação 1/1)

persistParsedBook is the single mandated persistence funnel (good), but it lives in book_library/data and is imported across feature boundaries by the producers that should arguably not depend on book_library: epub_import_provider.dart:11, article_import_provider.dart:5, and library_sync_service.dart:18. So the two import features depend on book_library purely to persist, and library_sync depends on it to auto-import. The dependency direction is upside-down (low-level import pipelines depending on the higher-level library feature). It works, but it cements book_library as a hub every other content feature must import.

**Correção sugerida:** Consider moving persistParsedBook (and inline_image_storage) into a shared `content`/persistence module that epub_import, article_import, library_sync and book_library all depend on, instead of book_library being the de-facto shared infrastructure owner.

#### [architecture] Core domain models (WordToken/Chapter/ParsedBook) live inside epub_import but are consumed by 4 features

`lib/features/epub_import/domain/entities/word_token.dart:1` (área: architecture · verificação 1/1)

WordToken, Chapter and ParsedBook are the app's central domain models — the unit the RSVP engine, TTS player, library, sync and article import all operate on. Yet they live under `lib/features/epub_import/domain/entities/`. Confirmed cross-feature consumers: article_import, book_library, rsvp_reader, library_sync (e.g. rsvp_engine_provider.dart:15-16, tts_player.dart:6, rsvp_state.dart:1-2, book_persistence.dart:10-12, article_extraction_service.dart:9-10). The docs promise feature-based Clean Architecture where a feature owns its domain, but here the most-shared entities are owned by an import-pipeline feature whose name implies EPUB-specific scope. A new contributor reading `article_import` would not expect its core data type to come from `epub_import`. These should live in a shared location (e.g. `lib/core/domain/` or a dedicated `content` feature).

**Correção sugerida:** Move WordToken/Chapter/ParsedBook to a neutral shared module (e.g. `lib/core/domain/entities/` or a `content` feature) and update imports. Keep EPUB-specific parsing in epub_import; only the pure models move.

#### [architecture] rsvp_reader presentation reaches into book_library data service (inline_image_storage)

`lib/features/rsvp_reader/presentation/widgets/context_scroll_view.dart:16` (área: architecture · verificação 1/1)

InlineImageStorage is a `book_library/data/services` class, yet it's imported by rsvp_reader PRESENTATION in three places (context_scroll_view.dart:16, fullscreen_image_screen.dart:6, rsvp_image_view.dart:7) and also by library_sync/data (library_sync_service.dart:19). A presentation layer importing another feature's data service is a layering violation — presentation should not know about another feature's storage internals. It also means inline-image storage is conceptually shared infrastructure misfiled under book_library.

**Correção sugerida:** Move InlineImageStorage to `core/` (it is infrastructure: a path/file helper for book images) or expose it through a provider, so reader presentation depends on an abstraction rather than book_library's concrete data service.

#### [bug] Import de artigo http:// falha silenciosamente no iOS por falta de ATS exception

`ios/Runner/Info.plist:0` (área: critic · verificação 1/1)

UrlUtils.parseWithHttpsFallback (url_utils.dart:25) preserva URLs http:// digitadas/compartilhadas e article_extraction_service.dart:35 faz `_client.get(uri)` com esse uri. ios/Runner/Info.plist nao declara NSAppTransportSecurity, entao o ATS padrao do iOS bloqueia conexoes em texto claro. Resultado: artigo cuja URL e http:// (ou que redireciona via http) falha o fetch apenas no iOS, caindo no ArticleImportStatus.error generico sem indicar a causa, enquanto funciona no Android/Linux.

**Correção sugerida:** Definir politica explicita: ou forcar upgrade para https em parseWithHttpsFallback/no fetch (mostrando erro claro se nao houver https), ou adicionar NSAppTransportSecurity restrito. Forcar https e o caminho mais seguro.

#### [bug] Desktop drop only imports the first matched file; multi-file drops silently drop the rest

`lib/core/share/desktop_drop_handler.dart:55` (área: core-misc · verificação 1/1)

_onDragDone iterates details.files but returns after the first .epub match (line 58-60) and after the first valid URL in the fallback loop (line 71-72). Dropping several EPUBs at once imports exactly one and silently ignores the rest. There is also no feedback when a drop matches nothing: details.files non-empty but no .epub and no readable URL falls through with no signal to the user.

**Correção sugerida:** Import every .epub in the drop instead of returning after the first; show a snackbar when a non-empty drop produced zero imports.

#### [bug] Table cells (td/th) concatenate - words from adjacent cells merge into one token

`lib/core/utils/html_stripper.dart:14` (área: import · verificação 1/1)

_blockTags (and the identical list in chapter_parser.dart:42) includes tr but not td/th/caption. I verified HtmlStripper.strip('<table><tr><td>cell1</td><td>cell2</td></tr></table>') returns 'cell1cell2' - adjacent cell texts run together with no whitespace, producing a single garbled token like cell1cell2 that the tokenizer treats as one word with a bogus ORP. Tables in EPUBs/articles (data tables, definition layouts) get corrupted; tr separates rows but cells within a row merge.

**Correção sugerida:** Add td, th (and ideally caption) to _blockTags in both html_stripper.dart and chapter_parser.dart so each cell is separated by a paragraph/whitespace boundary. Add a test covering a multi-cell row.

#### [bug] ImageExportService dereferences boundary RenderObject with ! after an await; disposed screen crashes

`lib/core/utils/image_export_service.dart:44` (área: core-misc · verificação 1/1)

_capturePng awaits SchedulerBinding.instance.endOfFrame (line 42) then does key.currentContext!.findRenderObject() as RenderRepaintBoundary (line 43-44). If the share screen is disposed during that async gap, currentContext is null and the ! throws 'Null check operator used on a null value'. Call sites guard with a _sharing flag but do not cancel the in-flight export on dispose, so share-then-back can throw an unhandled exception.

**Correção sugerida:** Replace the ! with a null check returning early or throwing a handled error; surface a localized export-failed message.

#### [bug] splitHyphenated drops a leading hyphen, losing visible text

`lib/core/utils/text_tokenizer.dart:77` (área: import · verificação 1/1)

The regex RegExp(r'[^-]+-?') requires at least one non-hyphen char before an optional trailing hyphen, so a leading hyphen is never matched. Verified: splitHyphenated('-x') yields ['x'] (leading - lost) and splitHyphenated('--') falls back to the whole word. For tokens like a dialogue dash or stray leading hyphen, the displayed word loses a character (globalIndex accounting stays consistent, so it is cosmetic, not a desync).

**Correção sugerida:** If preserving the leading hyphen matters, prepend it to the first match, or adjust the regex to -*[^-]+-? and keep leading dashes attached. Low priority given the no-hyphen fast path covers most words.

#### [bug] Article fetch ignores declared charset - latin-1/windows-1252 pages become mojibake

`lib/features/article_import/data/services/article_extraction_service.dart:59` (área: import · verificação 1/1)

final body = utf8.decode(response.bodyBytes, allowMalformed: true); unconditionally decodes as UTF-8, ignoring the HTTP Content-Type charset and any <meta charset>. The comment claims UTF-8 is 'almost always right', but for genuinely ISO-8859-1 / windows-1252 pages (still common on older sites and regional/PT news sites) every high byte (accented chars, em-dash, curly quotes) is replaced with U+FFFD, so the imported article is full of replacement characters. allowMalformed prevents a crash but guarantees data loss rather than correct decoding.

**Correção sugerida:** Detect charset from the Content-Type header (response.headers['content-type']) and/or a <meta charset> sniff of the raw bytes; fall back to UTF-8 only when unknown. A small windows-1252 table or charset_converter/enough_convert covers the common cases.

#### [bug] Article fetch has no response-size cap - hostile/large page can exhaust memory

`lib/features/article_import/data/services/article_extraction_service.dart:35` (área: import · verificação 1/1)

_client.get(uri, ...) buffers the entire response into response.bodyBytes with only a 20s timeout and no Content-Length / byte-count guard. A multi-hundred-MB page (or a server streaming an effectively unbounded body) is fully loaded into memory before readability/stripping even starts. On a phone this can OOM the app. Redirects are also followed with the default policy.

**Correção sugerida:** Use a streamed request and abort once accumulated bytes exceed a sane cap (e.g. 10-20 MB), throwing ArticleExtractionException. Optionally reject non-text content types early via the Content-Type header.

#### [bug] Delecao de livro e fan-out de tokens nao sao transacionais

`lib/features/book_library/presentation/providers/book_library_provider.dart:145` (área: database · verificação 1/1)

deleteBookProvider, _deleteBookLocally (library_sync_service.dart:690) e o fan-out persistChaptersWithImages (book_persistence.dart:75, N insertChapterTokens mais insertBook) fazem deletes/inserts sequenciais sem transaction. Crash no meio deixa livro sem tokens ou tokens orfaos; com FK OFF nada limpa.

**Correção sugerida:** Envolver o fan-out de import e a cascata de delete em db.transaction.

#### [bug] Existing-book metadata (title/author/syncFileName/counts) never converges on already-synced devices

`lib/features/library_sync/data/services/library_sync_service.dart:536` (área: sync · verificação 1/1)

`mergeBook` computes merged `title`, `author`, `totalWords`, `chapterCount`, and `syncFileName` (sync_library.dart:248-264) and these are pushed to the remote books shard, but `_applyShardsToLocal` only writes back progress (552-561), lastReadAt (562-567) and rating (570-586) for a book that already exists locally (`local != null`). The merged title/author/totalWords/chapterCount/syncFileName are never persisted to the local DB. So if device A re-imports or edits a book's metadata, device B (which already has the row) keeps stale metadata forever. Most relevant for `syncFileName`: a divergent filename between the local row and the merged shard can cause `_uploadMissingEpubs` / orphan logic to disagree about which file backs the book.

**Correção sugerida:** After the progress/rating writes, persist the merged metadata (title/author/totalWords/chapterCount/syncFileName) to the local book row when it differs from `local`, e.g. via a BooksDao.applySyncedMetadata method, guarded by the same isAtSameMomentAs/`updatedAt` comparison used elsewhere.

#### [bug] `pushTombstone` does a non-merging read-modify-write of the whole books shard

`lib/features/library_sync/data/services/library_sync_service.dart:1009` (área: sync · verificação 1/1)

Unlike the main `sync()` path which merges local×remote per shard, `pushTombstone` reads `library/books.json`, mutates a single entry (or appends a tombstone), and writes the whole shard back (lines 1009-1050) with no merge. If another device pushed a newer books shard (e.g. fresh progress on a different book) between this read and write, that concurrent change is clobbered by the overwrite. It self-heals only because each device re-pushes its own state on the next full sync, but the other device's update is temporarily lost from the file and any device that pulls in that window sees stale data. Combined with the dropped-tombstone bug above, the standalone tombstone path is the most fragile part of the sync.

**Correção sugerida:** Re-read + re-merge inside `pushTombstone` (reuse `mergeBooksShard` against a freshly-built local snapshot), or route deletes exclusively through the full merge `sync()` so a single code path owns books.json writes. At minimum, do the tombstone as part of the merged push rather than a separate write.

#### [bug] Remote bookmark for a just-deleted book can be resurrected as an orphan

`lib/features/library_sync/data/services/library_sync_service.dart:625` (área: sync · verificação 1/1)

In `_applyShardsToLocal`, book tombstones are processed first and `_deleteBookLocally` hard-deletes the book's bookmarks via `deleteAllForBook` (line 697). Later the bookmarks loop iterates `merged.bookmarks.bookmarks`; for a remote bookmark belonging to that now-deleted book, if this device never had the bookmark (`local == null`) and the remote row is NOT a tombstone (deletedAt==null, line 632), it is inserted via `applyFromSync` (lines 633-645). The bookmarks table has no FK to books (bookmarks_table.dart — `bookId` is a plain text column), so this creates an orphan bookmark with no parent book row. It won't crash but becomes invisible dead data. Reachable when a book+bookmark are created and the book deleted on device A before device B ever saw the book, and B's bookmark shard pull still contains the live bookmark.

**Correção sugerida:** When inserting a new remote bookmark, skip it if its `bookId` is a known book tombstone in the merged books shard (or if no active book row exists for it locally after the books pass).

#### [bug] `listFiles` failure (caught to empty list) triggers full EPUB re-upload and prunes all import-failure records

`lib/features/library_sync/data/services/library_sync_service.dart:194` (área: sync · verificação 1/1)

`listBooksF` swallows any error with `.catchError((_) => <String>[])`. A transient Drive list failure therefore yields `remoteEpubFiles = {}`, which makes `_uploadMissingEpubs` treat every active book as missing remotely (`remoteEpubFiles.contains(fileName)` is false) and re-read+re-upload every local EPUB (lines 832-840) — a potentially large, wasteful upload. It also makes `_autoImportOrphanFiles` call `_failuresDao.retainOnly({})` (line 865), pruning ALL recorded import-failure entries because the empty set matches nothing. A failed inventory should abort the EPUB phase, not silently behave as 'the folder is empty'.

**Correção sugerida:** Distinguish 'list failed' from 'list returned empty'. On list failure, skip both `_uploadMissingEpubs` and `_autoImportOrphanFiles` (and the `retainOnly` prune) for this sync instead of treating the folder as empty — e.g. propagate a sentinel/null rather than `[]`.

#### [bug] mergeBookmark / mergeBook are non-deterministic on exactly-equal timestamps

`lib/features/library_sync/domain/entities/sync_library.dart:725` (área: test-quality · verificação 1/1)

mergeBookmark returns a.updatedAt.isAfter(b.updatedAt) ? a : b; on equal updatedAt it returns b, so mergeBookmark(x,y) != mergeBookmark(y,x). Same shape in mergeBook via _later/newer selection and in _mergeRating (l278-280) when both timestamps are null but both sides carry different ratings (returns a). Sync timestamps are second-granularity ISO strings, so two devices editing the same record within the same recorded second is plausible. Because the merge is not commutative, peer A and peer B can converge to different values for that field, a CRDT correctness hole. No test asserts commutativity for any merge.

**Correção sugerida:** Add a deterministic tiebreaker independent of argument order (compare updatedBy/device id, or for bookmarks the higher globalWordIndex / lexicographic id) when timestamps are equal, and add commutativity tests (merge(a,b) == merge(b,a)) across the merge family.

#### [bug] Settings change made *during* an in-flight sync is silently dropped

`lib/features/library_sync/presentation/providers/library_sync_provider.dart:161` (área: sync · verificação 1/1)

`triggerSync` captures `_settingsUpdatedAt` at sync start (passed as `localSettingsUpdatedAt`, line 152) and then unconditionally sets `_settingsUpdatedAt = null` after `await service.sync(...)` returns (line 161). If the user changes a display setting while a sync is in flight, `DisplaySettingsNotifier._notifySyncChanged` calls `markSettingsDirty()` (sets `_settingsUpdatedAt` to the new timestamp) and `schedulePush()` (debounce timer). The completing sync then nulls `_settingsUpdatedAt`, discarding that timestamp. The next debounced sync reads the NEW setting values via `readSettings()` but with `_settingsUpdatedAt == null`, so `settingsTs` falls back to the remote settings' `updatedAt` (library_sync_service.dart:234-236) — the local change loses the settings LWW race and never propagates to other devices.

**Correção sugerida:** Snapshot the timestamp being synced into a local and only null `_settingsUpdatedAt` if it still equals that snapshot (compare-and-clear), or move the clear to before `service.sync` is awaited so a mid-sync `markSettingsDirty` survives.

#### [bug] Separador de milhar fixo em vírgula no _StatsBlock ignora locale

`lib/features/reading_stats/presentation/screens/book_completion_screen.dart:243` (área: library-stats-ui · verificação 1/1)

`_formatWithThousands` insere `,` como separador de milhar manualmente (`buf.write(',')`). O app é bilíngue PT/EN e usa `intl`/`DateFormat` em outros lugares (ex: monthly_recap_screen.dart:61). Em pt-BR o separador de milhar é `.`, não `,`, então `12,345` aparece errado para o usuário PT. O projeto já depende de `intl`, então há `NumberFormat` disponível.

**Correção sugerida:** Usar `NumberFormat.decimalPattern(l10n.localeName).format(n)` em vez do loop manual, alinhando com o resto da formatação localizada.

#### [bug] SSIP `_send` advances `_appliedRate`/`_appliedLanguage` etc. even when the command timed out or errored

`lib/features/rsvp_reader/data/services/speechd_socket_backend.dart:234` (área: tts · verificação 1/1)

`_applyDirtySettings` awaits each `_send('SET SELF …')` and then unconditionally records the value as applied (e.g. `await _send('SET SELF RATE $spdRate'); _appliedRate = _rate;`). But `_send` resolves to a synthetic `_SsipResponse(0, [], 'timeout')` on timeout (line 331-338) and never throws for a non-OK SSIP code — so a SET that the daemon rejected or that timed out still flips the `_applied*` snapshot. The dirty-tracking then suppresses every future re-send of that field, so a rate/voice/engine change the daemon never accepted is silently dropped until a *different* value is chosen. Same pattern for engine/language/voice/pitch.

**Correção sugerida:** Check the response code before advancing the snapshot: SSIP success replies are 2xx (e.g. 2xx OK). Only set `_appliedRate = _rate` when `r.code >= 200 && r.code < 300`; on timeout (code 0) or error, leave the field dirty so the next speak retries it.

#### [bug] `restartIfStalled` never resets `_lastProgressAt`, so a restart that fails to produce audio can re-trigger on every resume

`lib/features/rsvp_reader/data/services/tts_player.dart:265` (área: tts · verificação 1/1)

`restartIfStalled` sets `_isPlaying=false`, clears the queue, stops the backend and re-issues `play(...)`, but unlike `pause()` (which nulls `_lastProgressAt` at line 235) it leaves the stale heartbeat in place. `play()` doesn't set `_lastProgressAt` either — only an actual progress callback does. So if the restart still yields no progress (backend genuinely dead, e.g. daemon gone), `_lastProgressAt` remains >10s old and the *next* `didChangeAppLifecycleState(resumed)` immediately satisfies the stall threshold again and restarts once more. It won't tight-loop today (only fires on app resume, not a timer) but it's a latent foot-gun and inconsistent with `pause()`.

**Correção sugerida:** In `restartIfStalled`, set `_lastProgressAt = null` (or `DateTime.now()`) before calling `play(...)` so the new attempt is given a fresh stall window rather than inheriting the old one.

#### [bug] Shared TTS backend callbacks can be nulled by a stale player during master-detail reader flip

`lib/features/rsvp_reader/data/services/tts_player.dart:294` (área: architecture · verificação 1/1)

ttsBackendProvider is a non-autoDispose singleton shared across reader instances. Each engine builds its own TtsPlayer that, in init() (tts_player.dart:131-134), sets backend.onProgress/onStart/onCompletion/onError to its own handlers, and in dispose() (lines 294-297) sets them back to null. On tablet master-detail, switching the selected book disposes the old engine/player while constructing the new one. If the old player's async `dispose()` (which awaits `_backend.stop()` first, line 290) resolves AFTER the new player's `init()` has re-attached its callbacks, the old dispose nulls out the NEW player's backend callbacks — silently killing word-highlight progress and book-finished detection for the now-active reader, with no error surfaced.

**Correção sugerida:** Guard the null-out in dispose(): only clear a backend callback if it still points at this player's own handler (compare identity), or route all callback ownership through a generation/token the backend checks before invoking. Detaching another live player's callbacks must be impossible.

#### [bug] Zero uso de Semantics em toda a camada de UI (158 widgets)

`lib/features/rsvp_reader/presentation/widgets/rsvp_word_display.dart:0` (área: critic · verificação 1/1)

Grep por Semantics/semanticLabel/excludeSemantics/MergeSemantics retorna 0 ocorrencias em 158 arquivos de widget de lib/. O display RSVP renderiza a palavra atual via RichText com TextSpans coloridos (ORP) sem semanticsLabel, entao um leitor de tela le a palavra fragmentada por span ou nada coerente; os IconButtons de transport/lock/recenter e o FAB nao tem tooltips/labels semanticos. Para um leitor de livros, a ausencia total de suporte a screen reader e lacuna funcional real, nao cosmetica.

**Correção sugerida:** Adicionar semanticsLabel na palavra RSVP (palavra completa via ExcludeSemantics no RichText + Semantics(label: word)), tooltips nos IconButtons de controle e labels nos cards da biblioteca. Validar com flutter test + meetsGuideline(textContrastGuideline / labeledTapTargetGuideline).

#### [bug] Busy-loop sem timeout no _initialSync se SyncConfig.load() lançar

`lib/main.dart:91` (área: library-stats-ui · verificação 1/1)

`_initialSync` faz `while (!configNotifier.isLoaded) { await Future.delayed(50ms); }`. `_loaded` só é setado `true` na ÚLTIMA linha de `SyncConfigNotifier.load()` (sync_config_provider.dart:47); se qualquer await anterior dentro de `load()` lançar (SharedPreferences indisponível, etc.), `_loaded` permanece `false` e esse loop gira indefinidamente a cada 50ms em background. Baixa probabilidade, mas é um loop sem condição de saída/timeout.

**Correção sugerida:** Adicionar um timeout máximo ao polling (ex: parar após N iterações ou usar um Completer resolvido em try/finally dentro de `load()`), garantindo que o startup não fique presa num loop em caso de falha de leitura de prefs.

#### [docs] README nao menciona Bookmarks (feature shipada com sync completo)

`README.md:7` (área: docs-consistency · verificação 1/1)

Bookmarks e feature completa: tabela bookmarks (schema v9/v10), DAO, sync via shard library/bookmarks.json com LWW e tombstones, UI compartilhada (BookmarksList, BookmarksListSheet, tela global /bookmarks). Documentada em CLAUDE.md e tasks.md:38, mas a secao Features do README.md (linhas 7-28) nao a cita (grep -niE bookmark README.md = vazio).

**Correção sugerida:** Adicionar bullet de Bookmarks na secao Features do README, mencionando o sync cross-device.

#### [docs] tasks.md expoe bugs em aberto e nota interna contraditoria com CLAUDE.md

`tasks.md:38` (área: docs-consistency · verificação 1/1)

tasks.md tem bugs abertos potencialmente embaracosos em demo publica: linha 36 returning to the app in context mode breaks the sync, linha 51 investigate imports when the user drops an EPUB straight into the Drive folder ... something isnt behaving as expected, linha 53 highlight ainda desincroniza levemente (TTS Linux/Piper). Alem disso, linha 38 descreve bookmark long-press como triggers the native Android selection toolbar with a Salvar marcador entry enquanto CLAUDE.md:133 descreve um dialogo - as duas docs internas se contradizem (a verdade e a toolbar, conforme o codigo). Como arquivo versionado e visivel, convem revisar antes de divulgar.

**Correção sugerida:** Antes do video, fechar/atualizar bugs ja resolvidos e mover bugs especulativos em aberto para GitHub Issues. Reconciliar a descricao de bookmark entre tasks.md e CLAUDE.md.

#### [maintainability] ImageExportService writes deterministic temp PNGs that are never cleaned up

`lib/core/utils/image_export_service.dart:25` (área: core-misc · verificação 1/1)

shareWidgetAsPng writes ${dir.path}/$filename.png into the OS temp dir and never deletes it. Filenames are deterministic per book/month (rsvp-finished-<bookId>, rsvp-recap-2026-06) so they overwrite rather than grow unbounded, but every distinct book/month leaves a residual PNG with no cleanup pass.

**Correção sugerida:** Delete the temp file after SharePlus.instance.share returns (best-effort), or document that cleanup is delegated to the OS temp dir.

#### [maintainability] PlatformCapabilities supportsTts true on Windows/macOS but doc comment stale on Linux backend

`lib/core/utils/platform_capabilities.dart:61` (área: core-misc · verificação 1/1)

supportsTts returns true for Android/iOS/Linux/macOS/Windows (lines 63-67). The doc on this getter and on isLinux (line 40-43) says 'Linux desktop uses a custom backend on top of spd-say', while the implemented selection (per CLAUDE.md) is SpeechdSocketBackend (SSIP) primary with spd-say only as fallback. The doc conflates the two Linux backends and is stale.

**Correção sugerida:** Update doc comments to reflect SpeechdSocketBackend (SSIP) primary with spd-say fallback; confirm macOS/Windows flutter_tts voices populate at runtime.

#### [maintainability] Unused English errorMessage strings carried in import state

`lib/features/article_import/data/services/article_extraction_service.dart:30` (área: import · verificação 1/1)

The extraction services throw English messages ('Invalid URL: $url', 'Failed to fetch URL: $e', 'No readable content found') and the providers store e.toString() into errorMessage. The UI never displays these - library_screen.dart:83 shows the localized l10n.importError and app.dart:102 shows l10n.importArticleError, ignoring the stored message. So errorMessage/ImportState.errorMessage is effectively dead state that only invites a future i18n regression if someone wires it to a SnackBar. Same dead-ish field in both EpubImportNotifier and ArticleImportNotifier.

**Correção sugerida:** Either drop the errorMessage field (since the UI uses generic localized text) or model a typed error enum (network/parse/empty) that the UI maps to localized strings - never surface raw exception text.

#### [maintainability] Misleading comment: gateway returns a cached client, not a fresh one per operation

`lib/features/library_sync/presentation/providers/library_sync_provider.dart:17` (área: sync · verificação 1/1)

The `driveSyncFolderGatewayProvider` doc says it 'Takes a closure that returns a fresh authenticated client each operation', but `authenticatedClient()` in both auth backends returns the cached `_client` singleton (google_sign_in_drive_auth_backend.dart:183, desktop_oauth_drive_auth_backend.dart:117). The behavior (reusing one AutoRefreshingAuthClient) is actually correct and avoids leaks, but the comment misrepresents it and could lead a future maintainer to add per-call `client.close()` in the gateway, which would close the shared client mid-session.

**Correção sugerida:** Update the comment to state the factory returns the shared auto-refreshing client (refresh handled internally) and that callers must NOT close it.

#### [maintainability] gateway.clearCache() not invoked on the connect-failure signOut path

`lib/features/library_sync/presentation/widgets/sync_settings_section.dart:199` (área: async-safety · verificação 1/1)

`_disconnect` correctly calls `signOut()` then `driveSyncFolderGatewayProvider.clearCache()` (lines 208-210), but the error-recovery `signOut()` inside `_connect` (line 199, when `ensureRootFolder`/`setDriveFolderId` throws after a successful sign-in) does not clear the gateway cache. In practice the caches are likely empty at that point, so impact is minimal, but the two sign-out paths are inconsistent and a future reorder of `_connect` could leave stale cached fileIds tied to a now-disconnected account. CLAUDE.md treats `clearCache()` as the disconnect invariant.

**Correção sugerida:** Factor a single disconnect helper (signOut + setDriveFolderId(null) + clearCache) and reuse it from the `_connect` catch block so every teardown path clears the gateway cache uniformly.

#### [maintainability] Engine humaniser duplicated between flutter_tts and Linux backends with no shared source

`lib/features/rsvp_reader/data/services/flutter_tts_backend.dart:243` (área: tts · verificação 1/1)

`_humaniseEngineId` (flutter_tts_backend.dart:243, Android package-name → label) and `humaniseSpeechdModuleId` (_linux_tts_shared.dart:36, speech-dispatcher module → label) are two independent prettifier tables for the same UI concept (the engine picker). They've already diverged in style (one returns '$hit TTS', the other returns plain names like 'eSpeak NG'), so the same engine family can render inconsistently depending on platform. Not a bug, but the kind of split-brain mapping CLAUDE.md elsewhere consolidates (cf. the centralised font_mapper rule).

**Correção sugerida:** If unification isn't warranted (the inputs genuinely differ: Android dotted package ids vs speechd module ids), at least co-locate both tables and document the intended label style so future additions stay consistent.

#### [maintainability] Entities lack value equality (DisplaySettings/RsvpState/Bookmark/Chapter)

`lib/features/rsvp_reader/domain/entities/display_settings.dart:35` (área: engine · verificação 1/1)

These entities define copyWith but no operator==/hashCode (only WordToken via freezed). For displaySettingsProvider, an update producing an equal-valued object is a new identity, so every ref.watch rebuilds and .select cannot short-circuit; the settings preview watches these heavily.

**Correção sugerida:** Add operator==/hashCode or migrate to freezed/Equatable for at least DisplaySettings.

#### [maintainability] bookmarkCountProvider and bookmarksProvider open two DB streams for the same book

`lib/features/rsvp_reader/presentation/providers/bookmarks_provider.dart:23` (área: engine · verificação 1/1)

Both providers call dao.watchForBook(bookId) independently, opening two Drift streams over identical rows when a screen needs both. The count is just rows.length of data the list already maps.

**Correção sugerida:** Derive bookmarkCountProvider from bookmarksProvider so one stream backs both.

#### [maintainability] Implementacao duplicada da lista de capitulos

`lib/features/rsvp_reader/presentation/widgets/reader_side_panel.dart:152` (área: reader-ui · verificação 1/1)

`reader_side_panel.dart` `_ChapterList` (linhas 152-207) e `chapter_list_sheet.dart` `ChapterListSheet` (linhas 7-124) sao duas implementacoes quase identicas da mesma lista de capitulos: mesmo `ListView.builder` sobre `state.chapters`, mesmo destaque do capitulo atual via `settings.orpColor`, mesmo `onTap` em `engine.jumpToChapter(index)`. Divergem em detalhes (o sheet fecha com Navigator.pop e mostra 'N words'; o painel nao). Manutencao dupla — uma mudanca de layout/estilo precisa ser feita em dois lugares e ja divergiu.

**Correção sugerida:** Extrair um `ChapterList(bookId, settings, onAfterTap?)` compartilhado (como ja foi feito com `BookmarksList`) e consumi-lo tanto no sheet quanto no side panel.

#### [maintainability] Widgets _StepIcon e _PresetChip duplicados entre wpm_selector e tts_rate_selector

`lib/features/rsvp_reader/presentation/widgets/tts_rate_selector.dart:90` (área: reader-ui · verificação 1/1)

`tts_rate_selector.dart` define `_StepIcon` (linha 90) e `_PresetChip` (linha 205) que sao copias byte-a-byte dos mesmos em `wpm_selector.dart` (linhas 209 e 305). Os capsules `TtsRateCapsule` e `WpmCapsule` tambem compartilham toda a estrutura visual (border/body/AnimatedContainer/InkWell). Duplicacao pura que ja foi reconhecida no proprio comentario ('Mirrors WpmCapsule / WpmPresetRow shape').

**Correção sugerida:** Extrair `_StepIcon` e `_PresetChip` (e idealmente um `SpeedCapsule` base parametrizado pelo label) para um arquivo compartilhado e reusar em ambos.

#### [maintainability] Versao do app hardcoded como 'v0.1.0' em vez de PackageInfo

`lib/features/settings/presentation/screens/settings_screen.dart:67` (área: rules-compliance · verificação 1/1)

O subtitle do tile 'About' usa Text('v0.1.0', ...) literal. Nao e string traduzivel, mas e um valor de manutencao que vai desincronizar do pubspec.yaml a cada release (facil de esquecer de bumpar). Ja que o repo sera divulgado publicamente, uma versao fixa errada na tela e um arranhao de polish visivel.

**Correção sugerida:** Ler a versao via package_info_plus (PackageInfo.fromPlatform()) e exibir dinamicamente, ou ao menos centralizar a constante em app_constants.dart.

#### [maintainability] Versao do app hardcoded em 'v0.1.0' diverge da fonte unica (pubspec)

`lib/features/settings/presentation/screens/settings_screen.dart:67` (área: critic · verificação 1/1)

A secao About hardcoda `Text('RSVP Reader', ...)` (linha 65) e `Text('v0.1.0', ...)` (linha 67). A versao 'v0.1.0' e copia manual do pubspec.yaml (version: 0.1.0); na proxima bump do pubspec a tela About mostrara versao errada silenciosamente. O literal 'RSVP Reader' tambem deveria vir do app name/i18n.

**Correção sugerida:** Ler a versao em runtime via package_info_plus (PackageInfo.fromPlatform().version) em vez de hardcodar, eliminando o drift com o pubspec.

#### [maintainability] 12 chaves ARB orfas (dead i18n) infladas em EN e PT

`lib/l10n/app_en.arb:0` (área: critic · verificação 1/1)

Comparando as 218 chaves dos ARB com o uso real em lib/test, 12 nunca sao referenciadas: tapToPause, tapToResume, bookFinished, ttsFirstUseHint, statsOtherBooks, recapMonthHeadline, recapBookProgress, completionCardFooter, ttsVoiceCurrent, library, settingsFontSize, settingsLanguage. Existem em app_en.arb E app_pt.arb (e no app_localizations.dart gerado), custando manutencao de traducao para texto que nunca aparece; settingsFontSize/settingsLanguage/library sugerem features removidas cujas strings ficaram para tras.

**Correção sugerida:** Remover as 12 chaves de app_en.arb e app_pt.arb (com seus @-metadados) e rodar flutter gen-l10n. Considerar um teste/CI que falhe quando uma chave gerada nao e referenciada.

#### [maintainability] Bootstrap sem handler global de erros nem guarda em volta da init de I/O

`lib/main.dart:41` (área: critic · verificação 1/1)

main.dart faz getApplicationDocumentsDirectory (41), AudioService.init (53) e _initialSync sem nenhum try/catch, e nem main nem app.dart instalam FlutterError.onError, PlatformDispatcher.instance.onError, runZonedGuarded ou ErrorWidget.builder customizado. Uma falha de I/O ao criar o DB (disco cheio, permissao) antes de runApp derruba o app com a tela de erro vermelha padrao e sem telemetria; erros assincronos nao tratados tambem passam despercebidos.

**Correção sugerida:** Envolver o bootstrap em runZonedGuarded, instalar FlutterError.onError + PlatformDispatcher.instance.onError com log, e renderizar tela de erro amigavel (ErrorWidget.builder) em release.

#### [performance] cached_tokens sem indice em bookId (full scan na query mais quente)

`lib/database/tables/cached_tokens_table.dart:7` (área: database · verificação 2/3)

bookId filtra getTokensForBook, getTokensForChapter, getWordCountBeforeChapter e deleteTokensForBook. Apenas 3 indices no gerado e nenhum em cached_tokens; so a PK id e indexada, entao table scan. reading_session e bookmarks ganharam TableIndex em book_id; cached_tokens foi esquecido.

**Correção sugerida:** Adicionar TableIndex em bookId (ou bookId+chapterIndex) via m.createIndex num bump de schema.

#### [performance] GridView aninhado em ListView nos summary cards e reading grid (custo de layout)

`lib/features/reading_stats/presentation/widgets/stats_summary_cards.dart:23` (área: library-stats-ui · verificação 1/1)

`StatsSummaryCards` usa `GridView.count(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` dentro do `ListView` da tela de stats. shrinkWrap desabilita o sliver lazy e força o grid a medir todos os filhos a cada layout. Aqui o conjunto é pequeno (4 tiles fixos) então o impacto é baixo, mas é um anti-padrão repetido (também em monthly_recap_card `_ReadingGrid`). Não é bug, é dívida de layout que escala mal se a contagem crescer.

**Correção sugerida:** Para conjuntos fixos pequenos, preferir `Row`/`Wrap` ou um grid manual de 2 colunas com `Row`s; manter `GridView` lazy só quando a contagem é dinâmica e grande. Aceitável manter como está dado o tamanho fixo, mas vale documentar a escolha.

#### [performance] Every WPM/rate step rewrites all 25 prefs keys and schedules a sync push

`lib/features/rsvp_reader/presentation/providers/rsvp_engine_provider.dart:422` (área: engine · verificação 1/1)

setWpm/setTtsRate call displaySettings update(), which (display_settings_provider.dart:106) unconditionally _save()s ~25 prefs keys and _notifySyncChanged()s on every call with no debounce, unlike progress's 300ms debounce. A slider drag issues a full rewrite plus sync push per step.

**Correção sugerida:** Debounce settings persistence behind a Timer, or add a non-persisting live-drag path that flushes once on drag end.

#### [performance] Lista de vozes TTS usa ListView nao-lazy

`lib/features/rsvp_reader/presentation/widgets/tts_voice_picker_sheet.dart:585` (área: reader-ui · verificação 1/1)

`_VoiceList` materializa TODOS os tiles num `List<Widget>` e passa a `ListView(controller:..., children: items)` (linhas 565-589), nao usa `ListView.builder`. Engines Android (Google TTS) reportam frequentemente 100+ vozes; com escopo 'Todas' todas viram `_VoiceTile` (cada um com ListTile + subtitle de 2 linhas) instanciados de uma vez, fora do viewport. Custo de layout/construcao desnecessario na abertura do sheet.

**Correção sugerida:** Construir uma lista plana intercalada (headers + tiles) e renderizar com `ListView.builder`/`itemBuilder` indexando essa lista, ou usar `SliverList` com headers fixos.

#### [rule-violation] Hardcoded English 'Unknown Title'/'Unknown Author' shown verbatim in UI (i18n violation)

`lib/features/epub_import/data/services/epub_extraction_service.dart:16` (área: import · verificação 1/1)

final title = epubBook.title ?? 'Unknown Title'; and final author = epubBook.author ?? 'Unknown Author'; bake English literals into the persisted Book row. These are rendered verbatim in the library (book_card.dart:114 widget.book.title) and there are no unknownTitle/unknownAuthor keys in the ARB files. CLAUDE.md rule: 'Todas as strings de UI devem usar i18n ... Nunca hardcodar texto PT ou EN.' A Portuguese user importing an untitled EPUB sees English text.

**Correção sugerida:** Store null/empty for missing title/author and resolve a localized placeholder at the UI layer (book_card / reader), or pass the localized fallback into the extraction call. Add unknownTitle/unknownAuthor ARB keys (en + pt).

#### [rule-violation] Raw English backend exception text is interpolated into the user-facing snackbar

`lib/features/rsvp_reader/data/services/speechd_socket_backend.dart:81` (área: tts · verificação 1/1)

`TtsUnavailableException` messages and `_onError` strings (e.g. 'speech-dispatcher socket not found. Install and start…', 'SSIP SPEAK failed: …', 'speech-dispatcher socket closed unexpectedly') are hardcoded English. These propagate to the engine's `ttsErrorProvider` and are shown to the user via `l10n.ttsErrorPrefix(next)` (rsvp_reader_screen.dart:126) — so the prefix is localised but the actionable instruction the user actually reads is not, violating the project rule that all UI strings go through i18n. Same for `FlutterTtsBackend` error strings.

**Correção sugerida:** Map backend error *kinds* (e.g. an enum: socketMissing / spawnFailed / engineError) to localised ARB strings in the UI layer, keeping the raw technical detail as a non-translated suffix only. At minimum route the user-actionable 'install speech-dispatcher' guidance through l10n.

#### [rule-violation] Platform.isLinux usado direto em tts_backend_provider em vez de PlatformCapabilities

`lib/features/rsvp_reader/presentation/providers/tts_backend_provider.dart:25` (área: rules-compliance · verificação 1/1)

A regra 'Capacidades por plataforma' pede usar PlatformCapabilities em vez de espalhar Platform.isLinux. Em ttsBackendProvider a selecao de backend usa if (!kIsWeb && Platform.isLinux) diretamente (linha 25), importando dart:io. PlatformCapabilities.isLinux (que ja existe e ja embute o guard kIsWeb) cobre exatamente esse caso. E o unico Platform.is* fora do platform_capabilities.dart em todo o lib/.

**Correção sugerida:** Trocar por if (PlatformCapabilities.isLinux) e remover o import de dart:io/kIsWeb daqui.

#### [rule-violation] Strings hardcoded 'Error: $e' violam a regra de i18n obrigatoria

`lib/features/rsvp_reader/presentation/screens/bookmarks_screen.dart:30` (área: critic · verificação 1/1)

`error: (e, _) => Center(child: Text('Error: $e'))` (bookmarks_screen.dart:30) e `return Center(child: Text('Error: ${categorizedAsync.error}'))` (library_list.dart:37) hardcodam texto EN na UI, violando a regra do CLAUDE.md 'Todas as strings de UI devem usar i18n... Nunca hardcodar texto PT ou EN'. Alem de nao-traduzido, despeja a excecao crua (potencialmente SQL/stack) na tela do usuario.

**Correção sugerida:** Criar uma chave ARB generica (ex: genericError) e usar AppLocalizations.of(context)!.genericError, logando o erro detalhado em vez de exibi-lo. Aplicar tambem em library_list.dart:37.

#### [rule-violation] context_scroll_view reimplements sentence-end detection, diverging from the shared utility (rule violation)

`lib/features/rsvp_reader/presentation/widgets/context_scroll_view.dart:497` (área: architecture · verificação 3/3)

CLAUDE.md mandates: 'wordEndsSentence: usar a utility de lib/core/utils/sentence_boundary.dart (compartilhada por ... context_scroll_view). Não reimplementar detecção de fim de sentença.' The shared `wordEndsSentence` (sentence_boundary.dart:6-9) treats '…' and '...' as sentence ends. But context_scroll_view defines its own `_isSentenceEnd` (line 497-502) that only checks '.', '!', '?' — it MISSES ellipsis. It's actively used at line 188 for the velocity-based sentence-skip boundaries, so a paragraph ending in '…' is not recognized as a boundary there, while the engine's timing and TTS chunking DO treat it as one. The sentence_boundary.dart doc comment even falsely claims context_scroll_view is already a consumer. Also `_isSentenceEnd` trimRight()s while the shared one doesn't, a second behavioral divergence.

**Correção sugerida:** Delete `_isSentenceEnd` and call `wordEndsSentence` from sentence_boundary.dart at line 188. This restores the documented single source of truth and fixes the ellipsis gap.

#### [rule-violation] Botao 'OK' do color picker nao localizado

`lib/features/rsvp_reader/presentation/widgets/settings/settings_controls.dart:256` (área: reader-ui · verificação 1/1)

`ColorRow._showPicker` cria um `AlertDialog` cuja unica acao e `TextButton(... child: const Text('OK'))` (linha 256). String hardcoded num dialog visivel em todas as telas de cores do leitor (Word Color, Focus Letter, Background, Highlight). Viola a regra de i18n.

**Correção sugerida:** Usar `MaterialLocalizations.of(context).okButtonLabel` (ja disponivel) ou uma chave `l10n.ok`.

#### [test-gap] TtsPlayer.restartIfStalled positive (restart) path is untested; only the no-op path is

`lib/features/rsvp_reader/data/services/tts_player.dart:265` (área: test-quality · verificação 1/1)

restartIfStalled is the Android-backend-death recovery mechanism (re-speaks from the cursor after 10s of silence). The only test (tts_player_test.dart:215-245) asserts the no-op branch after pause. The actual stall-detected branch (l275-281: stop backend, replay from cursor) never runs in tests because it gates on DateTime.now().difference(_lastProgressAt) >= _stallThreshold (10s wall clock) and DateTime.now() is not injectable. So the most subtle TTS logic, whose failure silently strands a backgrounded listener, has no positive-case coverage.

**Correção sugerida:** Inject a clock (DateTime Function() now defaulting to DateTime.now) into TtsPlayer so the test can fast-forward past _stallThreshold and assert that restartIfStalled calls backend.stop() and re-issues a flush speak from the current cursor.

#### [test-gap] TtsPlayer.seek and generation-invalidation of stale callbacks have no direct unit test

`lib/features/rsvp_reader/data/services/tts_player.dart:248` (área: test-quality · verificação 1/1)

seek (l248: pause+play rebuild when playing, cursor-only when paused) and the _generation guard that drops stale completion/progress callbacks (l408, l426: if (active.generation != _generation) return) are core correctness mechanisms. The player test file never calls player.seek and never emits a stale completion after pause to prove generation bumping discards it. The engine integration test (rsvp_engine_provider_test.dart:1132) exercises seek-while-playing indirectly, but the paused-seek branch and the 'late completion after pause must be ignored' invariant are unverified at the unit level, exactly the race conditions CLAUDE.md flags as load-bearing.

**Correção sugerida:** Add unit tests on TtsPlayer: (1) seek while paused only moves currentGlobalIndex and issues no speak; (2) after play then pause, emitting emitCompletion() does NOT fire onBookFinished nor advance the cursor (stale generation); (3) seek while playing produces a flush-mode speak from the new index.

#### [test-gap] TtsPlayer image-only-segment skipping and _onProgress word advance not unit-tested

`lib/features/rsvp_reader/data/services/tts_player.dart:371` (área: test-quality · verificação 1/1)

Two player behaviors are unverified at the unit level: (1) _enqueueNext silently advancing the cursor past all-image ranges and firing onWordAdvance with a multi-word jump (l371-380), the player test only uses plain text chapters; (2) _onProgress mapping a charOffset to a token index and advancing onWordAdvance (l400-420), no test emits a progress callback and asserts the resulting currentGlobalIndex/onWordAdvance payload. The engine test covers image dismissal in RSVP mode but not the TTS player image-skip-with-audio-gap path.

**Correção sugerida:** Add player tests that (a) place an image token between text and assert onWordAdvance jumps the cursor past it with wordsAdvanced > 1 and no speak for that range, and (b) emit emitProgress with a known charOffset and assert currentGlobalIndex advances to the mapped global index.

## Gaps apontados pelo crítico de completude

- **Acessibilidade (Semantics, contraste, screen readers)**: Auditoria de UI focou em logica e cores via DisplaySettings, mas ninguem avaliou acessibilidade. Zero ocorrencias de Semantics/semanticLabel/excludeSemantics em 158 arquivos de widget. IconButtons, a palavra RSVP, o ORP highlight e os controles de transport nao tem labels semanticos; TalkBack/VoiceOver leem mal o app. Cores totalmente customizaveis pelo usuario tambem podem produzir contraste insuficiente sem nenhum guard.
- **Configuracao de plataforma iOS/macOS (Info.plist ATS, entitlements, sandbox)**: Os revisores nao receberam ios/ nem macos/. iOS Info.plist nao tem NSAppTransportSecurity, e o app aceita URLs http:// (UrlUtils nao forca https), entao import de artigos http silenciosamente falha no iOS. Nao ha macos/ auditado para sandbox/entitlements de rede (relevante para o Drive sync desktop em macOS).
- **Build/deploy Android (signing, R8/ProGuard, shrink)**: Ninguem auditou android/app/build.gradle.kts. Release assina com debug key, sem minify/shrink e sem proguard-rules. Combinado com .env embutido como asset, facilita reverse engineering e extracao de credenciais. Tambem nao ha config de release signing real (key.properties).
- **Robustez do bootstrap e error handling global (main.dart, app.dart)**: main.dart foi listado mas ninguem avaliou tratamento de erro de inicializacao. Nao ha try/catch em volta de getApplicationDocumentsDirectory / AudioService.init, nem FlutterError.onError, nem PlatformDispatcher.onError, nem runZonedGuarded, nem ErrorWidget.builder. Falha de I/O na criacao do DB antes de runApp resulta em crash sem tela/log amigavel.
- **Higiene de i18n e ARB (chaves orfas, strings hardcoded no chrome)**: A auditoria de rules-compliance nao varreu o conjunto completo de ARB nem o chrome. Ha 12 chaves ARB declaradas e nunca referenciadas e varias strings de UI hardcoded (Error:, OK, RSVP Reader, v0.1.0) violando a regra i18n. Tambem nao ha CI/teste que detecte chaves orfas.
- **Constraints de dependencias e estritura do analyzer**: pubspec.yaml usa intl: any (sem upper bound) e analysis_options.yaml nao habilita strict-casts/strict-raw-types/strict-inference; ninguem questionou a saude das constraints nem a folga do analyzer para um repo que sera divulgado publicamente.

## Findings refutados pela verificação adversarial (falsos positivos descartados)

- lib/features/rsvp_reader/presentation/providers/rsvp_engine_provider.dart: _saveProgress reads librarySyncProvider during dispose teardown
- lib/features/rsvp_reader/data/services/tts_player.dart: Player records `_onProgress` heartbeat even for stale-generation callbacks, which can mask a stall
- lib/features/library_sync/domain/entities/sync_library.dart: No tests for bookmark merge/shard/roundtrip despite tombstone semantics
- lib/features/rsvp_reader/presentation/widgets/context_scroll_view.dart: Efeitos colaterais de estado dentro de build() no ContextScrollView
- lib/features/rsvp_reader/presentation/screens/rsvp_reader_screen.dart: Top bar do leitor mistura textTheme global com cor de DisplaySettings
- lib/features/rsvp_reader/presentation/widgets/context_scroll_view.dart: Recomputo da indexacao do livro inteiro quando apenas a contagem de capitulos muda
- lib/features/reading_stats/presentation/providers/book_completion_provider.dart: Tela de conclusão de livro trava em loading infinito para bookId inválido/deletado
- lib/core/share/share_intent_handler.dart: Cold-start share import is fire-and-forget with no error handling and possible duplicate vs warm stream
- lib/features/rsvp_reader/presentation/providers/rsvp_engine_provider.dart: enterEreaderMode nao chama _pushPlaybackState(false) ao sair de TTS tocando
- lib/app.dart: Fallbacks de string de UI em ingles quando l10n e null (article import)
- lib/features/library_sync/domain/entities/sync_library.dart: mergeProgress readerMode preservation and clock-skew (>60s backwards) cases untested
- pubspec.yaml: OAuth client_secret e embutido no binario via asset .env (design documentado, nao vazamento)
- pubspec.yaml: Constraint 'intl: any' e analyzer sem lints estritos
