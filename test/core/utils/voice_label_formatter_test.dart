import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/utils/voice_label_formatter.dart';
import 'package:ledor/features/rsvp_reader/data/services/tts_backend.dart';

TtsVoice _voice({
  required String name,
  required String locale,
  String? gender,
}) =>
    TtsVoice(name: name, locale: locale, gender: gender);

void main() {
  group('localeDisplayName', () {
    test('renders language + region in English UI', () {
      expect(localeDisplayName('en-GB', 'en'), 'English (UK)');
      expect(localeDisplayName('pt-BR', 'en'), 'Portuguese (Brazil)');
      expect(localeDisplayName('zh-CN', 'en'), 'Chinese (China)');
    });

    test('renders language + region in Portuguese UI', () {
      expect(localeDisplayName('en-GB', 'pt'), 'Inglês (Reino Unido)');
      expect(localeDisplayName('pt-BR', 'pt'), 'Português (Brasil)');
      expect(localeDisplayName('de-DE', 'pt'), 'Alemão (Alemanha)');
    });

    test('returns only the language when no region is given', () {
      expect(localeDisplayName('en', 'en'), 'English');
      expect(localeDisplayName('pt', 'pt'), 'Português');
    });

    test('accepts underscore separators (Android-style locales)', () {
      expect(localeDisplayName('pt_BR', 'pt'), 'Português (Brasil)');
    });

    test('falls back to the raw code when the language is unknown', () {
      expect(localeDisplayName('xx-YY', 'en'), 'xx-YY');
    });

    test('falls back to the raw region code when only the region is unknown',
        () {
      expect(localeDisplayName('en-ZZ', 'en'), 'English (ZZ)');
    });

    test('treats an unknown UI language as English', () {
      expect(localeDisplayName('en-GB', 'xx'), 'English (UK)');
    });
  });

  group('inferGender', () {
    test('reads the voice.gender field when present (female / male)', () {
      expect(inferGender(_voice(name: 'x', locale: 'en-US', gender: 'female')),
          'female');
      expect(inferGender(_voice(name: 'x', locale: 'en-US', gender: 'male')),
          'male');
    });

    test('normalises capitalisation and short forms', () {
      expect(
          inferGender(_voice(name: 'x', locale: 'en-US', gender: 'F')), 'female');
      expect(inferGender(_voice(name: 'x', locale: 'en-US', gender: 'MALE')),
          'male');
    });

    test('detects gender from name patterns', () {
      expect(
        inferGender(_voice(name: 'samsung-tts-en-us-female', locale: 'en-US')),
        'female',
      );
      expect(
        inferGender(_voice(name: 'samsung-tts-en-us-male', locale: 'en-US')),
        'male',
      );
    });

    test('returns null when nothing is recognised', () {
      expect(
        inferGender(_voice(name: 'en-gb-x-fis-local', locale: 'en-GB')),
        isNull,
      );
    });

    test('female test wins over the male substring', () {
      // "female" contains "male" as a substring — the implementation must
      // test female first to avoid mislabelling.
      expect(
        inferGender(_voice(name: 'voice_female_01', locale: 'en-US')),
        'female',
      );
    });
  });

  group('formatVoice', () {
    test('friendly iOS name is shown as the primary label', () {
      final v = _voice(name: 'Samantha', locale: 'en-US', gender: 'female');
      final f = formatVoice(v, 'en');
      expect(f.primary, 'Samantha');
      expect(f.secondary, 'English (US) · Female');
      expect(f.techDetail, isNull);
    });

    test('friendly name with parenthesised qualifier still counts as friendly',
        () {
      final v = _voice(
          name: 'Samantha (Enhanced)', locale: 'en-US', gender: 'female');
      final f = formatVoice(v, 'en');
      expect(f.primary, 'Samantha (Enhanced)');
      expect(f.techDetail, isNull);
    });

    test('Android technical id maps to "Locale - Gender" with tech detail',
        () {
      final v = _voice(name: 'en-gb-x-fis-network', locale: 'en-GB');
      final f = formatVoice(v, 'en');
      expect(f.primary, 'English (UK)');
      // Gender not in the gender field — pattern inference won't catch
      // Google's `fis` code, so secondary stays null.
      expect(f.secondary, isNull);
      expect(f.techDetail, 'en-gb-x-fis-network');
    });

    test('serial gets appended to the gender label for tech names', () {
      final v = _voice(
        name: 'samsung-tts-en-us-female-1',
        locale: 'en-US',
        gender: 'female',
      );
      final f = formatVoice(v, 'en', variantSerial: 2);
      expect(f.primary, 'English (US)');
      expect(f.secondary, 'Female 2');
      expect(f.techDetail, 'samsung-tts-en-us-female-1');
    });

    test('serial without a gender uses the "Voice N" fallback (en)', () {
      final v = _voice(name: 'en-gb-x-fis-local', locale: 'en-GB');
      final f = formatVoice(v, 'en', variantSerial: 3);
      expect(f.secondary, 'Voice 3');
    });

    test('Portuguese gender labels', () {
      final v = _voice(name: 'pt-br-x-afs-network', locale: 'pt-BR', gender: 'female');
      final f = formatVoice(v, 'pt', variantSerial: 1);
      expect(f.primary, 'Português (Brasil)');
      expect(f.secondary, 'Feminina 1');
    });

    test('localeGroupName matches the locale display name', () {
      final v = _voice(name: 'en-us-x-tpf-local', locale: 'en-US');
      final f = formatVoice(v, 'pt');
      expect(f.localeGroupName, 'Inglês (EUA)');
      expect(f.localeGroupSortKey, 'en-us');
    });
  });

  group('enrichVoices', () {
    test('assigns serial numbers only when multiple voices share a group', () {
      final voices = [
        _voice(name: 'en-us-x-tpf-local', locale: 'en-US', gender: 'female'),
        _voice(name: 'en-us-x-tpf-network', locale: 'en-US', gender: 'female'),
        _voice(name: 'en-us-x-tpc-network', locale: 'en-US', gender: 'male'),
      ];
      final enriched = enrichVoices(voices, 'en');
      expect(enriched, hasLength(3));
      // Two female voices share a group → both get serials.
      expect(enriched[0].label.secondary, 'Female 1');
      expect(enriched[1].label.secondary, 'Female 2');
      // The single male voice doesn't need numbering.
      expect(enriched[2].label.secondary, 'Male');
    });

    test('friendly names don\'t get serial numbers (the name already disambiguates)',
        () {
      final voices = [
        _voice(name: 'Samantha', locale: 'en-US', gender: 'female'),
        _voice(name: 'Karen', locale: 'en-US', gender: 'female'),
      ];
      final enriched = enrichVoices(voices, 'en');
      expect(enriched[0].label.primary, 'Samantha');
      expect(enriched[0].label.secondary, 'English (US) · Female');
      expect(enriched[1].label.primary, 'Karen');
      expect(enriched[1].label.secondary, 'English (US) · Female');
    });

    test('search haystack includes everything searchable', () {
      final enriched = enrichVoices(
        [_voice(name: 'en-gb-x-fis-network', locale: 'en-GB')],
        'pt',
      );
      final hay = enriched.first.searchHaystack;
      expect(hay, contains('inglês'));
      expect(hay, contains('reino unido'));
      expect(hay, contains('en-gb-x-fis-network'));
      expect(hay, contains('en-gb'));
    });

    test('primaryLanguage strips the region for filter grouping', () {
      final enriched = enrichVoices(
        [
          _voice(name: 'a', locale: 'pt-BR'),
          _voice(name: 'b', locale: 'pt-PT'),
          _voice(name: 'c', locale: 'EN_us'),
        ],
        'en',
      );
      expect(enriched[0].primaryLanguage, 'pt');
      expect(enriched[1].primaryLanguage, 'pt');
      expect(enriched[2].primaryLanguage, 'en');
    });
  });
}
