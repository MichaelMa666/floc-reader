import 'source_adapter.dart';

/// 描述一个书源
class SourceInfo {
  const SourceInfo({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.exampleBookId = '',
  });

  final String id;
  final String name;
  final String baseUrl;
  final String exampleBookId;
}

/// 管理所有可用书源，并按 id 检索对应的 adapter
class SourceRegistry {
  SourceRegistry(this._adapters);

  final Map<String, SourceAdapter> _adapters;

  static const List<SourceInfo> availableSources = [
    SourceInfo(
      id: 'hetushu',
      name: '和图书',
      baseUrl: 'https://www.hetushu.com',
      exampleBookId: '700',
    ),
    SourceInfo(
      id: 'biquge',
      name: '笔趣阁',
      baseUrl: 'https://www.biquge.tw',
      exampleBookId: '1043863',
    ),
  ];

  SourceAdapter getAdapter(String sourceId) {
    final adapter = _adapters[sourceId];
    if (adapter == null) {
      throw ArgumentError('未注册的书源: $sourceId');
    }
    return adapter;
  }

  static SourceInfo getSourceInfo(String sourceId) {
    return availableSources.firstWhere(
      (s) => s.id == sourceId,
      orElse: () => availableSources.first,
    );
  }
}
