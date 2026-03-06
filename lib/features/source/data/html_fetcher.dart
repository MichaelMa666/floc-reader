import 'package:dio/dio.dart';

/// 抽取 HTML 获取逻辑，便于后续切换到 WebView 方案绕过 Cloudflare
abstract class HtmlFetcher {
  Future<String> fetch(String url);
}

class DioHtmlFetcher implements HtmlFetcher {
  DioHtmlFetcher() : _dio = Dio() {
    _dio.options.headers = {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    };
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.options.followRedirects = true;
    _dio.options.responseType = ResponseType.plain;
  }

  final Dio _dio;

  @override
  Future<String> fetch(String url) async {
    final response = await _dio.get<String>(url);
    return response.data ?? '';
  }
}
