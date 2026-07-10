# Reading Stats, Monthly Recap e Completion

Feature local-first de telemetria de leitura. Sem backend proprio: tudo vive
no Drift. Alimenta tres surfaces user-facing:

1. **Stats dashboard** (`/stats`) — graficos dos ultimos 7/30 dias.
2. **Monthly recap** (`/stats/recap`) — imagem compartilhavel 9:16 do mes corrente.
3. **Book completion** (`/books/:id/completion`) — tela de conclusao com nota e card compartilhavel, disparada automaticamente ao chegar no final de um livro.

## Modelo de sessao

Uma **sessao** e um trecho continuo de leitura. Dois sabores:

- **Playback** (RSVP ou TTS): trecho continuo de `isPlaying=true`. Comeca em
  `play()`, termina em `pause()` / fim-do-livro / troca de modo / dispose do
  engine. `seekToWord` durante play **nao** divide a sessao — palavras puladas
  pelo seek nao contam (`_wordsInSession` so incrementa em `_onTick` no RSVP e
  em `_onPlayerWordAdvance` no TTS).
- **Manual (ereader)**: abre em `enterEreaderMode()` (ou no auto-restore do
  modo em `_loadBook`) e fecha em `exitEreaderMode()` / troca de modo / play /
  dispose. As palavras vem dos seeks disparados pelo sync de posicao do scroll
  (`ContextScrollView` -> `seekToWord`): deltas positivos ate
  `_maxManualReadDelta` (500) contam como lidos; deltas maiores sao navegacao
  (capitulo/slider) e nao contam; scroll pra tras nao subtrai. Sessoes manuais
  com `avgWpm > 700` sao descartadas como skimming (`computeSessionAvgWpm`
  com `manual: true`).

Schema (`lib/database/tables/reading_session_table.dart`):

| Campo | Descricao |
|---|---|
| `id` | UUID |
| `bookId` | livro (sem FK — sobrevive a delete) |
| `startedAt` / `endedAt` | wall-clock |
| `durationMs` | tempo real do ticker (`_elapsed.inMilliseconds`) |
| `wordsRead` | `_wordsInSession` no momento do flush |
| `startWordIndex` / `endWordIndex` | cursor no inicio/fim |
| `avgWpm` | `wordsRead * 60000 / durationMs`, arredondado |

Indices em `startedAt` e `bookId` via `@TableIndex` (migration v5 cria).

### Threshold de ruido

`computeSessionAvgWpm` em `rsvp_engine_provider.dart` filtra sessoes com
`durationMs < 3000` OU `wordsRead < 5` — evita que taps acidentais no play
virem lixo nos graficos. Retorna `null` para dropar, numero para persistir.

### Por que `bookId` nao tem FK

Sessoes sobrevivem a delete do livro. O historico (e os recaps mensais) devem
continuar validos mesmo se o usuario limpar a biblioteca. Nos aggregates, livros
faltantes renderizam com titulo `—`.

## Stats dashboard

`lib/features/reading_stats/presentation/screens/reading_stats_screen.dart`
hospeda um `TabController` Weekly/Monthly. Cada aba e alimentada por
`statsSnapshotProvider(StatsRange)` — `StreamProvider.family` que escuta
`watchSessionsInRange(from, to)` e junta com `booksDao.getAllBooks()`.

### `StatsSnapshot`

Produto agregado consumido pelos widgets:
- `dailyBuckets: List<DailyBucket>` — um por dia no range, com `perBook` (fatias coloridas no stacked chart) e totais.
- `bookBreakdowns: List<BookBreakdown>` — agregado por livro no range inteiro, ordenado desc por `totalDurationMs`.
- `totalWords` / `totalDurationMs` / `avgWpm` / `booksTouched`.

Toda a agregacao fica em `buildSnapshot` (pura, testada).

### Charts (fl_chart)

- `stats_words_per_day_chart.dart` — `BarChart` com stack por livro. Cores vem de `StatsColorPalette.forBooks(orderedBookIds, scheme)` — HSL rotation do `scheme.primary`, top 5 livros com cores distintas, resto colapsa em "Other" (`scheme.outlineVariant`).
- `stats_time_per_day_chart.dart` — `BarChart` simples, minutos/dia.
- `stats_wpm_trend_chart.dart` — `LineChart` com weighted avg WPM diario. Dias sem sessoes nao emitem spot (a linha conecta dias reais diretamente).

### Layout responsivo

`context.isTablet && context.isLandscape` → duas colunas (summary+breakdown a esquerda, charts empilhados a direita). Caso contrario, single column scrollavel.

## Monthly recap

