import 'dart:convert';
import 'dart:typed_data';

import '../domain/local_book_parser.dart';

class TxtBookParser implements LocalBookParser {
  static final RegExp _chapterTitlePattern = RegExp(
    r'^\s*(第[0-9一二三四五六七八九十百千万零两〇\d\s\-_、.]{1,20}[章节回卷部篇集].*)\s*$',
  );

  @override
  ParsedLocalBook parse({
    required String fileName,
    required Uint8List bytes,
  }) {
    final rawText = _decode(bytes);
    final normalized = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final title = _extractTitle(fileName);
    final chapters = _splitChapters(normalized);

    return ParsedLocalBook(
      title: title,
      author: '本地导入',
      description: '来自本地文件导入',
      chapters: chapters,
    );
  }

  String _decode(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  String _extractTitle(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot > 0) {
      return fileName.substring(0, dot).trim();
    }
    final trimmed = fileName.trim();
    return trimmed.isEmpty ? '未命名书籍' : trimmed;
  }

  List<ParsedLocalChapter> _splitChapters(String text) {
    final lines = text.split('\n');
    final chapters = <ParsedLocalChapter>[];
    String? currentTitle;
    final buffer = StringBuffer();

    void flush() {
      final content = buffer.toString().trim();
      if (content.isEmpty) {
        buffer.clear();
        return;
      }

      final title = currentTitle ?? '正文';
      chapters.add(ParsedLocalChapter(title: title, content: content));
      buffer.clear();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (_chapterTitlePattern.hasMatch(trimmed)) {
        flush();
        currentTitle = trimmed;
      } else {
        buffer.writeln(line);
      }
    }
    flush();

    if (chapters.isNotEmpty) {
      return chapters;
    }

    return _splitByLength(text.trim(), chunkSize: 3000);
  }

  List<ParsedLocalChapter> _splitByLength(String text, {required int chunkSize}) {
    if (text.isEmpty) {
      return const <ParsedLocalChapter>[
        ParsedLocalChapter(title: '正文', content: ''),
      ];
    }

    final result = <ParsedLocalChapter>[];
    var start = 0;
    var index = 1;
    while (start < text.length) {
      final end = (start + chunkSize < text.length)
          ? start + chunkSize
          : text.length;
      final content = text.substring(start, end).trim();
      if (content.isNotEmpty) {
        result.add(
          ParsedLocalChapter(
            title: '第$index段',
            content: content,
          ),
        );
      }
      start = end;
      index++;
    }
    return result;
  }
}
