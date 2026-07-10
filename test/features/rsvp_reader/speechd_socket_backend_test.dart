import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/features/rsvp_reader/data/services/speechd_socket_backend.dart';
import 'package:ledor/features/rsvp_reader/data/services/tts_backend.dart';

/// Minimal fake speech-dispatcher speaking just enough SSIP for the backend:
/// - replies a 2xx terminal line to every command;
/// - treats `SPEAK` as a data block terminated by a lone `.` (one reply for
///   the whole block, mirroring the daemon);
/// - serves multi-line `249-`/`250-` bodies for the LIST commands;
/// - can push 700-range event blocks (`701-meta` lines + `701 BEGIN`
///   terminal) to the connected client.
///
/// Every received line is recorded in [received] in arrival order. Because
/// the backend awaits each command's response before returning, assertions
/// on [received] after an awaited backend call are deterministic — no
/// sleeps needed.
class FakeSsipServer {
  FakeSsipServer._(this._dir, this._server, this.socketPath);

  final Directory _dir;
  final ServerSocket _server;
  final String socketPath;

  final List<String> received = [];
  Socket? _client;
  bool _inSpeakBlock = false;

  List<String> voiceRows = const ['robert\ten-GB\tmale1'];
  List<String> moduleRows = const ['espeak-ng', 'piper'];

  static Future<FakeSsipServer> start() async {
    // systemTemp (not the test scratchpad) on purpose: AF_UNIX socket paths
    // are capped at ~108 chars and the scratchpad path alone nearly fills
    // that budget.
    final dir = await Directory.systemTemp.createTemp('ssip_test');
    final path = '${dir.path}/speechd.sock';
    final server = await ServerSocket.bind(
      InternetAddress(path, type: InternetAddressType.unix),
      0,
    );
    final fake = FakeSsipServer._(dir, server, path);
    server.listen(fake._onClient);
    return fake;
  }

  void _onClient(Socket client) {
    _client = client;
    utf8.decoder
        .bind(client)
        .transform(const LineSplitter())
        .listen(_onLine, onError: (_) {});
  }

  void _onLine(String line) {
    received.add(line);
    if (_inSpeakBlock) {
      if (line == '.') {
        _inSpeakBlock = false;
        _reply('225-42');
        _reply('225 OK MESSAGE QUEUED');
      }
      return; // data-block body lines get no per-line reply
    }
    if (line == 'SPEAK') {
      _inSpeakBlock = true;
      return;
    }
    if (line == 'LIST SYNTHESIS_VOICES') {
      for (final row in voiceRows) {
        _reply('249-$row');
      }
      _reply('249 OK VOICE LIST SENT');
      return;
    }
    if (line == 'LIST OUTPUT_MODULES') {
      for (final row in moduleRows) {
        _reply('250-$row');
      }
      _reply('250 OK MODULE LIST SENT');
      return;
    }
    if (line == 'QUIT') {
      _reply('231 HAPPY HACKING');
      return;
    }
    _reply('200 OK'); // generic success; the backend ignores 2xx codes here
  }

  /// Pushes raw event lines (e.g. `701-42`, `701 BEGIN`) to the client.
  void sendEvent(List<String> lines) {
    for (final l in lines) {
      _reply(l);
    }
  }

  /// Drops the current client connection (simulates a daemon restart —
  /// the server socket keeps listening for the reconnect).
  void dropClient() {
    _client?.destroy();
    _client = null;
  }

  void _reply(String line) => _client!.add(utf8.encode('$line\r\n'));

  int countOf(String line) => received.where((l) => l == line).length;

  Future<void> close() async {
    await _server.close();
    _client?.destroy();
    if (_dir.existsSync()) await _dir.delete(recursive: true);
  }
}

