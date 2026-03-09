class AppDatabase {
  AppDatabase();
  AppDatabase.forTesting(Object? _) : this();

  final Map<String, BookRow> _books = <String, BookRow>{};
  final Map<String, ChapterRow> _chapters = <String, ChapterRow>{};

  Future<void> upsertBook({
    required String id,
    required String sourceId,
    required String title,
    required String author,
    String? coverUrl,
    String description = '',
  }) async {
    _books[id] = BookRow(
      id: id,
      sourceId: sourceId,
      title: title,
      author: author,
      coverUrl: coverUrl,
      description: description,
    );
  }

  Future<List<BookRow>> getAllBooks() async {
    return _books.values.toList();
  }

  Future<BookRow?> getBookById(String id) async {
    return _books[id];
  }

  Future<void> upsertChapters(List<ChapterRow> chapters) async {
    for (final ch in chapters) {
      _chapters[_chapterKey(ch.bookId, ch.id)] = ch;
    }
  }

  Future<List<ChapterRow>> getChaptersByBookId(String bookId) async {
    final result = _chapters.values.where((c) => c.bookId == bookId).toList();
    result.sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    return result;
  }

  Future<ChapterRow?> getChapter(String bookId, String chapterId) async {
    return _chapters[_chapterKey(bookId, chapterId)];
  }

  Future<void> updateChapterContent(
    String bookId,
    String chapterId,
    String content,
  ) async {
    final key = _chapterKey(bookId, chapterId);
    final existing = _chapters[key];
    if (existing == null) return;

    _chapters[key] = ChapterRow(
      id: existing.id,
      bookId: existing.bookId,
      title: existing.title,
      chapterIndex: existing.chapterIndex,
      content: content,
      cached: true,
    );
  }

  Future<void> clearAllData() async {
    _chapters.clear();
    _books.clear();
  }

  String _chapterKey(String bookId, String chapterId) => '$bookId::$chapterId';
}

class BookRow {
  const BookRow({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.author,
    this.coverUrl,
    this.description = '',
  });

  final String id;
  final String sourceId;
  final String title;
  final String author;
  final String? coverUrl;
  final String description;
}

class ChapterRow {
  const ChapterRow({
    required this.id,
    required this.bookId,
    required this.title,
    required this.chapterIndex,
    this.content,
    this.cached = false,
  });

  final String id;
  final String bookId;
  final String title;
  final int chapterIndex;
  final String? content;
  final bool cached;
}
