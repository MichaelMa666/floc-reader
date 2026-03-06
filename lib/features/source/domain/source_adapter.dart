abstract class SourceAdapter {
  Future<List<SourceBook>> search(String keyword);

  Future<SourceBookDetail> getBookDetail(String bookId);

  Future<List<SourceChapter>> getChapters(String bookId);

  Future<SourceChapterContent> getChapterContent(
    String bookId,
    String chapterId,
  );
}

class SourceBook {
  const SourceBook({
    required this.id,
    required this.title,
    required this.author,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String author;
  final String? coverUrl;
}

class SourceBookDetail {
  const SourceBookDetail({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String author;
  final String description;
  final String? coverUrl;
}

class SourceChapter {
  const SourceChapter({
    required this.id,
    required this.bookId,
    required this.title,
    required this.index,
  });

  final String id;
  final String bookId;
  final String title;
  final int index;
}

class SourceChapterContent {
  const SourceChapterContent({
    required this.chapterId,
    required this.title,
    required this.content,
  });

  final String chapterId;
  final String title;
  final String content;
}
