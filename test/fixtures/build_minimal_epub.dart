import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Builds a minimal valid EPUB 2 archive in-memory for tests.
///
/// We zip together a `mimetype` entry (stored, never compressed), a
/// container manifest, an OPF manifest with one spine item, and one
/// XHTML chapter file. epub_pro reads OPF metadata to find the title /
/// author and walks the spine for chapter content; this fixture is the
/// smallest input it accepts.
///
/// Returns the EPUB bytes. The caller writes them to a temp file and
/// feeds the path to the import notifier.
Uint8List buildMinimalEpub({
  required String title,
  required String author,
  required List<({String title, String body})> chapters,
}) {
  final archive = Archive();

  // mimetype: must be the first entry and stored uncompressed for
  // strict EPUB readers to recognise the archive. epub_pro tolerates
  // missing mimetype, but real readers don't.
  const mimetype = 'application/epub+zip';
  archive.addFile(
    ArchiveFile.noCompress('mimetype', mimetype.length, utf8.encode(mimetype)),
  );

  archive.addFile(
    ArchiveFile.string(
      'META-INF/container.xml',
      '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''',
    ),
  );

  // Build the OPF: one manifest item + spine entry per chapter, plus the
  // ncx for the toc. Chapter ids are stable strings so the spine references
  // are deterministic.
  final manifestEntries = <String>[
    '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>',
  ];
  final spineEntries = <String>[];
  for (var i = 0; i < chapters.length; i++) {
    final id = 'ch$i';
    manifestEntries.add(
      '<item id="$id" href="$id.xhtml" media-type="application/xhtml+xml"/>',
    );
    spineEntries.add('<itemref idref="$id"/>');
  }

  archive.addFile(
    ArchiveFile.string(
      'OEBPS/content.opf',
      '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:identifier id="BookId">urn:uuid:test-fixture</dc:identifier>
    <dc:title>${_xmlEscape(title)}</dc:title>
    <dc:creator opf:role="aut">${_xmlEscape(author)}</dc:creator>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    ${manifestEntries.join('\n    ')}
  </manifest>
  <spine toc="ncx">
    ${spineEntries.join('\n    ')}
  </spine>
</package>''',
    ),
  );

  // NCX: small navigation map matching the spine order.
  final navPoints = StringBuffer();
  for (var i = 0; i < chapters.length; i++) {
    navPoints.writeln('''    <navPoint id="np$i" playOrder="${i + 1}">
      <navLabel><text>${_xmlEscape(chapters[i].title)}</text></navLabel>
      <content src="ch$i.xhtml"/>
    </navPoint>''');
  }

  archive.addFile(
    ArchiveFile.string(
      'OEBPS/toc.ncx',
      '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="urn:uuid:test-fixture"/>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
  </head>
  <docTitle><text>${_xmlEscape(title)}</text></docTitle>
  <navMap>
${navPoints.toString()}  </navMap>
</ncx>''',
    ),
  );

  for (var i = 0; i < chapters.length; i++) {
    final ch = chapters[i];
    archive.addFile(
      ArchiveFile.string(
        'OEBPS/ch$i.xhtml',
        '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
  "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>${_xmlEscape(ch.title)}</title></head>
<body>
  <h1>${_xmlEscape(ch.title)}</h1>
  <p>${_xmlEscape(ch.body)}</p>
</body>
</html>''',
      ),
    );
  }

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _xmlEscape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
