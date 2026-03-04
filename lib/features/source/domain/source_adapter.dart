abstract class SourceAdapter {
  Future<List<SourceBook>> search(String keyword);

  Future<SourceBookDetail> getBookDetail(String bookId);

  Future<List<SourceChapter>> getChapters(String bookId);

  Future<String> getChapterContent(String chapterId);
}

class SourceBook {
  const SourceBook({
    required this.id,
    required this.title,
    required this.author,
  });

  final String id;
  final String title;
  final String author;
}

class SourceBookDetail {
  const SourceBookDetail({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
  });

  final String id;
  final String title;
  final String author;
  final String description;
}

class SourceChapter {
  const SourceChapter({
    required this.id,
    required this.title,
    required this.index,
  });

  final String id;
  final String title;
  final int index;
}
