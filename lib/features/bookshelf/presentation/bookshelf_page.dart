import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/local/app_database_platform.dart';
import '../../../shared/providers/app_providers.dart';

class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  static const List<String> _filters = <String>['全部', '收藏', '历史', '小说', '经济'];
  static const String _favoriteBookIdsKey = 'favorite_book_ids';
  bool _isSyncing = false;
  bool _legacyMigrationTriggered = false;
  final GlobalKey _settingsFabKey = GlobalKey();
  String _selectedFilter = _filters[0];
  Set<String> _favoriteBookIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadFavoriteBookIds();
  }

  void _showSnackBarWithLog(String message) {
    debugPrint('[BOOKSHELF_SNACKBAR] $message');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(bookListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('书架')),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.small(
        key: _settingsFabKey,
        onPressed: _openSettingsPopover,
        tooltip: '设置',
        child: const Icon(Icons.settings),
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (books) {
          _maybeAutoMigrateLegacySources(books);
          if (books.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [const Text('书架空空如也，点击右上角刷新同步')],
              ),
            );
          }
          final filteredBooks = books.where((book) {
            if (_selectedFilter == '全部') return true;
            if (_selectedFilter == '收藏') {
              return _favoriteBookIds.contains(book.id);
            }
            return _categoryFromSourceId(book.sourceId) == _selectedFilter;
          }).toList();

          return Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final selected = _selectedFilter == filter;
                    return ChoiceChip(
                      label: Text(filter),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) {
                        if (_selectedFilter == filter) return;
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _filters.length,
                ),
              ),
              Expanded(
                child: filteredBooks.isEmpty
                    ? Center(
                        child: Text(
                          _selectedFilter == '收藏' ? '暂无收藏书籍' : '当前分类暂无书籍',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredBooks.length,
                        itemBuilder: (context, index) {
                          final book = filteredBooks[index];
                          return _BookCard(
                            book: book,
                            isFavorite: _favoriteBookIds.contains(book.id),
                            onToggleFavorite: () => _toggleFavorite(book.id),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _syncRemoteLibrary() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await ref.read(librarySyncServiceProvider).sync();
      ref.invalidate(bookListProvider);
      if (!mounted) return;

      for (final failure in result.failures) {
        debugPrint(
          '[LIBRARY_SYNC_FAILURE] id=${failure.bookId}, file=${failure.file}, reason=${failure.reason}',
        );
      }

      final summary =
          '同步完成：新增${result.importedCount}本，跳过${result.skippedCount}本，失败${result.failedCount}本';
      final details = result.failures.isEmpty
          ? ''
          : '；首个失败：${result.failures.first.file}，原因：${result.failures.first.reason}';
      _showSnackBarWithLog('$summary$details');
    } catch (e) {
      if (!mounted) return;
      _showSnackBarWithLog('同步失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _maybeAutoMigrateLegacySources(List<BookRow> books) {
    if (_legacyMigrationTriggered || _isSyncing) return;
    final hasLegacySource = books.any(_isLegacyLibrarySource);
    if (!hasLegacySource) return;
    _legacyMigrationTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showSnackBarWithLog('检测到旧版书籍数据，正在自动迁移分类...');
      _syncRemoteLibrary();
    });
  }

  Future<void> _openSettingsPopover() async {
    final buttonContext = _settingsFabKey.currentContext;
    if (buttonContext == null) return;
    final button = buttonContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final buttonRect = Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    final selected = await showMenu<_SettingsAction>(
      context: context,
      position: RelativeRect.fromRect(
        buttonRect,
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem<_SettingsAction>(
          value: _SettingsAction.refreshSync,
          child: Text('刷新同步'),
        ),
        PopupMenuItem<_SettingsAction>(
          value: _SettingsAction.clearCache,
          child: Text('清空缓存'),
        ),
      ],
    );
    if (!mounted) return;
    if (selected == _SettingsAction.refreshSync) {
      await _syncRemoteLibrary();
      return;
    }
    if (selected == _SettingsAction.clearCache) {
      await _clearCache();
    }
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空缓存'),
        content: const Text('将清空本地书籍、章节和阅读进度缓存，确认继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(bookRepositoryProvider).clearLocalCache();
      await ref.read(readingRepositoryProvider).clearReadingProgress();
      ref.invalidate(bookListProvider);
      ref.invalidate(chapterReadPercentMapProvider);
      if (!mounted) return;
      _showSnackBarWithLog('缓存已清空');
    } catch (e) {
      if (!mounted) return;
      _showSnackBarWithLog('清空缓存失败: $e');
    }
  }

  String? _categoryFromSourceId(String sourceId) {
    if (!sourceId.startsWith('library:')) return null;
    final segments = sourceId.split(':');
    if (segments.length >= 3 && segments[1].trim().isNotEmpty) {
      return segments[1].trim();
    }
    return null;
  }

  bool _isLegacyLibrarySource(BookRow book) {
    final sourceId = book.sourceId;
    if (!sourceId.startsWith('library:')) return false;
    final segments = sourceId.split(':');
    return segments.length < 3 || segments[1].trim().isEmpty;
  }

  Future<void> _loadFavoriteBookIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_favoriteBookIdsKey) ?? const <String>[];
    if (!mounted) return;
    setState(() {
      _favoriteBookIds = ids.toSet();
    });
  }

  Future<void> _toggleFavorite(String bookId) async {
    final next = Set<String>.from(_favoriteBookIds);
    if (next.contains(bookId)) {
      next.remove(bookId);
    } else {
      next.add(bookId);
    }
    setState(() {
      _favoriteBookIds = next;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteBookIdsKey, next.toList()..sort());
  }
}

enum _SettingsAction { refreshSync, clearCache }

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final BookRow book;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
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
                child: _CoverPlaceholder(title: book.title),
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
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavorite ? '取消收藏' : '收藏',
                onPressed: onToggleFavorite,
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
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
      padding: const EdgeInsets.all(6),
      alignment: Alignment.center,
      child: Text(
        title.isNotEmpty ? title : '未知书名',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          height: 1.2,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
