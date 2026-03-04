import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';

class BookshelfPage extends StatelessWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('书架')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: ListTile(
              title: const Text('最后一个道士（示例占位）'),
              subtitle: const Text('作者：夏忆'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('catalog'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push(AppRoutes.catalog),
            child: const Text('进入章节页（占位）'),
          ),
        ],
      ),
    );
  }
}
