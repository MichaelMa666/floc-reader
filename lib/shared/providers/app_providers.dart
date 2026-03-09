import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../data/local/app_database_platform.dart';
import '../../data/local/reading_preferences_store.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/reading_repository_impl.dart';
import '../../domain/repositories/reading_repository.dart';
import '../../domain/usecases/save_reading_progress_usecase.dart';
import '../../features/import/data/library_sync_service_platform.dart';
import '../../features/reader/application/reader_progress_service.dart';

final appRouterProvider = Provider<GoRouter>((ref) => appRouter);

final appThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

final readingPreferencesStoreProvider = Provider<ReadingPreferencesStore>(
  (ref) => ReadingPreferencesStore(),
);

final readingRepositoryProvider = Provider<ReadingRepository>(
  (ref) => ReadingRepositoryImpl(ref.watch(readingPreferencesStoreProvider)),
);

final saveReadingProgressUseCaseProvider = Provider<SaveReadingProgressUseCase>(
  (ref) => SaveReadingProgressUseCase(ref.watch(readingRepositoryProvider)),
);

final readerProgressServiceProvider = Provider<ReaderProgressService>(
  (ref) => ReaderProgressService(ref.watch(saveReadingProgressUseCaseProvider)),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => BookRepository(db: ref.watch(appDatabaseProvider)),
);

final librarySyncServiceProvider = Provider<LibrarySyncService>(
  (ref) => LibrarySyncService(repository: ref.watch(bookRepositoryProvider)),
);

final bookListProvider = FutureProvider<List<BookRow>>((ref) {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.getLocalBooks();
});

final chapterListProvider = FutureProvider.family<List<ChapterRow>, String>((
  ref,
  bookId,
) {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.getLocalChapters(bookId);
});

final chapterInfoProvider =
    FutureProvider.family<ChapterRow?, ({String bookId, String chapterId})>((
      ref,
      args,
    ) {
      final repo = ref.watch(bookRepositoryProvider);
      return repo.getLocalChapter(args.bookId, args.chapterId);
    });

final chapterReadPercentMapProvider = FutureProvider.family<Map<String, int>, String>((
  ref,
  bookId,
) {
  final readingRepo = ref.watch(readingRepositoryProvider);
  return readingRepo.getChapterReadPercents(bookId);
});

final chapterContentProvider =
    FutureProvider.family<String, ({String bookId, String chapterId})>((
      ref,
      args,
    ) {
      final repo = ref.watch(bookRepositoryProvider);
      return repo.getChapterContent(args.bookId, args.chapterId);
    });
