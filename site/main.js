/* Ledor promo site — i18n + demo RSVP (port do OrpCalculator do app) */

const I18N = {
  pt: {
    'meta.title': 'Ledor — as palavras vêm até você',
    'meta.desc': 'Leitor RSVP open source de EPUB e artigos web para Android e Linux. Sync entre aparelhos, estatísticas de leitura, TTS — grátis, MIT.',
    'nav.modes': 'Modos',
    'nav.sync': 'Sync',
    'nav.stats': 'Estatísticas',
    'nav.oss': 'Open source',
    'hero.eyebrow': 'Leitura RSVP · EPUB + artigos web · código aberto',
    'hero.title': 'As palavras <em>vêm até você.</em>',
    'hero.lead': 'Ledor é quem lê em voz alta para outra pessoa. Este aqui mostra uma palavra de cada vez, no ritmo que você escolher, com a letra de foco sempre no mesmo lugar — seus olhos param de perseguir o texto, e a leitura acelera.',
    'hero.download': 'Baixar · Android & Linux',
    'hero.github': 'Ver no GitHub',
    'hero.note': 'Grátis, sem anúncios, sem conta. Licença MIT.',
    'reader.chapter': 'Capítulo 1 · Por que RSVP',
    'zero.1': 'anúncios',
    'zero.2': 'assinaturas',
    'zero.3': 'rastreadores',
    'zero.4': 'código aberto',
    'modes.title': 'Três modos, o mesmo livro',
    'modes.lead': 'Pausou o RSVP ou o TTS? O texto completo aparece com a palavra atual destacada, no mesmo ponto — toque em outra palavra pra seguir dali.',
    'modes.rsvp.d': 'Uma palavra por vez, com o ponto ótimo de reconhecimento em destaque. O modo rápido.',
    'modes.ereader.d': 'Leitura tradicional, sem destaques nem controles. Só você e o texto.',
    'modes.tts.d': 'O app lê em voz alta com highlight sincronizado palavra a palavra — e segue com a tela bloqueada.',
    'tag.strike': 'assinatura',
    'tag.rest': 'incluso',
    'sync.h': 'Um livro, todos os seus aparelhos',
    'sync.lead': 'Comece no celular no ônibus, continue no tablet em casa, termine no desktop. Progresso, biblioteca, marcadores e até suas configurações de tema chegam juntos — pelo seu Google Drive, numa pasta que é sua.',
    'sync.li1': 'Sem servidor nosso, sem conta nova: a pasta fica no seu Drive, e o app só enxerga arquivos que ele mesmo criou.',
    'sync.li2': 'Sincroniza biblioteca, progresso por livro, marcadores, notas, sessões de leitura e configurações de exibição.',
    'sync.li3': 'Android, tablet e Linux desktop com o mesmo app — em tablet, biblioteca e leitor abrem lado a lado.',
    'sync.li4': 'Offline-first: o sync é opcional e o app funciona 100% sem internet.',
    'sync.d1': 'celular',
    'sync.d2': 'tablet',
    'sync.d3': 'desktop',
    'stats.h': 'Sua leitura, em números',
    'stats.lead': 'Cada sessão vira telemetria local: palavras, tempo e velocidade. O dashboard mostra sua semana e seu mês — e no fim do mês você ganha um recap compartilhável, estilo retrospectiva.',
    'stats.li1': 'Gráficos semanais e mensais de palavras por dia, tempo de leitura e tendência de WPM.',
    'stats.li2': 'Recap mensal em imagem 9:16 pronta pra stories, com livros terminados e em andamento.',
    'stats.li3': 'Terminou um livro? Tela de celebração com estatísticas, nota de 0 a 5 estrelas e card compartilhável.',
    'stats.li4': 'Tudo calculado no aparelho — nenhum dado de leitura sai dele.',
    'stats.tab1': 'Últimos 7 dias',
    'stats.tab2': 'Este mês',
    'stats.t1': 'Palavras lidas',
    'stats.t2': 'Tempo',
    'stats.t3': 'WPM médio',
    'stats.t4': 'Livros',
    'stats.v1': '12,4k',
    'stats.peak': '2.130',
    'stats.day1': 'S',
    'stats.day2': 'T',
    'stats.day3': 'Q',
    'stats.day4': 'Q',
    'stats.day5': 'S',
    'stats.day6': 'S',
    'stats.day7': 'D',
    'feat.title': 'E o resto vem junto',
    'feat.lead': 'Nada aqui é extra pago ou "pro". É só o app.',
    'feat.import.t': 'EPUB + artigos web',
    'feat.import.d': 'Importe livros ou salve qualquer artigo por URL — no Android, direto pelo share sheet. Tudo vira a mesma leitura.',
    'feat.tts.t': 'Narração TTS',
    'feat.tts.d': 'Vozes do sistema com nomes amigáveis, controles na tela de bloqueio e velocidade independente de 0,5× a 3×.',
    'feat.theme.t': 'Tema totalmente seu',
    'feat.theme.d': 'Cores, fontes, tamanhos e posições com preview ao vivo. Claro e escuro editoriais, laranja preservado.',
    'feat.marks.t': 'Marcadores',
    'feat.marks.d': 'Segure qualquer palavra, em qualquer modo, para marcar. Com trecho de contexto — e sincronizados também.',
    'feat.offline.t': 'Offline-first',
    'feat.offline.d': 'Tudo em SQLite no seu aparelho. Sync é opcional; internet, só para importar artigos.',
    'feat.timing.t': 'Timing inteligente',
    'feat.timing.d': 'Pausas maiores em pontuação, parágrafos e palavras longas, pré-computadas no import. Ramp-up suave ao dar play.',
    'shots.title': 'Por dentro',
    'shots.1': 'Biblioteca',
    'shots.2': 'Modo RSVP',
    'shots.3': 'Leitor pausado',
    'shots.4': 'Configurações',
    'oss.title': 'É seu, de verdade.',
    'oss.lead': 'Licença MIT, sem conta e sem servidor nosso — não existe “nosso servidor”. Seus livros ficam no seu aparelho e, se você quiser, no seu Drive. Não gostou de algo? Abra uma issue, mande um PR — ou faça um fork e deixe o leitor com a sua cara.',
    'oss.contribute': 'Como contribuir',
    'oss.issues': 'Issues abertas',
    'footer.tagline': 'Ledor — leitor RSVP de código aberto. MIT © 2026 Daniel Pimenta.',
    'footer.releases': 'Releases',
    'footer.contribute': 'Contribuir',
    'footer.privacy': 'Privacidade',
    'demo.text': 'Você está lendo uma palavra de cada vez, sem mover os olhos. A letra laranja marca o ponto onde o olho reconhece a palavra mais rápido; ela nunca sai do lugar, o texto é que vem até ela. Repare nas pausas: pontuação e palavras compridas ganham mais tempo, como numa leitura de verdade. Suba a velocidade quando se sentir pronto — leitores treinados passam de 600 palavras por minuto.',
    'a11y.play': 'Reproduzir',
    'a11y.pause': 'Pausar',
    'a11y.lang': 'Switch to English',
  },
  en: {
    'meta.title': 'Ledor — words come to you',
    'meta.desc': 'Open-source RSVP reader for EPUB and web articles on Android and Linux. Cross-device sync, reading stats, TTS — free, MIT.',
    'nav.modes': 'Modes',
    'nav.sync': 'Sync',
    'nav.stats': 'Stats',
    'nav.oss': 'Open source',
    'hero.eyebrow': 'RSVP reading · EPUB + web articles · open source',
    'hero.title': 'Words <em>come to you.</em>',
    'hero.lead': 'A ledor is someone who reads aloud to another person. This one shows you one word at a time, at the pace you choose, with the focus letter always in the same spot — your eyes stop chasing the text, and reading speeds up.',
    'hero.download': 'Download · Android & Linux',
    'hero.github': 'View on GitHub',
    'hero.note': 'Free, no ads, no account. MIT licensed.',
    'reader.chapter': 'Chapter 1 · Why RSVP',
    'zero.1': 'ads',
    'zero.2': 'subscriptions',
    'zero.3': 'trackers',
    'zero.4': 'open source',
    'modes.title': 'Three modes, one book',
    'modes.lead': 'Paused RSVP or TTS? The full text appears with the current word highlighted, at the same spot — tap another word to continue from there.',
    'modes.rsvp.d': 'One word at a time, with the optimal recognition point highlighted. The fast mode.',
    'modes.ereader.d': 'Traditional reading — no highlights, no controls. Just you and the text.',
    'modes.tts.d': 'The app reads aloud with word-by-word highlight — and keeps going with the screen locked.',
    'tag.strike': 'subscription',
    'tag.rest': 'included',
    'sync.h': 'One book, every device you own',
    'sync.lead': 'Start on your phone on the bus, continue on the tablet at home, finish on the desktop. Progress, library, bookmarks and even your theme settings arrive together — through your own Google Drive, in a folder you own.',
    'sync.li1': 'No server of ours, no new account: the folder lives in your Drive, and the app only sees files it created.',
    'sync.li2': 'Syncs your library, per-book progress, bookmarks, ratings, reading sessions and display settings.',
    'sync.li3': 'Android, tablet and Linux desktop with the same app — on tablets, library and reader open side by side.',
    'sync.li4': 'Offline-first: sync is optional and the app works fully without internet.',
    'sync.d1': 'phone',
    'sync.d2': 'tablet',
    'sync.d3': 'desktop',
    'stats.h': 'Your reading, in numbers',
    'stats.lead': 'Every session becomes local telemetry: words, time and speed. The dashboard shows your week and your month — and at the end of the month you get a shareable recap.',
    'stats.li1': 'Weekly and monthly charts of words per day, reading time and WPM trend.',
    'stats.li2': 'Monthly recap as a 9:16 image ready for stories, with finished and in-progress books.',
    'stats.li3': 'Finished a book? A celebration screen with stats, a 0–5 star rating and a shareable card.',
    'stats.li4': 'All computed on-device — no reading data ever leaves it.',
    'stats.tab1': 'Last 7 days',
    'stats.tab2': 'This month',
    'stats.t1': 'Words read',
    'stats.t2': 'Time',
    'stats.t3': 'Avg WPM',
    'stats.t4': 'Books',
    'stats.v1': '12.4k',
    'stats.peak': '2,130',
    'stats.day1': 'M',
    'stats.day2': 'T',
    'stats.day3': 'W',
    'stats.day4': 'T',
    'stats.day5': 'F',
    'stats.day6': 'S',
    'stats.day7': 'S',
    'feat.title': 'And the rest comes along',
    'feat.lead': 'Nothing here is a paid extra or a "pro" tier. It\'s just the app.',
    'feat.import.t': 'EPUB + web articles',
    'feat.import.d': 'Import books or save any article by URL — on Android, straight from the share sheet. Everything becomes the same read.',
    'feat.tts.t': 'TTS narration',
    'feat.tts.d': 'System voices with friendly names, lockscreen controls, and independent speed from 0.5× to 3×.',
    'feat.theme.t': "A theme that's yours",
    'feat.theme.d': 'Colors, fonts, sizes and positions with live preview. Editorial light and dark, orange preserved.',
    'feat.marks.t': 'Bookmarks',
    'feat.marks.d': 'Long-press any word, in any mode, to bookmark it. With a context snippet — synced too.',
    'feat.offline.t': 'Offline-first',
    'feat.offline.d': 'Everything in SQLite on your device. Sync is optional; internet only needed to import articles.',
    'feat.timing.t': 'Smart timing',
    'feat.timing.d': 'Longer pauses on punctuation, paragraphs and long words, precomputed at import. Gentle ramp-up on play.',
    'shots.title': 'A look inside',
    'shots.1': 'Library',
    'shots.2': 'RSVP mode',
    'shots.3': 'Paused reader',
    'shots.4': 'Settings',
    'oss.title': 'Truly yours.',
    'oss.lead': 'MIT licensed, no account, and no server of ours — there is no “our server”. Your books live on your device and, if you want, in your Drive. Don’t like something? Open an issue, send a PR — or fork it and make the reader your own.',
    'oss.contribute': 'How to contribute',
    'oss.issues': 'Open issues',
    'footer.tagline': 'Ledor — open-source RSVP reader. MIT © 2026 Daniel Pimenta.',
    'footer.releases': 'Releases',
    'footer.contribute': 'Contribute',
    'footer.privacy': 'Privacy',
    'demo.text': 'You are reading one word at a time without moving your eyes. The orange letter marks the spot where your eye recognizes a word fastest; it never moves — the text comes to it. Notice the pauses: punctuation and long words get extra time, like real reading. Raise the speed when you feel ready — trained readers go past 600 words per minute.',
    'a11y.play': 'Play',
    'a11y.pause': 'Pause',
    'a11y.lang': 'Mudar para português',
  },
};

