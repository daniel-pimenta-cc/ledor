import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '_linux_tts_shared.dart';
import 'tts_backend.dart';

/// Linux TTS backend speaking the SSIP protocol directly to the
/// `speech-dispatcher` daemon over a Unix socket.
///
/// Replaces the older [SpeechDispatcherBackend] (which spawned `spd-say` per
/// utterance). Each `spd-say` invocation cost ~50-100ms in process startup,
/// so chunk transitions had an audible gap. Holding a persistent socket
/// connection lets the daemon's internal queue handle back-to-back
/// utterances seamlessly — same outcome that `flutter_tts.setQueueMode(1)`
/// gives us on Android / iOS.
///
/// Word boundaries are emulated via a periodic timer (no INDEX_MARK
/// integration yet — see follow-ups in `docs/tts-mode.md`). Accuracy:
/// ±200ms across a long sentence, indistinguishable from the spd-say
/// backend.
class SpeechdSocketBackend implements TtsBackend {
  /// [socketPathOverride] bypasses [_resolveSocketPath] (which reads
  /// `Platform.environment` and fixed system paths) so tests can point the
  /// backend at a fake SSIP server socket. Production callers use the
  /// default.
  SpeechdSocketBackend({String? socketPathOverride})
      : _socketPathOverride = socketPathOverride;

  final String? _socketPathOverride;

  @override
  bool get canPipeline => true;

  Socket? _socket;
  StreamSubscription<String>? _lineSub;
  bool _initialised = false;

  /// Completer for the pending command response. SSIP is request/response
  /// over a single stream, so we only allow one outstanding command at a
  /// time — caller awaits each `_send` before issuing the next.
  Completer<_SsipResponse>? _pendingResponse;
  final List<String> _responseLines = [];

  TtsProgressHandler? _onProgress;
  VoidCallback? _onCompletion;
  void Function(String)? _onError;
  VoidCallback? _onStart;

  // Periodic word-boundary emitter for the active utterance.
  Timer? _wordTimer;
  List<int> _currentWordOffsets = const [];
  // Per-word delay multipliers — words ending in punctuation get extra
  // dwell time so the highlight doesn't run ahead of the TTS, which
  // pauses naturally at commas / full stops.
  List<double> _currentWordMultipliers = const [];
  int _currentWordCursor = 0;
  int _currentBasePeriodMs = 200;
  // Empirical WPM baseline for the current backend+voice, measured from
  // the previous utterance's BEGIN-to-END elapsed time / word count.
  // Per-voice cache so switching voices doesn't carry over a stale rate.
  // Null until we've completed at least one utterance, falling back to a
  // conservative neural-TTS-friendly default (~150 WPM at rate=1.0).
  final Map<String, double> _empiricalWpmPerVoice = {};
  DateTime? _utteranceStartedAt;

  // Latest settings; applied before each speak() so a settings change
  // reaches the daemon without us having to track dirty flags.
  double _rate = 1.0;
  double _pitch = 1.0;
  String _language = 'en-US';
  TtsVoice? _voice;
  String? _engineId;

  // Tracks the settings we already pushed so we don't re-send them on every
  // speak (cuts a few ms off each chunk).
  double? _appliedRate;
  double? _appliedPitch;
  String? _appliedLanguage;
  String? _appliedVoiceName;
  String? _appliedEngineId;

