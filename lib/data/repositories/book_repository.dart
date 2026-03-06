import '../local/app_database.dart';
import '../../features/source/domain/source_registry.dart';

class BookRepository {
  BookRepository({required this.registry, required this.db});

  final SourceRegistry registry;
  final AppDatabase db;

  /// 从网络抓取书籍详情 + 章节列表，写入本地库
  Future<void> fetchAndCacheBook(String sourceId, String bookId) async {
    final adapter = registry.getAdapter(sourceId);

    final detail = await adapter.getBookDetail(bookId);
    await db.upsertBook(
      id: detail.id,
      sourceId: sourceId,
      title: detail.title,
      author: detail.author,
      coverUrl: detail.coverUrl,
      description: detail.description,
    );

    final chapters = await adapter.getChapters(bookId);
    final chapterRows = chapters
        .map((c) => ChapterRow(
              id: c.id,
              bookId: c.bookId,
              title: c.title,
              chapterIndex: c.index,
            ))
        .toList();
    await db.upsertChapters(chapterRows);
  }

  /// 抓取并缓存单章正文
  Future<String> fetchAndCacheChapterContent(
    String sourceId,
    String bookId,
    String chapterId,
  ) async {
    final adapter = registry.getAdapter(sourceId);
    final result = await adapter.getChapterContent(bookId, chapterId);
    await db.updateChapterContent(bookId, chapterId, result.content);
    return result.content;
  }

  /// 本地书籍列表
  Future<List<BookRow>> getLocalBooks() => db.getAllBooks();

  /// 本地章节列表
  Future<List<ChapterRow>> getLocalChapters(String bookId) =>
      db.getChaptersByBookId(bookId);

  /// 获取章节内容：优先本地，未缓存则通过对应书源抓取
  Future<String> getChapterContent(
    String sourceId,
    String bookId,
    String chapterId,
  ) async {
    final chapter = await db.getChapter(bookId, chapterId);
    if (chapter != null && chapter.cached && chapter.content != null) {
      return chapter.content!;
    }
    return fetchAndCacheChapterContent(sourceId, bookId, chapterId);
  }
}
