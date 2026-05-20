import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'tts_backend.dart';

/// Linux desktop backend on top of `spd-say` (speech-dispatcher CLI).
///
/// `spd-say` is the CLI front-end to the `speech-dispatcher` daemon shipped
/// with almost every desktop Linux distribution (GNOME / KDE both rely on it
/// for screen-reader accessibility). It accepts text on the command line,
/// blocks until the audio finishes when invoked with `-w`, and exposes
/// rate/pitch/voice via flags.
///
/// **Limitations vs flutter_tts**:
/// - No native word-boundary callbacks. We emulate them with a
///   `Timer.periodic` paced at the configured WPM so the scroll highlight
///   tracks the narration to within ~200ms.
/// - No real pause: a mid-sentence stop is unrecoverable, so the engine
///   re-speaks from the current globalWordIndex on resume.
class SpeechDispatcherBackend implements TtsBackend {
  Process? _current;
  Timer? _wordTimer;
  bool _initialised = false;

  // Latest configured values; applied on the next speak() since spd-say
  // takes them as flags per invocation.
  double _rate = 1.0;
  double _pitch = 1.0;
  String _language = 'en-US';
  TtsVoice? _voice;

  // Filled by speak() so the periodic timer can stride through the words
  // of the current utterance, computing approximate progress charOffsets.
  List<int> _currentWordCharOffsets = const [];
  int _currentWordCursor = 0;

  TtsProgressHandler? _onProgress;
  VoidCallback? _onCompletion;
  void Function(String)? _onError;
  VoidCallback? _onStart;