  @override
  Future<void> init() async {
    if (_initialised) return;
    final socketPath = _socketPathOverride ?? _resolveSocketPath();
    if (socketPath == null) {
      throw const TtsUnavailableException(
        'speech-dispatcher socket not found. Install and start the '
        'speech-dispatcher service (e.g. `sudo apt install speech-dispatcher` '
        'on Debian/Ubuntu, `sudo dnf install speech-dispatcher` on Fedora).',
      );
    }

    try {
      _socket = await Socket.connect(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
    } catch (e) {
      throw TtsUnavailableException(
        'Failed to connect to speech-dispatcher at $socketPath: $e',
      );
    }

    _lineSub = utf8.decoder
        .bind(_socket!)
        .transform(const LineSplitter())
        .listen(_onLine, onError: _onSocketError, onDone: _onSocketClosed);

    // Some daemon builds send a "208 OK CONNECTED" greeting; others don't.
    // We don't wait for it explicitly — the first command we send will
    // synchronise the pending-response state.

    final user =
        Platform.environment['USER'] ?? Platform.environment['USERNAME'] ?? 'user';
    await _send('SET SELF CLIENT_NAME $user:rsvp_reader:default');

    // Subscribe to 700-range events. Without this opt-in the daemon never
    // emits BEGIN/END/INDEX_MARK to this connection, so the word timer
    // wouldn't start and highlights would freeze the whole utterance.
    await _send('SET SELF NOTIFICATION ALL ON');

    _initialised = true;
  }

  String? _resolveSocketPath() {
    final runtimeDir = Platform.environment['XDG_RUNTIME_DIR'];
    if (runtimeDir != null && runtimeDir.isNotEmpty) {
      final p = '$runtimeDir/speech-dispatcher/speechd.sock';
      if (File(p).existsSync()) return p;
    }
    const fallback = '/var/run/speech-dispatcher/speechd.sock';
    if (File(fallback).existsSync()) return fallback;
    // Older daemons used /tmp.
    const oldFallback = '/tmp/speech-dispatcher/speechd.sock';
    if (File(oldFallback).existsSync()) return oldFallback;
    return null;
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    await init();
    try {
      final r = await _send('LIST SYNTHESIS_VOICES');
      if (r.code != 249) return const [];
      return _parseVoiceLines(r.lines);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<String>> getLanguages() async {
    final voices = await getVoices();
    final locales = <String>{for (final v in voices) v.locale};
    return locales.toList()..sort();
  }

  @override
  Future<List<TtsEngine>> getEngines() async {
    await init();
    try {
      final r = await _send('LIST OUTPUT_MODULES');
      if (r.code != 250) return const [];
      return _parseEngineLines(r.lines);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> setEngine(String engineId) async {
    _engineId = engineId.isEmpty ? null : engineId;
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
  Future<void> speak(
    String text,
    {TtsQueueMode mode = TtsQueueMode.flush}
  ) async {
    await init();
    if (text.isEmpty) {
      _onCompletion?.call();
      return;
    }

    // Flush mode cancels any in-flight + queued utterances; add mode lets
    // them play through. The daemon stitches consecutive SPEAK calls
    // together with no audible gap, so add-mode is what gives us
    // pipelining without process spawn costs.
    if (mode == TtsQueueMode.flush) {
      try {
        await _send('CANCEL ALL');
      } catch (_) {}
      _resetWordTimerState();
    }

    await _applyDirtySettings();

    // Pre-compute the word offsets for the timer-based progress callback.
    _currentWordOffsets = wordCharOffsets(text);
    _currentWordMultipliers = _computeWordMultipliers(text);
    _currentWordCursor = 0;

    // SSIP SPEAK takes the text as a "data block" terminated by a single "."
    // on its own line. To send a literal "." at the start of a line we'd
    // double it; most utterances won't have that pattern.
    final escapedText = _escapeForSpeak(text);
    final payload = 'SPEAK\r\n$escapedText\r\n.';
    try {
      await _send(payload);
    } catch (e) {
      _onError?.call('SSIP SPEAK failed: $e');
      return;
    }
    // The daemon will fire 701 BEGIN soon — _handleEvent picks that up and
    // calls _onStart + starts the word timer.
  }

  Future<void> _applyDirtySettings() async {
    if (_engineId != _appliedEngineId) {
      final eng = _engineId;
      if (eng != null && eng.isNotEmpty) {
        await _send('SET SELF OUTPUT_MODULE $eng');
      }
      _appliedEngineId = _engineId;
    }
    if (_language != _appliedLanguage) {
      await _send('SET SELF LANGUAGE $_language');
      _appliedLanguage = _language;
    }
    final voiceName = _voice?.name;
    if (voiceName != _appliedVoiceName) {
      if (voiceName != null && voiceName.isNotEmpty) {
        await _send('SET SELF SYNTHESIS_VOICE $voiceName');
      }
      _appliedVoiceName = voiceName;
    }
    if (_rate != _appliedRate) {
      final spdRate = ((_rate - 1.0) * 50).round().clamp(-100, 100);
      await _send('SET SELF RATE $spdRate');
      _appliedRate = _rate;
    }
    if (_pitch != _appliedPitch) {
      final spdPitch = ((_pitch - 1.0) * 50).round().clamp(-100, 100);
      await _send('SET SELF PITCH $spdPitch');
      _appliedPitch = _pitch;
    }
  }

  @override
  Future<void> stop() async {
    if (!_initialised) return;
    _resetWordTimerState();
    try {
      await _send('CANCEL ALL');
    } catch (_) {
      // Caller doesn't care if cancel fails — they're shutting down anyway.
    }
  }

  @override
  Future<void> dispose() async {
    _resetWordTimerState();
    try {
      if (_initialised) await _send('QUIT');
    } catch (_) {}
    await _lineSub?.cancel();
    _lineSub = null;
    _socket?.destroy();
    _socket = null;
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

  // ---------- Internals ----------

  /// Sends a command and awaits its response. Caller is responsible for
  /// not interleaving sends — SSIP doesn't multiplex requests.
  Future<_SsipResponse> _send(String command) {
    final socket = _socket;
    if (socket == null) {
      return Future.error(
          StateError('SpeechdSocketBackend not initialised'));
    }
    if (_pendingResponse != null) {
      return Future.error(
          StateError('SpeechdSocketBackend has an outstanding command'));
    }
    final completer = Completer<_SsipResponse>();
    _pendingResponse = completer;
    socket.add(utf8.encode('$command\r\n'));
    // SSIP commands on a healthy localhost daemon return in < 10ms.
    // A 1s timeout still leaves a 100× safety margin while shrinking the
    // window in which a stale response could arrive after timeout and
    // race a newly-issued command. There IS a residual race: if cmd A
    // times out while still emitting partial responses, those late
    // lines can complete cmd B with the wrong payload (no way to tag
    // lines on the wire — the SSIP protocol has no request id). Low
    // probability on a working daemon; if it happens, the caller sees
    // a malformed list parsing result and retries on the next sync.
    return completer.future.timeout(
      const Duration(seconds: 1),
      onTimeout: () {
        _pendingResponse = null;
        _responseLines.clear();
        return _SsipResponse(0, const [], 'timeout');
      },
    );
  }

  void _onLine(String line) {
    if (line.isEmpty) return;
    // Format: "XXX[-| ]text" where XXX is the 3-digit code; "-" marks an
    // intermediate response line, " " (space) marks the terminal line.
    if (line.length < 4) return;
    final code = int.tryParse(line.substring(0, 3));
    if (code == null) return;
    final separator = line[3];
    final body = line.length > 4 ? line.substring(4) : '';

    if (code >= 700 && code < 800) {
      // 700-range events arrive as a multi-line block: leading lines carry
      // metadata (msg_id, client_id) with the `-` continuation separator,
      // then a single terminal line (` ` separator) holds the human label
      // (BEGIN/END/...). Acting on the metadata lines would fire the
      // handler three times per event and start the word timer twice
      // before the real BEGIN arrives.
      if (separator == ' ') _handleEvent(code, body);
      return;
    }

    final pending = _pendingResponse;
    if (pending == null) return;
    if (separator == '-') {
      _responseLines.add(body);
    } else {
      pending.complete(
          _SsipResponse(code, _responseLines.toList(), body));
      _responseLines.clear();
      _pendingResponse = null;
    }
  }

  void _handleEvent(int code, String body) {
    switch (code) {
      case 701: // BEGIN
        _utteranceStartedAt = DateTime.now();
        _startWordTimer();
        _onStart?.call();
        break;
      case 702: // END
        _captureEmpiricalWpm();
        _stopWordTimer();
        _flushRemainingWordCallbacks();
        _onCompletion?.call();
        break;
      case 703: // INDEX_MARK <name>
        // No marks emitted by us yet — leave for future SSML integration.
        break;
      case 704: // CANCEL
        _resetWordTimerState();
        // Don't fire completion: caller initiated the cancel.
        break;
      case 705: // PAUSE
      case 706: // RESUME
        // Not used (engine pauses by cancelling + re-speaking).
        break;
    }
  }

  void _startWordTimer() {
    _wordTimer?.cancel();
    if (_currentWordOffsets.isEmpty) return;
    // Baseline derived from the last measured utterance for this voice.
    // Falls back to 150 WPM — closer to neural backends (Piper, RHVoice)
    // than the 200 WPM that flutter_tts averages, so the very first
    // utterance doesn't run badly ahead of the audio.
    final voiceKey = _voice?.name ?? '';
    final baselineAtRateOne = _empiricalWpmPerVoice[voiceKey] ?? 150.0;
    final effectiveWpm = (baselineAtRateOne * _rate).clamp(60, 800);
    _currentBasePeriodMs = (60000.0 / effectiveWpm).clamp(80, 2000).round();
    _scheduleNextWord();
  }

  void _scheduleNextWord() {
    if (_currentWordCursor >= _currentWordOffsets.length) {
      _wordTimer = null;
      return;
    }
    final mult = _currentWordCursor < _currentWordMultipliers.length
        ? _currentWordMultipliers[_currentWordCursor]
        : 1.0;
    final delayMs = (_currentBasePeriodMs * mult).round();
    _wordTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_currentWordCursor >= _currentWordOffsets.length) {
        _wordTimer = null;
        return;
      }
      final offset = _currentWordOffsets[_currentWordCursor];
      _onProgress?.call(offset, offset, '');
      _currentWordCursor++;
      _scheduleNextWord();
    });
  }

  void _stopWordTimer() {
    _wordTimer?.cancel();
    _wordTimer = null;
  }

  /// Updates the per-voice WPM cache from the just-ended utterance. We
  /// divide back out the current rate so the cached value is comparable
  /// across rate changes (cache holds the baseline at rate=1.0).
  void _captureEmpiricalWpm() {
    final started = _utteranceStartedAt;
    _utteranceStartedAt = null;
    if (started == null) return;
    final wordCount = _currentWordOffsets.length;
    if (wordCount < 5) return; // too few words to be statistically useful
    final elapsedMs = DateTime.now().difference(started).inMilliseconds;
    if (elapsedMs < 500) return; // implausibly fast — likely a cancel race
    final wpm = (wordCount * 60000.0) / elapsedMs;
    if (_rate <= 0) return;
    final baseline = wpm / _rate;
    final voiceKey = _voice?.name ?? '';
    // Light low-pass: 70% old, 30% new. Smooths out one-off noise (e.g. a
    // single short utterance with long initial silence) without losing
    // responsiveness when the user actually switches voices.
    final prev = _empiricalWpmPerVoice[voiceKey];
    final smoothed = prev == null ? baseline : (prev * 0.7 + baseline * 0.3);
    _empiricalWpmPerVoice[voiceKey] = smoothed.clamp(60.0, 800.0);
  }

  void _flushRemainingWordCallbacks() {
    if (_currentWordOffsets.isEmpty) return;
    if (_currentWordCursor < _currentWordOffsets.length) {
      final last = _currentWordOffsets.last;
      _onProgress?.call(last, last, '');
    }
    _currentWordOffsets = const [];
    _currentWordCursor = 0;
  }

  void _resetWordTimerState() {
    _stopWordTimer();
    _currentWordOffsets = const [];
    _currentWordMultipliers = const [];
    _currentWordCursor = 0;
  }

  /// Computes a per-word dwell multiplier from the utterance text. Words
  /// ending in punctuation get a longer dwell so the highlight tracks the
  /// natural pause the TTS produces. Order matches [wordCharOffsets] so
  /// the cursor index can index either list directly.
  static List<double> _computeWordMultipliers(String text) {
    final mult = <double>[];
    bool inWord = false;
    int? lastNonSpaceIdx;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      final isSpace = ch == ' ' || ch == '\n' || ch == '\t';
      if (!isSpace) {
        if (!inWord) inWord = true;
        lastNonSpaceIdx = i;
      } else if (inWord) {
        mult.add(_dwellMultiplierForLastChar(text[lastNonSpaceIdx!]));
        inWord = false;
      }
    }
    if (inWord && lastNonSpaceIdx != null) {
      mult.add(_dwellMultiplierForLastChar(text[lastNonSpaceIdx]));
    }
    return mult;
  }

  static double _dwellMultiplierForLastChar(String ch) {
    switch (ch) {
      case ',':
        return 1.6;
      case ';':
      case ':':
        return 1.9;
      case '.':
      case '!':
      case '?':
        return 2.4;
      case ')':
      case ']':
      case '"':
      case '”': // right double quote
        return 1.3;
      default:
        return 1.0;
    }
  }

  void _onSocketError(Object error) {
    _failPendingResponse('socket error: $error');
    _onError?.call('speech-dispatcher socket error: $error');
  }

  void _onSocketClosed() {
    _failPendingResponse('socket closed');
    _onError?.call('speech-dispatcher socket closed unexpectedly');
    _initialised = false;
    _socket = null;
    _lineSub = null;
  }

  /// Rejects any in-flight `_send` so its `await` returns immediately
  /// instead of hanging on the 5s timeout, then clears the accumulated
  /// response state. Idempotent.
  void _failPendingResponse(String reason) {
    final pending = _pendingResponse;
    if (pending == null) return;
    _pendingResponse = null;
    _responseLines.clear();
    if (!pending.isCompleted) {
      pending.completeError(StateError(reason));
    }
  }

  // ---------- Testing hooks ----------

  @visibleForTesting
  static String escapeForSpeakForTest(String text) => _escapeForSpeak(text);

  @visibleForTesting
  static List<TtsEngine> parseEngineLinesForTest(List<String> lines) =>
      _parseEngineLines(lines);

  @visibleForTesting
  static List<TtsVoice> parseVoiceLinesForTest(List<String> lines) =>
      _parseVoiceLines(lines);

  @visibleForTesting
  static List<int> wordCharOffsetsForTest(String text) =>
      wordCharOffsets(text);
}

class _SsipResponse {
  final int code;
  final List<String> lines;
  final String terminalLine;

  _SsipResponse(this.code, this.lines, this.terminalLine);
}

/// Escapes a payload for the SPEAK data block. A literal `.` on its own
/// line would terminate the block, so we double-dot any such occurrence.
String _escapeForSpeak(String text) {
  // Split on real line breaks; any line consisting solely of "." gets a
  // leading dot added (SSIP dot-stuffing rule).
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (lines[i] == '.') lines[i] = '..';
  }
  return lines.join('\r\n');
}

/// Parses the multi-line body of `LIST SYNTHESIS_VOICES`. Each line is a
/// tab-separated `NAME\tLANGUAGE\tVARIANT` triple.
List<TtsVoice> _parseVoiceLines(List<String> lines) {
  final voices = <TtsVoice>[];
  for (final raw in lines) {
    final cols = raw.split('\t');
    if (cols.length < 2) continue;
    final name = cols[0].trim();
    final locale = cols[1].trim();
    final variant = cols.length >= 3 ? cols[2].trim() : null;
    if (name.isEmpty || locale.isEmpty) continue;
    voices.add(TtsVoice(name: name, locale: locale, gender: variant));
  }
  return voices;
}

/// Parses the multi-line body of `LIST OUTPUT_MODULES`. Each non-empty
/// line is a module id.
List<TtsEngine> _parseEngineLines(List<String> lines) {
  final engines = <TtsEngine>[];
  for (final raw in lines) {
    final id = raw.trim();
    if (id.isEmpty) continue;
    engines.add(speechdModuleAsEngine(id));
  }
  return engines;
}

