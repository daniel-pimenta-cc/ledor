import '../../features/rsvp_reader/data/services/tts_backend.dart';

/// Friendly labels derived from a [TtsVoice] for the picker UI.
///
/// `voice.name` from the platform engines is usually a technical id like
/// `en-gb-x-fis-network` or `Samsung-text-to-speech-engine-en-us-female`
/// — useful to the engine, useless to humans. iOS / macOS instead expose
/// proper names ("Samantha", "Karen") that are already user-readable.
/// The formatter detects which kind it has and composes:
///
/// - For friendly names: [primary] = "Samantha", [secondary] = "English
///   (US) · Female".
/// - For technical names: [primary] = "English (US)", [secondary] =
///   "Female · Voice 2", [techDetail] = the raw `voice.name` (small
///   caption so power users can still see it).
///
/// Pure data — no Flutter dependencies — so it's easy to unit-test.
class FormattedVoiceLabel {
  /// Bold first line in the tile.
  final String primary;

  /// Secondary line below [primary]. May be null when there's nothing
  /// extra to say (e.g. an unknown-gender voice with a friendly name).
  final String? secondary;

  /// Raw `voice.name` shown as a tiny caption beneath [secondary], but
  /// only when the name is a technical id — friendly names use [primary]
  /// already and don't need to be repeated.
  final String? techDetail;

  /// Display label for the section header that contains this voice.
  /// Same value (per locale) across every voice in the group.
  final String localeGroupName;

  /// Sort key used to order section headers consistently. Lowercased
  /// locale id so groups land in a stable order even when display names
  /// differ between UI languages.
  final String localeGroupSortKey;

  /// Normalised gender for this voice (`'male'` / `'female'` /
  /// `'neutral'`) or `null` when the platform didn't tell us.
  final String? gender;

  const FormattedVoiceLabel({
    required this.primary,
    required this.secondary,
    required this.techDetail,
    required this.localeGroupName,
    required this.localeGroupSortKey,
    required this.gender,
  });
}

/// Returns the friendly labels for [voice] given the UI language code
/// ([uiLanguage] — `'pt'` or `'en'`). Unknown languages fall back to
/// English. Unknown locales render the raw locale id.
///
/// Optional [variantSerial] disambiguates voices that share the same
/// locale + gender (typical on Android Google TTS). When provided,
/// it's appended to [FormattedVoiceLabel.secondary] as "Female 2".
FormattedVoiceLabel formatVoice(
  TtsVoice voice,
  String uiLanguage, {
  int? variantSerial,
}) {
  final lang = _normaliseUiLanguage(uiLanguage);
  final localeName = localeDisplayName(voice.locale, lang);
  final gender = inferGender(voice);
  final genderLabel = gender != null ? _genderLabel(gender, lang) : null;

  final friendly = _looksLikeFriendlyName(voice.name);

  if (friendly) {
    // Friendly name (iOS / macOS): "Samantha"
    final parts = <String>[localeName];
    if (genderLabel != null) parts.add(genderLabel);
    return FormattedVoiceLabel(
      primary: voice.name,
      secondary: parts.join(' · '),
      techDetail: null,
      localeGroupName: localeName,
      localeGroupSortKey: voice.locale.toLowerCase(),
      gender: gender,
    );
  }

  // Technical id (Android / Linux / Samsung): build the human label from
  // locale + gender, keep raw id as a discreet caption.
  final secondaryParts = <String>[];
  if (genderLabel != null) {
    if (variantSerial != null) {
      secondaryParts.add('$genderLabel $variantSerial');
    } else {
      secondaryParts.add(genderLabel);
    }
  } else if (variantSerial != null) {
    secondaryParts.add(_voiceVariantLabel(variantSerial, lang));
  }

  return FormattedVoiceLabel(
    primary: localeName,
    secondary: secondaryParts.isEmpty ? null : secondaryParts.join(' · '),
    techDetail: voice.name,
    localeGroupName: localeName,
    localeGroupSortKey: voice.locale.toLowerCase(),
    gender: gender,
  );
}