let lang = localStorage.getItem('ledor-lang')
  || (navigator.language && navigator.language.toLowerCase().startsWith('pt') ? 'pt' : 'en');

function applyLang() {
  const dict = I18N[lang];
  document.documentElement.lang = lang === 'pt' ? 'pt-BR' : 'en';
  document.title = dict['meta.title'];
  document.querySelector('meta[name="description"]').content = dict['meta.desc'];
  document.querySelectorAll('[data-i18n]').forEach((el) => {
    el.textContent = dict[el.dataset.i18n];
  });
  document.querySelectorAll('[data-i18n-html]').forEach((el) => {
    el.innerHTML = dict[el.dataset.i18nHtml];
  });
  const toggle = document.getElementById('lang-toggle');
  toggle.textContent = lang === 'pt' ? 'EN' : 'PT';
  toggle.setAttribute('aria-label', dict['a11y.lang']);
  demo.setText(dict['demo.text']);
  updatePlayLabel();
}

document.getElementById('lang-toggle').addEventListener('click', () => {
  lang = lang === 'pt' ? 'en' : 'pt';
  localStorage.setItem('ledor-lang', lang);
  applyLang();
});

/* ---------- ORP: port de lib/core/utils/orp_calculator.dart ---------- */

const LETTER_OR_DIGIT = /[\p{L}\p{N}]/u;
const ORP_LOOKUP = [0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4];

