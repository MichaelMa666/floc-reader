import 'package:html/parser.dart' as html_parser;

import '../domain/source_adapter.dart';
import 'html_fetcher.dart';

/// 笔趣阁 (biquge.tw) 书源适配器
class BiqugeAdapter implements SourceAdapter {
  BiqugeAdapter(this._fetcher);

  static const String _baseUrl = 'https://www.biquge.tw';

  final HtmlFetcher _fetcher;

  @override
  Future<List<SourceBook>> search(String keyword) async {
    return [];
  }

  @override
  Future<SourceBookDetail> getBookDetail(String bookId) async {
    final html = await _fetcher.fetch('$_baseUrl/book/$bookId/');
    return _parseBookDetail(bookId, html);
  }

  @override
  Future<List<SourceChapter>> getChapters(String bookId) async {
    final html = await _fetcher.fetch('$_baseUrl/book/$bookId/');
    return _parseChapters(bookId, html);
  }

  @override
  Future<SourceChapterContent> getChapterContent(
    String bookId,
    String chapterId,
  ) async {
    // 笔趣阁章节可能分页，需要拼接所有页
    final allContent = StringBuffer();
    String title = '';

    int page = 1;
    while (true) {
      final suffix = page == 1 ? '' : '_$page';
      final url = '$_baseUrl/book/$bookId/$chapterId$suffix.html';

      String html;
      try {
        html = await _fetcher.fetch(url);
      } catch (_) {
        break;
      }

      final doc = html_parser.parse(html);

      if (page == 1) {
        // 从第一页提取标题
        final h1 = doc.querySelector('h1');
        if (h1 != null) {
          title = h1.text.trim();
          // 去掉分页标记 "（1 / 2）"
          title = title.replaceAll(RegExp(r'[（(]\d+\s*/\s*\d+[）)]'), '').trim();
        }
      }

      final contentElem = doc.querySelector('#content, .content, .readcontent');
      if (contentElem != null) {
        allContent.write(contentElem.text.trim());
        allContent.write('\n');
      } else {
        // 没找到内容元素，取最长文本块
        final allDivs = doc.querySelectorAll('div');
        String longest = '';
        for (final div in allDivs) {
          final text = div.text.trim();
          if (text.length > longest.length && text.length > 200) {
            longest = text;
          }
        }
        if (longest.isNotEmpty) {
          allContent.write(longest);
          allContent.write('\n');
        }
      }

      // 检查是否有下一页
      final hasNextPage = doc.querySelectorAll('a').any((a) {
        final href = a.attributes['href'] ?? '';
        return href.contains('${chapterId}_${page + 1}.html');
      });

      if (!hasNextPage) break;
      page++;
    }

    return SourceChapterContent(
      chapterId: chapterId,
      title: title,
      content: _cleanWatermarks(allContent.toString()),
    );
  }

  SourceBookDetail _parseBookDetail(String bookId, String html) {
    final doc = html_parser.parse(html);

    final titleTag = doc.querySelector('title')?.text ?? '';

    // 书名：h1 标签，或从 <title> 提取
    String title = '';
    final h1 = doc.querySelector('h1');
    if (h1 != null) {
      title = h1.text
          .replaceAll('在线阅读', '')
          .replaceAll('最新章节', '')
          .trim();
    }
    if (title.isEmpty) {
      title = titleTag.split(RegExp(r'[_\-]')).first.trim();
    }

    // 作者：从 h2 "小说夏忆 162万字 全本" 中提取
    String author = '';
    final h2 = doc.querySelector('h2');
    if (h2 != null) {
      final h2Text = h2.text.trim();
      // 格式："小说夏忆 162万字 全本"
      final match = RegExp(r'小说(.+?)\s').firstMatch(h2Text);
      if (match != null) {
        author = match.group(1)!.trim();
      }
    }

    // 简介：通常在 .intro 或特定元素中
    String description = '';
    final introElem = doc.querySelector('.intro, .book_info p, .book_des');
    if (introElem != null) {
      description = introElem.text.trim();
    }

    // 封面
    String? coverUrl;
    final coverImg = doc.querySelector('img[src*="cover"], .book_info img');
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

    // 匹配 /book/{bookId}/{chapterId}.html
    final pattern = RegExp('/book/$bookId/(\\d+)\\.html');
    final links = doc.querySelectorAll('a[href]');

    for (final link in links) {
      final href = link.attributes['href'] ?? '';
      final match = pattern.firstMatch(href);
      if (match != null) {
        final chapterId = match.group(1)!;
        final chapterTitle = link.text.trim();
        if (chapterTitle.isNotEmpty) {
          // 去重
          final exists = chapters.any((c) => c.id == chapterId);
          if (!exists) {
            chapters.add(SourceChapter(
              id: chapterId,
              bookId: bookId,
              title: chapterTitle,
              index: 0, // 稍后重新编号
            ));
          }
        }
      }
    }

    // 笔趣阁目录页章节是倒序的，翻转成正序并重新编号
    final reversed = chapters.reversed.toList();
    return [
      for (int i = 0; i < reversed.length; i++)
        SourceChapter(
          id: reversed[i].id,
          bookId: reversed[i].bookId,
          title: reversed[i].title,
          index: i,
        ),
    ];
  }

  String _cleanWatermarks(String text) {
    return text
        .replaceAll(RegExp(r'm\.[A-Za-z0-9]+\.[A-Za-z]{2,4}'), '')
        .replaceAll(RegExp(r'www\.[A-Za-z0-9]+\.[A-Za-z]{2,4}'), '')
        .replaceAll(RegExp(r'https?://[^\s，。！？]+'), '')
        .replaceAll('笔趣阁', '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
