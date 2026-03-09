import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dir.path, 'floc_reader.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// 使用 drift 底层 API + 原生 SQL，无需代码生成
class AppDatabase extends GeneratedDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement('''
        CREATE TABLE IF NOT EXISTS books (
          id TEXT PRIMARY KEY,
          source_id TEXT NOT NULL DEFAULT 'hetushu',
          title TEXT NOT NULL,
          author TEXT NOT NULL,
          cover_url TEXT,
          description TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        )
      ''');
      await customStatement('''
        CREATE TABLE IF NOT EXISTS chapters (
          id TEXT NOT NULL,
          book_id TEXT NOT NULL,
          title TEXT NOT NULL,
          chapter_index INTEGER NOT NULL,
          content TEXT,
          cached INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (id, book_id),
          FOREIGN KEY (book_id) REFERENCES books(id)
        )
      ''');
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v1 → v2: 重建表以加入 source_id
        await customStatement('DROP TABLE IF EXISTS chapters');
        await customStatement('DROP TABLE IF EXISTS books');
        await customStatement('''
          CREATE TABLE books (
            id TEXT PRIMARY KEY,
            source_id TEXT NOT NULL DEFAULT 'hetushu',
            title TEXT NOT NULL,
            author TEXT NOT NULL,
            cover_url TEXT,
            description TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');
        await customStatement('''
          CREATE TABLE chapters (
            id TEXT NOT NULL,
            book_id TEXT NOT NULL,
            title TEXT NOT NULL,
            chapter_index INTEGER NOT NULL,
            content TEXT,
            cached INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (id, book_id),
            FOREIGN KEY (book_id) REFERENCES books(id)
          )
        ''');
      }
    },
  );

  // ── books CRUD ──

  Future<void> upsertBook({
    required String id,
    required String sourceId,
    required String title,
    required String author,
    String? coverUrl,
    String description = '',
  }) {
    return customInsert(
      'INSERT OR REPLACE INTO books (id, source_id, title, author, cover_url, description) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString(sourceId),
        Variable.withString(title),
        Variable.withString(author),
        Variable(coverUrl),
        Variable.withString(description),
      ],
      updates: {},
    );
  }

  Future<List<BookRow>> getAllBooks() async {
    final rows = await customSelect(
      'SELECT * FROM books ORDER BY created_at DESC',
    ).get();
    return rows.map(BookRow.fromRow).toList();
  }

  Future<BookRow?> getBookById(String id) async {
    final rows = await customSelect(
      'SELECT * FROM books WHERE id = ?',
      variables: [Variable.withString(id)],
    ).get();
    if (rows.isEmpty) return null;
    return BookRow.fromRow(rows.first);
  }

  // ── chapters CRUD ──

  Future<void> upsertChapters(List<ChapterRow> chapters) async {
    await batch((b) {
      for (final ch in chapters) {
        b.customStatement(
          'INSERT OR REPLACE INTO chapters (id, book_id, title, chapter_index, content, cached) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [
            ch.id,
            ch.bookId,
            ch.title,
            ch.chapterIndex,
            ch.content,
            ch.cached ? 1 : 0,
          ],
        );
      }
    });
  }

  Future<List<ChapterRow>> getChaptersByBookId(String bookId) async {
    final rows = await customSelect(
      'SELECT * FROM chapters WHERE book_id = ? ORDER BY chapter_index',
      variables: [Variable.withString(bookId)],
    ).get();
    return rows.map(ChapterRow.fromRow).toList();
  }

  Future<ChapterRow?> getChapter(String bookId, String chapterId) async {
    final rows = await customSelect(
      'SELECT * FROM chapters WHERE book_id = ? AND id = ?',
      variables: [Variable.withString(bookId), Variable.withString(chapterId)],
    ).get();
    if (rows.isEmpty) return null;
    return ChapterRow.fromRow(rows.first);
  }

  Future<void> updateChapterContent(
    String bookId,
    String chapterId,
    String content,
  ) {
    return customUpdate(
      'UPDATE chapters SET content = ?, cached = 1 WHERE book_id = ? AND id = ?',
      variables: [
        Variable.withString(content),
        Variable.withString(bookId),
        Variable.withString(chapterId),
      ],
      updates: {},
      updateKind: UpdateKind.update,
    );
  }

  Future<void> clearAllData() async {
    await customStatement('DELETE FROM chapters');
    await customStatement('DELETE FROM books');
  }
}

// ── 行映射类 ──

class BookRow {
  const BookRow({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.author,
    this.coverUrl,
    this.description = '',
  });

  factory BookRow.fromRow(QueryRow row) {
    return BookRow(
      id: row.read<String>('id'),
      sourceId: row.read<String>('source_id'),
      title: row.read<String>('title'),
      author: row.read<String>('author'),
      coverUrl: row.readNullable<String>('cover_url'),
      description: row.read<String>('description'),
    );
  }

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

  factory ChapterRow.fromRow(QueryRow row) {
    return ChapterRow(
      id: row.read<String>('id'),
      bookId: row.read<String>('book_id'),
      title: row.read<String>('title'),
      chapterIndex: row.read<int>('chapter_index'),
      content: row.readNullable<String>('content'),
      cached: row.read<int>('cached') == 1,
    );
  }

  final String id;
  final String bookId;
  final String title;
  final int chapterIndex;
  final String? content;
  final bool cached;
}