void main() {
  late FakeSsipServer server;
  late SpeechdSocketBackend backend;

  setUp(() async {
    server = await FakeSsipServer.start();
    backend = SpeechdSocketBackend(socketPathOverride: server.socketPath);
  });

  tearDown(() async {
    await backend.dispose(); // safe when never initialised
    await server.close();
  });

  test('escapeForSpeak dot-stuffs lines consisting of a single "."', () {
    expect(
      SpeechdSocketBackend.escapeForSpeakForTest('a\n.\nb'),
      'a\r\n..\r\nb',
    );
    expect(SpeechdSocketBackend.escapeForSpeakForTest('plain'), 'plain');
  });

  group('init', () {
    test('handshake sends CLIENT_NAME then NOTIFICATION ALL ON', () async {
      await backend.init();

      final clientNameIdx = server.received
          .indexWhere((l) => l.startsWith('SET SELF CLIENT_NAME '));
      expect(clientNameIdx, isNot(-1),
          reason: 'handshake must identify the client');
      expect(server.received[clientNameIdx], endsWith(':rsvp_reader:default'));

      final notificationIdx =
          server.received.indexOf('SET SELF NOTIFICATION ALL ON');
      expect(notificationIdx, isNot(-1),
          reason: 'without the notification opt-in the daemon never emits '
              'BEGIN/END and highlights would freeze');
      expect(clientNameIdx, lessThan(notificationIdx));

      // init() is idempotent — second call must not re-handshake.
      final lineCount = server.received.length;
      await backend.init();
      expect(server.received.length, lineCount);
    });

    test('throws TtsUnavailableException when the socket does not exist',
        () async {
      final missing = SpeechdSocketBackend(
        socketPathOverride:
            '${Directory.systemTemp.path}/ssip-missing-${DateTime.now().microsecondsSinceEpoch}/speechd.sock',
      );
      await expectLater(
        missing.init(),
        throwsA(isA<TtsUnavailableException>()),
      );
    });
  });

  group('speak', () {
    test('applies settings before SPEAK and sends the dot-terminated block',
        () async {
      await backend.init();
      await backend.setEngine('espeak-ng');
      await backend.setLanguage('pt-BR');
      await backend.setVoice(const TtsVoice(name: 'pt-voice', locale: 'pt'));
      await backend.setRate(1.5); // (1.5 - 1.0) * 50 = 25
      await backend.setPitch(1.2); // (1.2 - 1.0) * 50 = 10

      await backend.speak('Hello world');

      expect(server.received, contains('CANCEL ALL')); // flush mode
      expect(server.received, contains('SET SELF OUTPUT_MODULE espeak-ng'));
      expect(server.received, contains('SET SELF LANGUAGE pt-BR'));
      expect(server.received, contains('SET SELF SYNTHESIS_VOICE pt-voice'));
      expect(server.received, contains('SET SELF RATE 25'));
      expect(server.received, contains('SET SELF PITCH 10'));

      final speakIdx = server.received.indexOf('SPEAK');
      expect(speakIdx, isNot(-1));
      // Every SET must land before the SPEAK block.
      for (final set in server.received.where((l) => l.startsWith('SET SELF'))) {
        expect(server.received.indexOf(set), lessThan(speakIdx));
      }
      // Data block: text followed by the lone "." terminator.
      expect(server.received[speakIdx + 1], 'Hello world');
      expect(server.received[speakIdx + 2], '.');
    });

    test('dedups unchanged settings across speaks; re-sends on real change',
        () async {
      await backend.init();
      await backend.setLanguage('pt-BR');
      await backend.setRate(1.5);
      await backend.setPitch(1.2);

      await backend.speak('Hello world');

      // Re-emit the exact same values (slider re-emitting) + speak again.
      await backend.setLanguage('pt-BR');
      await backend.setRate(1.5);
      await backend.setPitch(1.2);
      await backend.speak('Hello world');

      expect(server.countOf('SET SELF LANGUAGE pt-BR'), 1,
          reason: 'unchanged language must not be re-sent');
      expect(server.countOf('SET SELF RATE 25'), 1,
          reason: 'rate slider re-emitting the same value must not burn IPC');
      expect(server.countOf('SET SELF PITCH 10'), 1);
      expect(server.countOf('SPEAK'), 2);
      expect(server.countOf('CANCEL ALL'), 2);

      // An actual change must reach the daemon on the next speak.
      await backend.setRate(2.0);
      await backend.speak('Hello world');
      expect(server.countOf('SET SELF RATE 50'), 1);
    });

    test('re-applies settings on a fresh connection after the socket drops',
        () async {
      await backend.init();
      await backend.setLanguage('pt-BR');
      await backend.setVoice(const TtsVoice(name: 'pt-voice', locale: 'pt'));
      await backend.speak('Hello');
      expect(server.countOf('SET SELF LANGUAGE pt-BR'), 1);
      expect(server.countOf('SET SELF SYNTHESIS_VOICE pt-voice'), 1);

      // Daemon restart: connection drops; the backend must notice (onDone)
      // and the next speak must reconnect AND re-apply every setting — the
      // new daemon connection starts from defaults.
      server.dropClient();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await backend.speak('World');
      expect(server.countOf('SET SELF LANGUAGE pt-BR'), 2,
          reason: 'a reconnect must not trust the stale applied-snapshot — '
              'the daemon side reset to defaults');
      expect(server.countOf('SET SELF SYNTHESIS_VOICE pt-voice'), 2);
      expect(server.countOf('SPEAK'), 2);
    });

    test('add mode does not CANCEL the in-flight utterance', () async {
      await backend.init();
      await backend.speak('one two three', mode: TtsQueueMode.add);
      expect(server.received, isNot(contains('CANCEL ALL')));
      expect(server.countOf('SPEAK'), 1);
    });

    test('empty text completes immediately without a SPEAK', () async {
      var completions = 0;
      backend.onCompletion = () => completions++;
      await backend.speak('');
      expect(completions, 1);
      expect(server.countOf('SPEAK'), 0);
    });
  });

  group('SSIP events', () {
    test('702 END fires completion and flushes progress to the last word',
        () async {
      final completed = Completer<void>();
      final progressOffsets = <int>[];
      backend.onCompletion = () {
        if (!completed.isCompleted) completed.complete();
      };
      backend.onProgress = (offset, end, _) => progressOffsets.add(offset);

      await backend.speak('Hello world'); // word offsets: [0, 6]

      // Real daemons send event metadata lines (`-` separator) before the
      // terminal label line — only the terminal line may trigger handlers.
      server.sendEvent(['701-42', '701-1', '701 BEGIN']);
      server.sendEvent(['702-42', '702-1', '702 END']);
      await completed.future.timeout(const Duration(seconds: 5));

      // END flushes the remaining word callbacks up to the last offset.
      expect(progressOffsets, contains(6));
    });
  });

  test('stop() sends CANCEL ALL', () async {
    await backend.init();
    await backend.stop();
    expect(server.received, contains('CANCEL ALL'));
  });

  test('dispose() sends QUIT', () async {
    await backend.init();
    await backend.dispose();
    expect(server.received, contains('QUIT'));
  });

  group('LIST commands over the socket', () {
    test('getVoices parses the multi-line 249 response', () async {
      server.voiceRows = ['robert\ten-GB\tmale1', 'alice\tpt-BR\tfemale2'];
      final voices = await backend.getVoices();
      expect(voices, hasLength(2));
      expect(voices[0].name, 'robert');
      expect(voices[0].locale, 'en-GB');
      expect(voices[0].gender, 'male1');
      expect(voices[1].name, 'alice');
      expect(voices[1].locale, 'pt-BR');
    });

    test('getEngines parses the multi-line 250 response', () async {
      final engines = await backend.getEngines();
      expect(engines.map((e) => e.id), ['espeak-ng', 'piper']);
      expect(engines[0].displayName, 'eSpeak NG');
      expect(engines[1].displayName, 'Piper TTS');
    });
  });
}
