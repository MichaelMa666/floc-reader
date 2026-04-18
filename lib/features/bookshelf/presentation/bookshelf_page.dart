import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/local/app_database_platform.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/cupertino_toast.dart';

class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  static const List<String> _filters = <String>['全部', '收藏'];
  static const String _favoriteBookIdsKey = 'favorite_book_ids';
  bool _isSyncing = false;
  String _selectedFilter = _filters[0];
  Set<String> _favoriteBookIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadFavoriteBookIds();
  }

  void _showToast(String message, {IconData? icon}) {
    debugPrint('[BOOKSHELF_TOAST] $message');
    CupertinoToast.show(context, message: message, icon: icon);
  }

  void _openBook(String path) {
    context.push(path).then((_) {
      if (!mounted) return;
      ref.invalidate(lastReadShortcutProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(bookListProvider);
    final shortcutAsync = ref.watch(lastReadShortcutProvider);
    final shortcut = shortcutAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('书库'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _openSettingsPopover,
            tooltip: _isSyncing ? '正在获取书库' : '设置',
            icon: _isSyncing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : const Icon(Icons.settings),
          ),
        ],
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (books) {
          if (books.isEmpty) {
            return const Center(
              child: Text('书库空空如也，点右上角设置 → 获取书库'),
            );
          }
          final filteredBooks = _selectedFilter == '收藏'
              ? books
                  .where((book) => _favoriteBookIds.contains(book.id))
                  .toList()
              : books;

          return Column(
            children: [
              if (shortcut != null)
                _ContinueReadingBanner(
                  shortcut: shortcut,
                  onTap: () => _openBook(
                    '/reader/${shortcut.book.id}/${shortcut.progress.chapterId}',
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    for (final filter in _filters)
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: InkWell(
                          onTap: () {
                            if (_selectedFilter == filter) return;
                            setState(() {
                              _selectedFilter = filter;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              filter,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedFilter == filter
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _selectedFilter == filter
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: filteredBooks.isEmpty
                    ? Center(
                        child: Text(
                          _selectedFilter == '收藏' ? '暂无收藏书籍' : '暂无书籍',
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 28,
                          childAspectRatio: 0.56,
                        ),
                        itemCount: filteredBooks.length,
                        itemBuilder: (context, index) {
                          final book = filteredBooks[index];
                          return _BookGridItem(
                            book: book,
                            onTap: () => _openBook('/catalog/${book.id}'),
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
      ref.invalidate(lastReadShortcutProvider);
      if (!mounted) return;

      for (final failure in result.failures) {
        debugPrint(
          '[LIBRARY_SYNC_FAILURE] id=${failure.bookId}, file=${failure.file}, reason=${failure.reason}',
        );
      }

      final summary =
          '已获取：新增${result.importedCount}本，跳过${result.skippedCount}本，失败${result.failedCount}本';
      final details = result.failures.isEmpty
          ? ''
          : '；首个失败：${result.failures.first.file}，原因：${result.failures.first.reason}';
      _showToast('$summary$details');
    } catch (e) {
      if (!mounted) return;
      _showToast('获取失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _openSettingsPopover() async {
    final selected = await showCupertinoModalPopup<_SettingsAction>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(ctx, _SettingsAction.refreshSync),
            child: const Text('获取书库'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, _SettingsAction.clearCache),
            child: const Text('清空书库'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
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
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('清空书库'),
        content: const Text('将清空本地书籍、章节和阅读进度，确认继续吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
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
      ref.invalidate(lastReadShortcutProvider);
      if (!mounted) return;
      _showToast('书库已清空');
    } catch (e) {
      if (!mounted) return;
      _showToast('清空书库失败: $e');
    }
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
    final wasFavorite = next.contains(bookId);
    if (wasFavorite) {
      next.remove(bookId);
    } else {
      next.add(bookId);
    }
    setState(() {
      _favoriteBookIds = next;
    });
    CupertinoToast.show(
      context,
      message: wasFavorite ? '已取消收藏' : '已收藏',
      icon: wasFavorite ? CupertinoIcons.heart : CupertinoIcons.heart_fill,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteBookIdsKey, next.toList()..sort());
  }
}

enum _SettingsAction { refreshSync, clearCache }

class _BookGridItem extends StatelessWidget {
  const _BookGridItem({
    required this.book,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final BookRow book;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      onLongPress: () {
        HapticFeedback.selectionClick();
        onToggleFavorite();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: _BookCover(title: book.title, coverPath: book.coverUrl),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({
    required this.title,
    required this.coverPath,
    this.width,
    this.height,
  });

  final String title;
  final String? coverPath;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(6);
    final path = coverPath;
    Widget child;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      child = ClipRRect(
        borderRadius: borderRadius,
        child: Image.file(
          File(path),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _CoverPlaceholder(title: title),
        ),
      );
    } else {
      child = _CoverPlaceholder(title: title);
    }
    if (width != null || height != null) {
      return SizedBox(width: width, height: height, child: child);
    }
    return child;
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
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

class _ContinueReadingBanner extends StatelessWidget {
  const _ContinueReadingBanner({
    required this.shortcut,
    required this.onTap,
  });

  final LastReadShortcut shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _BookCover(
                  title: shortcut.book.title,
                  coverPath: shortcut.book.coverUrl,
                  width: 60,
                  height: 80,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shortcut.book.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (shortcut.chapterTitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          shortcut.chapterTitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '继续阅读',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          indent: 16,
          endIndent: 16,
          color: colorScheme.outlineVariant,
        ),
      ],
    );
  }
}