function orpIndex(word) {
  if (!word) return 0;
  let firstAlpha = -1;
  let alphaCount = 0;
  for (let i = 0; i < word.length; i++) {
    if (LETTER_OR_DIGIT.test(word[i])) {
      if (firstAlpha === -1) firstAlpha = i;
      alphaCount++;
    }
  }
  if (firstAlpha === -1) return 0;
  const orpInAlpha = alphaCount <= ORP_LOOKUP.length
    ? ORP_LOOKUP[alphaCount - 1]
    : Math.floor(alphaCount * 0.35);
  let count = 0;
  for (let i = 0; i < word.length; i++) {
    if (LETTER_OR_DIGIT.test(word[i])) {
      if (count === orpInAlpha) return i;
      count++;
    }
  }
  return firstAlpha;
}

/* ---------- demo RSVP ---------- */

const REDUCED_MOTION = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

const demo = {
  words: [],
  index: 0,
  wpm: 350,
  playing: false,
  timer: null,

  setText(text) {
    this.words = text.split(/\s+/).filter(Boolean);
    this.index = 0;
    this.render();
  },

  render() {
    const word = this.words[this.index] || '';
    const orp = orpIndex(word);
    document.querySelector('.w-pre').textContent = word.slice(0, orp);
    document.querySelector('.w-orp').textContent = word[orp] || '';
    document.querySelector('.w-post').textContent = word.slice(orp + 1);
    document.getElementById('focus-fill').style.width =
      `${((this.index + 1) / this.words.length) * 100}%`;
  },

  // multiplicadores no espírito do word_timing do app: pontuação e palavras longas seguram mais
  intervalFor(word) {
    const base = 60000 / this.wpm;
    let mult = 1;
    if (/[.!?…;:]["')\]]?$/.test(word)) mult = 2.2;
    else if (/,["')\]]?$/.test(word)) mult = 1.5;
    if (word.length >= 9) mult *= 1.3;
    return base * mult;
  },

  tick() {
    if (!this.playing) return;
    this.index = (this.index + 1) % this.words.length;
    this.render();
    this.timer = setTimeout(() => this.tick(), this.intervalFor(this.words[this.index]));
  },

  play() {
    if (this.playing) return;
    this.playing = true;
    this.timer = setTimeout(() => this.tick(), this.intervalFor(this.words[this.index] || ''));
    updatePlayLabel();
  },

  pause() {
    this.playing = false;
    clearTimeout(this.timer);
    updatePlayLabel();
  },

  setWpm(value) {
    this.wpm = Math.min(900, Math.max(100, value));
    document.getElementById('wpm-value').textContent = this.wpm;
    document.getElementById('wpm-status').textContent = this.wpm;
  },
};

function updatePlayLabel() {
  const btn = document.getElementById('play-btn');
  btn.dataset.playing = String(demo.playing);
  btn.setAttribute('aria-label', I18N[lang][demo.playing ? 'a11y.pause' : 'a11y.play']);
}

document.getElementById('play-btn').addEventListener('click', () => {
  demo.playing ? demo.pause() : demo.play();
});
document.getElementById('wpm-minus').addEventListener('click', () => demo.setWpm(demo.wpm - 25));
document.getElementById('wpm-plus').addEventListener('click', () => demo.setWpm(demo.wpm + 25));

/* ---------- autostart do demo quando visível ---------- */

if (!REDUCED_MOTION) {
  const demoObserver = new IntersectionObserver((entries) => {
    entries.forEach((e) => (e.isIntersecting ? demo.play() : demo.pause()));
  }, { threshold: 0.4 });
  demoObserver.observe(document.querySelector('.reader'));
}

applyLang();
