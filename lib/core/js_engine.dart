import 'package:flutter_js/flutter_js.dart';
import 'package:ios_tvbox/models/spider_source.dart';
import 'package:ios_tvbox/core/network_service.dart';
import 'dart:convert';

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

    // 注册网络请求通道（flutter_js标准API）
    _runtime.registerChannelHandler('httpGet', (args) async {
      try {
        final url = args[0] as String;
        final headers = args.length > 1 ? Map<String, dynamic>.from(args[1]) : null;
        final result = await NetworkService.instance.get(url, headers: headers);
        return result;
      } catch (e) {
        return {"error": e.toString()};
      }
    });

    _runtime.registerChannelHandler('httpPost', (args) async {
      try {
        final url = args[0] as String;
        final data = args.length > 1 ? args[1] : null;
        final headers = args.length > 2 ? Map<String, dynamic>.from(args[2]) : null;
        final result = await NetworkService.instance.post(url, data: data, headers: headers);
        return result;
      } catch (e) {
        return {"error": e.toString()};
      }
    });

    // 注入http工具到JS全局
    _runtime.evaluate("""
      const http = {
        get: async (url, headers) => {
          return await channel.invokeMethod('httpGet', [url, headers || {}]);
        },
        post: async (url, data, headers) => {
          return await channel.invokeMethod('httpPost', [url, data, headers || {}]);
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

    // 执行目标方法（异步方法用evaluateAsync）
    final argsJson = args.map((e) => jsonEncode(e)).join(',');
    final jsCode = """
      (async () => {
        const spider = new MySpider();
        const result = await spider.${method}(${argsJson});
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