Acessado pelo botao `recapGenerateCta` no topo da aba Monthly.
`monthlyRecapProvider(RecapMonth)` agrega via `aggregateByBookInRange` (SQL
`GROUP BY bookId` com `SUM`/`MAX`/`COUNT`) e classifica cada livro em:

- **Finalizados**: `maxEndWordIndex >= totalWords - 1` (cursor chegou na ultima palavra).
- **Em leitura**: qualquer sessao no mes, nao finalizado.

A tela preview (`MonthlyRecapScreen`) envelopa o `MonthlyRecapCard` num
`RepaintBoundary` com `GlobalKey` + `FittedBox(BoxFit.contain)`. Share chama
a função top-level `shareWidgetAsPng()` (em `image_export_service.dart`).

## Book completion

Disparo automatico: `_advanceWord` hit end-of-book incrementa
`RsvpState.finishTicket`. `RsvpReaderScreen` faz `ref.listen` comparando
`next.finishTicket > prev.finishTicket` e faz `context.push` dentro de
`addPostFrameCallback` (deixa o ultimo frame do RSVP word display estabilizar
antes de empurrar a tela celebratoria).

Por que `finishTicket` (contador) e nao bool `didFinish`:
- Contador permite re-disparo se usuario voltar e finalizar de novo apos seek.
- Um bool precisaria ser resetado explicitamente; contador so incrementa.

### Tela e card

`book_completion_screen.dart` mostra, em ordem:
1. Preview do `BookCompletionCard` no `FittedBox`.
2. `StarRatingPicker` (0-5, tap na mesma estrela limpa). Cada mudanca persiste via `booksDao.updateRating(bookId, value)` — schema v6 adicionou coluna nullable `rating`.
3. `_StatsBlock` em `SectionCard` com tempo/palavras/sessoes/WPM medio.
4. Span de dias ("Concluido em X dias") se `firstSessionAt != lastSessionAt`.
5. `SwitchListTile` "Incluir estatisticas na imagem" → alterna `showStats` no card (nao afeta a tela).
6. Share button.

### Card 9:16

Fixo 360×640 dp. Paleta **independente de tema** (ink-on-paper) pra
consistencia entre usuarios. Font families via `GoogleFonts.lora()` /
`GoogleFonts.inter()` — strings `'Lora'`/`'Inter'` nao resolvem no PNG exportado
porque o app carrega fontes via package `google_fonts`, nao assets bundled.

Cover grande e central (220 com stats, 260 sem). Quando `showStats = false`,
rodape vira "Finalizado em {data}" via `DateFormat.yMMMd(locale)`. Estrelas
so aparecem se `rating != null`.

## Image export pipeline

`lib/core/utils/image_export_service.dart`:

```dart
shareWidgetAsPng({
  required GlobalKey boundaryKey,
  required String filename,
  String? shareText,
  double pixelRatio = 3.0,
}) {
  await SchedulerBinding.instance.endOfFrame;
  final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  ...
  SharePlus.instance.share(ShareParams(files: [XFile(...)], text: shareText));
}
```

Pontos nao-obvios:
- **`await endOfFrame`**: garante que o boundary tenha pintado ao menos um frame. Sem isso, a primeira captura pos-navegacao pode vir em branco.
- **`pixelRatio: 3.0`** sobre 360dp → ~1080px de largura real no PNG. Bom pra Stories/feed.
- **`FittedBox` envolvendo o RepaintBoundary no preview**: a captura usa o tamanho logico do child (360×640), nao o escalonado. Preview pequeno na tela, export em resolucao cheia.

## Pontos de manutencao

- **Ao adicionar schema Drift**: bump `schemaVersion` em `app_database.dart`, adicionar bloco `if (from < N)` na `onUpgrade`. Rodar `dart run build_runner build --delete-conflicting-outputs`.
- **Ao adicionar i18n no recap/completion cards**: strings tem que resolver sem `Navigator`/theme especifico (o card e capturado fora do fluxo normal de navegacao).
- **Ao mexer no engine**: qualquer ponto novo de "saida do isPlaying=true" (nao so pause/end/ereader/dispose) deve chamar `_flushSession()` antes de zerar contadores. Idem pra qualquer saida nova do modo ereader (sessao manual aberta) — e o flush deve rodar **antes** de mutar `state.mode`, porque `_flushSession` le `state.mode` pra decidir se aplica o cap de skimming manual.
- **Testes prioritarios**: `computeSessionAvgWpm` (threshold/arredondamento), `buildSnapshot` (bucketing + avgWpm ponderado), `buildMonthlyRecap` (classificacao finished/reading), `buildCompletionSummary` (totais + firstSessionAt/lastSessionAt).
