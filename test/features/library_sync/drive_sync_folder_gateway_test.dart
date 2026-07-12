import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as ga;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ledor/features/library_sync/data/gateways/drive_sync_folder_gateway.dart';

const _folderMime = 'application/vnd.google-apps.folder';

class _FakeFile {
  _FakeFile({required this.name, required this.parent, required this.bytes});
  String name;
  String parent;
  List<int> bytes;
}

/// In-memory Drive v3 REST fake served through a [MockClient]. Records every
/// request so tests can assert which endpoints were (not) hit — that's how
/// the fileId-cache contract is verified.
class FakeDrive {
  final requests = <http.Request>[];
  final folders = <String, ({String name, String parent})>{};
  final files = <String, _FakeFile>{};
  int _nextId = 0;

  /// While > 0, metadata GETs (files.get?fields=id) return 500 and decrement.
  int failMetadataGets = 0;

  late final String rootId = addFolder('drive-root', 'Ledor');

  String _newId() => 'id-${(_nextId++).toString().padLeft(3, '0')}';

  String addFolder(String parent, String name, {String? id}) {
    final fid = id ?? _newId();
    folders[fid] = (name: name, parent: parent);
    return fid;
  }

  String addFile(String parent, String name, List<int> bytes, {String? id}) {
    final fid = id ?? _newId();
    files[fid] = _FakeFile(name: name, parent: parent, bytes: bytes);
    return fid;
  }

