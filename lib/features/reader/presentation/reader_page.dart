import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';

class ReaderPage extends ConsumerWidget {
  const ReaderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('阅读器')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '这是阅读器占位页。\n\n'
              '后续会接入：翻页手势、长按设置 BottomSheet、阅读进度保存。',
              style: TextStyle(fontSize: 16, height: 1.6),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await ref.read(readerProgressServiceProvider).save(
                      bookId: 'demo_book',
                      chapterId: 'demo_chapter_1',
                      offset: 0,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已保存示例阅读进度')),
                  );
                }
              },
              child: const Text('保存阅读进度（占位流程）'),
            ),
          ],
        ),
      ),
    );
  }
}
