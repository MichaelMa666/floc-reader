import '../entities/reading_progress.dart';
import '../repositories/reading_repository.dart';

class SaveReadingProgressUseCase {
  const SaveReadingProgressUseCase(this._readingRepository);

  final ReadingRepository _readingRepository;

  Future<void> call(ReadingProgress progress) {
    return _readingRepository.saveReadingProgress(progress);
  }
}
