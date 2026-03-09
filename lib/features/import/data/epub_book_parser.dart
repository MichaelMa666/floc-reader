import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../domain/local_book_parser.dart';

class EpubBookParser implements LocalBookParser {
  static final RegExp _chapterLinePattern = RegExp(
    r'^\s*((第[0-9一二三四五六七八九十百千万零两〇\d]{1,8}[章节回卷部篇集].*)|([0-9]{1,4}[.、]\s*.+))\s*$',
  );
  static final RegExp _bracketHeadingPattern = RegExp(
    r'^[【\[]\s*[^【】\[\]]{1,80}\s*[】\]]$',
  );
  static final RegExp _leadingBracketHeadingPattern = RegExp(
    r'^([【\[]\s*[^【】\[\]]{1,80}\s*[】\]])\s*(.+)$',
  );

  @override
  ParsedLocalBook parse({required String fileName, required Uint8List bytes}) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = <String, ArchiveFile>{
      for (final file in archive.files.where((f) => f.isFile))
        _normalizePath(file.name): file,
    };

    final containerXml = _readTextFile(files, 'META-INF/container.xml');
    final opfPath = _readOpfPath(containerXml);
    final opfXml = _readTextFile(files, opfPath);
    final opfDoc = XmlDocument.parse(opfXml);
    final opfDir = p.posix.dirname(opfPath);

    final metadata = _readMetadata(opfDoc, fileName);
    final manifest = _readManifest(opfDoc, opfDir);
    final spine = _readSpine(opfDoc);

    final sections = <ParsedLocalChapter>[];
    for (var index = 0; index < spine.length; index++) {
      final manifestItem = manifest[spine[index]];
      if (manifestItem == null) continue;
      if (_isLikelyNonReadingItem(manifestItem)) {
        continue;
      }
      final chapterFile = files[manifestItem.href];
      if (chapterFile == null) continue;
      final chapterHtml = _decodeChapterText(chapterFile.content);
      final chapter = _parseChapter(
        chapterHtml,
        index + 1,
        bookTitle: metadata.title,
      );
      if (chapter.content.trim().isNotEmpty &&
          !_isLikelyNoiseSection(chapter.title, chapter.content)) {
        sections.add(chapter);
      }
    }

    final chapters = _splitSectionsByHeadings(sections, bookTitle: metadata.title);
    if (chapters.isEmpty) {
      throw FormatException('EPUB 未解析到有效章节内容');
    }

