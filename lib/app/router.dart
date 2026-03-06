import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/bookshelf/presentation/bookshelf_page.dart';
import '../features/catalog/presentation/catalog_page.dart';
import '../features/reader/presentation/reader_page.dart';

class AppRoutes {
  static const bookshelf = '/';
  static const catalog = '/catalog/:bookId';
  static const reader = '/reader/:bookId/:chapterId';
}

final appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.bookshelf,
      name: 'bookshelf',
      builder: (BuildContext context, GoRouterState state) {
        return const BookshelfPage();
      },
    ),
    GoRoute(
      path: AppRoutes.catalog,
      name: 'catalog',
      builder: (BuildContext context, GoRouterState state) {
        final bookId = state.pathParameters['bookId']!;
        return CatalogPage(bookId: bookId);
      },
    ),
    GoRoute(
      path: AppRoutes.reader,
      name: 'reader',
      builder: (BuildContext context, GoRouterState state) {
        final bookId = state.pathParameters['bookId']!;
        final chapterId = state.pathParameters['chapterId']!;
        return ReaderPage(bookId: bookId, chapterId: chapterId);
      },
    ),
  ],
);
