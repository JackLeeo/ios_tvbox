import 'dart:convert';
import 'package:flutter/services.dart';

class NodeJsEngine {
  static final NodeJsEngine instance = NodeJsEngine._internal();
  NodeJsEngine._internal();

  static const MethodChannel _channel = MethodChannel('com.tvbox.nodejs');
  static bool _isInitialized = false;

  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await _channel.invokeMethod('startEngine');
      _isInitialized = true;
    }
  }

  // 日志回调，外部可以注册这个回调来接收Node.js的日志
  static Function(String)? onLog;

  static Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onLog') {
      final log = call.arguments as String;
      onLog?.call(log);
    }
    return null;
  }

  Future<dynamic> executeScript(String api, String ext, String method, List<dynamic> args) async {
    // 注册MethodChannel的消息监听，接收日志
    _channel.setMethodCallHandler(_handleNativeCall);
    
    final params = args.map((e) => jsonEncode(e)).toList();
    final result = await _channel.invokeMethod('executeScript', {
      'api': api,
      'ext': ext,
      'method': method,
      'params': params,
    });
    return result;
  }
}
