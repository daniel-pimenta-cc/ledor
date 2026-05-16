// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'word_token.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WordToken {

 String get text; int get orpIndex; double get timingMultiplier; int get globalIndex; int get chapterIndex; int get paragraphIndex; bool get isParagraphStart; bool get isChapterStart; bool get isImage;/// Path of the saved image, relative to the application documents
/// directory (e.g. `book_images/<bookId>/<hash>.png`). Only set on
/// image tokens after the persist step writes the bytes to disk.
 String? get imageRelativePath;/// Native image dimensions when known, used to compute the inline
/// aspect ratio before the file is loaded.
 int? get imageWidth; int? get imageHeight;/// Transient bytes attached during extraction so [persistParsedBook]
/// can write them to disk and turn them into [imageRelativePath].
/// Excluded from the persisted JSON — the disk file is the source of
/// truth after a book is saved.
@JsonKey(includeFromJson: false, includeToJson: false) Uint8List? get pendingImageBytes;
/// Create a copy of WordToken
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WordTokenCopyWith<WordToken> get copyWith => _$WordTokenCopyWithImpl<WordToken>(this as WordToken, _$identity);

  /// Serializes this WordToken to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WordToken&&(identical(other.text, text) || other.text == text)&&(identical(other.orpIndex, orpIndex) || other.orpIndex == orpIndex)&&(identical(other.timingMultiplier, timingMultiplier) || other.timingMultiplier == timingMultiplier)&&(identical(other.globalIndex, globalIndex) || other.globalIndex == globalIndex)&&(identical(other.chapterIndex, chapterIndex) || other.chapterIndex == chapterIndex)&&(identical(other.paragraphIndex, paragraphIndex) || other.paragraphIndex == paragraphIndex)&&(identical(other.isParagraphStart, isParagraphStart) || other.isParagraphStart == isParagraphStart)&&(identical(other.isChapterStart, isChapterStart) || other.isChapterStart == isChapterStart)&&(identical(other.isImage, isImage) || other.isImage == isImage)&&(identical(other.imageRelativePath, imageRelativePath) || other.imageRelativePath == imageRelativePath)&&(identical(other.imageWidth, imageWidth) || other.imageWidth == imageWidth)&&(identical(other.imageHeight, imageHeight) || other.imageHeight == imageHeight)&&const DeepCollectionEquality().equals(other.pendingImageBytes, pendingImageBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,orpIndex,timingMultiplier,globalIndex,chapterIndex,paragraphIndex,isParagraphStart,isChapterStart,isImage,imageRelativePath,imageWidth,imageHeight,const DeepCollectionEquality().hash(pendingImageBytes));

@override
String toString() {
  return 'WordToken(text: $text, orpIndex: $orpIndex, timingMultiplier: $timingMultiplier, globalIndex: $globalIndex, chapterIndex: $chapterIndex, paragraphIndex: $paragraphIndex, isParagraphStart: $isParagraphStart, isChapterStart: $isChapterStart, isImage: $isImage, imageRelativePath: $imageRelativePath, imageWidth: $imageWidth, imageHeight: $imageHeight, pendingImageBytes: $pendingImageBytes)';
}


}

