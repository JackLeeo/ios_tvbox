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

    // 注册全局CatVodSpider基类（兼容TVBox标准JS源）
    await _runtime.evaluate("""
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
    """);

    // 注册网络请求工具（兼容CatJS标准）
    _runtime.setProperty("http", (String url, [Map<String, dynamic>? options]) async {
      final networkService = NetworkService.instance;
      if (options?['method']?.toLowerCase() == 'post') {
        return await networkService.post(url, data: options?['data'], headers: options?['headers']);
      }
      return await networkService.get(url, headers: options?['headers']);
    });

    _isInitialized = true;
  }

  Future<dynamic> executeScript(SpiderSource source, String method, List<dynamic> args) async {
    if (!_isInitialized) await init();

    // 加载并执行爬虫脚本
    if (source.ext?.isNotEmpty == true) {
      await _runtime.evaluate(source.ext!);
    }
    if (source.api?.isNotEmpty == true) {
      final networkService = NetworkService.instance;
      final remoteScript = await networkService.get(source.api!);
      await _runtime.evaluate(remoteScript);
    }

    // 执行目标方法
    final jsCode = """
      (async () => {
        const spider = new MySpider();
        const result = await spider.${method}(${args.map((e) => jsonEncode(e)).join(',')});
        return JSON.stringify(result);
      })();
    """;

    final result = await _runtime.evaluateAsync(jsCode);
    if (result.isError) {
      throw Exception("JS脚本执行错误: ${result.rawResult}");
    }
    return jsonDecode(result.stringResult);
  }

  Future<void> dispose() async {
    _runtime.dispose();
    _isInitialized = false;
  }
}