  @override
  Future<void> init() async {
    if (_initialised) return;
    final which = await Process.run('which', ['spd-say']);
    if (which.exitCode != 0) {
      throw const TtsUnavailableException(
        'spd-say not found on PATH. Install the speech-dispatcher '
        'package (e.g. `sudo apt install speech-dispatcher` on Debian/Ubuntu, '
        '`sudo dnf install speech-dispatcher` on Fedora).',
      );
    }
    _initialised = true;
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    await init();
    try {
      final r = await Process.run('spd-say', ['-L']);
      if (r.exitCode != 0) return const [];
      return _parseVoiceList(r.stdout.toString());
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<String>> getLanguages() async {
    // spd-say doesn't expose a clean languages list; derive from voices.
    final voices = await getVoices();
    final locales = <String>{for (final v in voices) v.locale};
    return locales.toList()..sort();
  }

  @override
  Future<void> setVoice(TtsVoice? voice) async {
    _voice = voice;
  }

  @override
  Future<void> setLanguage(String iso) async {
    _language = iso;
  }

  @override
  Future<void> setRate(double rate) async {
    _rate = rate;
  }

  @override
  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
  }

  @override
  Future<void> speak(String text) async {
    await init();
    await stop();

    if (text.isEmpty) {
      _onCompletion?.call();
      return;
    }

    // Map rate ([0.3..2.5], 1.0 = default ~200 WPM) to spd-say's
    // [-100, +100] integer scale. Each ~0.02 of relative rate corresponds
    // to one spd-say step.
    final spdRate = ((_rate - 1.0) * 50).round().clamp(-100, 100);
    final spdPitch = ((_pitch - 1.0) * 50).round().clamp(-100, 100);

    final args = <String>[
      '-w', // wait until the message has been spoken
      '-r', '$spdRate',
      '-p', '$spdPitch',
      '-l', _language,
    ];
    final voice = _voice;
    if (voice != null && voice.name.isNotEmpty) {
      args
        ..add('-y')
        ..add(voice.name);
    }
    args.add(text);

    _setupWordTimer(text);
    _onStart?.call();

    try {
      _current = await Process.start('spd-say', args);
    } catch (e) {
      _wordTimer?.cancel();
      _wordTimer = null;
      _onError?.call('Failed to spawn spd-say: $e');
      return;
    }

    final process = _current!;
    unawaited(process.exitCode.then((code) {
      _wordTimer?.cancel();
      _wordTimer = null;
      if (!identical(_current, process)) return; // was cancelled by stop()
      _current = null;
      if (code == 0) {
        // Flush any remaining word callbacks so the highlight lands on the
        // last token before the listener hears completion.
        _flushRemainingWordCallbacks();
        _onCompletion?.call();
      } else {
        _onError?.call('spd-say exited with code $code');
      }
    }));
  }

  void _setupWordTimer(String text) {
    // Pre-compute the char offset of each whitespace-delimited word in the
    // utterance. These are the points the periodic timer will emit
    // progress for; cadence comes from the configured rate.
    _currentWordCharOffsets = _wordCharOffsets(text);
    _currentWordCursor = 0;
    if (_currentWordCharOffsets.isEmpty) return;

    // Effective WPM = nominal 200 × rate. Period = 60000/wpm milliseconds.
    final effectiveWpm = (200 * _rate).clamp(60, 800);
    final periodMs = (60000.0 / effectiveWpm).clamp(80, 2000).round();

    _wordTimer = Timer.periodic(Duration(milliseconds: periodMs), (t) {
      if (_currentWordCursor >= _currentWordCharOffsets.length) {
        t.cancel();
        return;
      }
      final offset = _currentWordCharOffsets[_currentWordCursor];
      _onProgress?.call(offset, offset, '');
      _currentWordCursor++;
    });
  }

  void _flushRemainingWordCallbacks() {
    if (_currentWordCharOffsets.isEmpty) return;
    final last = _currentWordCharOffsets.last;
    if (_currentWordCursor < _currentWordCharOffsets.length) {
      _onProgress?.call(last, last, '');
    }
    _currentWordCharOffsets = const [];
    _currentWordCursor = 0;
  }

  @override
  Future<void> stop() async {
    final timer = _wordTimer;
    _wordTimer = null;
    timer?.cancel();
    _currentWordCharOffsets = const [];
    _currentWordCursor = 0;

    final p = _current;
    _current = null;
    if (p == null) return;
    p.kill(ProcessSignal.sigterm);
    try {
      await p.exitCode.timeout(const Duration(milliseconds: 500));
    } catch (_) {
      // Process didn't exit in time. SIGKILL it.
      try {
        p.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    _onProgress = null;
    _onCompletion = null;
    _onError = null;
    _onStart = null;
    _initialised = false;
  }

  @override
  set onProgress(TtsProgressHandler? cb) => _onProgress = cb;

  @override
  set onCompletion(VoidCallback? cb) => _onCompletion = cb;

  @override
  set onError(void Function(String error)? cb) => _onError = cb;

  @override
  set onStart(VoidCallback? cb) => _onStart = cb;

  // ---------- Helpers (visible for testing) ----------

  /// Returns the starting char offset of each whitespace-delimited word in
  /// [text]. Used by the periodic timer to emit progress callbacks.
  @visibleForTesting
  static List<int> wordCharOffsetsForTest(String text) =>
      _wordCharOffsets(text);

  /// Parses the `spd-say -L` output. The output has a 2-line header
  /// followed by columns: `NAME LANGUAGE VARIANT`. Returns an empty list
  /// when the format isn't recognised — the UI shows "no voices" then.
  @visibleForTesting
  static List<TtsVoice> parseVoiceListForTest(String stdout) =>
      _parseVoiceList(stdout);
}

List<int> _wordCharOffsets(String text) {
  final offsets = <int>[];
  bool inWord = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    final isSpace = ch == ' ' || ch == '\n' || ch == '\t';
    if (!isSpace && !inWord) {
      offsets.add(i);
      inWord = true;
    } else if (isSpace) {
      inWord = false;
    }
  }
  return offsets;
}

List<TtsVoice> _parseVoiceList(String stdout) {
  final voices = <TtsVoice>[];
  final lines = stdout.split('\n');
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    // Skip headers and underline rows.
    final lower = line.toLowerCase();
    if (lower.startsWith('name') ||
        lower.startsWith('there are') ||
        lower.startsWith('output module') ||
        line.startsWith('-')) {
      continue;
    }
    // Columns split by 2+ spaces (spd-say pads with spaces).
    final cols = line.split(RegExp(r'\s{2,}'));
    if (cols.length < 2) continue;
    final name = cols[0].trim();
    final locale = cols[1].trim();
    final gender = cols.length >= 3 ? cols[2].trim() : null;
    if (name.isEmpty || locale.isEmpty) continue;
    voices.add(TtsVoice(name: name, locale: locale, gender: gender));
  }
  return voices;
}