  ga.AuthClient authClient() => ga.authenticatedClient(
        MockClient(_handle),
        ga.AccessCredentials(
          ga.AccessToken(
            'Bearer',
            'fake-token',
            DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
          null,
          const [],
        ),
      );

  /// files.list search queries (`GET /drive/v3/files?q=...`) — the expensive
  /// lookup the fileId cache exists to skip.
  int get searchQueries => requests
      .where((r) =>
          r.method == 'GET' &&
          r.url.path == '/drive/v3/files' &&
          r.url.queryParameters.containsKey('q'))
      .length;

  int get mediaDownloads => requests
      .where((r) =>
          r.method == 'GET' && r.url.queryParameters['alt'] == 'media')
      .length;

  int get uploadCreates => requests
      .where((r) => r.method == 'POST' && r.url.path == '/upload/drive/v3/files')
      .length;

  int get uploadUpdates => requests
      .where((r) =>
          r.method == 'PATCH' &&
          r.url.path.startsWith('/upload/drive/v3/files/'))
      .length;

  http.Response _json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json; charset=utf-8'});

  http.Response _error(int code, String message) =>
      _json({'error': {'code': code, 'message': message}}, code);

  Future<http.Response> _handle(http.Request req) async {
    requests.add(req);
    final path = req.url.path;
    final method = req.method;

    if (method == 'GET' && path == '/drive/v3/files') return _list(req);
    if (method == 'POST' && path == '/drive/v3/files') {
      return _metadataCreate(req);
    }
    if (method == 'POST' && path == '/upload/drive/v3/files') {
      final (meta, bytes) = _parseMultipart(req);
      final id = addFile(
        (meta['parents'] as List).first as String,
        meta['name'] as String,
        bytes,
      );
      return _json({'id': id, 'name': meta['name']});
    }
    if (method == 'PATCH' && path.startsWith('/upload/drive/v3/files/')) {
      final id = path.split('/').last;
      final file = files[id];
      if (file == null) return _error(404, 'File not found: $id');
      final (meta, bytes) = _parseMultipart(req);
      file.bytes = bytes;
      return _json({'id': id, 'name': meta['name'] ?? file.name});
    }
    if (method == 'DELETE' && path.startsWith('/drive/v3/files/')) {
      final id = path.split('/').last;
      files.remove(id);
      folders.remove(id);
      return http.Response('', 204);
    }
    if (method == 'GET' && path.startsWith('/drive/v3/files/')) {
      final id = path.split('/').last;
      if (req.url.queryParameters['alt'] == 'media') {
        final file = files[id];
        if (file == null) return _error(404, 'File not found: $id');
        return http.Response.bytes(file.bytes, 200,
            headers: {'content-type': 'application/octet-stream'});
      }
      if (failMetadataGets > 0) {
        failMetadataGets--;
        return _error(500, 'transient');
      }
      if (folders.containsKey(id) || files.containsKey(id)) {
        return _json({'id': id});
      }
      return _error(404, 'File not found: $id');
    }
    return _error(400, 'Unhandled request: $method $path');
  }

  Future<http.Response> _list(http.Request req) async {
    final q = req.url.queryParameters['q']!;
    // ponytail: naive q parsing — test names never contain quotes.
    final parent = RegExp(r"'([^']+)' in parents").firstMatch(q)?.group(1);
    final name = RegExp(r"name='([^']+)'").firstMatch(q)?.group(1);
    final wantsFolders = q.contains("mimeType='$_folderMime'");
    final excludesFolders = q.contains("mimeType!='$_folderMime'");

    final out = <Map<String, String>>[];
    if (!excludesFolders) {
      folders.forEach((id, f) {
        if (f.parent == parent && (name == null || f.name == name)) {
          out.add({'id': id, 'name': f.name, 'mimeType': _folderMime});
        }
      });
    }
    if (!wantsFolders) {
      files.forEach((id, f) {
        if (f.parent == parent && (name == null || f.name == name)) {
          out.add({'id': id, 'name': f.name});
        }
      });
    }
    return _json({'files': out});
  }

  Future<http.Response> _metadataCreate(http.Request req) async {
    final meta = jsonDecode(req.body) as Map<String, dynamic>;
    final parent = (meta['parents'] as List).first as String;
    final name = meta['name'] as String;
    final id = meta['mimeType'] == _folderMime
        ? addFolder(parent, name)
        : addFile(parent, name, const []);
    return _json({'id': id, 'name': name});
  }

  /// googleapis multipart upload: JSON metadata part + base64 media part
  /// (see _discoveryapis_commons MultipartMediaUploader).
  (Map<String, dynamic>, List<int>) _parseMultipart(http.Request req) {
    final contentType = req.headers['content-type']!;
    final boundary =
        RegExp(r'boundary="?([^";]+)"?').firstMatch(contentType)!.group(1)!;
    final parts = req.body.split('--$boundary');

    String bodyOf(String part) {
      final headerEnd = part.indexOf('\r\n\r\n');
      var body = part.substring(headerEnd + 4);
      if (body.endsWith('\r\n')) body = body.substring(0, body.length - 2);
      return body;
    }

    final meta = jsonDecode(bodyOf(parts[1])) as Map<String, dynamic>;
    final bytes = base64.decode(bodyOf(parts[2]).trim());
    return (meta, bytes);
  }
}

void main() {
  late FakeDrive drive;
  late DriveSyncFolderGateway gateway;

  setUp(() {
    drive = FakeDrive();
    gateway = DriveSyncFolderGateway(() async => drive.authClient());
  });

  group('no auth (client factory returns null)', () {
    late FakeDrive offline;
    late DriveSyncFolderGateway noAuth;

    setUp(() {
      offline = FakeDrive();
      noAuth = DriveSyncFolderGateway(() async => null);
    });

    test('reads/lists return empty, delete is a no-op', () async {
      expect(await noAuth.readBytes('root', 'books.json'), isNull);
      expect(await noAuth.readText('root', 'books.json'), isNull);
      expect(await noAuth.listFiles('root', 'library'), isEmpty);
      expect(await noAuth.isReadable('root'), isFalse);
      await noAuth.deleteFile('root', 'books.json'); // must not throw
      expect(offline.requests, isEmpty);
    });

    test('writeBytes and ensureRootFolder throw StateError', () async {
      await expectLater(
        noAuth.writeText('root', 'books.json', '{}'),
        throwsStateError,
      );
      await expectLater(noAuth.ensureRootFolder(), throwsStateError);
    });
  });

  group('read round-trip', () {
    test('readBytes returns the stored bytes', () async {
      final content = utf8.encode('{"books":[]}');
      drive.addFile(drive.rootId, 'books.json', content);

      final bytes = await gateway.readBytes(drive.rootId, 'books.json');

      expect(bytes, content);
    });

    test('readText decodes utf8', () async {
      drive.addFile(drive.rootId, 'note.txt', utf8.encode('olá çedilha'));

      expect(await gateway.readText(drive.rootId, 'note.txt'), 'olá çedilha');
    });

    test('missing file returns null', () async {
      expect(await gateway.readBytes(drive.rootId, 'nope.json'), isNull);
    });

    test('resolves files inside subfolders', () async {
      final libId = drive.addFolder(drive.rootId, 'library');
      drive.addFile(libId, 'books.json', utf8.encode('shard'));

      expect(
        await gateway.readText(drive.rootId, 'library/books.json'),
        'shard',
      );
    });

    test('name collision picks the copy with the lowest id (stable)',
        () async {
      drive.addFile(drive.rootId, 'dup.json', utf8.encode('loser'),
          id: 'zz-later');
      drive.addFile(drive.rootId, 'dup.json', utf8.encode('winner'),
          id: 'aa-first');

      expect(await gateway.readText(drive.rootId, 'dup.json'), 'winner');
    });
  });

  group('writeBytes', () {
    test('creates a new file when none exists', () async {
      await gateway.writeText(drive.rootId, 'books.json', '{"v":1}');

      expect(drive.uploadCreates, 1);
      expect(drive.uploadUpdates, 0);
      final file = drive.files.values.single;
      expect(file.name, 'books.json');
      expect(file.parent, drive.rootId);
      expect(utf8.decode(file.bytes), '{"v":1}');
    });

    test('updates in place when the file already exists', () async {
      final id = drive.addFile(
          drive.rootId, 'books.json', utf8.encode('old'));

      await gateway.writeText(drive.rootId, 'books.json', 'new');

      expect(drive.uploadCreates, 0);
      expect(drive.uploadUpdates, 1);
      expect(drive.files.length, 1, reason: 'must not duplicate the file');
      expect(utf8.decode(drive.files[id]!.bytes), 'new');
    });

    test('creates missing subfolders on demand', () async {
      await gateway.writeText(drive.rootId, 'library/books.json', 'shard');

      final folder = drive.folders.entries
          .singleWhere((e) => e.value.name == 'library');
      expect(folder.value.parent, drive.rootId);
      final file = drive.files.values.single;
      expect(file.parent, folder.key);
      expect(await gateway.readText(drive.rootId, 'library/books.json'),
          'shard');
    });
  });

  group('listFiles', () {
    test('lists file names, excluding folders', () async {
      drive.addFile(drive.rootId, 'a.json', const [1]);
      drive.addFile(drive.rootId, 'b.epub', const [2]);
      drive.addFolder(drive.rootId, 'library');

      final names = await gateway.listFiles(drive.rootId, '');

      expect(names, unorderedEquals(['a.json', 'b.epub']));
    });
  });

  group('fileId cache', () {
    test('listFiles populates: later readBytes skips the search query',
        () async {
      drive.addFile(drive.rootId, 'books.json', utf8.encode('data'));
      await gateway.listFiles(drive.rootId, '');
      final searchesAfterList = drive.searchQueries;

      final bytes = await gateway.readBytes(drive.rootId, 'books.json');

      expect(utf8.decode(bytes!), 'data');
      expect(drive.searchQueries, searchesAfterList,
          reason: 'cached fileId must skip files.list?q=');
      expect(drive.mediaDownloads, 1);
    });

    test('readBytes populates: second readBytes skips the search query',
        () async {
      drive.addFile(drive.rootId, 'books.json', utf8.encode('data'));

      await gateway.readBytes(drive.rootId, 'books.json');
      final searchesAfterFirst = drive.searchQueries;
      expect(searchesAfterFirst, 1);

      await gateway.readBytes(drive.rootId, 'books.json');

      expect(drive.searchQueries, searchesAfterFirst);
      expect(drive.mediaDownloads, 2);
    });

    test('writeBytes create branch populates: later readBytes skips search',
        () async {
      await gateway.writeText(drive.rootId, 'books.json', 'fresh');
      final searchesAfterWrite = drive.searchQueries;

      final text = await gateway.readText(drive.rootId, 'books.json');

      expect(text, 'fresh');
      expect(drive.searchQueries, searchesAfterWrite);
    });

    test('writeBytes consumes cache: goes straight to update', () async {
      drive.addFile(drive.rootId, 'books.json', utf8.encode('old'));
      await gateway.listFiles(drive.rootId, '');
      final searchesAfterList = drive.searchQueries;

      await gateway.writeText(drive.rootId, 'books.json', 'new');

      expect(drive.searchQueries, searchesAfterList);
      expect(drive.uploadUpdates, 1);
      expect(drive.uploadCreates, 0);
    });

    test('deleteFile uses the cache and invalidates the entry', () async {
      drive.addFile(drive.rootId, 'books.json', utf8.encode('data'));
      await gateway.listFiles(drive.rootId, '');
      final searchesAfterList = drive.searchQueries;

      await gateway.deleteFile(drive.rootId, 'books.json');
      expect(drive.searchQueries, searchesAfterList,
          reason: 'delete of a cached file must not re-search');
      expect(drive.files, isEmpty);

      // Entry invalidated: the next write must search again and, finding
      // nothing, create a fresh file instead of updating a dead id.
      await gateway.writeText(drive.rootId, 'books.json', 'reborn');
      expect(drive.searchQueries, searchesAfterList + 1);
      expect(drive.uploadCreates, 1);
      expect(drive.uploadUpdates, 0);
    });

    test('clearCache drops everything: next read searches again', () async {
      drive.addFile(drive.rootId, 'books.json', utf8.encode('data'));
      await gateway.readBytes(drive.rootId, 'books.json');
      expect(drive.searchQueries, 1);

      gateway.clearCache();
      await gateway.readBytes(drive.rootId, 'books.json');

      expect(drive.searchQueries, 2);
    });
  });

  group('isReadable', () {
    test('true for an existing folder id', () async {
      expect(await gateway.isReadable(drive.rootId), isTrue);
    });

    test('false on a genuine 404', () async {
      expect(await gateway.isReadable('gone-folder-id'), isFalse);
    });

    test('retries transient errors before succeeding', () async {
      drive.failMetadataGets = 1;

      expect(await gateway.isReadable(drive.rootId), isTrue);
      // First attempt 500 + one retry that succeeded.
      expect(drive.requests.length, 2);
    });
  });

  group('ensureRootFolder', () {
    test('creates the folder under root when missing, then reuses it',
        () async {
      final id = await gateway.ensureRootFolder();

      expect(drive.folders[id]?.name, 'Ledor');
      expect(drive.folders[id]?.parent, 'root');

      final again = await gateway.ensureRootFolder();
      expect(again, id, reason: 'second call must find, not recreate');
      expect(
        drive.folders.values.where((f) => f.name == 'Ledor').length,
        1,
      );
    });
  });
}
