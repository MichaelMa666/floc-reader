import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../data/local/reading_preferences_store.dart';
import '../../data/network/app_dio_client.dart';
import '../../data/repositories/reading_repository_impl.dart';
import '../../domain/repositories/reading_repository.dart';
import '../../domain/usecases/save_reading_progress_usecase.dart';
import '../../features/reader/application/reader_progress_service.dart';

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
