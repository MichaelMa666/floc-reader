import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../data/local/app_database.dart';
import '../../data/local/reading_preferences_store.dart';
import '../../data/network/app_dio_client.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/reading_repository_impl.dart';
import '../../domain/repositories/reading_repository.dart';
import '../../domain/usecases/save_reading_progress_usecase.dart';
import '../../features/reader/application/reader_progress_service.dart';
import '../../features/source/data/biquge_adapter.dart';
import '../../features/source/data/hetushu_adapter.dart';
import '../../features/source/data/html_fetcher.dart';
import '../../features/source/domain/source_registry.dart';

final appRouterProvider = Provider<GoRouter>((ref) => appRouter);

final appThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

final appDioClientProvider = Provider<AppDioClient>(
  (ref) => AppDioClient(baseUrl: ''),
);

final readingPreferencesStoreProvider = Provider<ReadingPreferencesStore>(
  (ref) => ReadingPreferencesStore(),
);

final readingRepositoryProvider = Provider<ReadingRepository>(
  (ref) => ReadingRepositoryImpl(ref.watch(readingPreferencesStoreProvider)),
);

final saveReadingProgressUseCaseProvider =
    Provider<SaveReadingProgressUseCase>(
  (ref) => SaveReadingProgressUseCase(ref.watch(readingRepositoryProvider)),
);

final readerProgressServiceProvider = Provider<ReaderProgressService>(
  (ref) => ReaderProgressService(ref.watch(saveReadingProgressUseCaseProvider)),
);

// ── 书源相关 Provider ──

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final htmlFetcherProvider = Provider<HtmlFetcher>((ref) => DioHtmlFetcher());

/// 当前选中的书源 ID
class CurrentSourceIdNotifier extends Notifier<String> {
  @override
  String build() => 'hetushu';

  void set(String sourceId) => state = sourceId;
}

final currentSourceIdProvider =
    NotifierProvider<CurrentSourceIdNotifier, String>(
  CurrentSourceIdNotifier.new,
);

/// 书源注册表，持有所有 adapter 实例
final sourceRegistryProvider = Provider<SourceRegistry>((ref) {
  final fetcher = ref.watch(htmlFetcherProvider);
  return SourceRegistry({
    'hetushu': HetushuAdapter(fetcher),
    'biquge': BiqugeAdapter(fetcher),
  });
});

final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => BookRepository(
    registry: ref.watch(sourceRegistryProvider),
    db: ref.watch(appDatabaseProvider),
  ),
);

final bookListProvider = FutureProvider<List<BookRow>>((ref) {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.getLocalBooks();
});

final chapterListProvider =
    FutureProvider.family<List<ChapterRow>, String>((ref, bookId) {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.getLocalChapters(bookId);
});

/// 根据 bookId 查本地数据库中的书源 ID
final bookSourceIdProvider =
    FutureProvider.family<String, String>((ref, bookId) async {
  final db = ref.watch(appDatabaseProvider);
  final book = await db.getBookById(bookId);
  return book?.sourceId ?? 'hetushu';
});

final chapterContentProvider = FutureProvider.family<String,
    ({String sourceId, String bookId, String chapterId})>(
  (ref, args) {
    final repo = ref.watch(bookRepositoryProvider);
    return repo.getChapterContent(args.sourceId, args.bookId, args.chapterId);
  },
);