/// @nodoc
abstract mixin class $WordTokenCopyWith<$Res>  {
  factory $WordTokenCopyWith(WordToken value, $Res Function(WordToken) _then) = _$WordTokenCopyWithImpl;
@useResult
$Res call({
 String text, int orpIndex, double timingMultiplier, int globalIndex, int chapterIndex, int paragraphIndex, bool isParagraphStart, bool isChapterStart, bool isImage, String? imageRelativePath, int? imageWidth, int? imageHeight,@JsonKey(includeFromJson: false, includeToJson: false) Uint8List? pendingImageBytes
});




}
/// @nodoc
class _$WordTokenCopyWithImpl<$Res>
    implements $WordTokenCopyWith<$Res> {
  _$WordTokenCopyWithImpl(this._self, this._then);

  final WordToken _self;
  final $Res Function(WordToken) _then;

/// Create a copy of WordToken
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? orpIndex = null,Object? timingMultiplier = null,Object? globalIndex = null,Object? chapterIndex = null,Object? paragraphIndex = null,Object? isParagraphStart = null,Object? isChapterStart = null,Object? isImage = null,Object? imageRelativePath = freezed,Object? imageWidth = freezed,Object? imageHeight = freezed,Object? pendingImageBytes = freezed,}) {
  return _then(_self.copyWith(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,orpIndex: null == orpIndex ? _self.orpIndex : orpIndex // ignore: cast_nullable_to_non_nullable
as int,timingMultiplier: null == timingMultiplier ? _self.timingMultiplier : timingMultiplier // ignore: cast_nullable_to_non_nullable
as double,globalIndex: null == globalIndex ? _self.globalIndex : globalIndex // ignore: cast_nullable_to_non_nullable
as int,chapterIndex: null == chapterIndex ? _self.chapterIndex : chapterIndex // ignore: cast_nullable_to_non_nullable
as int,paragraphIndex: null == paragraphIndex ? _self.paragraphIndex : paragraphIndex // ignore: cast_nullable_to_non_nullable
as int,isParagraphStart: null == isParagraphStart ? _self.isParagraphStart : isParagraphStart // ignore: cast_nullable_to_non_nullable
as bool,isChapterStart: null == isChapterStart ? _self.isChapterStart : isChapterStart // ignore: cast_nullable_to_non_nullable
as bool,isImage: null == isImage ? _self.isImage : isImage // ignore: cast_nullable_to_non_nullable
as bool,imageRelativePath: freezed == imageRelativePath ? _self.imageRelativePath : imageRelativePath // ignore: cast_nullable_to_non_nullable
as String?,imageWidth: freezed == imageWidth ? _self.imageWidth : imageWidth // ignore: cast_nullable_to_non_nullable
as int?,imageHeight: freezed == imageHeight ? _self.imageHeight : imageHeight // ignore: cast_nullable_to_non_nullable
as int?,pendingImageBytes: freezed == pendingImageBytes ? _self.pendingImageBytes : pendingImageBytes // ignore: cast_nullable_to_non_nullable
as Uint8List?,
  ));
}

}


