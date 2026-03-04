import '../../domain/entities/reading_config.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/reading_repository.dart';
import '../local/reading_preferences_store.dart';

class ReadingRepositoryImpl implements ReadingRepository {
  ReadingRepositoryImpl(this._store);

  final ReadingPreferencesStore _store;

  static const ReadingConfig _defaultConfig = ReadingConfig(
    fontSize: 18,
    lineHeight: 1.6,
    nightMode: false,
    brightness: 0.6,
  );

  @override
  Future<ReadingConfig> getReadingConfig() async {
    return (await _store.getReadingConfig()) ?? _defaultConfig;
  }

  @override
  Future<ReadingProgress?> getReadingProgress(String bookId) {
    return _store.getReadingProgress(bookId);
  }

  @override
  Future<void> saveReadingConfig(ReadingConfig config) {
    return _store.saveReadingConfig(config);
  }

  @override
  Future<void> saveReadingProgress(ReadingProgress progress) {
    return _store.saveReadingProgress(progress);
  }
}
