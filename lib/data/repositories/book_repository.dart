import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/import/data/epub_book_parser.dart';
import '../../features/import/data/txt_book_parser.dart';
import '../../features/import/domain/local_book_parser.dart';
import '../local/app_database_platform.dart';

class BookRepository {
  BookRepository({
    required this.db,
    TxtBookParser? txtParser,
    EpubBookParser? epubParser,
  }) : _txtParser = txtParser ?? TxtBookParser(),
       _epubParser = epubParser ?? EpubBookParser();

  final AppDatabase db;
  final TxtBookParser _txtParser;
  final EpubBookParser _epubParser;

  /// 导入本地书籍（txt / epub）并写入本地库
  Future<ImportBookResult> importLocalBook({
    required String fileName,
    required Uint8List bytes,
    String sourceId = 'local',
    String? stableBookId,
    String? titleOverride,
  }) async {
    final parsed = _selectParser(
      fileName,
    ).parse(fileName: fileName, bytes: bytes);
    final bookId = stableBookId ?? _buildBookId(fileName, bytes);
    final resolvedTitle =
        (titleOverride != null && titleOverride.trim().isNotEmpty)
        ? titleOverride.trim()
        : parsed.title;
    await db.upsertBook(
      id: bookId,
      sourceId: sourceId,
      title: resolvedTitle,
      author: parsed.author,
      description: parsed.description,
    );

    final chapterRows = parsed.chapters
        .asMap()
        .entries
        .map(
          (entry) => ChapterRow(
            id: (entry.key + 1).toString(),
            bookId: bookId,
            title: entry.value.title,
            chapterIndex: entry.key,
            content: entry.value.content,
            cached: true,
          ),
        )
        .toList();
    await db.upsertChapters(chapterRows);

    final totalChars = parsed.chapters.fold<int>(
      0,
      (sum, chapter) => sum + chapter.content.length,
    );
    return ImportBookResult(
      bookId: bookId,
      title: resolvedTitle,
      chapterCount: chapterRows.length,
      totalChars: totalChars,
    );
  }

  Future<bool> existsBySourceId(String sourceId) async {
    final books = await db.getAllBooks();
    return books.any((book) => book.sourceId == sourceId);
  }

  Future<void> clearLocalCache() async {
    await db.clearAllData();

    if (kIsWeb) return;
    final docsDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(
      p.join(docsDir.path, 'floc_reader_library', 'books'),
    );
    if (await booksDir.exists()) {
      await booksDir.delete(recursive: true);
    }
  }

  LocalBookParser _selectParser(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.txt':
        return _txtParser;
      case '.epub':
        return _epubParser;
      default:
        throw UnsupportedError('暂不支持的文件格式: $ext');
    }
  }

  String _buildBookId(String fileName, Uint8List bytes) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hash = Object.hash(
      fileName,
      bytes.length,
      bytes.hashCode,
    ).toUnsigned(32);
    return 'local_${now}_$hash';
  }

  /// 本地书籍列表
  Future<List<BookRow>> getLocalBooks() => db.getAllBooks();

  /// 本地章节列表
  Future<List<ChapterRow>> getLocalChapters(String bookId) =>
      db.getChaptersByBookId(bookId);

  /// 单章信息
  Future<ChapterRow?> getLocalChapter(String bookId, String chapterId) =>
      db.getChapter(bookId, chapterId);

  /// 获取章节内容：纯本地模式下仅从本地读取
  Future<String> getChapterContent(String bookId, String chapterId) async {
    final chapter = await db.getChapter(bookId, chapterId);
    if (chapter == null) {
      throw StateError('章节不存在，请重新导入书籍');
    }
    if (chapter.content == null || chapter.content!.trim().isEmpty) {
      throw StateError('章节内容为空，请重新导入书籍');
    }
    return chapter.content!;
  }
}

class ImportBookResult {
  const ImportBookResult({
    required this.bookId,
    required this.title,
    required this.chapterCount,
    required this.totalChars,
  });

  final String bookId;
  final String title;
  final int chapterCount;
  final int totalChars;
}
