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

    return Scaffold(
      appBar: AppBar(title: const Text('章节目录')),
      body: chaptersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (chapters) {
          if (chapters.isEmpty) {
            return const Center(child: Text('暂无章节'));
          }
          return ListView.separated(
            itemCount: chapters.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final ch = chapters[index];
              return ListTile(
                title: Text(ch.title),
                trailing: ch.cached
                    ? Icon(
                        Icons.download_done,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => context.push('/reader/$bookId/${ch.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
