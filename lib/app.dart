import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/share/desktop_drop_handler.dart';
import 'core/share/share_intent_handler.dart';
import 'core/theme/app_theme.dart';
import 'features/article_import/presentation/providers/article_import_provider.dart';
import 'features/settings/presentation/providers/theme_mode_provider.dart';
import 'l10n/generated/app_localizations.dart';

/// Surfaces snackbars (progress/error) from listeners that live above
/// [MaterialApp], where `ScaffoldMessenger.of(context)` isn't reachable.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class RsvpReaderApp extends ConsumerWidget {
  const RsvpReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return ShareIntentHandler(
      child: _ArticleImportCoordinator(
        child: MaterialApp.router(
          title: 'Ledor',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: rootMessengerKey,
          theme: AppTheme.build(brightness: Brightness.light),
          darkTheme: AppTheme.build(brightness: Brightness.dark),
          themeMode: themeMode,
          routerConfig: appRouter,
          builder: (context, child) =>
              DesktopDropHandler(child: child ?? const SizedBox.shrink()),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
  }
}

/// Listens to [articleImportProvider] at the app level so that article
/// imports initiated from *anywhere* (share-sheet, URL dialog, future entry
/// points) surface a consistent progress indicator and navigate to the
/// reader on success.
///
/// Sits above [MaterialApp.router] so `ref.listen` stays mounted across
/// route changes.
class _ArticleImportCoordinator extends ConsumerStatefulWidget {
  final Widget child;
  const _ArticleImportCoordinator({required this.child});

  @override
  ConsumerState<_ArticleImportCoordinator> createState() =>
      _ArticleImportCoordinatorState();
}

class _ArticleImportCoordinatorState
    extends ConsumerState<_ArticleImportCoordinator> {
  @override
  Widget build(BuildContext context) {
    ref.listen<ArticleImportState>(articleImportProvider, _onStateChange);
    return widget.child;
  }

  void _onStateChange(ArticleImportState? prev, ArticleImportState next) {
    final messenger = rootMessengerKey.currentState;
    final navCtx = rootMessengerKey.currentContext;
    final l10n = navCtx == null ? null : AppLocalizations.of(navCtx);

    switch (next.status) {
      case ArticleImportStatus.fetching:
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          _progressSnack(l10n?.importArticleFetching ?? 'Fetching article…'),
        );
        break;
      case ArticleImportStatus.processing:
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          _progressSnack(l10n?.importing ?? 'Importing…'),
        );
        break;
      case ArticleImportStatus.done:
        messenger?.hideCurrentSnackBar();
        final id = next.importedBookId;
        if (id != null) {
          appRouter.push('/reader/$id');
        }
        ref.read(articleImportProvider.notifier).reset();
        break;
      case ArticleImportStatus.error:
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(SnackBar(
          content: Text(l10n?.importArticleError ?? 'Failed to import article'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(navCtx ?? context).colorScheme.error,
        ));
        ref.read(articleImportProvider.notifier).reset();
        break;
      case ArticleImportStatus.idle:
        break;
    }
  }

  static SnackBar _progressSnack(String label) {
    return SnackBar(
      content: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
      duration: const Duration(minutes: 2),
      behavior: SnackBarBehavior.floating,
    );
  }
}