/// Returns the human-friendly display for an ISO/BCP-47 locale. Splits
/// the code on `-` or `_`, looks each part up in the curated maps, and
/// composes them as "Language (Region)" — falling back to the raw code
/// when the language isn't in the table.
///
/// Visible for testing.
String localeDisplayName(String locale, String uiLanguage) {
  if (locale.isEmpty) return locale;
  final lang = _normaliseUiLanguage(uiLanguage);
  final parts = locale.split(RegExp(r'[-_]'));
  final primary = parts[0].toLowerCase();
  final region = parts.length > 1 ? parts[1].toUpperCase() : null;

  final language = _languageNames[primary]?[lang];
  if (language == null) return locale;
  if (region == null) return language;
  final regionLabel = _regionNames[region]?[lang];
  if (regionLabel == null) return '$language ($region)';
  return '$language ($regionLabel)';
}

/// Returns `'male'` / `'female'` / `'neutral'` from a voice's gender
/// field, falling back to pattern-matching the technical name. Returns
/// `null` when nothing is recognised.
///
/// Visible for testing.
String? inferGender(TtsVoice voice) {
  final raw = voice.gender?.toLowerCase().trim() ?? '';
  if (raw.contains('female') || raw == 'f') return 'female';
  if (raw.contains('male') || raw == 'm') return 'male';
  if (raw.contains('neutral')) return 'neutral';

  final name = voice.name.toLowerCase();
  if (name.contains('female') || name.contains('woman')) return 'female';
  // Order matters: 'male' is a substring of 'female', so we test female first.
  if (name.contains('male') || name.contains(' man') || name.contains('-man-')) {
    return 'male';
  }
  return null;
}

/// Friendly-name heuristic: technical ids contain `-`, `_`, `#`, or
/// digits. Real names ("Samantha", "Karen", "Daniel") don't. iOS adds
/// "(Enhanced)" / "(Premium)" suffixes — those are fine to display as-is.
bool _looksLikeFriendlyName(String name) {
  if (name.isEmpty) return false;
  if (name.length < 3) return false;
  // Strip parenthesised qualifiers ("Samantha (Enhanced)") before checking.
  final core = name.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), '').trim();
  if (core.isEmpty) return false;
  if (core.contains('-') || core.contains('_') || core.contains('#')) {
    return false;
  }
  if (RegExp(r'[0-9]').hasMatch(core)) return false;
  return true;
}

String _normaliseUiLanguage(String code) {
  final c = code.toLowerCase().split(RegExp(r'[-_]')).first;
  return _languageNames.containsKey(c) ? c : 'en';
}

String _genderLabel(String gender, String uiLanguage) {
  switch (gender) {
    case 'female':
      return uiLanguage == 'pt' ? 'Feminina' : 'Female';
    case 'male':
      return uiLanguage == 'pt' ? 'Masculina' : 'Male';
    case 'neutral':
      return uiLanguage == 'pt' ? 'Neutra' : 'Neutral';
    default:
      return gender;
  }
}

String _voiceVariantLabel(int serial, String uiLanguage) {
  return uiLanguage == 'pt' ? 'Voz $serial' : 'Voice $serial';
}

/// Pairs a [TtsVoice] with the labels the picker should display. Built
/// once per voice list so the UI doesn't repeat the formatter work in
/// every rebuild + every filter pass.
class EnrichedVoice {
  final TtsVoice voice;
  final FormattedVoiceLabel label;

  /// Lowercased haystack used by the search box. Includes everything a
  /// user might reasonably type to find this voice: the friendly label,
  /// the raw name, the locale id.
  final String searchHaystack;

  /// Primary language part of the locale (`'en'` for `en-GB`, `'pt'` for
  /// `pt-BR`). Used by the "current language" filter so it spans every
  /// region of the same language.
  final String primaryLanguage;

  EnrichedVoice._({
    required this.voice,
    required this.label,
    required this.searchHaystack,
    required this.primaryLanguage,
  });
}

