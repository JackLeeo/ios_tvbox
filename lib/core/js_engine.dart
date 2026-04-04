import 'package:quick_js/quick_js.dart';
import 'dart:convert';
import '../models/spider_source.dart';
import './network_service.dart';

class JsEngine {
  JsRuntime? _runtime;
  bool _isInitialized = false;

  static final JsEngine instance = JsEngine._internal();
  JsEngine._internal();

  /// 初始化JS引擎，注入全局环境和http工具
  Future<void> init() async {
    if (_isInitialized && _runtime != null) return;

    // 创建JS运行时
    _runtime = await JsRuntime.create();
    // 全局变量兼容，适配TVBox JS脚本标准
    await _runtime!.evaluate('''
      var globalThis = this;
      var window = globalThis;
      // TVBox标准爬虫基类，所有自定义脚本继承此类
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
    ''');

    // 注册Dart http方法给JS调用，完全兼容原有http.get/http.post调用规范
    await _runtime!.setGlobalFunction('DartHttpGet', (List<dynamic> args) async {
      try {
        final url = args[0] as String;
        final headers = args.length > 1 ? Map<String, dynamic>.from(args[1]) : <String, dynamic>{};
        return await NetworkService.instance.get(url, headers: headers);
      } catch (e) {
        throw Exception('HttpGet请求失败: ${e.toString()}');
      }
    });

    await _runtime!.setGlobalFunction('DartHttpPost', (List<dynamic> args) async {
      try {
        final url = args[0] as String;
        final data = args.length > 1 ? args[1] : null;
        final headers = args.length > 2 ? Map<String, dynamic>.from(args[2]) : <String, dynamic>{};
        return await NetworkService.instance.post(url, data: data, headers: headers);
      } catch (e) {
        throw Exception('HttpPost请求失败: ${e.toString()}');
      }
    });

    // 注入全局http工具，和原有JS脚本完全兼容，无需修改任何JS代码
    await _runtime!.evaluate('''
      const http = {
        get: async (url, headers) => {
          return await DartHttpGet(url, headers || {});
        },
        post: async (url, data, headers) => {
          return await DartHttpPost(url, data, headers || {});
        }
      };
    ''');

    _isInitialized = true;
  }

  /// 执行爬虫脚本方法，完全兼容原有调用规范，上层代码零改动
  Future<dynamic> executeScript(SpiderSource source, String method, List<dynamic> args) async {
    if (!_isInitialized || _runtime == null) await init();

    try {
      // 加载远程JS脚本
      if (source.api?.isNotEmpty == true) {
        final remoteScript = await NetworkService.instance.get(source.api!);
        await _runtime!.evaluate(remoteScript);
      }

      // 加载本地JS脚本（ext字段）
      if (source.ext?.isNotEmpty == true) {
        await _runtime!.evaluate(source.ext!);
      }

      // 序列化参数，适配JS方法入参
      final argsJson = args.map((e) => jsonEncode(e)).join(',');
      // 执行目标异步方法，自动等待Promise完成
      final jsCode = '''
        (async () => {
          const spider = new MySpider();
          const result = await spider.$method($argsJson);
          return JSON.stringify(result);
        })();
      ''';

      final result = await _runtime!.evaluate(jsCode);
      // 解析返回结果
      return jsonDecode(result.toString());
    } catch (e) {
      throw Exception("JS脚本执行失败: ${e.toString()}");
    }
  }

  /// 释放JS引擎资源
  Future<void> dispose() async {
    if (_runtime != null) {
      await _runtime!.dispose();
      _runtime = null;
    }
    _isInitialized = false;
  }
}
