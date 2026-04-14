import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

class NodeJsEngine {
  // Node.js http服务的端口，Dart层通过这个端口请求服务
  static int? nodeServerPort;

  // 日志回调，外部可以注册这个回调来接收Node.js的日志
  static Function(String)? onLog;

  // 初始化Node.js引擎
  static Future<void> init() async {
    // 注册MethodChannel，监听原生层的消息
    const channel = MethodChannel('nodejs_channel');
    channel.setMethodCallHandler(_handleNativeCall);

    // 启动Node.js引擎
    await MethodChannel('nodejs_channel').invokeMethod('startNodeEngine');

    // 等待端口就绪
    while (nodeServerPort == null) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // 处理原生层的消息
  static Future<dynamic> _handleNativeCall(MethodCall call) async {
    if(call.method == 'onNodeServerReady') {
      // Node.js的http服务启动了，保存端口
      nodeServerPort = call.arguments as int;
    } else if(call.method == 'onNodeLog') {
      // Node.js的日志，转发给外部的回调
      final log = call.arguments as String;
      if(onLog != null) {
        onLog!(log);
      }
    }
  }

  // 获取Dio客户端，自动配置baseUrl
  static Dio get dio {
    if(nodeServerPort == null) {
      throw Exception('Node.js engine not initialized');
    }
    return Dio(BaseOptions(
      baseUrl: 'http://127.0.0.1:$nodeServerPort',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  // 等待端口就绪
  static Future<void> waitForReady() async {
    while (nodeServerPort == null) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}
