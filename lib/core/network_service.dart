import 'package:dio/dio.dart';

class NetworkService {
  late final Dio _dio;
  bool _isInitialized = false;

  static final NetworkService instance = NetworkService._internal();
  NetworkService._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
        followRedirects: true,
        validateStatus: (status) => status! < 500,
      ),
    );
    _isInitialized = true;
  }

  // GET请求
  Future<dynamic> get(String url, {Map<String, dynamic>? headers, Map<String, dynamic>? queryParameters}) async {
    if (!_isInitialized) await init();
    try {
      final response = await _dio.get(
        url,
        options: headers != null ? Options(headers: headers) : null,
        queryParameters: queryParameters,
      );
      return response.data;
    } catch (e) {
      throw Exception("网络请求失败: $e");
    }
  }

  // POST请求
  Future<dynamic> post(String url, {dynamic data, Map<String, dynamic>? headers}) async {
    if (!_isInitialized) await init();
    try {
      final response = await _dio.post(
        url,
        data: data,
        options: headers != null ? Options(headers: headers) : null,
      );
      return response.data;
    } catch (e) {
      throw Exception("网络请求失败: $e");
    }
  }
}