/// Wraps each entry in [voices] with display labels and a search-friendly
/// haystack, assigning per-group serial numbers when multiple voices
/// share the same locale + gender. Caller passes [uiLanguage] (`'pt'` or
/// `'en'`) — the formatter localises everything off that.
List<EnrichedVoice> enrichVoices(List<TtsVoice> voices, String uiLanguage) {
  // First pass: figure out which (locale, gender) groups have multiple
  // technical-name voices that need numbering.
  final groupSize = <String, int>{};
  final preLabels = <FormattedVoiceLabel>[];
  for (final v in voices) {
    final label = formatVoice(v, uiLanguage);
    preLabels.add(label);
    if (label.techDetail != null) {
      final key = '${v.locale.toLowerCase()}|${label.gender ?? '?'}';
      groupSize[key] = (groupSize[key] ?? 0) + 1;
    }
  }

  final used = <String, int>{};
  final result = <EnrichedVoice>[];
  for (var i = 0; i < voices.length; i++) {
    final v = voices[i];
    final initialLabel = preLabels[i];
    FormattedVoiceLabel label;
    if (initialLabel.techDetail != null) {
      final key = '${v.locale.toLowerCase()}|${initialLabel.gender ?? '?'}';
      if ((groupSize[key] ?? 0) > 1) {
        used[key] = (used[key] ?? 0) + 1;
        label = formatVoice(v, uiLanguage, variantSerial: used[key]);
      } else {
        label = initialLabel;
      }
    } else {
      label = initialLabel;
    }

    final primaryLang = v.locale.split(RegExp(r'[-_]')).first.toLowerCase();
    final haystack = [
      label.primary,
      label.secondary ?? '',
      label.techDetail ?? '',
      v.name,
      v.locale,
      label.localeGroupName,
    ].join(' ').toLowerCase();

    result.add(EnrichedVoice._(
      voice: v,
      label: label,
      searchHaystack: haystack,
      primaryLanguage: primaryLang,
    ));
  }
  return result;
}

