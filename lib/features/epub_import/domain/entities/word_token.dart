import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'word_token.freezed.dart';
part 'word_token.g.dart';

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
@freezed
abstract class WordToken with _$WordToken {
  const factory WordToken({
    required String text,
    required int orpIndex,
    required double timingMultiplier,
    required int globalIndex,
    required int chapterIndex,
    required int paragraphIndex,
    @Default(false) bool isParagraphStart,
    @Default(false) bool isChapterStart,
    @Default(false) bool isImage,

    /// Path of the saved image, relative to the application documents
    /// directory (e.g. `book_images/<bookId>/<hash>.png`). Only set on
    /// image tokens after the persist step writes the bytes to disk.
    String? imageRelativePath,

    /// Native image dimensions when known, used to compute the inline
    /// aspect ratio before the file is loaded.
    int? imageWidth,
    int? imageHeight,

    /// Transient bytes attached during extraction so [persistParsedBook]
    /// can write them to disk and turn them into [imageRelativePath].
    /// Excluded from the persisted JSON — the disk file is the source of
    /// truth after a book is saved.
    @JsonKey(includeFromJson: false, includeToJson: false)
    Uint8List? pendingImageBytes,
  }) = _WordToken;

  factory WordToken.fromJson(Map<String, dynamic> json) =>
      _$WordTokenFromJson(json);
}
