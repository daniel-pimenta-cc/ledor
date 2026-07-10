import 'dart:typed_data';

/// The fundamental unit of RSVP playback.
///
/// Every word in a book is pre-processed into a WordToken at import time.
/// ORP index and timing multiplier are pre-calculated so the RSVP engine's
/// hot loop does zero computation beyond reading these fields.
///
/// Tokens are mostly text words, but a chapter may also carry inline image
/// tokens (`isImage: true`) at the position where the EPUB had an `<img>`.
/// Image tokens skip ORP/timing and instead point at a file under
/// `<docs>/book_images/<bookId>/` via [imageRelativePath]. The engine pauses
/// on them so the reader can pan/zoom in RSVP mode, and the scroll view
/// renders them inline with a tap-to-fullscreen affordance.
class WordToken {
  const WordToken({
    required this.text,
    required this.orpIndex,
    required this.timingMultiplier,
    required this.globalIndex,
    required this.chapterIndex,
    required this.paragraphIndex,
    this.isParagraphStart = false,
    this.isChapterStart = false,
    this.isImage = false,
    this.imageRelativePath,
    this.pendingImageBytes,
  });

  final String text;
  final int orpIndex;
  final double timingMultiplier;
  final int globalIndex;
  final int chapterIndex;
  final int paragraphIndex;
  final bool isParagraphStart;
  final bool isChapterStart;
  final bool isImage;

  /// Path of the saved image, relative to the application documents
  /// directory (e.g. `book_images/<bookId>/<hash>.png`). Only set on
  /// image tokens after the persist step writes the bytes to disk.
  final String? imageRelativePath;

  /// Transient bytes attached during extraction so [persistParsedBook]
  /// can write them to disk and turn them into [imageRelativePath].
  /// Excluded from the persisted JSON — the disk file is the source of
  /// truth after a book is saved.
  final Uint8List? pendingImageBytes;

  /// Key names and value shapes here are load-bearing: [TokenCodec]'s v1
  /// path persists this exact JSON, so old books on disk still decode.
  /// Unknown keys (e.g. the removed `imageWidth`/`imageHeight`) are ignored.
  factory WordToken.fromJson(Map<String, dynamic> json) => WordToken(
        text: json['text'] as String,
        orpIndex: (json['orpIndex'] as num).toInt(),
        timingMultiplier: (json['timingMultiplier'] as num).toDouble(),
        globalIndex: (json['globalIndex'] as num).toInt(),
        chapterIndex: (json['chapterIndex'] as num).toInt(),
        paragraphIndex: (json['paragraphIndex'] as num).toInt(),
        isParagraphStart: json['isParagraphStart'] as bool? ?? false,
        isChapterStart: json['isChapterStart'] as bool? ?? false,
        isImage: json['isImage'] as bool? ?? false,
        imageRelativePath: json['imageRelativePath'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        'orpIndex': orpIndex,
        'timingMultiplier': timingMultiplier,
        'globalIndex': globalIndex,
        'chapterIndex': chapterIndex,
        'paragraphIndex': paragraphIndex,
        'isParagraphStart': isParagraphStart,
        'isChapterStart': isChapterStart,
        'isImage': isImage,
        'imageRelativePath': imageRelativePath,
      };

  // ponytail: only the fields anything actually copies are exposed. The
  // sentinel lets pendingImageBytes be nulled out (the persist step clears it).
  WordToken copyWith({
    int? globalIndex,
    int? paragraphIndex,
    bool? isChapterStart,
    String? imageRelativePath,
    Object? pendingImageBytes = _unset,
  }) =>
      WordToken(
        text: text,
        orpIndex: orpIndex,
        timingMultiplier: timingMultiplier,
        globalIndex: globalIndex ?? this.globalIndex,
        chapterIndex: chapterIndex,
        paragraphIndex: paragraphIndex ?? this.paragraphIndex,
        isParagraphStart: isParagraphStart,
        isChapterStart: isChapterStart ?? this.isChapterStart,
        isImage: isImage,
        imageRelativePath: imageRelativePath ?? this.imageRelativePath,
        pendingImageBytes: identical(pendingImageBytes, _unset)
            ? this.pendingImageBytes
            : pendingImageBytes as Uint8List?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordToken &&
          other.text == text &&
          other.orpIndex == orpIndex &&
          other.timingMultiplier == timingMultiplier &&
          other.globalIndex == globalIndex &&
          other.chapterIndex == chapterIndex &&
          other.paragraphIndex == paragraphIndex &&
          other.isParagraphStart == isParagraphStart &&
          other.isChapterStart == isChapterStart &&
          other.isImage == isImage &&
          other.imageRelativePath == imageRelativePath &&
          other.pendingImageBytes == pendingImageBytes;

  @override
  int get hashCode => Object.hash(
        text,
        orpIndex,
        timingMultiplier,
        globalIndex,
        chapterIndex,
        paragraphIndex,
        isParagraphStart,
        isChapterStart,
        isImage,
        imageRelativePath,
        pendingImageBytes,
      );

  @override
  String toString() => 'WordToken(text: $text, globalIndex: $globalIndex, '
      'chapterIndex: $chapterIndex, paragraphIndex: $paragraphIndex, '
      'isImage: $isImage)';
}

const _unset = Object();