/// Curated language code → display name table. Covers the languages a
/// non-trivial set of users will see in their installed TTS engines.
/// Anything missing falls through to the raw locale id, which is still
/// readable.
const Map<String, Map<String, String>> _languageNames = {
  'af': {'pt': 'Africâner', 'en': 'Afrikaans'},
  'ar': {'pt': 'Árabe', 'en': 'Arabic'},
  'bg': {'pt': 'Búlgaro', 'en': 'Bulgarian'},
  'bn': {'pt': 'Bengali', 'en': 'Bengali'},
  'ca': {'pt': 'Catalão', 'en': 'Catalan'},
  'cs': {'pt': 'Tcheco', 'en': 'Czech'},
  'cy': {'pt': 'Galês', 'en': 'Welsh'},
  'da': {'pt': 'Dinamarquês', 'en': 'Danish'},
  'de': {'pt': 'Alemão', 'en': 'German'},
  'el': {'pt': 'Grego', 'en': 'Greek'},
  'en': {'pt': 'Inglês', 'en': 'English'},
  'es': {'pt': 'Espanhol', 'en': 'Spanish'},
  'et': {'pt': 'Estoniano', 'en': 'Estonian'},
  'eu': {'pt': 'Basco', 'en': 'Basque'},
  'fa': {'pt': 'Persa', 'en': 'Persian'},
  'fi': {'pt': 'Finlandês', 'en': 'Finnish'},
  'fr': {'pt': 'Francês', 'en': 'French'},
  'ga': {'pt': 'Irlandês', 'en': 'Irish'},
  'gl': {'pt': 'Galego', 'en': 'Galician'},
  'gu': {'pt': 'Guzerate', 'en': 'Gujarati'},
  'he': {'pt': 'Hebraico', 'en': 'Hebrew'},
  'hi': {'pt': 'Hindi', 'en': 'Hindi'},
  'hr': {'pt': 'Croata', 'en': 'Croatian'},
  'hu': {'pt': 'Húngaro', 'en': 'Hungarian'},
  'hy': {'pt': 'Armênio', 'en': 'Armenian'},
  'id': {'pt': 'Indonésio', 'en': 'Indonesian'},
  'is': {'pt': 'Islandês', 'en': 'Icelandic'},
  'it': {'pt': 'Italiano', 'en': 'Italian'},
  'ja': {'pt': 'Japonês', 'en': 'Japanese'},
  'ka': {'pt': 'Georgiano', 'en': 'Georgian'},
  'kk': {'pt': 'Cazaque', 'en': 'Kazakh'},
  'km': {'pt': 'Khmer', 'en': 'Khmer'},
  'kn': {'pt': 'Canarês', 'en': 'Kannada'},
  'ko': {'pt': 'Coreano', 'en': 'Korean'},
  'lt': {'pt': 'Lituano', 'en': 'Lithuanian'},
  'lv': {'pt': 'Letão', 'en': 'Latvian'},
  'mk': {'pt': 'Macedônio', 'en': 'Macedonian'},
  'ml': {'pt': 'Malaiala', 'en': 'Malayalam'},
  'mn': {'pt': 'Mongol', 'en': 'Mongolian'},
  'mr': {'pt': 'Marathi', 'en': 'Marathi'},
  'ms': {'pt': 'Malaio', 'en': 'Malay'},
  'my': {'pt': 'Birmanês', 'en': 'Burmese'},
  'nb': {'pt': 'Norueguês (Bokmål)', 'en': 'Norwegian (Bokmål)'},
  'ne': {'pt': 'Nepalês', 'en': 'Nepali'},
  'nl': {'pt': 'Holandês', 'en': 'Dutch'},
  'nn': {'pt': 'Norueguês (Nynorsk)', 'en': 'Norwegian (Nynorsk)'},
  'no': {'pt': 'Norueguês', 'en': 'Norwegian'},
  'pa': {'pt': 'Punjabi', 'en': 'Punjabi'},
  'pl': {'pt': 'Polonês', 'en': 'Polish'},
  'pt': {'pt': 'Português', 'en': 'Portuguese'},
  'ro': {'pt': 'Romeno', 'en': 'Romanian'},
  'ru': {'pt': 'Russo', 'en': 'Russian'},
  'si': {'pt': 'Cingalês', 'en': 'Sinhala'},
  'sk': {'pt': 'Eslovaco', 'en': 'Slovak'},
  'sl': {'pt': 'Esloveno', 'en': 'Slovenian'},
  'sq': {'pt': 'Albanês', 'en': 'Albanian'},
  'sr': {'pt': 'Sérvio', 'en': 'Serbian'},
  'sv': {'pt': 'Sueco', 'en': 'Swedish'},
  'sw': {'pt': 'Suaíli', 'en': 'Swahili'},
  'ta': {'pt': 'Tâmil', 'en': 'Tamil'},
  'te': {'pt': 'Telugu', 'en': 'Telugu'},
  'th': {'pt': 'Tailandês', 'en': 'Thai'},
  'tr': {'pt': 'Turco', 'en': 'Turkish'},
  'uk': {'pt': 'Ucraniano', 'en': 'Ukrainian'},
  'ur': {'pt': 'Urdu', 'en': 'Urdu'},
  'vi': {'pt': 'Vietnamita', 'en': 'Vietnamese'},
  'zh': {'pt': 'Chinês', 'en': 'Chinese'},
};

