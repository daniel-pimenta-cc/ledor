# Library sync

EPUBs + reading progress + display settings sincronizados via Google Drive.
Disponivel em Android (via `google_sign_in` nativo) e Linux desktop (via
fluxo OAuth loopback — ver [linux-desktop.md](linux-desktop.md#google-drive-sync)).
Opt-in, scope `drive.file` (o app so enxerga arquivos que ele proprio criou).

A camada de auth é abstraída por `DriveAuthBackend`
(`lib/features/library_sync/data/auth/`), com duas implementações concretas:
`GoogleSignInDriveAuthBackend` (mobile) e `DesktopOAuthDriveAuthBackend`
(desktop). Tudo abaixo de `DriveAuthNotifier` — incluindo o gateway, o sync
service e o manifest — é idêntico entre as plataformas; só o `AuthClient`
muda de fornecedor.

## Visao geral

O sync usa uma pasta `RSVP Reader/` no Drive do usuario, com tres
arquivos de metadata + uma pasta de EPUBs:

```
RSVP Reader/
  library/
    books.json          ← per-book metadata + progress + rating + tombstones
    settings.json       ← display settings
    sessions.json       ← reading_session rows (append-only)
  books/
    <user-chosen>.epub  ← um EPUB por livro ativo
    ...
```

O layout atual e *sharded*: cada concern vive no seu proprio arquivo, e o
push so reescreve o shard que mudou (typical case: so progresso → so
`books.json` sobe). A versao anterior usava um unico `library.json`
monolitico; ele e migrado uma vez no primeiro sync apos upgrade e depois
deletado.

Livros sao a fonte da verdade do shard `books.json`; os EPUBs sao payload.
Um livro "existe" quando tem entrada em `books.json` E (opcionalmente) o
EPUB correspondente em `books/`.

Cada dispositivo roda o mesmo algoritmo de merge last-write-wins ao sincronizar:

1. **Pull** do manifest remoto + listagem de `books/`
2. **Snapshot** do estado local (livros + progress + settings)
3. **Merge** com regras determinísticas
4. **Apply** as mudancas no DB local
5. **Push** o manifest merged de volta + upload de EPUBs faltando

A sincronizacao de EPUBs e opcional (`SyncConfig.syncEpubs`). Sem ela, so
manifest (metadata + progress + settings) sobe/desce.

## Shards

Serializados em `lib/features/library_sync/domain/entities/sync_library.dart`.
Cada shard tem seu proprio `schemaVersion` (`syncShardSchemaVersion = 1`)
mais um meta block (`updatedAt`/`updatedBy`) que muda todo push e e
ignorado no skip-write check.

### `library/books.json`

```jsonc
{
  "schemaVersion": 1,
  "updatedAt": "2026-04-23T...Z",
  "updatedBy": "<deviceId>",
  "books": [
    {
      "id": "<uuid>",
      "title": "...",
      "author": "...",
      "totalWords": 12345,
      "chapterCount": 10,
      "importedAt": "...",
      "lastReadAt": "...",
      "hasEpubFile": true,
      "syncFileName": "user-visible.epub",
      "progress": { "chapterIndex": 3, "wordIndex": 512, "wpm": 425, "updatedAt": "..." },
      "deletedAt": null,
      "updatedAt": "...",
      "rating": 4,                  // 1..5 ou null
      "ratingUpdatedAt": "..."     // timestamp dedicado pro LWW de rating
    }
  ]
}
```

### `library/settings.json`

```jsonc
{
  "schemaVersion": 1,
  "updatedAt": "...",
  "updatedBy": "<deviceId>",
  "settings": {
    "values": { /* DisplaySettings serializado */ },
    "updatedAt": "..."
  }
}
```

### `library/sessions.json`

```jsonc
{
  "schemaVersion": 1,
  "updatedAt": "...",
  "updatedBy": "<deviceId>",
  "sessions": [
    {
      "id": "<uuid>",
      "bookId": "<uuid>",
      "startedAt": "...",
      "endedAt": "...",
      "durationMs": 60000,
      "wordsRead": 200,
      "startWordIndex": 0,
      "endWordIndex": 200,
      "avgWpm": 300
    }
  ]
}
```

Sessions sao **append-only por id**: uma vez emitida, uma session nunca
muda. O merge entre devices e a uniao por id.

### Legado: `library.json`

O monolitico antigo (`schemaVersion: 1`, com `books` + `settings`)
continua sendo lido na primeira sync apos o upgrade: seu conteudo e
carregado em memoria como shards, e o arquivo e deletado no proximo push
para nao confundir devices que ja migraram.

## Regras de merge

Definidas em `mergeBooksShard` / `mergeSettingsShard` / `mergeSessionsShard`
(que reusam `mergeBook` / `mergeProgress`), em
`lib/features/library_sync/domain/entities/sync_library.dart`. Todo o
codigo de merge e puro (sem I/O) e coberto por
`test/features/library_sync/sync_library_test.dart`.

**Per-book** (`mergeBook(a, b)`):
- `updatedAt`: o maior dos dois (wins determina varios outros campos).
- Campos que seguem o "newer": `title`, `author`, `syncFileName` (com fallback
  pro older se newer for null).
- `importedAt`: o **menor** (preserva data de import original).
- `lastReadAt`: o **maior** (progresso nunca volta).
- `hasEpubFile`: `a.hasEpubFile || b.hasEpubFile`.
- `progress`: `mergeProgress` — dentro de 60s, prefere o `wordIndex` maior
  (resistencia a clock skew); alem disso, LWW.
- `deletedAt`: `_laterNullable` — **tombstone e monotonico**. Uma vez
  marcado deletado de um lado, merged fica tombstoned pra sempre. Nao ha
  "ressurreicao".
- `rating`/`ratingUpdatedAt`: LWW **pelo proprio timestamp**, nao pelo
  `updatedAt` do livro. Sem isso, uma alteracao em outro campo
  (progresso, lastReadAt) em outro device bumparia `updatedAt` e
  sobrescreveria um rating mais novo. O timestamp dedicado da imunidade.

**Books shard (`mergeBooksShard`)**: uniao por `id`, cada lado passa pelo
`mergeBook`. Sort por id na saida pra estabilizar serializacao.

**Settings shard (`mergeSettingsShard`)**: o lado com `settings.updatedAt`
mais recente vence; preserva o lado nao-nulo quando o outro e nulo.

**Sessions shard (`mergeSessionsShard`)**: uniao por `id`. Sessions sao
append-only — uma vez gravadas com um id no DB nunca mudam. Colisao por
id e tratada deterministicamente (preserva o lado `a`).

## Tombstones

Quando o usuario deleta um livro (`deleteBookProvider`), alem de remover a
row local, disparamos um `pushTombstone`:

1. Le manifest atual.
2. Marca a entrada do livro com `deletedAt = now` (ou adiciona uma nova se
   nao existir).
3. Reescreve manifest.
4. Deleta o arquivo fisico em `books/`.

Outros dispositivos que sincronizarem depois veem a entrada tombstoned e
fazem `_deleteBookLocally` no proprio DB.

### Compactacao de tombstones zumbis

A manifest acumulava tombstones "zumbis": entradas com `deletedAt` cujo
`syncFileName` era o mesmo de um livro ativo em merged. Origem tipica:

1. Usuario deletou livro X em algum dispositivo → `deletedAt` + arquivo
   removido do Drive.
2. Se o `deleteFile` falhou por rede, arquivo ficou orfao no Drive.
3. Sync seguinte: `_autoImportOrphanFiles` viu o arquivo, nao encontrou na
   manifest como ativo (so tombstoned), importou como livro novo com
   **UUID novo** mas **mesmo syncFileName**.
4. Agora merged tem dois registros apontando pro mesmo filename: X-tombstone
   e Y-ativo.
5. `_uploadMissingEpubs` apagava o arquivo do tombstone (que era
   fisicamente o arquivo de Y), depois re-uploadava Y na proxima iteracao.
   Eterno flip-flop.

**Fix** (em `library_sync_service.sync()`): apos `mergeLibraries`, um step
de compactacao remove do manifest todo tombstone cujo `syncFileName` ja e
reivindicado por um livro ativo em merged. O ativo "herdou" a posse do
filename; o tombstone nao propaga nada util e so polui as comparacoes.

Tombstones **legitimos** (sem colisao de filename) ficam ate propagar pra
todos os devices. Nao ha GC por idade hoje — seria o proximo passo.

### Prevencao do re-import-como-orfao

`_autoImportOrphanFiles` ja trata `syncFileName` tombstonado na manifest
como "conhecido" (como se fosse ativo). Assim, um arquivo orfao com nome
igual a um tombstone nao vira um livro novo; o proximo `_uploadMissingEpubs`
respeita o tombstone e deleta o arquivo.

## Ordem da pipeline de sync

`LibrarySyncService.sync()`, em alto nivel:

```
┌ em paralelo ─────────────────────────────────────┐
│ 1a. isReadable(folder)                           │
│ 1b. readText(library.json)        ← legacy probe │
│ 1c. readText(library/books.json)                 │
│ 1d. readText(library/settings.json)              │
│ 1e. readText(library/sessions.json)              │
│ 1f. listFiles(books/)                            │
└──────────────────────────────────────────────────┘
2. _loadRemoteShards (legacy migra in-memory se shards ausentes)
3. autoImportOrphanFiles  ← so quando config.syncEpubs
4. buildLocalShards (books + settings + sessions)
5. merge*Shard + compactacao de zumbis (no books shard)
6. _applyShardsToLocal (progress, lastReadAt, rating, novas sessions, tombstones, settings)
7. writes em paralelo:
   - delete library.json   ← so quando legacy ainda esta presente
   - writeText library/books.json    ← SKIP se _booksShardEquals
   - writeText library/settings.json ← SKIP se _settingsShardEquals
   - writeText library/sessions.json ← SKIP se _sessionsShardEquals
8. uploadMissingEpubs      ← so quando config.syncEpubs
```

Em modo idle (nada mudou), o passo 7 reduz a um no-op por shard: os tres
`_*ShardEquals` retornam true e nenhum write sobe. Os passos 5 e 6 sao
puros / locais e custam ms.

### Paralelizacao

As leituras iniciais sao independentes e disparadas juntas; o wall-clock
e dominado pela mais lenta. Os writes da fase 7 tambem sao paralelizados
(`Future.wait`) — quando dois shards mudaram simultaneamente, o custo
e `max(write1, write2)` em vez de soma.

### Skip de writes por shard

`_booksShardEquals` / `_settingsShardEquals` / `_sessionsShardEquals`
comparam o conteudo do shard ignorando `updatedAt`/`updatedBy` (que
mudam todo sync por natureza). Quando identicos, o write nao acontece —
um sync idle nao gera trafego de write nenhum. Para mudancas isoladas
(so progresso, por exemplo), apenas o `books.json` sobe.

## Comparacao de DateTime

**Armadilha importante**: `DateTime.==` compara `(microsSinceEpoch, isUtc)`.
No nosso sync:

- Horarios **locais** vem do Drift, que por padrao armazena como unix
  seconds → reconstrui com `isUtc: false`.
- Horarios **remotos** vem do JSON manifest. `toJson` faz `toUtc()` antes
  do `toIso8601String()`, entao o parse resulta em `isUtc: true`.

Mesmo instante, `isUtc` diferente → `==` retorna `false`.

Em `_applyToLocal` isso causava um write pra cada livro todo sync (11
livros × ~60ms = 660ms jogados fora). **Use sempre `isAtSameMomentAs` para
comparar DateTimes que cruzam a fronteira local/remoto** — normaliza TZ.

O `_libraryContentEquals` nao sofre porque compara JSON encoding, que ja
passa por `toUtc()`.

## Cache de fileId (DriveSyncFolderGateway)

Qualquer operacao em um arquivo no Drive exige saber o `fileId`, e para
descobri-lo o gateway faz `api.files.list` filtrado por nome/pasta — uma
round-trip de ~500-700ms ("find" nos logs). Esse custo era pago antes de
cada `read`/`write`/`delete`.

`_fileIdCache` (keyed por `"<parentId>/<fileName>"`) e populado por:
- `_findFile` (quando precisa resolver na marra)
- `listFiles` (de gracca — a resposta ja traz id+name)
- branch "create" do `writeBytes` (acabou de criar, sabe o id)

Consumido por `readBytes`, `writeBytes`, `deleteFile` — se tiver cache,
pula o `_findFile`.

Invalidacao:
- `deleteFile` remove a entrada do cache.
- `clearCache()` dropa tudo (chamado no disconnect).
- **Nao** ha detection de renomeacao concorrente por outro device; na
  pratica o sync e efemero o suficiente pra isso nao ser problema.

## Orfaos na pasta `books/`

Se o usuario largar um EPUB direto na pasta do Drive (fora do app),
`_autoImportOrphanFiles` detecta no proximo sync:
- Filtra `.epub` (case-insensitive).
- Exclui filenames ja conhecidos (ativos + tombstones na manifest +
  `syncFileName`s locais).
- Exclui arquivos que falharam antes (`SyncImportFailuresDao` pra nao
  thrashar em EPUB corrompido).
- Import o resto como novos livros (UUID local novo), preservando o
  filename em `syncFileName` pra nao duplicar no proximo sync.

## Sync so de EPUB

`LibrarySyncService._buildLocalSnapshot` filtra `source == BookSource.epub`.
Artigos (`source == article`) sao **sempre locais**, nao participam do
sync. Razao: o manifest e um formato de biblioteca EPUB, e artigos
dependem de fetch de URL.

## Observabilidade

Quando o sync esta rodando, a UI mostra uma hairline de 2px logo abaixo
da TabBar da biblioteca (via `LibraryAppBarBottom` + `LibrarySyncState.stage
== SyncStage.syncing`). Durante auto-import de orfaos, a hairline e
substituida pela `LibraryImportProgressBar` mais detalhada.

Para diagnostico no dev, os logs `[sync]` / `[drive]` dao:
- Fase + duracao de cada etapa do pipeline.
- `writes: progress=N lastRead=N deletes=N imports=N` em `_applyToLocal`.
- `uploads=N deletes=N skippedTombstones=N` em `_uploadMissingEpubs`.
- `[sync] diff: ...` quando o skip do manifest falha.

## Arquivos chave

- `lib/features/library_sync/data/services/library_sync_service.dart` — o
  `sync()`, `pushTombstone()`, `_loadRemoteShards`, `_buildLocalShards`,
  `_applyShardsToLocal`, `_uploadMissingEpubs`, `_autoImportOrphanFiles`,
  `_booksShardEquals` / `_settingsShardEquals` / `_sessionsShardEquals`.
- `lib/features/library_sync/data/gateways/drive_sync_folder_gateway.dart`
  — wrapper da Drive API com caches (folder + file).
- `lib/features/library_sync/domain/entities/sync_library.dart` — schemas
  (`SyncBooksShard`, `SyncSettingsShard`, `SyncSessionsShard`,
  `SyncReadingSession`) + merges puros. A classe legada `SyncLibrary` e
  mantida so para a leitura unica do monolito migrado.
- `lib/features/library_sync/presentation/providers/library_sync_provider.dart`
  — notifier que debouncing pushes (2s), faz flush de pending deletes,
  serializa syncs concorrentes.
- `lib/features/library_sync/presentation/providers/drive_auth_provider.dart`
  — sign-in silencioso no startup, manipulacao de `http.Client`
  autenticado.
