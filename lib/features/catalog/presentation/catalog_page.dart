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

    return Scaffold(
      appBar: AppBar(title: const Text('章节目录')),
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
            return ListView.separated(
              itemCount: chapters.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final ch = chapters[index];
                final chapterNo = ch.chapterIndex + 1;
                final primaryTitle = '第$chapterNo章';
                final percent = (progressMap[ch.id] ?? 0).clamp(0, 100);
                return ListTile(
                  title: Text(primaryTitle),
                  subtitle: ch.title.trim().isEmpty
                      ? null
                      : Text(
                          ch.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: Text(
                    '$percent%',
                    style: TextStyle(
                      color: percent > 0
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => context.push('/reader/$bookId/${ch.id}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
