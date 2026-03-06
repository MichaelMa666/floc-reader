import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';

class ReaderPage extends ConsumerWidget {
  const ReaderPage({
    super.key,
    required this.bookId,
    required this.chapterId,
  });

  final String bookId;
  final String chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceIdAsync = ref.watch(bookSourceIdProvider(bookId));

    return sourceIdAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('阅读')),
        body: Center(child: Text('加载失败: $e')),
      ),
      data: (sourceId) => _ReaderContent(
        sourceId: sourceId,
        bookId: bookId,
        chapterId: chapterId,
      ),
    );
  }
}

class _ReaderContent extends ConsumerWidget {
  const _ReaderContent({
    required this.sourceId,
    required this.bookId,
    required this.chapterId,
  });

  final String sourceId;
  final String bookId;
  final String chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(
      chapterContentProvider((
        sourceId: sourceId,
        bookId: bookId,
        chapterId: chapterId,
      )),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('阅读')),
      body: contentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('加载失败: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (content) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              content,
              style: const TextStyle(fontSize: 18, height: 1.8),
            ),
          );
        },
      ),
    );
  }
}
