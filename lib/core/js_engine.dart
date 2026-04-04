import 'package:flutter_js/flutter_js.dart';
import 'dart:convert';
import 'dart:async';
import '../models/spider_source.dart';
import './network_service.dart';

class JsEngine {
  late final JavascriptRuntime _runtime;
  bool _isInitialized = false;
  // 用于JS-Dart异步通信的请求映射
  final Map<String, Completer<dynamic>> _requestCompleters = {};
  int _requestId = 0;

  static final JsEngine instance = JsEngine._internal();
  JsEngine._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    _runtime = getJavascriptRuntime();

    // 【全版本通用】监听JS发送到Dart的消息
    _runtime.onMessage.listen((dynamic message) async {
      if (message is! Map) return;
      final String requestId = message['requestId'];
      final String method = message['method'];
      final List<dynamic> args = message['args'] ?? [];

      try {
        dynamic result;
        if (method == 'httpGet') {
          final url = args[0] as String;
          final headers = args.length > 1 ? Map<String, dynamic>.from(args[1]) : null;
          result = await NetworkService.instance.get(url, headers: headers);
        } else if (method == 'httpPost') {
          final url = args[0] as String;
          final data = args.length > 1 ? args[1] : null;
          final headers = args.length > 2 ? Map<String, dynamic>.from(args[2]) : null;
          result = await NetworkService.instance.post(url, data: data, headers: headers);
        }
        // 把结果返回给JS
        _runtime.sendMessage({
          "requestId": requestId,
          "result": result,
          "error": null,
        });
      } catch (e) {
        // 把错误返回给JS
        _runtime.sendMessage({
          "requestId": requestId,
          "result": null,
          "error": e.toString(),
        });
      }
    });

    // 【全版本通用】监听Dart发送到JS的消息响应
    _runtime.onMessage.listen((dynamic message) {
      if (message is! Map) return;
      final String requestId = message['requestId'];
      final completer = _requestCompleters.remove(requestId);
      if (completer == null) return;

      if (message['error'] != null) {
        completer.completeError(message['error']);
      } else {
        completer.complete(message['result']);
      }
    });

    // 初始化全局CatVodSpider基类 + 注入http工具（全版本兼容）
    final initResult = _runtime.evaluate("""
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
      // 全局请求ID计数器
      var _dartRequestId = 0;
      // 全局请求回调映射
      var _dartRequestCallbacks = {};
      // 监听Dart返回的消息
      window.onMessage.listen((msg) {
        if (msg.requestId && _dartRequestCallbacks[msg.requestId]) {
          const callback = _dartRequestCallbacks[msg.requestId];
          delete _dartRequestCallbacks[msg.requestId];
          if (msg.error) {
            callback.reject(msg.error);
          } else {
            callback.resolve(msg.result);
          }
        }
      });
      // 注入http工具，100%兼容所有flutter_js版本
      const http = {
        get: async (url, headers) => {
          return new Promise((resolve, reject) => {
            const requestId = (++_dartRequestId).toString();
            _dartRequestCallbacks[requestId] = { resolve, reject };
            window.sendMessage({
              requestId: requestId,
              method: 'httpGet',
              args: [url, headers || {}]
            });
          });
        },
        post: async (url, data, headers) => {
          return new Promise((resolve, reject) => {
            const requestId = (++_dartRequestId).toString();
            _dartRequestCallbacks[requestId] = { resolve, reject };
            window.sendMessage({
              requestId: requestId,
              method: 'httpPost',
              args: [url, data, headers || {}]
            });
          });
        }
      };
    """);

    if (initResult.isError) {
      throw Exception("JS引擎初始化失败: ${initResult.rawResult}");
    }

    _isInitialized = true;
  }

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
    final jsCode = """
      (async () => {
        const spider = new MySpider();
        const result = await spider.$method($argsJson);
        return JSON.stringify(result);
      })();
    """;

    final result = await _runtime.evaluateAsync(jsCode);
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
    _requestCompleters.clear();
  }
}
