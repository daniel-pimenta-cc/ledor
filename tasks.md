# Tasks

## Bugs
- [x] Scroll travado no modo contexto — precisa rolar suave como manteiga
- [x] Ao pausar, o texto volta para o início ao invés de focar na palavra atual (resolvido junto com o fix do scroll)
- [x] Botão de configurações no leitor não abre nada
- [x] Tags de estilo do EPUB vazando no texto (CSS aparecendo entre capítulos com imagens) — `HtmlStripper._skipTags`

## Features
- [x] Ramp-up de velocidade — ao dar play, começar mais devagar e acelerar gradualmente até o WPM desejado ao invés de começar na velocidade máxima direto
- [x] Navegação por capítulos — ter uma forma clara de visualizar a lista de capítulos e navegar entre eles
- [x] Modo ereader — terceiro modo de leitura sem highlight nem controles (ebook tradicional)
- [x] Marcadores de capítulo no slider de progresso (com tooltip do título via value indicator)
- [x] Linha de foco abaixo da palavra (modo focus puro ou focus + progresso, configurável)

## Polish
- [x] Polir scroll do modo contexto — velocity-based stepping (word/sentence/paragraph), highlight em pill com glow sutil, dead zone para seleção fina
- [x] Preview de fonte no settings (cada item do dropdown renderizado na própria fonte + linha de amostra)
- [x] Consolidar telas de configuração (DisplaySettingsPanel compartilhado entre bottom sheet e tela full-screen)

## Pendente
- [x] Import de artigos web por URL (readability extractor em Dart puro, tabs Books/Articles na biblioteca)
- [x] Share sheet Android (intent-filter + `receive_sharing_intent`, coordinator global de navegação/snackbar em `app.dart`)
- [ ] Share sheet iOS — Xcode target precisa ser criado num Mac, passos em [docs/share-extension-ios.md](docs/share-extension-ios.md)
- [x] Tablet layout pass (landscape liberado, grid adaptativo 2/3/4, master-detail em tablet landscape)
- [x] Reading stats: sessões de leitura (tabela `reading_session` v5) + dashboard `/stats` com charts weekly/monthly (fl_chart)
- [x] Monthly recap: imagem 9:16 compartilhável do mês com livros finalizados + em leitura, gerada via `RepaintBoundary -> PNG -> share_plus`
- [x] Book completion: tela disparada no fim do livro com stats detalhadas, rating 0-5 estrelas (coluna `books.rating` v6), card 9:16 compartilhável com toggle "incluir stats"
- [x] Entry point na biblioteca para reabrir a tela de completion de livros já terminados — long-press num livro Lido mostra "Ver tela de conclusão"; reader settings sheet/side panel ganhou botão "Finalizar livro" pra livros em andamento (bumpa progresso até o fim e abre completion)
- [ ] Yearly recap — reutilizar pipeline do monthly com layout diferente
- [ ] Triagem de issues do GitHub

## Backlog novo
- [x] Modo contexto: lock + recenter no overlay flutuante (mede o RenderBox real da palavra via GlobalKey para centralizar com precisao em paragrafos longos)
- [x] Splash screen ao abrir o app (flutter_native_splash com paleta light/dark, icone sem o fundo navy)
- [ ] Bug: ao sair e voltar ao app no modo contexto o sync quebra — em pausa, nao reproduzido na ultima sessao
- [x] Sync de stats (`reading_session` + `books.rating`) entre devices via Drive (junto com o shard refactor — sessions append-only, rating com timestamp dedicado)
- [ ] Bookmarks (marcar posicoes nomeadas dentro de um livro/artigo)
- [ ] Modo TTS (text-to-speech) — alternativa de leitura por audio
- [x] Sync incremental (phase 1): manifest shardado em `library/books.json` + `settings.json` + `sessions.json`; push paraleliza writes e pula shards inalterados. Phase 2 (per-record + index.json) fica pra quando virar gargalo.
- [ ] Melhorar ramp-up de velocidade (curva mais natural? configurar duracao/word count?)
- [ ] Bug: investigar import quando o usuario joga um EPUB direto na pasta `RSVP Reader/books/` no Drive (orphan import via `_autoImportOrphanFiles`) — algo nao esta funcionando como esperado
- [ ] Suporte a imagens nos livros (figuras inline do EPUB) — hoje so o texto e tokenizado e a capa e extraida; imagens inline sao descartadas no `HtmlStripper`/tokenizer
