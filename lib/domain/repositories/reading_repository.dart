import '../entities/reading_config.dart';
import '../entities/reading_progress.dart';

abstract class ReadingRepository {
  Future<ReadingConfig> getReadingConfig();

  Future<void> saveReadingConfig(ReadingConfig config);

  Future<ReadingProgress?> getReadingProgress(String bookId);

  Future<ReadingProgress?> getLatestReadingProgress();

  Future<void> saveReadingProgress(ReadingProgress progress);

  Future<Map<String, int>> getChapterReadPercents(String bookId);

  Future<void> saveChapterReadPercent({
    required String bookId,
    required String chapterId,
    required int percent,
  });

  Future<void> clearReadingProgress();
}
