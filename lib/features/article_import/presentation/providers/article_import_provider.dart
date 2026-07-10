import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../database/tables/book_source.dart';
import '../../../book_library/data/services/book_persistence.dart';
import '../../data/services/article_extraction_service.dart';

final articleExtractionServiceProvider =
    Provider<ArticleExtractionService>((ref) {
  final service = ArticleExtractionService();
  ref.onDispose(service.close);
  return service;
});

enum ArticleImportStatus { idle, fetching, processing, done, error }

class ArticleImportState {
  final ArticleImportStatus status;
  final String? importedBookId;

  const ArticleImportState({
    this.status = ArticleImportStatus.idle,
    this.importedBookId,
  });

  ArticleImportState copyWith({
    ArticleImportStatus? status,
    String? importedBookId,
  }) {
    return ArticleImportState(
      status: status ?? this.status,
      importedBookId: importedBookId ?? this.importedBookId,
    );
  }
}

class ArticleImportNotifier extends StateNotifier<ArticleImportState> {
  final Ref _ref;

  ArticleImportNotifier(this._ref) : super(const ArticleImportState());

  /// Import an article from [url], save it as a Book with source='article',
  /// and cache its tokens. Navigation is driven by listeners watching
  /// [importedBookId] (same pattern as the EPUB importer).
  Future<void> importFromUrl(String url) async {
    state = state.copyWith(status: ArticleImportStatus.fetching);

    try {
      final extractionService = _ref.read(articleExtractionServiceProvider);
      final result = await extractionService.extractFromUrl(url);

      state = state.copyWith(status: ArticleImportStatus.processing);

      final parsed = result.book;
      if (parsed.chapters.isEmpty) {
        state = state.copyWith(status: ArticleImportStatus.error);
        return;
      }

      final bookId = await persistParsedBook(
        book: parsed,
        booksDao: _ref.read(booksDaoProvider),
        tokensDao: _ref.read(cachedTokensDaoProvider),
        source: BookSource.article,
        sourceUrl: result.sourceUrl,
        siteName: result.siteName,
      );

      state = state.copyWith(
        status: ArticleImportStatus.done,
        importedBookId: bookId,
      );
    } catch (_) {
      state = state.copyWith(status: ArticleImportStatus.error);
    }
  }

  void reset() {
    state = const ArticleImportState();
  }
}

final articleImportProvider =
    StateNotifierProvider<ArticleImportNotifier, ArticleImportState>((ref) {
  return ArticleImportNotifier(ref);
});