    return ParsedLocalBook(
      title: metadata.title,
      author: metadata.author,
      description: metadata.description,
      chapters: chapters,
    );
  }

  String _readTextFile(Map<String, ArchiveFile> files, String path) {
    final normalizedPath = _normalizePath(path);
    final file = files[normalizedPath];
    if (file == null) {
      throw FormatException('EPUB 缺少文件: $normalizedPath');
    }
    return utf8.decode(file.content, allowMalformed: true);
  }

  String _readOpfPath(String containerXml) {
    final doc = XmlDocument.parse(containerXml);
    for (final element in doc.descendants.whereType<XmlElement>()) {
      if (element.name.local == 'rootfile') {
        final fullPath = element.getAttribute('full-path');
        if (fullPath != null && fullPath.trim().isNotEmpty) {
          return _normalizePath(fullPath.trim());
        }
      }
    }
    throw FormatException('EPUB container.xml 未找到 OPF 路径');
  }

  _EpubMetadata _readMetadata(XmlDocument opfDoc, String fileName) {
    String? title;
    String? author;
    String? description;

    for (final element in opfDoc.descendants.whereType<XmlElement>()) {
      final local = element.name.local;
      final text = _plainText(element.innerText);
      if (text.isEmpty) continue;
      if (local == 'title' && title == null) title = text;
      if (local == 'creator' && author == null) author = text;
      if (local == 'description' && description == null) description = text;
    }

    final fallbackTitle = _titleFromFileName(fileName);
    return _EpubMetadata(
      title: title ?? fallbackTitle,
      author: author ?? '未知作者',
      description: description ?? '来自本地 EPUB 导入',
    );
  }

  Map<String, _ManifestItem> _readManifest(XmlDocument opfDoc, String opfDir) {
    final manifest = <String, _ManifestItem>{};
    for (final element in opfDoc.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'item') continue;
      final id = element.getAttribute('id');
      final hrefRaw = element.getAttribute('href');
      if (id == null || hrefRaw == null) continue;
      final href = _resolvePath(opfDir, hrefRaw);
      final mediaType =
          (element.getAttribute('media-type') ?? '').trim().toLowerCase();
      final properties =
          (element.getAttribute('properties') ?? '').trim().toLowerCase();
      manifest[id] = _ManifestItem(
        href: href,
        mediaType: mediaType,
        properties: properties,
      );
    }
    return manifest;
  }

  List<String> _readSpine(XmlDocument opfDoc) {
    final spine = <String>[];
    for (final element in opfDoc.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'itemref') continue;
      final idref = element.getAttribute('idref');
      if (idref != null && idref.isNotEmpty) {
        spine.add(idref);
      }
    }
    return spine;
  }

  ParsedLocalChapter _parseChapter(
    String chapterHtml,
    int index, {
    required String bookTitle,
  }) {
    String? title;
    String content;
    try {
      final doc = XmlDocument.parse(chapterHtml);
      title = _extractTitleFromXml(doc);
      content = _extractContentFromXml(doc);
    } catch (_) {
      // 一些 EPUB 章节是宽松 HTML，不是严格 XML，使用兜底解析避免整本失败。
      title = _extractTitleLenient(chapterHtml);
      content = _extractContentLenient(chapterHtml);
    }
    content = _cleanupContent(content);
    final headingResult = _extractInlineHeading(content);
    final resolvedTitle = _resolveChapterTitle(
      explicitTitle: title,
      inlineHeading: headingResult.title,
      bookTitle: bookTitle,
      index: index,
    );
    final resolvedContent = headingResult.shouldStripLine
        ? headingResult.contentWithoutHeading
        : content;

    return ParsedLocalChapter(
      title: resolvedTitle,
      content: resolvedContent,
    );
  }

  _InlineHeadingResult _extractInlineHeading(String content) {
    final lines = content.split('\n');
    final searchLimit = lines.length < 6 ? lines.length : 6;
    for (var i = 0; i < searchLimit; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.length > 80) continue;
      final inlineMatch = _leadingBracketHeadingPattern.firstMatch(line);
      if (inlineMatch != null) {
        final heading = inlineMatch.group(1)?.trim();
        final remain = inlineMatch.group(2)?.trim() ?? '';
        if (heading != null && heading.isNotEmpty) {
          final rebuilt = <String>[
            ...lines.take(i),
            if (remain.isNotEmpty) remain,
            ...lines.skip(i + 1),
          ];
          final rebuiltContent = _cleanupContent(rebuilt.join('\n'));
          return _InlineHeadingResult(
            title: heading,
            shouldStripLine: true,
            contentWithoutHeading: rebuiltContent.isNotEmpty ? rebuiltContent : content,
          );
        }
      }
      if (!_bracketHeadingPattern.hasMatch(line) &&
          !_chapterLinePattern.hasMatch(line)) {
        continue;
      }
      final strippedLines = <String>[
        ...lines.take(i),
        ...lines.skip(i + 1),
      ];
      final strippedContent = _cleanupContent(strippedLines.join('\n'));
      return _InlineHeadingResult(
        title: line,
        shouldStripLine: strippedContent.isNotEmpty,
        contentWithoutHeading: strippedContent.isNotEmpty ? strippedContent : content,
      );
    }
    return _InlineHeadingResult(
      title: null,
      shouldStripLine: false,
      contentWithoutHeading: content,
    );
  }

  String _resolveChapterTitle({
    required String? explicitTitle,
    required String? inlineHeading,
    required String bookTitle,
    required int index,
  }) {
    if (inlineHeading != null && inlineHeading.trim().isNotEmpty) {
      return inlineHeading.trim();
    }
    final title = explicitTitle?.trim();
    if (title == null || title.isEmpty) {
      return '第$index章';
    }
    if (_looksLikeBookTitle(title, bookTitle)) {
      return '第$index章';
    }
    return title;
  }

  bool _looksLikeBookTitle(String title, String bookTitle) {
    final a = _normalizeForCompare(title);
    final b = _normalizeForCompare(bookTitle);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b;
  }

  String _normalizeForCompare(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'''[《》【】\[\]（）()·,，。:：;；!！?？"“”'`-]'''), '');
  }

  String _decodeChapterText(List<int> bytes) {
    final utf8Text = utf8.decode(bytes, allowMalformed: true);
    final hint = _detectEncodingHint(bytes, utf8Text);
    if (!_looksBrokenText(utf8Text)) {
      return utf8Text;
    }
    if (hint != null && _isGbkEncoding(hint)) {
      return gbk.decode(bytes);
    }
    final gbkText = gbk.decode(bytes);
    if (!_looksBrokenText(gbkText)) {
      return gbkText;
    }
    return utf8Text;
  }

  String? _detectEncodingHint(List<int> bytes, String utf8Text) {
    final header = utf8Text.length > 1024
        ? utf8Text.substring(0, 1024)
        : utf8Text;
    final xmlDecl = RegExp(
      r'''<\?xml[^>]*encoding=['"]([^'"]+)['"]''',
      caseSensitive: false,
    ).firstMatch(header);
    final metaCharset = RegExp(
      r'''<meta[^>]*charset=['"]?([^'"\s/>]+)''',
      caseSensitive: false,
    ).firstMatch(header);
    final contentTypeCharset = RegExp(
      r'''content=['"][^'"]*charset=([^'"\s;]+)''',
      caseSensitive: false,
    ).firstMatch(header);
    final hint =
        xmlDecl?.group(1) ?? metaCharset?.group(1) ?? contentTypeCharset?.group(1);
    if (hint != null && hint.trim().isNotEmpty) {
      return hint.trim().toLowerCase();
    }

    // UTF-8 解码严重损坏时，回退到字节级文本里再尝试提取编码声明。
    if (_looksBrokenText(utf8Text)) {
      final latinText = latin1.decode(bytes, allowInvalid: true);
      final latinHeader = latinText.length > 1024
          ? latinText.substring(0, 1024)
          : latinText;
      final latinXmlDecl = RegExp(
        r'''<\?xml[^>]*encoding=['"]([^'"]+)['"]''',
        caseSensitive: false,
      ).firstMatch(latinHeader);
      final latinMeta = RegExp(
        r'''<meta[^>]*charset=['"]?([^'"\s/>]+)''',
        caseSensitive: false,
      ).firstMatch(latinHeader);
      final latinHint = latinXmlDecl?.group(1) ?? latinMeta?.group(1);
      if (latinHint != null && latinHint.trim().isNotEmpty) {
        return latinHint.trim().toLowerCase();
      }
    }
    return null;
  }

  bool _isGbkEncoding(String encoding) {
    return encoding.contains('gbk') ||
        encoding.contains('gb2312') ||
        encoding.contains('gb18030');
  }

  bool _looksBrokenText(String text) {
    if (text.isEmpty) return false;
    final replacementCount = '�'.allMatches(text).length;
    final ratio = replacementCount / text.length;
    return replacementCount >= 8 && ratio > 0.01;
  }

  bool _isLikelyNonReadingItem(_ManifestItem item) {
    if (item.mediaType.contains('ncx')) return true;
    if (item.mediaType == 'application/oebps-page-map+xml') return true;
    if (item.properties.contains('nav')) return true;

    final name = p.posix.basename(item.href).toLowerCase();
    const noisyNameHints = <String>[
      'toc',
      'nav',
      'cover',
      'titlepage',
      'copyright',
      'colophon',
    ];
    return noisyNameHints.any((hint) => name.contains(hint));
  }

  bool _isLikelyNoiseSection(String title, String content) {
    final compactTitle = title.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final compactContent = content.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    const noiseKeywords = <String>[
      '目录',
      'contents',
      '版权',
      'copyright',
      '封面',
      'titlepage',
      'navigation',
    ];
    final hitNoiseTitle = noiseKeywords.any(
      (keyword) => compactTitle.contains(keyword),
    );
    final hitNoiseContent = noiseKeywords.any(
      (keyword) => compactContent.contains(keyword),
    );
    if (hitNoiseTitle && content.length < 2000) return true;
    if (hitNoiseContent && content.length < 500) return true;
    return false;
  }

  List<ParsedLocalChapter> _splitSectionsByHeadings(
    List<ParsedLocalChapter> sections,
    {required String bookTitle}
  ) {
    final chapters = <ParsedLocalChapter>[];
    var fallbackIndex = 1;

    for (final section in sections) {
      final lines = section.content.split('\n');
      final buffer = <String>[];
      String currentTitle = section.title.trim().isEmpty
          ? '第$fallbackIndex章'
          : section.title.trim();
      if (_looksLikeBookTitle(currentTitle, bookTitle)) {
        currentTitle = '第$fallbackIndex章';
      }

      void flush() {
        final content = _cleanupContent(buffer.join('\n'));
        buffer.clear();
        if (content.isEmpty) return;
        chapters.add(ParsedLocalChapter(title: currentTitle, content: content));
        fallbackIndex++;
      }

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          buffer.add(line);
          continue;
        }
        final inlineMatch = _leadingBracketHeadingPattern.firstMatch(trimmed);
        if (inlineMatch != null) {
          flush();
          currentTitle = inlineMatch.group(1)!.trim();
          final remain = inlineMatch.group(2)?.trim() ?? '';
          if (remain.isNotEmpty) {
            buffer.add(remain);
          }
          continue;
        }
        if (_bracketHeadingPattern.hasMatch(trimmed) ||
            _chapterLinePattern.hasMatch(trimmed)) {
          flush();
          currentTitle = trimmed;
          continue;
        }
        buffer.add(line);
      }
      flush();
    }

    return chapters;
  }

  String? _extractTitleFromXml(XmlDocument doc) {
    for (final element in doc.descendants.whereType<XmlElement>()) {
      final local = element.name.local;
      if (local == 'h1' || local == 'h2' || local == 'h3') {
        final text = _plainText(element.innerText);
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  String _extractContentFromXml(XmlDocument doc) {
    final contentBuffer = StringBuffer();
    for (final element in doc.descendants.whereType<XmlElement>()) {
      if (element.name.local == 'body') {
        _collectElementText(element, contentBuffer);
        break;
      }
    }
    return contentBuffer.toString();
  }

  String? _extractTitleLenient(String html) {
    final patterns = <RegExp>[
      RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false, dotAll: true),
      RegExp(r'<h2[^>]*>(.*?)</h2>', caseSensitive: false, dotAll: true),
      RegExp(r'<h3[^>]*>(.*?)</h3>', caseSensitive: false, dotAll: true),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match == null) continue;
      final text = _stripTags(match.group(1) ?? '');
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String _extractContentLenient(String html) {
    final bodyMatch = RegExp(
      r'<body[^>]*>([\s\S]*?)</body>',
      caseSensitive: false,
    ).firstMatch(html);
    var fragment = bodyMatch?.group(1) ?? html;
    fragment = fragment.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );
    fragment = fragment.replaceAll(
      RegExp(r'</(p|div|section|article|li|h[1-6])>', caseSensitive: false),
      '\n',
    );
    return _stripTags(fragment);
  }

  String _stripTags(String input) {
    final withoutTags = input.replaceAll(RegExp(r'<[^>]+>'), ' ');
    final decoded = _decodeHtmlEntities(
      withoutTags,
    ).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = decoded
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return lines.join('\n');
  }

  void _collectElementText(XmlElement element, StringBuffer buffer) {
    const blockTags = <String>{
      'p',
      'div',
      'section',
      'article',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'li',
      'br',
    };
    const ignoredTags = <String>{'script', 'style', 'head'};

    final local = element.name.local;
    if (ignoredTags.contains(local)) return;

    if (local == 'br') {
      buffer.writeln();
      return;
    }

    if (blockTags.contains(local)) {
      buffer.writeln();
    }

    for (final node in element.children) {
      if (node is XmlText) {
        final text = _plainText(node.value);
        if (text.isNotEmpty) {
          buffer.write(text);
        }
      } else if (node is XmlCDATA) {
        final text = _plainText(node.value);
        if (text.isNotEmpty) {
          buffer.write(text);
        }
      } else if (node is XmlElement) {
        _collectElementText(node, buffer);
      }
    }

    if (blockTags.contains(local)) {
      buffer.writeln();
    }
  }

  String _cleanupContent(String content) {
    final lines = content
        .split('\n')
        .map(_normalizeLine)
        .where((line) => line.isNotEmpty)
        .toList();
    return lines.join('\n');
  }

  String _normalizeLine(String line) {
    return _decodeHtmlEntities(
      line,
    ).replaceAll('\u00a0', ' ').replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  String _plainText(String input) {
    return _decodeHtmlEntities(input.replaceAll(RegExp(r'\s+'), ' ')).trim();
  }

  String _decodeHtmlEntities(String input) {
    return _decodeNumericEntities(
      input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'"),
    );
  }

  String _decodeNumericEntities(String input) {
    return input.replaceAllMapped(RegExp(r'&#(x?[0-9a-fA-F]+);'), (match) {
      final value = match.group(1);
      if (value == null || value.isEmpty) return match.group(0) ?? '';
      int? codePoint;
      if (value.startsWith('x') || value.startsWith('X')) {
        codePoint = int.tryParse(value.substring(1), radix: 16);
      } else {
        codePoint = int.tryParse(value);
      }
      if (codePoint == null || codePoint <= 0 || codePoint > 0x10FFFF) {
        return match.group(0) ?? '';
      }
      return String.fromCharCode(codePoint);
    });
  }

  String _titleFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot > 0) {
      return fileName.substring(0, dot).trim();
    }
    return fileName.trim().isEmpty ? '未命名书籍' : fileName.trim();
  }

  String _resolvePath(String baseDir, String href) {
    final clean = href.split('#').first.split('?').first;
    return _normalizePath(p.posix.normalize(p.posix.join(baseDir, clean)));
  }

  String _normalizePath(String path) {
    return path.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), '');
  }
}

class _EpubMetadata {
  const _EpubMetadata({
    required this.title,
    required this.author,
    required this.description,
  });

  final String title;
  final String author;
  final String description;
}

class _ManifestItem {
  const _ManifestItem({
    required this.href,
    required this.mediaType,
    required this.properties,
  });

  final String href;
  final String mediaType;
  final String properties;
}

class _InlineHeadingResult {
  const _InlineHeadingResult({
    required this.title,
    required this.shouldStripLine,
    required this.contentWithoutHeading,
  });

  final String? title;
  final bool shouldStripLine;
  final String contentWithoutHeading;
}
