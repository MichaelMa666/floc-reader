import '../entities/reading_config.dart';
import '../entities/reading_progress.dart';

abstract class ReadingRepository {
  Future<ReadingConfig> getReadingConfig();

  Future<void> saveReadingConfig(ReadingConfig config);

  Future<ReadingProgress?> getReadingProgress(String bookId);

  Future<void> saveReadingProgress(ReadingProgress progress);
}
