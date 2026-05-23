// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'RSVP Reader';

  @override
  String get library => 'Biblioteca';

  @override
  String get settings => 'Configurações';

  @override
  String get importBook => 'Importar Livro';

  @override
  String get emptyLibrary => 'Sua biblioteca está vazia';

  @override
  String get emptyLibrarySubtitle => 'Importe um EPUB para começar';

  @override
  String get deleteBook => 'Excluir Livro';

  @override
  String deleteBookConfirm(String title) {
    return 'Tem certeza que deseja excluir \"$title\"?';
  }

  @override
  String get markAsRead => 'Marcar como lido';

  @override
  String get viewCompletion => 'Ver tela de conclusão';

  @override
  String get finishBook => 'Finalizar livro';

  @override
  String get finishBookConfirmTitle => 'Finalizar este livro?';

  @override
  String get finishBookConfirmBody =>
      'Vamos saltar seu progresso até o fim e abrir a tela de conclusão pra você avaliar.';

  @override
  String get finishBookConfirmCta => 'Finalizar';

  @override
  String markedAsRead(String title) {
    return '\"$title\" marcado como lido';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Excluir';

  @override
  String get reading => 'Lendo';

  @override
  String get play => 'Reproduzir';

  @override
  String get pause => 'Pausar';

  @override
  String wordsPerMinute(int wpm) {
    return '$wpm PPM';
  }

  @override
  String chapterOf(int current, int total) {
    return 'Capítulo $current de $total';
  }

  @override
  String progressPercent(int percent) {
    return '$percent%';
  }

  @override
  String minutesRemaining(int minutes) {
    return '~$minutes min';
  }

  @override
  String get settingsFontSize => 'Tamanho da Fonte';

  @override
  String get settingsFontSizeRsvp => 'Fonte RSVP';

  @override
  String get settingsFontSizeContext => 'Fonte Leitura';

  @override
  String get settingsWordColor => 'Cor da Palavra';

  @override
  String get settingsOrpColor => 'Cor da Letra de Foco';

  @override
  String get settingsBackgroundColor => 'Cor de Fundo';

  @override
  String get settingsHighlightColor => 'Cor do Destaque';

  @override
  String get settingsVerticalPosition => 'Posição Vertical';

  @override
  String get settingsHorizontalPosition => 'Posição Horizontal';

  @override
  String get settingsFont => 'Fonte';

  @override
  String get settingsDefaultSpeed => 'Velocidade Padrão';

  @override
  String get settingsSmartTiming => 'Timing Inteligente';

  @override
  String get settingsSmartTimingDesc =>
      'Ajusta a duração da palavra com base em pontuação e comprimento';

  @override
  String get settingsOrpHighlight => 'Letra de Foco';

  @override
  String get settingsOrpHighlightDesc =>
      'Destacar o ponto de reconhecimento ótimo em cada palavra';

  @override
  String get settingsRampUp => 'Aceleração Gradual';

  @override
  String get settingsRampUpDesc =>
      'Acelerar gradualmente até a velocidade alvo ao iniciar a leitura';

  @override
  String get settingsSentencePause => 'Pausa de frase';

  @override
  String get settingsSentencePauseDesc => 'Pausa extra ao fim de cada frase';

  @override
  String get settingsChapterPause => 'Pausa de capítulo';

  @override
  String get settingsChapterPauseDesc =>
      'Pausa extra antes do início de cada capítulo';

  @override
  String multiplierValue(String value) {
    return '${value}x';
  }

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsAbout => 'Sobre';

  @override
  String get settingsAppearance => 'Aparência';

  @override
  String get settingsThemeMode => 'Tema';

  @override
  String get themeModeSystem => 'Sistema';

  @override
  String get themeModeLight => 'Claro';

  @override
  String get themeModeDark => 'Escuro';

  @override
  String get readerPlaceholderTitle => 'Escolha um livro pra começar';

  @override
  String get readerPlaceholderSubtitle =>
      'Selecione da sua biblioteca à esquerda e ele abre aqui do lado.';

  @override
  String get importArticleClipboardHint => 'Colado da área de transferência';

  @override
  String get importing => 'Importando...';

  @override
  String get importError => 'Falha ao importar livro';

  @override
  String get importArticle => 'Importar artigo';

  @override
  String get importArticleUrlLabel => 'URL do artigo';

  @override
  String get importArticleUrlHint => 'https://exemplo.com/artigo';

  @override
  String get importArticleCta => 'Importar';

  @override
  String get importArticleError => 'Falha ao importar artigo';

  @override
  String get importArticleFetching => 'Baixando artigo…';

  @override
  String get libraryTabBooks => 'Livros';

  @override
  String get libraryTabArticles => 'Artigos';

  @override
  String get emptyArticles => 'Nenhum artigo ainda';

  @override
  String get emptyArticlesSubtitle =>
      'Cole uma URL pra ler qualquer artigo da web em RSVP';

  @override
  String get bookFinished => 'Você terminou o livro!';

  @override
  String get tapToPause => 'Toque para pausar';

  @override
  String get tapToResume => 'Toque para retomar';

  @override
  String get readerModeMenuTooltip => 'Modo de leitura';

  @override
  String get readerModeRsvp => 'RSVP';

  @override
  String get readerModeEreader => 'E-reader';

  @override
  String get readerModeTts => 'Narração';

  @override
  String get lockHighlight => 'Travar palavra de foco';

  @override
  String get unlockHighlight => 'Destravar palavra de foco';

  @override
  String get recenterHighlight => 'Voltar para a palavra';

  @override
  String get hideLibraryPanel => 'Esconder biblioteca';

  @override
  String get showLibraryPanel => 'Mostrar biblioteca';

  @override
  String get settingsProgressSlider => 'Barra de progresso';

  @override
  String get settingsProgressSliderDesc =>
      'Exibe a barra de progresso com marcadores de capítulo acima dos controles';

  @override
  String get settingsTimeRemaining => 'Tempo restante';

  @override
  String get settingsTimeRemainingDesc =>
      'Como exibir o tempo restante ao lado do título do capítulo';

  @override
  String get timeRemainingTotal => 'Livro inteiro';

  @override
  String get timeRemainingChapter => 'Capítulo atual';

  @override
  String get timeRemainingOff => 'Desligado';

  @override
  String get settingsFocusLine => 'Linha de foco';

  @override
  String get settingsFocusLineDesc =>
      'Exibe uma linha fina abaixo da palavra para ancorar o olhar';

  @override
  String get settingsFocusLineProgress => 'Progresso na linha de foco';

  @override
  String get settingsFocusLineProgressDesc =>
      'Usa a linha de foco também para mostrar o progresso de leitura';

  @override
  String get settingsOrpIndicator => 'Marcador da letra de foco';

  @override
  String get settingsOrpIndicatorDesc =>
      'Escolha como apontar para a letra de foco';

  @override
  String get orpIndicatorNotch => 'Triângulo';

  @override
  String get orpIndicatorLineAbove => 'Linha acima';

  @override
  String get orpIndicatorLinesAround => 'Linhas ao redor';

  @override
  String get orpIndicatorOff => 'Nenhum';

  @override
  String get librarySectionInProgress => 'Em progresso';

  @override
  String get librarySectionNotStarted => 'Não iniciados';

  @override
  String get librarySectionRead => 'Lidos';

  @override
  String get settingsSync => 'Sincronização da biblioteca';

  @override
  String get syncConnectDrive => 'Conectar Google Drive';

  @override
  String get syncConnectingDrive => 'Conectando…';

  @override
  String syncConnectedAs(String email) {
    return 'Conectado como $email';
  }

  @override
  String get syncEpubFiles => 'Sincronizar arquivos EPUB';

  @override
  String get syncEpubFilesDesc =>
      'Copia os arquivos EPUB para o Drive, fazendo com que apareçam em outros dispositivos. Desligue para economizar espaço na nuvem.';

  @override
  String get syncAutoSync => 'Sincronização automática';

  @override
  String get syncAutoSyncDesc =>
      'Sincroniza automaticamente ao abrir o app e quando o progresso muda.';

  @override
  String get syncNow => 'Sincronizar agora';

  @override
  String get syncInProgress => 'Sincronizando…';

  @override
  String syncLastSyncedAt(String when) {
    return 'Última sincronização: $when';
  }

  @override
  String get syncNever => 'Nunca';

  @override
  String syncFailed(String error) {
    return 'Falha ao sincronizar: $error';
  }

  @override
  String get syncDisconnect => 'Desconectar';

  @override
  String syncFailedImportsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos falharam ao importar',
      one: '1 arquivo falhou ao importar',
    );
    return '$_temp0';
  }

  @override
  String get syncFailedImportsHelp =>
      'Esses arquivos estão sendo ignorados. Apague ou substitua eles na pasta de sincronização e toque em Tentar de novo.';

  @override
  String get syncRetry => 'Tentar de novo';

  @override
  String syncImportingProgress(int current, int total, String fileName) {
    return 'Importando $current de $total: $fileName';
  }

  @override
  String get syncHelp =>
      'Os metadados da biblioteca, progresso de leitura e configurações sincronizam através de uma pasta que o app cria no seu Google Drive (\"RSVP Reader\"). Entre com uma conta para conectar; desconectar neste dispositivo não apaga os arquivos no Drive.';

  @override
  String get statsTitle => 'Estatísticas';

  @override
  String get statsTabWeekly => 'Últimos 7 dias';

  @override
  String get statsTabMonthly => 'Últimos 30 dias';

  @override
  String get statsSummaryWordsRead => 'Palavras lidas';

  @override
  String get statsSummaryTimeSpent => 'Tempo';

  @override
  String get statsSummaryAvgWpm => 'WPM médio';

  @override
  String get statsSummaryBooksTouched => 'Livros';

  @override
  String get statsChartWordsPerDay => 'Palavras por dia';

  @override
  String get statsChartTimePerDay => 'Tempo por dia';

  @override
  String get statsChartWpmTrend => 'WPM ao longo do tempo';

  @override
  String get statsBookBreakdownTitle => 'Por livro';

  @override
  String statsBookBreakdownEntry(int minutes, int sessions) {
    String _temp0 = intl.Intl.pluralLogic(
      sessions,
      locale: localeName,
      other: '$sessions sessões',
      one: '1 sessão',
    );
    return '$minutes min • $_temp0';
  }

  @override
  String get statsEmptyTitle => 'Nada para mostrar ainda';

  @override
  String get statsEmptySubtitle =>
      'Inicie uma sessão de leitura RSVP para ver estatísticas aqui.';

  @override
  String statsDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String statsDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get statsOtherBooks => 'Outros';

  @override
  String get recapTitle => 'Recap mensal';

  @override
  String get recapGenerateCta => 'Compartilhar recap do mês';

  @override
  String get recapShareCta => 'Compartilhar';

  @override
  String get recapEmptyMonth =>
      'Nada lido neste mês ainda — volte depois de uma sessão RSVP.';

  @override
  String get recapFinished => 'Finalizados';

  @override
  String get recapReading => 'Em leitura';

  @override
  String recapStatsFooter(String words, int hours, int minutes) {
    return '$words palavras lidas • ${hours}h ${minutes}m';
  }

  @override
  String get recapWordmark => 'RSVP Reader';

  @override
  String recapMonthHeadline(String month, int year) {
    return '$month $year';
  }

  @override
  String recapShareText(String month) {
    return 'Meu recap de leitura de $month no RSVP Reader.';
  }

  @override
  String recapBookProgress(int percent) {
    return '$percent% lido';
  }

  @override
  String get completionHeadline => 'Livro finalizado';

  @override
  String get completionShareCta => 'Compartilhar';

  @override
  String get completionRatingLabel => 'Sua nota';

  @override
  String get completionRatingHint => 'Toque em uma estrela para avaliar';

  @override
  String get completionStatTime => 'Tempo de leitura';

  @override
  String get completionStatWords => 'Palavras lidas';

  @override
  String get completionStatSessions => 'Sessões';

  @override
  String get completionStatAvgWpm => 'WPM médio';

  @override
  String completionStatSpan(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dias',
      one: '1 dia',
    );
    return 'Concluído em $_temp0';
  }

  @override
  String get completionCardHeadline => 'Finalizado!';

  @override
  String completionCardFooter(int hours, int minutes, int sessions) {
    String _temp0 = intl.Intl.pluralLogic(
      sessions,
      locale: localeName,
      other: '$sessions sessões',
      one: '1 sessão',
    );
    return '${hours}h ${minutes}m • $_temp0';
  }

  @override
  String completionShareText(String title) {
    return 'Acabei de terminar \"$title\" no RSVP Reader.';
  }

  @override
  String get completionIncludeStats => 'Incluir estatísticas na imagem';

  @override
  String completionFinishedOn(String date) {
    return 'Finalizado em $date';
  }

  @override
  String get imageContinue => 'Continuar';

  @override
  String get imageClose => 'Fechar';

  @override
  String get imageMissing => 'Imagem indisponível';

  @override
  String get settingsTtsVoice => 'Voz';

  @override
  String get settingsTtsVoiceDesc => 'Escolha a voz usada no modo TTS';

  @override
  String get settingsTtsPitch => 'Tom';

  @override
  String get settingsTtsPitchDesc =>
      'Tom da voz — mais baixo soa grave, mais alto soa agudo';

  @override
  String get ttsVoicePickerTitle => 'Escolha uma voz';

  @override
  String get ttsVoicePreviewSample =>
      'O sol nasceu cedo e a manhã estava clara.';

  @override
  String get ttsVoicePreviewTooltip => 'Ouvir prévia';

  @override
  String get ttsVoiceCurrent => 'Selecionada';

  @override
  String get ttsNoVoicesAvailable => 'Nenhuma voz disponível neste dispositivo';

  @override
  String get ttsLinuxRequiresSpeechDispatcher =>
      'Instale o speech-dispatcher para habilitar a narração no Linux (ex.: `sudo apt install speech-dispatcher`)';

  @override
  String get ttsFirstUseHint => 'Toque em play para iniciar a narração';

  @override
  String ttsErrorPrefix(String error) {
    return 'Erro de narração: $error';
  }

  @override
  String ttsVoiceFallbackLabel(String locale) {
    return 'Padrão para $locale';
  }

  @override
  String get settingsTtsEngine => 'Engine';

  @override
  String get settingsTtsEngineDesc => 'Engine usada para sintetizar a fala';

  @override
  String get ttsEnginePickerTitle => 'Escolha uma engine';

  @override
  String get ttsEnginePickerSubtitle =>
      'Engines diferentes oferecem vozes e qualidades distintas';

  @override
  String get ttsEnginePickerEmpty => 'Nenhuma engine alternativa instalada';

  @override
  String get ttsEnginePickerSystemDefault => 'Padrão do sistema';

  @override
  String get ttsVoicePickerSearchHint => 'Buscar vozes, idiomas, regiões...';

  @override
  String get ttsVoicePickerScopeCurrent => 'Idioma atual';

  @override
  String get ttsVoicePickerScopeAll => 'Todos os idiomas';

  @override
  String get ttsVoicePickerNoMatches => 'Nenhuma voz corresponde à busca';

  @override
  String ttsVoicePickerNoCurrentVoices(String language) {
    return 'Não há vozes para $language neste aparelho. Mude para Todos os idiomas para ver as disponíveis.';
  }

  @override
  String get settingsSectionSpeedTiming => 'Velocidade & Timing';

  @override
  String get settingsSectionRsvpDisplay => 'Exibição RSVP';

  @override
  String get settingsSectionAudio => 'Áudio';

  @override
  String get settingsSectionReaderView => 'Texto Corrido';

  @override
  String get settingsSectionTypography => 'Tipografia & Fundo';

  @override
  String get settingsSectionChrome => 'Controles do Leitor';

  @override
  String get settingsScopeRsvp => 'RSVP';

  @override
  String get settingsScopeAudio => 'Áudio';

  @override
  String get settingsScopeReader => 'Leitor';

  @override
  String get settingsScopeAllModes => 'Todos os modos';

  @override
  String get settingsScopeControls => 'RSVP & Áudio';

  @override
  String get settingsScopeRsvpTooltip => 'Aplica-se apenas ao modo RSVP';

  @override
  String get settingsScopeAudioTooltip =>
      'Aplica-se à reprodução em áudio (TTS)';

  @override
  String get settingsScopeReaderTooltip =>
      'Aplica-se aos modos RSVP, e-reader e áudio';

  @override
  String get settingsScopeAllModesTooltip =>
      'Aplica-se a todos os modos de leitura';

  @override
  String get settingsScopeControlsTooltip =>
      'Aplica-se quando os controles de leitura estão visíveis (não em e-reader)';

  @override
  String get bookmarksTitle => 'Marcadores';

  @override
  String get bookmarksTooltip => 'Marcadores';

  @override
  String get bookmarkCreateTitle => 'Salvar marcador';

  @override
  String get bookmarkEditTitle => 'Editar marcador';

  @override
  String get bookmarkLabelHint => 'Adicione uma nota (opcional)';

  @override
  String get bookmarkSave => 'Salvar';

  @override
  String get bookmarkEmptyTitle => 'Nenhum marcador ainda';

  @override
  String get bookmarkEmptySubtitle =>
      'Mantenha pressionada uma palavra em qualquer modo de leitura para salvar este ponto.';

  @override
  String bookmarkLocationLabel(int chapter, int percent) {
    return 'Cap. $chapter · $percent%';
  }

  @override
  String get bookmarkActionEdit => 'Editar';

  @override
  String get bookmarkActionDelete => 'Excluir';

  @override
  String get bookmarkDeleteConfirmTitle => 'Excluir marcador?';

  @override
  String get bookmarkDeleteConfirmBody => 'Este marcador será removido.';

  @override
  String get bookmarkCreatedToast => 'Marcador salvo';
}
