import 'package:html/parser.dart' as html_parser;

import '../domain/source_adapter.dart';
import 'html_fetcher.dart';

class HetushuAdapter implements SourceAdapter {
  HetushuAdapter(this._fetcher);

  static const String _baseUrl = 'https://www.hetushu.com';

  final HtmlFetcher _fetcher;

  @override
  Future<List<SourceBook>> search(String keyword) async {
    // MVP 阶段暂不实现搜索
    return [];
  }

  @override
  Future<SourceBookDetail> getBookDetail(String bookId) async {
    final html = await _fetcher.fetch('$_baseUrl/book/$bookId/index.html');
    return _parseBookDetail(bookId, html);
  }

  @override
  Future<List<SourceChapter>> getChapters(String bookId) async {
    final html = await _fetcher.fetch('$_baseUrl/book/$bookId/index.html');
    return _parseChapters(bookId, html);
  }

  @override
  Future<SourceChapterContent> getChapterContent(
    String bookId,
    String chapterId,
  ) async {
    final html =
        await _fetcher.fetch('$_baseUrl/book/$bookId/$chapterId.html');
    return _parseChapterContent(chapterId, html);
  }

  SourceBookDetail _parseBookDetail(String bookId, String html) {
    final doc = html_parser.parse(html);

    // 从 <title> 提取书名和作者：格式 "书名_xxx_作者_和图书" 或类似
    final titleTag = doc.querySelector('title')?.text ?? '';
    final titleParts = titleTag.split('_');

    // 尝试多种选择器找书名
    String title = '';
    final h2 = doc.querySelector('.book_info h2, h2');
    if (h2 != null) {
      title = h2.text.trim();
    }
    if (title.isEmpty && titleParts.isNotEmpty) {
      title = titleParts.first
          .replaceAll('免费在线阅读', '')
          .replaceAll('全文阅读', '')
          .trim();
    }

    // 提取作者
    String author = '';
    final authorLink = doc.querySelector('a[href*="/author/"]');
    if (authorLink != null) {
      author = authorLink.text.trim();
    }
    if (author.isEmpty && titleParts.length >= 2) {
      author = titleParts[1].trim();
    }

    // 提取简介：通常在 .intro 或特定 div 里
    String description = '';
    final introElem = doc.querySelector('.intro, .book_info p, .book_des');
    if (introElem != null) {
      description = introElem.text.trim();
    }

    // 提取封面
    String? coverUrl;
    final coverImg = doc.querySelector('.book_info img, img[src*="cover"]');
    if (coverImg != null) {
      final src = coverImg.attributes['src'] ?? '';
      coverUrl = src.startsWith('http') ? src : '$_baseUrl$src';
    }

    return SourceBookDetail(
      id: bookId,
      title: title.isNotEmpty ? title : '未知书名',
      author: author.isNotEmpty ? author : '未知作者',
      description: description,
      coverUrl: coverUrl,
    );
  }

  List<SourceChapter> _parseChapters(String bookId, String html) {
    final doc = html_parser.parse(html);
    final chapters = <SourceChapter>[];

    // 匹配所有指向 /book/{bookId}/数字.html 的链接
    final pattern = RegExp('/book/$bookId/(\\d+)\\.html');
    final links = doc.querySelectorAll('a[href]');
    int index = 0;

    for (final link in links) {
      final href = link.attributes['href'] ?? '';
      final match = pattern.firstMatch(href);
      if (match != null) {
        final chapterId = match.group(1)!;
        final chapterTitle = link.text.trim();
        if (chapterTitle.isNotEmpty) {
          chapters.add(SourceChapter(
            id: chapterId,
            bookId: bookId,
            title: chapterTitle,
            index: index++,
          ));
        }
      }
    }

    return chapters;
  }

  SourceChapterContent _parseChapterContent(String chapterId, String html) {
    final doc = html_parser.parse(html);

    // 提取章节标题
    String title = '';
    final h2Elements = doc.querySelectorAll('h2');
    for (final h2 in h2Elements) {
      final text = h2.text.trim();
      if (text.contains('章') || text.contains('第')) {
        title = text;
        break;
      }
    }

    // 提取正文：通常在 #content 或 .content 或 .book_text
    String content = '';
    final contentElem =
        doc.querySelector('#content, .content, .book_text, .reader_content');
    if (contentElem != null) {
      content = contentElem.text.trim();
    } else {
      // 回退：取 body 中最长的文本块
      final allDivs = doc.querySelectorAll('div');
      int maxLen = 0;
      for (final div in allDivs) {
        final text = div.text.trim();
        if (text.length > maxLen && text.length > 200) {
          maxLen = text.length;
          content = text;
        }
      }
    }

    content = _cleanWatermarks(content);

    return SourceChapterContent(
      chapterId: chapterId,
      title: title,
      content: content,
    );
  }

  /// 清洗水印和广告文字
  String _cleanWatermarks(String text) {
    return text
        .replaceAll('和图书', '')
        .replaceAll('和-图-书', '')
        .replaceAll(RegExp(r'https?://[^\s，。！？]+'), '')
        .replaceAll(RegExp(r'[ｗＷwW]{2,3}[•．.·][^\s，。！？]+'), '')
        .replaceAll(RegExp(r'm\.heｔusｈｕ[^\s，。！？]*'), '')
        .replaceAll(RegExp(r'ｗwｗ[^\s，。！？]*'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
