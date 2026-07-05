import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/features/book_library/data/services/inline_image_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../fixtures/fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  const storage = InlineImageStorage();

  final pngBytes = Uint8List.fromList(
      [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]);
  final jpgBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 4, 5]);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ledor_images_test_');
    PathProviderPlatform.instance = FakePathProvider(tmp);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('writeImage stores bytes under book_images/<bookId> and sniffs PNG',
      () async {
    final rel = await storage.writeImage(
        bookId: 'book1', sequenceIndex: 3, bytes: pngBytes);

    expect(rel, 'book_images/book1/3.png');
    final abs = await storage.resolveAbsolutePath(rel);
    expect(abs, '${tmp.path}/$rel');
    expect(File(abs).readAsBytesSync(), pngBytes);
  });

  test('detects JPEG from magic bytes, not from what the EPUB declared',
      () async {
    final rel = await storage.writeImage(
        bookId: 'book1', sequenceIndex: 0, bytes: jpgBytes);
    expect(rel, endsWith('.jpg'));
  });

  test('unknown bytes fall back to .bin', () async {
    final rel = await storage.writeImage(
        bookId: 'book1',
        sequenceIndex: 0,
        bytes: Uint8List.fromList([1, 2, 3, 4]));
    expect(rel, endsWith('.bin'));
  });

  test('deleteForBook removes the whole folder, other books untouched',
      () async {
    await storage.writeImage(
        bookId: 'gone', sequenceIndex: 0, bytes: pngBytes);
    await storage.writeImage(
        bookId: 'kept', sequenceIndex: 0, bytes: pngBytes);

    await storage.deleteForBook('gone');

    expect(Directory('${tmp.path}/book_images/gone').existsSync(), isFalse);
    expect(Directory('${tmp.path}/book_images/kept').existsSync(), isTrue);
  });

  test('deleteForBook on a book without images is a no-op', () async {
    await expectLater(storage.deleteForBook('never-existed'), completes);
  });
}
