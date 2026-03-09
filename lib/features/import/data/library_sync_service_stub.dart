import '../../../data/repositories/book_repository.dart';
import 'library_sync_models.dart';

class LibrarySyncService {
  LibrarySyncService({required BookRepository repository});

  static const String catalogUrl =
      'https://raw.githubusercontent.com/MichaelMa666/floc-reader-library/refs/heads/main/catalog.json';

  Future<LibrarySyncResult> sync() {
    throw UnsupportedError('当前平台不支持远程书库同步');
  }
}
