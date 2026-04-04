import 'package:dio/dio.dart';

class NetworkService {
  late final Dio _dio;

  NetworkService() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ),
    );
    
    // 拦截器
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  // GET请求
  Future<Response> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return await _dio.get(
      url,
      queryParameters: queryParameters,
      options: Options(headers: headers),
    );
  }

  // POST请求
  Future<Response> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    return await _dio.post(
      url,
      data: data,
      options: Options(headers: headers),
    );
  }
}