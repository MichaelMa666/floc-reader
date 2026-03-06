import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/local/app_database.dart';
import '../../../features/source/domain/source_registry.dart';
import '../../../shared/providers/app_providers.dart';

class BookshelfPage extends ConsumerWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bookListProvider);
    final currentSourceId = ref.watch(currentSourceIdProvider);
    final sourceInfo = SourceRegistry.getSourceInfo(currentSourceId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: '切换书源',
            onPressed: () => _showSourcePicker(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addBook(context, ref),
        child: const Icon(Icons.add),
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (books) {
          if (books.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('书架空空如也，点击右下角添加书籍'),
                  const SizedBox(height: 8),
                  Text(
                    '当前书源：${sourceInfo.name}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: books.length,
            itemBuilder: (context, index) => _BookCard(book: books[index]),
          );
        },
      ),
    );
  }

  void _showSourcePicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(currentSourceIdProvider);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '切换书源',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            ...SourceRegistry.availableSources.map((source) {
              final isSelected = source.id == current;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(source.name),
                subtitle: Text(source.baseUrl),
                onTap: () {
                  ref.read(currentSourceIdProvider.notifier).set(source.id);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _addBook(BuildContext context, WidgetRef ref) async {
    final currentSourceId = ref.read(currentSourceIdProvider);
    final sourceInfo = SourceRegistry.getSourceInfo(currentSourceId);
    final controller = TextEditingController(text: sourceInfo.exampleBookId);

    final bookId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('添加书籍（${sourceInfo.name}）'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: '书籍 ID',
            hintText: '如 ${sourceInfo.exampleBookId}',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (bookId == null || bookId.isEmpty) return;

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在从${sourceInfo.name}解析书籍信息…')),
    );

    try {
      await ref
          .read(bookRepositoryProvider)
          .fetchAndCacheBook(currentSourceId, bookId);
      ref.invalidate(bookListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('添加成功')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失败: $e')),
      );
    }
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});

  final BookRow book;

  @override
  Widget build(BuildContext context) {
    final sourceName = SourceRegistry.getSourceInfo(book.sourceId).name;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/catalog/${book.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: book.coverUrl != null
                    ? Image.network(
                        book.coverUrl!,
                        width: 60,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _CoverPlaceholder(title: book.title),
                      )
                    : _CoverPlaceholder(title: book.title),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sourceName,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        title.isNotEmpty ? title[0] : '?',
        style: TextStyle(
          fontSize: 24,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
