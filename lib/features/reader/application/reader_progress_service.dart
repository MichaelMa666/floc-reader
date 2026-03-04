import '../../../domain/entities/reading_progress.dart';
import '../../../domain/usecases/save_reading_progress_usecase.dart';

class ReaderProgressService {
  ReaderProgressService(this._saveReadingProgressUseCase);

  final SaveReadingProgressUseCase _saveReadingProgressUseCase;

  Future<void> save({
    required String bookId,
    required String chapterId,
    required int offset,
  }) {
    return _saveReadingProgressUseCase(
      ReadingProgress(
        bookId: bookId,
        chapterId: chapterId,
        offset: offset,
        updatedAt: DateTime.now(),
      ),
    );
  }
}
