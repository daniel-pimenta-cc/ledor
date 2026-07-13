/* Ledor promo site — i18n + demo RSVP (port do OrpCalculator do app) */

const I18N = {
  pt: {
    'meta.title': 'Ledor · as palavras vêm até você',
    'meta.desc': 'Leia mais rápido com RSVP. Leitor open source de EPUB e artigos web para Android e Linux. Sync entre aparelhos, estatísticas, TTS. Grátis e sem anúncios.',
    'nav.modes': 'Modos',
    'nav.sync': 'Sync',
    'nav.stats': 'Estatísticas',
    'nav.oss': 'Open source',
    'hero.eyebrow': 'Leitura RSVP · EPUB + artigos web · código aberto',
    'hero.title': 'As palavras <em>vêm até você.</em>',
    'hero.lead': 'Uma palavra de cada vez, no ritmo que você escolher, com a letra de foco sempre no mesmo lugar. Seus olhos param de correr atrás do texto, a distração some e a velocidade sobe sem esforço. Aperte o play e sinta a diferença.',
    'hero.download': 'Baixar · Android & Linux',
    'hero.github': 'Ver no GitHub',
    'hero.note': 'Grátis, sem anúncios, sem conta. Licença MIT.',
    'reader.chapter': 'Capítulo 1 · Por que RSVP',
    'zero.1': 'anúncios',
    'zero.2': 'assinaturas',
    'zero.3': 'rastreadores',
    'zero.4': 'código aberto',
    'modes.title': 'Três modos, o mesmo livro',
    'modes.lead': 'Pausou o RSVP ou o TTS? O texto completo aparece com a palavra atual destacada, no mesmo ponto. Toque em outra palavra pra seguir dali.',
    'modes.rsvp.d': 'Uma palavra por vez, com a letra de foco em destaque. O modo mais rápido, feito pra devorar capítulos.',
    'modes.ereader.d': 'Leitura tradicional, sem destaques nem controles. Só você e o texto.',
    'modes.tts.d': 'Ledor é quem lê em voz alta pra outra pessoa. Aqui o app faz jus ao nome: narra o livro destacando cada palavra, mesmo com a tela bloqueada.',
    'tag.strike': 'assinatura',
    'tag.rest': 'incluso',
    'sync.h': 'Um livro, todos os seus aparelhos',
    'sync.lead': 'Comece no celular no ônibus, continue no tablet no sofá, termine no desktop. Biblioteca, progresso, marcadores e até o tema chegam juntos em todos os aparelhos, pelo seu próprio Google Drive.',
    'sync.li1': 'Sem servidor nosso, sem conta nova: a pasta fica no seu Drive, e o app só enxerga arquivos que ele mesmo criou.',
    'sync.li2': 'Sincroniza biblioteca, progresso por livro, marcadores, notas, sessões de leitura e configurações de exibição.',
    'sync.li3': 'Android, tablet e Linux desktop com o mesmo app. No tablet, biblioteca e leitor abrem lado a lado.',
    'sync.li4': 'Offline-first: o sync é opcional e o app funciona 100% sem internet.',
    'sync.d1': 'celular',
    'sync.d2': 'tablet',
    'sync.d3': 'desktop',
    'stats.h': 'Sua leitura, em números',
    'stats.lead': 'Quantas palavras você leu essa semana? Em que velocidade? O Ledor registra cada sessão e transforma sua leitura em gráficos da semana e do mês. E no fim do mês ainda sai uma retrospectiva pronta pra compartilhar.',
    'stats.li1': 'Gráficos semanais e mensais de palavras por dia, tempo de leitura e tendência de WPM.',
    'stats.li2': 'Recap mensal em imagem 9:16 pronta pra stories, com livros terminados e em andamento.',
    'stats.li3': 'Terminou um livro? Tela de celebração com estatísticas, nota de 0 a 5 estrelas e card compartilhável.',
    'stats.li4': 'Tudo calculado no aparelho. Nenhum dado de leitura sai dele.',
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
    'feat.lead': 'Nada disso é extra pago. É só o app, inteiro, de graça.',
    'feat.import.t': 'EPUB + artigos web',
    'feat.import.d': 'Importe seus EPUBs ou salve qualquer artigo pela URL. No Android, é só compartilhar a página com o Ledor. Tudo vira a mesma leitura.',
    'feat.tts.t': 'Narração TTS',
    'feat.tts.d': 'Vozes do sistema com nomes amigáveis, controles na tela de bloqueio e velocidade de 0,5× a 3×.',
    'feat.theme.t': 'Tema totalmente seu',
    'feat.theme.d': 'Cores, fontes, tamanhos e posições, tudo com preview ao vivo. Temas claro e escuro com cara de página impressa.',
    'feat.marks.t': 'Marcadores',
    'feat.marks.d': 'Segure qualquer palavra, em qualquer modo, e ela vira marcador com um trecho do contexto. Sincronizado entre aparelhos, claro.',
    'feat.offline.t': 'Offline-first',
    'feat.offline.d': 'Seus livros e seu progresso moram no aparelho, não na nuvem. Internet só pra importar artigos ou sincronizar.',
    'feat.timing.t': 'Timing inteligente',
    'feat.timing.d': 'O ritmo respira como leitura de verdade: pausas maiores em pontuação, parágrafos e palavras longas, e aceleração suave quando você dá play.',
    'shots.title': 'Por dentro',
    'shots.1': 'Biblioteca',
    'shots.2': 'Modo RSVP',
    'shots.3': 'Leitor pausado',
    'shots.4': 'Configurações',
    'oss.title': 'É seu, de verdade.',
    'oss.lead': 'Licença MIT, sem conta e sem servidor no meio do caminho. Seus livros ficam no seu aparelho e, se você quiser, no seu Drive. Quer mudar alguma coisa? Abra uma issue, mande um PR, ou faça um fork e deixe o leitor com a sua cara.',
    'oss.contribute': 'Como contribuir',
    'oss.issues': 'Issues abertas',
    'footer.tagline': 'Ledor, leitor RSVP de código aberto. MIT © 2026 Daniel Pimenta.',
    'footer.releases': 'Releases',
    'footer.contribute': 'Contribuir',
    'footer.privacy': 'Privacidade',
    'demo.text': 'Você está lendo uma palavra de cada vez, sem mover os olhos. A letra laranja marca o ponto onde o olho reconhece a palavra mais rápido; ela nunca sai do lugar, o texto é que vem até ela. Repare nas pausas: pontuação e palavras compridas ganham mais tempo, como numa leitura de verdade. Suba a velocidade quando se sentir pronto. Leitores treinados passam de 600 palavras por minuto.',
    'a11y.play': 'Reproduzir',
    'a11y.pause': 'Pausar',
    'a11y.lang': 'Switch to English',
    'a11y.themeLight': 'Mudar para tema claro',
    'a11y.themeDark': 'Mudar para tema escuro',
  },
  en: {
    'meta.title': 'Ledor · words come to you',
    'meta.desc': 'Read faster with RSVP. Open-source EPUB and web article reader for Android and Linux. Cross-device sync, reading stats, TTS. Free, no ads.',
    'nav.modes': 'Modes',
    'nav.sync': 'Sync',
    'nav.stats': 'Stats',
    'nav.oss': 'Open source',
    'hero.eyebrow': 'RSVP reading · EPUB + web articles · open source',
    'hero.title': 'Words <em>come to you.</em>',
    'hero.lead': 'One word at a time, at the pace you choose, with the focus letter always in the same spot. Your eyes stop chasing the text, distractions fade and speed climbs on its own. Press play and feel the difference.',
    'hero.download': 'Download · Android & Linux',
    'hero.github': 'View on GitHub',
    'hero.note': 'Free, no ads, no account. MIT licensed.',
    'reader.chapter': 'Chapter 1 · Why RSVP',
    'zero.1': 'ads',
    'zero.2': 'subscriptions',
    'zero.3': 'trackers',
    'zero.4': 'open source',
    'modes.title': 'Three modes, one book',
    'modes.lead': 'Paused RSVP or TTS? The full text appears with the current word highlighted, at the same spot. Tap another word to continue from there.',
    'modes.rsvp.d': 'One word at a time, with the focus letter highlighted. The fastest mode, made for devouring chapters.',
    'modes.ereader.d': 'Traditional reading. No highlights, no controls, just you and the text.',
    'modes.tts.d': 'A ledor is someone who reads aloud to another person. Here the app lives up to its name: it narrates the book highlighting each word, even with the screen locked.',
    'tag.strike': 'subscription',
    'tag.rest': 'included',
    'sync.h': 'One book, every device you own',
    'sync.lead': 'Start on your phone on the bus, continue on the tablet on the couch, finish on the desktop. Library, progress, bookmarks and even your theme arrive together on every device, through your own Google Drive.',
    'sync.li1': 'No server of ours, no new account: the folder lives in your Drive, and the app only sees files it created.',
    'sync.li2': 'Syncs your library, per-book progress, bookmarks, ratings, reading sessions and display settings.',
    'sync.li3': 'Android, tablet and Linux desktop with the same app. On tablets, library and reader open side by side.',
    'sync.li4': 'Offline-first: sync is optional and the app works fully without internet.',
    'sync.d1': 'phone',
    'sync.d2': 'tablet',
    'sync.d3': 'desktop',
    'stats.h': 'Your reading, in numbers',
    'stats.lead': 'How many words did you read this week? How fast? Ledor logs every session and turns your reading into weekly and monthly charts. At the end of the month, you even get a recap ready to share.',
    'stats.li1': 'Weekly and monthly charts of words per day, reading time and WPM trend.',
    'stats.li2': 'Monthly recap as a 9:16 image ready for stories, with finished and in-progress books.',
    'stats.li3': 'Finished a book? A celebration screen with stats, a 0–5 star rating and a shareable card.',
    'stats.li4': 'All computed on your device. No reading data ever leaves it.',
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
    'feat.lead': "None of this is a paid extra. It's just the app, all of it, free.",
    'feat.import.t': 'EPUB + web articles',
    'feat.import.d': 'Import your EPUBs or save any article by its URL. On Android, just share the page with Ledor. Everything becomes the same read.',
    'feat.tts.t': 'TTS narration',
    'feat.tts.d': 'System voices with friendly names, lockscreen controls, and speed from 0.5× to 3×.',
    'feat.theme.t': "A theme that's yours",
    'feat.theme.d': 'Colors, fonts, sizes and positions, all with live preview. Light and dark themes that feel like a printed page.',
    'feat.marks.t': 'Bookmarks',
    'feat.marks.d': 'Long-press any word, in any mode, and it becomes a bookmark with a context snippet. Synced across devices, of course.',
    'feat.offline.t': 'Offline-first',
    'feat.offline.d': 'Your books and your progress live on your device, not in a cloud. Internet only needed to import articles or to sync.',
    'feat.timing.t': 'Smart timing',
    'feat.timing.d': 'The pace breathes like real reading: longer pauses on punctuation, paragraphs and long words, and a gentle speed-up when you hit play.',
    'shots.title': 'A look inside',
    'shots.1': 'Library',
    'shots.2': 'RSVP mode',
    'shots.3': 'Paused reader',
    'shots.4': 'Settings',
    'oss.title': 'Truly yours.',
    'oss.lead': 'MIT licensed, no account, no server in between. Your books live on your device and, if you want, in your Drive. Want something changed? Open an issue, send a PR, or fork it and make the reader your own.',
    'oss.contribute': 'How to contribute',
    'oss.issues': 'Open issues',
    'footer.tagline': 'Ledor, an open-source RSVP reader. MIT © 2026 Daniel Pimenta.',
    'footer.releases': 'Releases',
    'footer.contribute': 'Contribute',
    'footer.privacy': 'Privacy',
    'demo.text': 'You are reading one word at a time without moving your eyes. The orange letter marks the spot where your eye recognizes a word fastest; it never moves, the text comes to it. Notice the pauses: punctuation and long words get extra time, like real reading. Raise the speed when you feel ready. Trained readers go past 600 words per minute.',
    'a11y.play': 'Play',
    'a11y.pause': 'Pause',
    'a11y.lang': 'Mudar para português',
    'a11y.themeLight': 'Switch to light theme',
    'a11y.themeDark': 'Switch to dark theme',
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
  applyTheme();
}

document.getElementById('lang-toggle').addEventListener('click', () => {
  lang = lang === 'pt' ? 'en' : 'pt';
  localStorage.setItem('ledor-lang', lang);
  applyLang();
});

/* ---------- theme toggle ---------- */

const prefersDark = window.matchMedia('(prefers-color-scheme: dark)');
let theme = document.documentElement.dataset.theme || (prefersDark.matches ? 'dark' : 'light');

function applyTheme() {
  document.documentElement.setAttribute('data-theme', theme);
  document.getElementById('theme-toggle')
    .setAttribute('aria-label', I18N[lang][theme === 'dark' ? 'a11y.themeLight' : 'a11y.themeDark']);
}

document.getElementById('theme-toggle').addEventListener('click', () => {
  theme = theme === 'dark' ? 'light' : 'dark';
  localStorage.setItem('ledor-theme', theme);
  applyTheme();
});

prefersDark.addEventListener('change', (e) => {
  if (!localStorage.getItem('ledor-theme')) {
    theme = e.matches ? 'dark' : 'light';
    applyTheme();
  }
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
