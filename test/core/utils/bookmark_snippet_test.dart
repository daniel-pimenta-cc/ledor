import 'package:flutter_test/flutter_test.dart';
import 'package:ledor/core/utils/bookmark_snippet.dart';
import 'package:ledor/features/epub_import/domain/entities/word_token.dart';

WordToken _t(String text, int globalIndex, {bool isImage = false}) => WordToken(
      text: text,
      orpIndex: 0,
      timingMultiplier: 1.0,
      globalIndex: globalIndex,
      chapterIndex: 0,
      paragraphIndex: 0,
      isImage: isImage,
    );

void main() {
  group('buildBookmarkSnippet', () {
    test('returns "…before [TARGET] after…" with ellipses on both sides', () {
      final tokens = [
        _t('the', 0),
        _t('quick', 1),
        _t('brown', 2),
        _t('fox', 3),
        _t('jumps', 4),
        _t('over', 5),
        _t('the', 6),
        _t('lazy', 7),
        _t('dog', 8),
      ];
      final snippet = buildBookmarkSnippet(
        tokens: tokens,
        targetLocalIndex: 4,
        contextWords: 2,
      );
      expect(snippet, '… brown fox [jumps] over the …');
    });

    test('no leading ellipsis at start of paragraph', () {
      final tokens = [_t('alpha', 0), _t('beta', 1), _t('gamma', 2)];
      final snippet =
          buildBookmarkSnippet(tokens: tokens, targetLocalIndex: 0);
      expect(snippet, startsWith('[alpha]'));
      expect(snippet, isNot(contains('…')));
    });

    test('no trailing ellipsis at end of paragraph', () {
      final tokens = [_t('alpha', 0), _t('beta', 1), _t('gamma', 2)];
      final snippet =
          buildBookmarkSnippet(tokens: tokens, targetLocalIndex: 2);
      expect(snippet, endsWith('[gamma]'));
    });

    test('skips image tokens while gathering context', () {
      final tokens = [
        _t('alpha', 0),
        _t('', 1, isImage: true),
        _t('beta', 2),
        _t('gamma', 3),
      ];
      final snippet = buildBookmarkSnippet(
        tokens: tokens,
        targetLocalIndex: 3,
        contextWords: 2,
      );
      expect(snippet, isNot(contains('…')));
      expect(snippet, contains('alpha'));
      expect(snippet, contains('beta'));
      expect(snippet, endsWith('[gamma]'));
    });

    test('returns null for empty / image target', () {
      final tokens = [_t('', 0, isImage: true)];
      expect(
        buildBookmarkSnippet(tokens: tokens, targetLocalIndex: 0),
        isNull,
      );
    });

    test('returns null for out-of-range index', () {
      final tokens = [_t('alpha', 0)];
      expect(
        buildBookmarkSnippet(tokens: tokens, targetLocalIndex: 5),
        isNull,
      );
      expect(
        buildBookmarkSnippet(tokens: tokens, targetLocalIndex: -1),
        isNull,
      );
    });
  });
}
