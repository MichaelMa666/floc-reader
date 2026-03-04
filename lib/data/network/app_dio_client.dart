import 'package:dio/dio.dart';

import 'app_error.dart';

class AppDioClient {
  AppDioClient({
    required String baseUrl,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 10),
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: connectTimeout,
            receiveTimeout: receiveTimeout,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException err, ErrorInterceptorHandler handler) {
          handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: AppError(err.message ?? '网络请求失败'),
              type: err.type,
              response: err.response,
            ),
          );
        },
      ),
    );
  }

  final Dio _dio;

  Dio get client => _dio;
}
