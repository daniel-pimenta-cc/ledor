import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/book_library/presentation/screens/library_screen.dart';
import '../../features/reading_stats/presentation/providers/monthly_recap_provider.dart';
import '../../features/reading_stats/presentation/screens/book_completion_screen.dart';
import '../../features/reading_stats/presentation/screens/monthly_recap_screen.dart';
import '../../features/reading_stats/presentation/screens/reading_stats_screen.dart';
import '../../features/rsvp_reader/presentation/screens/bookmarks_screen.dart';
import '../../features/rsvp_reader/presentation/screens/rsvp_reader_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: '/reader/:bookId',
      pageBuilder: (context, state) {
        final bookId = state.pathParameters['bookId']!;
        return MaterialPage(
          fullscreenDialog: true,
          child: RsvpReaderScreen(bookId: bookId),
        );
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/stats',
      builder: (context, state) => const ReadingStatsScreen(),
    ),
    GoRoute(
      path: '/stats/recap',
      builder: (context, state) =>
          MonthlyRecapScreen(month: RecapMonth.current()),
    ),
    GoRoute(
      path: '/books/:bookId/completion',
      builder: (context, state) =>
          BookCompletionScreen(bookId: state.pathParameters['bookId']!),
    ),
    GoRoute(
      path: '/bookmarks',
      builder: (context, state) => const BookmarksScreen(),
    ),
  ],
);
