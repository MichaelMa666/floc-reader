import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('章节目录')),
      body: ListView.separated(
        itemCount: 20,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          return ListTile(
            title: Text('第 ${index + 1} 章'),
            subtitle: const Text('点击进入阅读页（占位）'),
            onTap: () => context.pushNamed('reader'),
          );
        },
      ),
    );
  }
}
