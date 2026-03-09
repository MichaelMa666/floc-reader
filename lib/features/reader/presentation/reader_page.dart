import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/local/app_database_platform.dart';
import '../../../shared/providers/app_providers.dart';

class ReaderPage extends ConsumerWidget {
  const ReaderPage({super.key, required this.bookId, required this.chapterId});

  final String bookId;
  final String chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ReaderContent(bookId: bookId, chapterId: chapterId);
  }
}

class _ReaderContent extends ConsumerStatefulWidget {
  const _ReaderContent({required this.bookId, required this.chapterId});

  final String bookId;
  final String chapterId;

  @override
  ConsumerState<_ReaderContent> createState() => _ReaderContentState();
}

class _ReaderContentState extends ConsumerState<_ReaderContent> {
  static const EdgeInsets _pagePadding = EdgeInsets.fromLTRB(20, 10, 20, 0);
  static const TextStyle _bodyStyle = TextStyle(fontSize: 18, height: 1.8);
  static const double _paginationSafetyBottom = 0;
  static const StrutStyle _bodyStrut = StrutStyle(
    fontSize: 18,
    height: 1.8,
    forceStrutHeight: true,
    leading: 0,
  );
  static const TextHeightBehavior _textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: true,
    applyHeightToLastDescent: false,
  );

  PageController? _pageController;
  String _paginationSignature = '';
  List<String> _pages = const <String>[];
  int _currentPage = 0;
  int _lastSavedPercent = 0;
  int _initialPercent = 0;
  bool _initialPercentLoaded = false;
  int _restoreToken = 0;
  bool _isChapterNavigating = false;

  @override
  void initState() {
    super.initState();
    _loadInitialPercent();
  }

  @override
  void didUpdateWidget(covariant _ReaderContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId ||
        oldWidget.chapterId != widget.chapterId) {
      _lastSavedPercent = 0;
      _initialPercent = 0;
      _initialPercentLoaded = false;
      _isChapterNavigating = false;
      _paginationSignature = '';
      _pages = const <String>[];
      _currentPage = 0;
      _disposePageController();
      _loadInitialPercent();
    }
  }

  @override
  void dispose() {
    _disposePageController();
    super.dispose();
  }

  Future<void> _savePercent(int percent) async {
    if (percent <= _lastSavedPercent) return;
    _lastSavedPercent = percent;
    await ref
        .read(readingRepositoryProvider)
        .saveChapterReadPercent(
          bookId: widget.bookId,
          chapterId: widget.chapterId,
          percent: percent,
        );
    ref.invalidate(chapterReadPercentMapProvider(widget.bookId));
  }

  Future<void> _loadInitialPercent() async {
    final token = ++_restoreToken;
    final map = await ref
        .read(readingRepositoryProvider)
        .getChapterReadPercents(widget.bookId);
    if (!mounted || token != _restoreToken) return;
    final percent = (map[widget.chapterId] ?? 0).clamp(0, 100);
    setState(() {
      _initialPercent = percent;
      _initialPercentLoaded = true;
    });
  }

  void _disposePageController() {
    _pageController?.dispose();
    _pageController = null;
  }

  int _percentFromPage(int pageIndex, int totalPages) {
    if (totalPages <= 0) return 1;
    final raw = (((pageIndex + 1) / totalPages) * 100).round();
    return raw.clamp(1, 100);
  }

  int _pageFromPercent(int percent, int totalPages) {
    if (totalPages <= 1) return 0;
    final p = percent.clamp(0, 100) / 100.0;
    return (p * (totalPages - 1)).round().clamp(0, totalPages - 1);
  }

  List<String> _buildPages({
    required List<String> paragraphs,
    required String? inlineTitle,
    required double maxWidth,
    required double maxHeight,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required double devicePixelRatio,
  }) {
    final title = inlineTitle?.trim();
    final pieces = <String>[];
    if (title != null && title.isNotEmpty) {
      pieces.add(title);
    }
    pieces.addAll(paragraphs);
    final fullText = pieces.join('\n').trim();
    if (fullText.isEmpty || maxWidth <= 0 || maxHeight <= 0) {
      return const <String>[''];
    }

    final painter = TextPainter(
      textDirection: textDirection,
      textAlign: TextAlign.start,
      maxLines: null,
      textScaler: textScaler,
      strutStyle: _bodyStrut,
      textHeightBehavior: _textHeightBehavior,
    );
    final fitHeight = (maxHeight - (1 / devicePixelRatio)).clamp(
      1.0,
      maxHeight,
    );

    final pages = <String>[];
    var start = 0;
    while (start < fullText.length) {
      final remaining = fullText.substring(start);
      painter.text = TextSpan(text: remaining, style: _bodyStyle);
      painter.layout(maxWidth: maxWidth);

      if (painter.height <= fitHeight) {
        final lastPage = remaining.trimRight();
        if (lastPage.trim().isNotEmpty) {
          pages.add(lastPage);
        }
        break;
      }

      final lines = painter.computeLineMetrics();
      var lastLineIndex = -1;
      for (final line in lines) {
        final lineBottom = line.baseline + line.descent;
        if (lineBottom <= fitHeight) {
          lastLineIndex = line.lineNumber;
        } else {
          break;
        }
      }

      int localEndIndex;
      if (lastLineIndex >= 0) {
        final targetY =
            lines[lastLineIndex].baseline +
            lines[lastLineIndex].descent -
            (1 / devicePixelRatio);
        final pos = painter.getPositionForOffset(Offset(maxWidth, targetY));
        localEndIndex = painter.getLineBoundary(pos).end;
        if (localEndIndex <= 0) {
          localEndIndex = pos.offset;
        }
      } else {
        localEndIndex = painter.getPositionForOffset(
          Offset(maxWidth, fitHeight),
        ).offset;
      }
      if (localEndIndex <= 0) {
        localEndIndex = 1;
      }

      var cut = start + localEndIndex;
      if (cut <= start) {
        cut = start + 1;
      }

      final pageText = fullText.substring(start, cut).trimRight();
      if (pageText.trim().isNotEmpty) {
        pages.add(pageText);
      }
      start = cut;
      while (start < fullText.length && fullText[start] == '\n') {
        start++;
      }
    }

    return pages.isEmpty ? const <String>[''] : pages;
  }

  void _preparePagination({
    required List<String> paragraphs,
    required String? inlineTitle,
    required double maxWidth,
    required double maxHeight,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required double devicePixelRatio,
  }) {
    final signature =
        '${widget.bookId}|${widget.chapterId}|${paragraphs.length}|${inlineTitle ?? ''}|${maxWidth.toStringAsFixed(1)}|${maxHeight.toStringAsFixed(1)}|${textScaler.scale(1).toStringAsFixed(2)}|$textDirection|${devicePixelRatio.toStringAsFixed(2)}|$_initialPercent';
    if (signature == _paginationSignature && _pageController != null) {
      return;
    }

    _paginationSignature = signature;
    _pages = _buildPages(
      paragraphs: paragraphs,
      inlineTitle: inlineTitle,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      textScaler: textScaler,
      textDirection: textDirection,
      devicePixelRatio: devicePixelRatio,
    );
    _currentPage = _pageFromPercent(_initialPercent, _pages.length);
    _disposePageController();
    _pageController = PageController(initialPage: _currentPage);

    final enteredPercent = _percentFromPage(_currentPage, _pages.length);
    _savePercent(enteredPercent);
  }

  Future<void> _goToAdjacentChapter(
    List<ChapterRow> chapters, {
    required bool next,
  }) async {
    if (_isChapterNavigating || chapters.isEmpty) return;
    final currentIndex = chapters.indexWhere((ch) => ch.id == widget.chapterId);
    if (currentIndex < 0) return;
    final targetIndex = next ? currentIndex + 1 : currentIndex - 1;
    if (targetIndex < 0 || targetIndex >= chapters.length) return;

    _isChapterNavigating = true;
    await _savePercent(100);
    if (!mounted) return;
    final targetChapterId = chapters[targetIndex].id;
    context.pushReplacement('/reader/${widget.bookId}/$targetChapterId');
  }

  bool _hasNextChapter(List<ChapterRow> chapters) {
    if (chapters.isEmpty) return false;
    final currentIndex = chapters.indexWhere((ch) => ch.id == widget.chapterId);
    if (currentIndex < 0) return false;
    return currentIndex < chapters.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final chapterInfoAsync = ref.watch(
      chapterInfoProvider((bookId: widget.bookId, chapterId: widget.chapterId)),
    );
    final chapterListAsync = ref.watch(chapterListProvider(widget.bookId));
    final contentAsync = ref.watch(
      chapterContentProvider((
        bookId: widget.bookId,
        chapterId: widget.chapterId,
      )),
    );
    final inlineTitle = chapterInfoAsync.maybeWhen(
      data: (chapter) {
        if (chapter == null) return null;
        final number = chapter.chapterIndex + 1;
        return '第$number章  ${chapter.title}';
      },
      orElse: () => null,
    );

    return Scaffold(
      body: contentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('加载失败: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (content) {
          if (!_initialPercentLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final chapters = chapterListAsync.maybeWhen(
            data: (value) => value,
            orElse: () => const <ChapterRow>[],
          );
          final paragraphs = _ReaderFormatter.toParagraphs(content);
          return SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pageWidth =
                    constraints.maxWidth - _pagePadding.horizontal;
                final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
                final unsafeBottom = MediaQuery.paddingOf(context).bottom;
                // 预留一点分页安全高度，避免最后一行落在边界时被裁切。
                final pageHeight =
                    constraints.maxHeight -
                    _pagePadding.vertical -
                    unsafeBottom -
                    _paginationSafetyBottom;
                final textScaler = MediaQuery.textScalerOf(context);
                final textDirection = Directionality.of(context);
                _preparePagination(
                  paragraphs: paragraphs,
                  inlineTitle: inlineTitle,
                  maxWidth: pageWidth,
                  maxHeight: pageHeight,
                  textScaler: textScaler,
                  textDirection: textDirection,
                  devicePixelRatio: devicePixelRatio,
                );
                final controller = _pageController;
                if (controller == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final hasNext = _hasNextChapter(chapters);
                final pageCount = hasNext ? _pages.length + 1 : _pages.length;

                return PageView.builder(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  onPageChanged: (index) {
                    _currentPage = index;
                    if (index >= _pages.length) {
                      _goToAdjacentChapter(chapters, next: true);
                      return;
                    }
                    _savePercent(_percentFromPage(index, _pages.length));
                  },
                  itemCount: pageCount,
                  itemBuilder: (context, index) {
                    if (index >= _pages.length) {
                      return const Center(
                        child: Text(
                          '继续阅读下一章',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }
                    return Padding(
                      padding: _pagePadding,
                      child: Text(
                        _pages[index],
                        style: _bodyStyle,
                        strutStyle: _bodyStrut,
                        textHeightBehavior: _textHeightBehavior,
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ReaderFormatter {
  static const String _indent = '\u3000\u3000';
  static final RegExp _blankLinePattern = RegExp(r'\n\s*\n+');
  static final RegExp _headingAnchorPattern = RegExp(
    r'([。！？；.!?])\s*(?=(第[0-9一二三四五六七八九十百千万零两〇\d]{1,8}[章节回卷部篇集]|[0-9]{1,3}[.、]))',
  );

  static List<String> toParagraphs(String raw) {
    final normalized = _cleanupNoise(
      raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
    ).trim();
    if (normalized.isEmpty) return const <String>[];

    final blocks = normalized
        .split(_blankLinePattern)
        .map(_mergeWrappedLines)
        .where((p) => p.isNotEmpty)
        .toList();

    final paragraphs = <String>[];
    for (final block in blocks) {
      if (_looksSingleHugeParagraph(block)) {
        paragraphs.addAll(_splitByPunctuation(block));
      } else {
        paragraphs.add(block);
      }
    }

    return paragraphs.map((p) => '$_indent$p').toList();
  }

  static String _mergeWrappedLines(String block) {
    var text = block
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .join();
    text = text.replaceAllMapped(
      _headingAnchorPattern,
      (m) => '${m.group(1)}\n',
    );
    return text;
  }

  static bool _looksSingleHugeParagraph(String text) {
    return text.length > 180 && !text.contains('\n');
  }

  static List<String> _splitByPunctuation(String text) {
    final out = <String>[];
    var buf = StringBuffer();
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(ch);
      var current = buf.toString();
      final shouldBreakAtPunctuation =
          (ch == '。' || ch == '！' || ch == '？' || ch == '；') &&
          current.length >= 80;
      if (shouldBreakAtPunctuation) {
        out.add(current.trim());
        buf = StringBuffer();
        continue;
      }
      if (current.length >= 180) {
        final softCut = _findLastSoftBreak(current);
        if (softCut != null && softCut >= 80) {
          out.add(current.substring(0, softCut).trim());
          final remain = current.substring(softCut).trimLeft();
          buf = StringBuffer()..write(remain);
          continue;
        }
      }
      // 兜底：极端长句没有任何可断点时，最多到 260 再硬切，避免一整屏不换段。
      if (current.length >= 260) {
        out.add(current.trim());
        buf = StringBuffer();
      }
    }
    final tail = buf.toString().trim();
    if (tail.isNotEmpty) out.add(tail);
    return out.where((p) => p.isNotEmpty).toList();
  }

  static int? _findLastSoftBreak(String text) {
    final punctuations = <String>{'，', '、', '；', '：', ',', ';', ':'};
    for (var i = text.length - 1; i >= 0; i--) {
      if (punctuations.contains(text[i])) {
        return i + 1;
      }
    }
    return null;
  }

  static String _cleanupNoise(String text) {
    var output = text;
    // 清理常见电子书声明，避免污染正文段落。
    output = output.replaceAll(
      RegExp(r'声明[:：][^。！？]*[。！？]?', caseSensitive: false),
      '',
    );
    output = output.replaceAll(RegExp(r'仅供交流学习使用[,，。]?版权归原作者和出版社所有[,，。]?'), '');
    output = output.replaceAll(RegExp(r'如果喜欢[,，]?请支持正版[。!?！]?'), '');
    // 归一化标点附近空白。
    output = output.replaceAllMapped(
      RegExp(r'\s*([，。！？；：])\s*'),
      (m) => m.group(1) ?? '',
    );
    return output;
  }
}
