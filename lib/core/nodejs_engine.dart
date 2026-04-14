import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

class NodeJsEngine {
  static final NodeJsEngine instance = NodeJsEngine._internal();
  NodeJsEngine._internal();

  static const MethodChannel _channel = MethodChannel('com.tvbox.nodejs');
  static bool _isInitialized = false;

  // Node.js http服务的端口，Dart层通过这个端口请求服务
  int? nodeServerPort;

  // 日志回调，外部可以注册这个回调来接收Node.js的日志
  static Function(String)? onLog;

  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      // 注册MethodChannel的消息监听
      _channel.setMethodCallHandler(_handleNativeCall);
      // 启动Node.js引擎
      await _channel.invokeMethod('startEngine');
      _isInitialized = true;
    }
    // 等待端口准备就绪
    while(nodeServerPort == null) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  static Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onLog') {
      final log = call.arguments as String;
      onLog?.call(log);
    } else if(call.method == 'onNodeServerReady') {
      // Node.js的http服务启动了，保存端口
      nodeServerPort = call.arguments as int;
    } else if(call.method == 'onNodeReady') {
      // Node.js层准备就绪
      print('Node.js engine ready');
    }
    return null;
  }

  // 获取请求Node.js服务的Dio实例，自动配置baseUrl
  Dio get dioClient {
    if(nodeServerPort == null) {
      throw Exception('Node.js server not ready yet');
    }
    final dio = Dio();
    dio.options.baseUrl = 'http://127.0.0.1:\$nodeServerPort';
    return dio;
  }
}
