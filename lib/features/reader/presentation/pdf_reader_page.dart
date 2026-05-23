import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';

import '../../../data/local/app_database_platform.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../shared/providers/app_providers.dart';

/// 用于在 ReadingProgress 中区分 PDF 进度记录的固定 chapterId。
const String pdfReadingChapterId = '__pdf__';

class PdfReaderPage extends ConsumerStatefulWidget {
  const PdfReaderPage({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends ConsumerState<PdfReaderPage> {
  PdfControllerPinch? _controller;
  Future<void>? _initFuture;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _menuVisible = false;
  Object? _initError;

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final book = await ref.read(bookRepositoryProvider).getLocalBook(
            widget.bookId,
          );
      final path = book?.filePath;
      if (book == null || path == null || path.trim().isEmpty) {
        throw StateError('PDF 文件路径缺失，请重新获取书库');
      }
      if (!await File(path).exists()) {
        throw StateError('PDF 文件不存在：$path');
      }

      final progress = await ref
          .read(readingRepositoryProvider)
          .getReadingProgress(widget.bookId);
      final initialPage = (progress?.chapterId == pdfReadingChapterId
              ? (progress?.offset ?? 1)
              : 1)
          .clamp(1, 1 << 30);

      final controller = PdfControllerPinch(
        document: PdfDocument.openFile(path),
        initialPage: initialPage,
      );
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _currentPage = initialPage;
      });
      // 进入即把当前页记一次进度，确保「继续阅读」横幅生效。
      unawaited(_persistProgress(initialPage));
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = e);
    }
  }

  Future<void> _persistProgress(int page) async {
    await ref.read(readingRepositoryProvider).saveReadingProgress(
          ReadingProgress(
            bookId: widget.bookId,
            chapterId: pdfReadingChapterId,
            offset: page,
            updatedAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    ref.invalidate(readingProgressProvider(widget.bookId));
    ref.invalidate(lastReadShortcutProvider);
  }

  void _onPageChanged(int page) {
    _currentPage = page;
    if (_menuVisible) {
      setState(() {});
    }
    unawaited(_persistProgress(page));
  }

  Future<void> _goPrevPage() async {
    final controller = _controller;
    if (controller == null) return;
    if (_currentPage <= 1) return;
    await controller.previousPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goNextPage() async {
    final controller = _controller;
    if (controller == null) return;
    if (_totalPages > 0 && _currentPage >= _totalPages) return;
    await controller.nextPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _handleZoneTap(_TapZone zone) {
    if (_menuVisible) {
      setState(() => _menuVisible = false);
      return;
    }
    switch (zone) {
      case _TapZone.left:
        _goPrevPage();
        break;
      case _TapZone.middle:
        setState(() => _menuVisible = true);
        break;
      case _TapZone.right:
        _goNextPage();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (_initError != null) {
            return _ErrorView(message: '$_initError', onBack: () => context.pop());
          }
          final controller = _controller;
          if (controller == null ||
              snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          return Stack(
            children: [
              Positioned.fill(
                child: PdfViewPinch(
                  controller: controller,
                  onDocumentLoaded: (doc) {
                    if (!mounted) return;
                    setState(() => _totalPages = doc.pagesCount);
                  },
                  onPageChanged: _onPageChanged,
                  onDocumentError: (error) {
                    if (!mounted) return;
                    setState(() => _initError = error);
                  },
                ),
              ),
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _handleZoneTap(_TapZone.left),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _handleZoneTap(_TapZone.middle),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _handleZoneTap(_TapZone.right),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !_menuVisible,
                  child: AnimatedSlide(
                    offset: _menuVisible ? Offset.zero : const Offset(0, -1),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: _menuVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: _TopBar(
                        currentPage: _currentPage,
                        totalPages: _totalPages,
                        onClose: () => setState(() => _menuVisible = false),
                        onBack: () => context.pop(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _TapZone { left, middle, right }

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.currentPage,
    required this.totalPages,
    required this.onClose,
    required this.onBack,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback onClose;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final pageLabel = totalPages > 0
        ? '$currentPage / $totalPages'
        : '$currentPage';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: '返回',
                    onPressed: onBack,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        pageLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(
              'PDF 加载失败\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
              ),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}
