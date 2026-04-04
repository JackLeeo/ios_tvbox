import 'package:flutter_js/flutter_js.dart';
import 'dart:convert';
import 'dart:async';
import '../models/spider_source.dart';
import './network_service.dart';

class JsEngine {
  late final JavascriptRuntime _runtime;
  bool _isInitialized = false;
  // JS-Dart异步通信映射
  final Map<String, Completer<dynamic>> _pendingRequests = {};
  int _requestSeq = 0;

  static final JsEngine instance = JsEngine._internal();
  JsEngine._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    _runtime = getJavascriptRuntime();

    // 【全版本通用】监听JS发送到Dart的所有消息
    _runtime.onMessage.listen((dynamic message) async {
      // 处理JS调用Dart的http请求
      if (message is Map && message['__type__'] == 'http_request') {
        final String reqId = message['reqId'];
        final String method = message['method'];
        final List<dynamic> args = message['args'] ?? [];

        try {
          dynamic result;
          if (method == 'get') {
            final url = args[0] as String;
            final headers = args.length > 1 ? Map<String, dynamic>.from(args[1]) : null;
            result = await NetworkService.instance.get(url, headers: headers);
          } else if (method == 'post') {
            final url = args[0] as String;
            final data = args.length > 1 ? args[1] : null;
            final headers = args.length > 2 ? Map<String, dynamic>.from(args[2]) : null;
            result = await NetworkService.instance.post(url, data: data, headers: headers);
          }
          // 把结果返回给JS
          _runtime.sendMessage({
            "__type__": "http_response",
            "reqId": reqId,
            "success": true,
            "data": result,
          });
        } catch (e) {
          // 把错误返回给JS
          _runtime.sendMessage({
            "__type__": "http_response",
            "reqId": reqId,
            "success": false,
            "error": e.toString(),
          });
        }
        return;
      }

      // 处理Dart调用JS的响应
      if (message is Map && message['__type__'] == 'dart_response') {
        final String reqId = message['reqId'];
        final completer = _pendingRequests.remove(reqId);
        if (completer == null) return;

        if (message['success'] == true) {
          completer.complete(message['data']);
        } else {
          completer.completeError(message['error'] ?? '未知错误');
        }
      }
    });

    // 初始化全局环境 + 注入http工具（全版本兼容，无特殊API）
    final initCode = """
      class CatVodSpider {
        constructor() {}
        async homeContent(filter) { return {}; }
        async homeVideoContent() { return {}; }
        async categoryContent(tid, pg, filter, extend) { return {}; }
        async detailContent(ids) { return {}; }
        async searchContent(wd, quick, pg) { return {}; }
        async playerContent(flag, id, vipFlags) { return {}; }
        async liveContent() { return {}; }
      }
      var globalThis = this;
      var window = globalThis;
      // 待处理的http请求
      window._pendingHttp = {};
      // 监听Dart返回的http响应
      window.onMessage.listen((msg) => {
        if (msg.__type__ === 'http_response') {
          const req = window._pendingHttp[msg.reqId];
          if (req) {
            delete window._pendingHttp[msg.reqId];
            if (msg.success) req.resolve(msg.data);
            else req.reject(msg.error);
          }
        }
      });
      // 注入http工具，100%兼容所有flutter_js版本
      const http = {
        get: async (url, headers) => {
          return new Promise((resolve, reject) => {
            const reqId = Date.now() + '_' + Math.random();
            window._pendingHttp[reqId] = { resolve, reject };
            window.sendMessage({
              __type__: 'http_request',
              reqId: reqId,
              method: 'get',
              args: [url, headers || {}]
            });
          });
        },
        post: async (url, data, headers) => {
          return new Promise((resolve, reject) => {
            const reqId = Date.now() + '_' + Math.random();
            window._pendingHttp[reqId] = { resolve, reject };
            window.sendMessage({
              __type__: 'http_request',
              reqId: reqId,
              method: 'post',
              args: [url, data, headers || {}]
            });
          });
        }
      };
    """;

    final initResult = _runtime.evaluate(initCode);
    if (initResult.isError) {
      throw Exception("JS引擎初始化失败: ${initResult.rawResult}");
    }

    _isInitialized = true;
  }

  // 执行JS脚本方法
  Future<dynamic> executeScript(SpiderSource source, String method, List<dynamic> args) async {
    if (!_isInitialized) await init();

    // 加载远程脚本
    if (source.api?.isNotEmpty == true) {
      final remoteScript = await NetworkService.instance.get(source.api!);
      final loadResult = _runtime.evaluate(remoteScript);
      if (loadResult.isError) {
        throw Exception("远程JS脚本加载失败: ${loadResult.rawResult}");
      }
    }

    // 加载本地脚本
    if (source.ext?.isNotEmpty == true) {
      final extResult = _runtime.evaluate(source.ext!);
      if (extResult.isError) {
        throw Exception("本地JS脚本加载失败: ${extResult.rawResult}");
      }
    }

    // 执行目标方法
    final argsJson = args.map((e) => jsonEncode(e)).join(',');
    final execCode = """
      (async () => {
        const spider = new MySpider();
        const result = await spider.$method($argsJson);
        return JSON.stringify(result);
      })();
    """;

    final result = await _runtime.evaluateAsync(execCode);
    if (result.isError) {
      throw Exception("JS方法执行失败: ${result.rawResult}");
    }

    try {
      return jsonDecode(result.stringResult);
    } catch (e) {
      throw Exception("JS返回数据解析失败: $e, 原始数据: ${result.stringResult}");
    }
  }

  Future<void> dispose() async {
    _runtime.dispose();
    _isInitialized = false;
    _pendingRequests.clear();
  }
}