/// Adds pattern-matching-related methods to [WordToken].
extension WordTokenPatterns on WordToken {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WordToken value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WordToken() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WordToken value)  $default,){
final _that = this;
switch (_that) {
case _WordToken():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WordToken value)?  $default,){
final _that = this;
switch (_that) {
case _WordToken() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  int orpIndex,  double timingMultiplier,  int globalIndex,  int chapterIndex,  int paragraphIndex,  bool isParagraphStart,  bool isChapterStart,  bool isImage,  String? imageRelativePath,  int? imageWidth,  int? imageHeight, @JsonKey(includeFromJson: false, includeToJson: false)  Uint8List? pendingImageBytes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WordToken() when $default != null:
return $default(_that.text,_that.orpIndex,_that.timingMultiplier,_that.globalIndex,_that.chapterIndex,_that.paragraphIndex,_that.isParagraphStart,_that.isChapterStart,_that.isImage,_that.imageRelativePath,_that.imageWidth,_that.imageHeight,_that.pendingImageBytes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  int orpIndex,  double timingMultiplier,  int globalIndex,  int chapterIndex,  int paragraphIndex,  bool isParagraphStart,  bool isChapterStart,  bool isImage,  String? imageRelativePath,  int? imageWidth,  int? imageHeight, @JsonKey(includeFromJson: false, includeToJson: false)  Uint8List? pendingImageBytes)  $default,) {final _that = this;
switch (_that) {
case _WordToken():
return $default(_that.text,_that.orpIndex,_that.timingMultiplier,_that.globalIndex,_that.chapterIndex,_that.paragraphIndex,_that.isParagraphStart,_that.isChapterStart,_that.isImage,_that.imageRelativePath,_that.imageWidth,_that.imageHeight,_that.pendingImageBytes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  int orpIndex,  double timingMultiplier,  int globalIndex,  int chapterIndex,  int paragraphIndex,  bool isParagraphStart,  bool isChapterStart,  bool isImage,  String? imageRelativePath,  int? imageWidth,  int? imageHeight, @JsonKey(includeFromJson: false, includeToJson: false)  Uint8List? pendingImageBytes)?  $default,) {final _that = this;
switch (_that) {
case _WordToken() when $default != null:
return $default(_that.text,_that.orpIndex,_that.timingMultiplier,_that.globalIndex,_that.chapterIndex,_that.paragraphIndex,_that.isParagraphStart,_that.isChapterStart,_that.isImage,_that.imageRelativePath,_that.imageWidth,_that.imageHeight,_that.pendingImageBytes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WordToken implements WordToken {
  const _WordToken({required this.text, required this.orpIndex, required this.timingMultiplier, required this.globalIndex, required this.chapterIndex, required this.paragraphIndex, this.isParagraphStart = false, this.isChapterStart = false, this.isImage = false, this.imageRelativePath, this.imageWidth, this.imageHeight, @JsonKey(includeFromJson: false, includeToJson: false) this.pendingImageBytes});
  factory _WordToken.fromJson(Map<String, dynamic> json) => _$WordTokenFromJson(json);

@override final  String text;
@override final  int orpIndex;
@override final  double timingMultiplier;
@override final  int globalIndex;
@override final  int chapterIndex;
@override final  int paragraphIndex;
@override@JsonKey() final  bool isParagraphStart;
@override@JsonKey() final  bool isChapterStart;
@override@JsonKey() final  bool isImage;
/// Path of the saved image, relative to the application documents
/// directory (e.g. `book_images/<bookId>/<hash>.png`). Only set on
/// image tokens after the persist step writes the bytes to disk.
@override final  String? imageRelativePath;
/// Native image dimensions when known, used to compute the inline
/// aspect ratio before the file is loaded.
@override final  int? imageWidth;
@override final  int? imageHeight;
/// Transient bytes attached during extraction so [persistParsedBook]
/// can write them to disk and turn them into [imageRelativePath].
/// Excluded from the persisted JSON — the disk file is the source of
/// truth after a book is saved.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  Uint8List? pendingImageBytes;

/// Create a copy of WordToken
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WordTokenCopyWith<_WordToken> get copyWith => __$WordTokenCopyWithImpl<_WordToken>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WordTokenToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WordToken&&(identical(other.text, text) || other.text == text)&&(identical(other.orpIndex, orpIndex) || other.orpIndex == orpIndex)&&(identical(other.timingMultiplier, timingMultiplier) || other.timingMultiplier == timingMultiplier)&&(identical(other.globalIndex, globalIndex) || other.globalIndex == globalIndex)&&(identical(other.chapterIndex, chapterIndex) || other.chapterIndex == chapterIndex)&&(identical(other.paragraphIndex, paragraphIndex) || other.paragraphIndex == paragraphIndex)&&(identical(other.isParagraphStart, isParagraphStart) || other.isParagraphStart == isParagraphStart)&&(identical(other.isChapterStart, isChapterStart) || other.isChapterStart == isChapterStart)&&(identical(other.isImage, isImage) || other.isImage == isImage)&&(identical(other.imageRelativePath, imageRelativePath) || other.imageRelativePath == imageRelativePath)&&(identical(other.imageWidth, imageWidth) || other.imageWidth == imageWidth)&&(identical(other.imageHeight, imageHeight) || other.imageHeight == imageHeight)&&const DeepCollectionEquality().equals(other.pendingImageBytes, pendingImageBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,orpIndex,timingMultiplier,globalIndex,chapterIndex,paragraphIndex,isParagraphStart,isChapterStart,isImage,imageRelativePath,imageWidth,imageHeight,const DeepCollectionEquality().hash(pendingImageBytes));

@override
String toString() {
  return 'WordToken(text: $text, orpIndex: $orpIndex, timingMultiplier: $timingMultiplier, globalIndex: $globalIndex, chapterIndex: $chapterIndex, paragraphIndex: $paragraphIndex, isParagraphStart: $isParagraphStart, isChapterStart: $isChapterStart, isImage: $isImage, imageRelativePath: $imageRelativePath, imageWidth: $imageWidth, imageHeight: $imageHeight, pendingImageBytes: $pendingImageBytes)';
}


}

/// @nodoc
abstract mixin class _$WordTokenCopyWith<$Res> implements $WordTokenCopyWith<$Res> {
  factory _$WordTokenCopyWith(_WordToken value, $Res Function(_WordToken) _then) = __$WordTokenCopyWithImpl;
@override @useResult
$Res call({
 String text, int orpIndex, double timingMultiplier, int globalIndex, int chapterIndex, int paragraphIndex, bool isParagraphStart, bool isChapterStart, bool isImage, String? imageRelativePath, int? imageWidth, int? imageHeight,@JsonKey(includeFromJson: false, includeToJson: false) Uint8List? pendingImageBytes
});




}
/// @nodoc
class __$WordTokenCopyWithImpl<$Res>
    implements _$WordTokenCopyWith<$Res> {
  __$WordTokenCopyWithImpl(this._self, this._then);

  final _WordToken _self;
  final $Res Function(_WordToken) _then;

/// Create a copy of WordToken
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? orpIndex = null,Object? timingMultiplier = null,Object? globalIndex = null,Object? chapterIndex = null,Object? paragraphIndex = null,Object? isParagraphStart = null,Object? isChapterStart = null,Object? isImage = null,Object? imageRelativePath = freezed,Object? imageWidth = freezed,Object? imageHeight = freezed,Object? pendingImageBytes = freezed,}) {
  return _then(_WordToken(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,orpIndex: null == orpIndex ? _self.orpIndex : orpIndex // ignore: cast_nullable_to_non_nullable
as int,timingMultiplier: null == timingMultiplier ? _self.timingMultiplier : timingMultiplier // ignore: cast_nullable_to_non_nullable
as double,globalIndex: null == globalIndex ? _self.globalIndex : globalIndex // ignore: cast_nullable_to_non_nullable
as int,chapterIndex: null == chapterIndex ? _self.chapterIndex : chapterIndex // ignore: cast_nullable_to_non_nullable
as int,paragraphIndex: null == paragraphIndex ? _self.paragraphIndex : paragraphIndex // ignore: cast_nullable_to_non_nullable
as int,isParagraphStart: null == isParagraphStart ? _self.isParagraphStart : isParagraphStart // ignore: cast_nullable_to_non_nullable
as bool,isChapterStart: null == isChapterStart ? _self.isChapterStart : isChapterStart // ignore: cast_nullable_to_non_nullable
as bool,isImage: null == isImage ? _self.isImage : isImage // ignore: cast_nullable_to_non_nullable
as bool,imageRelativePath: freezed == imageRelativePath ? _self.imageRelativePath : imageRelativePath // ignore: cast_nullable_to_non_nullable
as String?,imageWidth: freezed == imageWidth ? _self.imageWidth : imageWidth // ignore: cast_nullable_to_non_nullable
as int?,imageHeight: freezed == imageHeight ? _self.imageHeight : imageHeight // ignore: cast_nullable_to_non_nullable
as int?,pendingImageBytes: freezed == pendingImageBytes ? _self.pendingImageBytes : pendingImageBytes // ignore: cast_nullable_to_non_nullable
as Uint8List?,
  ));
}


}

// dart format on