/// Curated region code → display name table. ISO 3166-1 alpha-2 codes
/// (`US`, `BR`, …). Same fallback story as [_languageNames]: missing
/// regions render as the raw code in parentheses.
const Map<String, Map<String, String>> _regionNames = {
  'AE': {'pt': 'Emirados Árabes', 'en': 'UAE'},
  'AR': {'pt': 'Argentina', 'en': 'Argentina'},
  'AT': {'pt': 'Áustria', 'en': 'Austria'},
  'AU': {'pt': 'Austrália', 'en': 'Australia'},
  'BE': {'pt': 'Bélgica', 'en': 'Belgium'},
  'BG': {'pt': 'Bulgária', 'en': 'Bulgaria'},
  'BR': {'pt': 'Brasil', 'en': 'Brazil'},
  'CA': {'pt': 'Canadá', 'en': 'Canada'},
  'CH': {'pt': 'Suíça', 'en': 'Switzerland'},
  'CL': {'pt': 'Chile', 'en': 'Chile'},
  'CN': {'pt': 'China', 'en': 'China'},
  'CO': {'pt': 'Colômbia', 'en': 'Colombia'},
  'CZ': {'pt': 'República Tcheca', 'en': 'Czech Republic'},
  'DE': {'pt': 'Alemanha', 'en': 'Germany'},
  'DK': {'pt': 'Dinamarca', 'en': 'Denmark'},
  'EE': {'pt': 'Estônia', 'en': 'Estonia'},
  'EG': {'pt': 'Egito', 'en': 'Egypt'},
  'ES': {'pt': 'Espanha', 'en': 'Spain'},
  'FI': {'pt': 'Finlândia', 'en': 'Finland'},
  'FR': {'pt': 'França', 'en': 'France'},
  'GB': {'pt': 'Reino Unido', 'en': 'UK'},
  'GR': {'pt': 'Grécia', 'en': 'Greece'},
  'HK': {'pt': 'Hong Kong', 'en': 'Hong Kong'},
  'HR': {'pt': 'Croácia', 'en': 'Croatia'},
  'HU': {'pt': 'Hungria', 'en': 'Hungary'},
  'ID': {'pt': 'Indonésia', 'en': 'Indonesia'},
  'IE': {'pt': 'Irlanda', 'en': 'Ireland'},
  'IL': {'pt': 'Israel', 'en': 'Israel'},
  'IN': {'pt': 'Índia', 'en': 'India'},
  'IT': {'pt': 'Itália', 'en': 'Italy'},
  'JP': {'pt': 'Japão', 'en': 'Japan'},
  'KR': {'pt': 'Coreia do Sul', 'en': 'South Korea'},
  'LT': {'pt': 'Lituânia', 'en': 'Lithuania'},
  'LV': {'pt': 'Letônia', 'en': 'Latvia'},
  'MX': {'pt': 'México', 'en': 'Mexico'},
  'MY': {'pt': 'Malásia', 'en': 'Malaysia'},
  'NL': {'pt': 'Holanda', 'en': 'Netherlands'},
  'NO': {'pt': 'Noruega', 'en': 'Norway'},
  'NZ': {'pt': 'Nova Zelândia', 'en': 'New Zealand'},
  'PH': {'pt': 'Filipinas', 'en': 'Philippines'},
  'PL': {'pt': 'Polônia', 'en': 'Poland'},
  'PT': {'pt': 'Portugal', 'en': 'Portugal'},
  'RO': {'pt': 'Romênia', 'en': 'Romania'},
  'RU': {'pt': 'Rússia', 'en': 'Russia'},
  'SA': {'pt': 'Arábia Saudita', 'en': 'Saudi Arabia'},
  'SE': {'pt': 'Suécia', 'en': 'Sweden'},
  'SG': {'pt': 'Singapura', 'en': 'Singapore'},
  'SI': {'pt': 'Eslovênia', 'en': 'Slovenia'},
  'SK': {'pt': 'Eslováquia', 'en': 'Slovakia'},
  'TH': {'pt': 'Tailândia', 'en': 'Thailand'},
  'TR': {'pt': 'Turquia', 'en': 'Turkey'},
  'TW': {'pt': 'Taiwan', 'en': 'Taiwan'},
  'UA': {'pt': 'Ucrânia', 'en': 'Ukraine'},
  'US': {'pt': 'EUA', 'en': 'US'},
  'VN': {'pt': 'Vietnã', 'en': 'Vietnam'},
  'ZA': {'pt': 'África do Sul', 'en': 'South Africa'},
};
