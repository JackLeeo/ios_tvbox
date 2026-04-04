import 'package:flutter_js/flutter_js.dart';
import 'dart:convert';
import '../models/spider_source.dart';
import './network_service.dart';

class JsEngine {
  late final JavascriptRuntime _runtime;
  bool _isInitialized = false;

  static final JsEngine instance = JsEngine._internal();
  JsEngine._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    _runtime = getJavascriptRuntime();

    // 初始化全局环境
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
    """);
    if (initResult.isError) {
      throw Exception("JS引擎初始化失败: ${initResult.rawResult}");
    }

    // 适配flutter_js 0.8.0 正确的双向通信API
    _runtime.onMessage.listen((dynamic message) async {
      if (message is! Map) return;
      final String method = message['method'];
      final List<dynamic> args = message['args'] ?? [];

      try {
        if (method == 'httpGet') {
          final url = args[0] as String;
          final headers = args.length > 1 ? Map<String, dynamic>.from(args[1]) : null;
          final result = await NetworkService.instance.get(url, headers: headers);
          _runtime.sendMessage({"result": result, "error": null});
        } else if (method == 'httpPost') {
          final url = args[0] as String;
          final data = args.length > 1 ? args[1] : null;
          final headers = args.length > 2 ? Map<String, dynamic>.from(args[2]) : null;
          final result = await NetworkService.instance.post(url, data: data, headers: headers);
          _runtime.sendMessage({"result": result, "error": null});
        }
      } catch (e) {
        _runtime.sendMessage({"result": null, "error": e.toString()});
      }
    });

    // 注入http工具到JS全局
    _runtime.evaluate("""
      const http = {
        get: async (url, headers) => {
          return new Promise((resolve, reject) => {
            const listener = (msg) => {
              if (msg.error) reject(msg.error);
              else resolve(msg.result);
              window.onMessage.remove(listener);
            };
            window.onMessage.listen(listener);
            window.sendMessage({
              method: 'httpGet',
              args: [url, headers || {}]
            });
          });
        },
        post: async (url, data, headers) => {
          return new Promise((resolve, reject) => {
            const listener = (msg) => {
              if (msg.error) reject(msg.error);
              else resolve(msg.result);
              window.onMessage.remove(listener);
            };
            window.onMessage.listen(listener);
            window.sendMessage({
              method: 'httpPost',
              args: [url, data, headers || {}]
            });
          });
        }
      };
    """);

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

    // 执行目标方法（修复多余大括号警告）
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
  }
}
