import 'dart:typed_data';

class ParsedLocalBook {
  const ParsedLocalBook({
    required this.title,
    required this.author,
    required this.description,
    required this.chapters,
    this.coverBytes,
    this.coverMediaType,
  });

  final String title;
  final String author;
  final String description;
  final List<ParsedLocalChapter> chapters;
  final Uint8List? coverBytes;
  final String? coverMediaType;
}

class ParsedLocalChapter {
  const ParsedLocalChapter({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;
}

abstract class LocalBookParser {
  ParsedLocalBook parse({
    required String fileName,
    required Uint8List bytes,
  });
}
