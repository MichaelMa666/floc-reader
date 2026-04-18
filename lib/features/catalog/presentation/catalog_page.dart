import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/app_providers.dart';

class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chapterListProvider(bookId));
    final progressAsync = ref.watch(chapterReadPercentMapProvider(bookId));
    final lastProgressAsync = ref.watch(readingProgressProvider(bookId));
    final lastProgress = lastProgressAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('目录'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: '上次阅读',
            onPressed: lastProgress == null
                ? null
                : () =>
                    context.push('/reader/$bookId/${lastProgress.chapterId}'),
          ),
        ],
      ),
      body: chaptersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (chapters) => progressAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
          data: (progressMap) {
            if (chapters.isEmpty) {
              return const Center(child: Text('暂无章节'));
            }
            final colorScheme = Theme.of(context).colorScheme;
            return ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: chapters.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 0.5,
                indent: 16,
                endIndent: 16,
                color: colorScheme.outlineVariant,
              ),
              itemBuilder: (context, index) {
                final ch = chapters[index];
                final percent = (progressMap[ch.id] ?? 0).clamp(0, 100);
                final isRead = percent >= 90;
                final title = ch.title.trim().isEmpty ? '未命名章节' : ch.title;
                return InkWell(
                  onTap: () => context.push('/reader/$bookId/${ch.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: isRead
                            ? colorScheme.outline
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
