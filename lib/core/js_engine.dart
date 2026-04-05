import 'package:flutter/foundation.dart';
import 'package:flutter_nodejs/flutter_nodejs.dart';
import 'dart:convert';
import 'dart:async';
import '../models/spider_source.dart';
import './network_service.dart';

class JsEngine {
  bool _isInitialized = false;
  // 单例模式，和原有接口完全一致
  static final JsEngine instance = JsEngine._internal();
  JsEngine._internal();

  /// 懒加载初始化Node.js运行时
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    await init();
  }

  /// 初始化Node.js运行时，注入TVBox全局环境
  Future<void> init() async {
    try {
      debugPrint('🚀 开始初始化Node.js运行时');
      // 1. 启动Node.js引擎
      await FlutterNodejs.instance.startEngine();
      
      // 2. 注入全局HTTP工具，和TVBox JS标准完全兼容
      final httpInjectCode = """
        const http = {
          get: async function(url, headers = {}) {
            return new Promise((resolve, reject) => {
              // 调用Dart端网络请求，完全适配你的NetworkService
              globalThis._dartHttpCallback = (success, data) => {
                if (success) resolve(data);
                else reject(data);
              };
              globalThis.sendHttpMessage('get', [url, headers]);
            });
          },
          post: async function(url, data = null, headers = {}) {
            return new Promise((resolve, reject) => {
              globalThis._dartHttpCallback = (success, data) => {
                if (success) resolve(data);
                else reject(data);
              };
              globalThis.sendHttpMessage('post', [url, data, headers]);
            });
          }
        };
        // 全局变量兼容
        var globalThis = global;
        var module = { exports: {} };
        var exports = module.exports;
      """;
      await FlutterNodejs.instance.evaluateCode(httpInjectCode);

      // 3. 注入TVBox标准爬虫基类
      final baseSpiderCode = """
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
      """;
      await FlutterNodejs.instance.evaluateCode(baseSpiderCode);

      // 4. 注册Dart-JS通信通道，处理HTTP请求
      FlutterNodejs.instance.onMessageReceived.listen((message) async {
        try {
          final Map<String, dynamic> msgData = jsonDecode(message);
          final String method = msgData['method'];
          final List<dynamic> args = msgData['args'];

          dynamic result;
          if (method == 'get') {
            final url = args[0] as String;
            final headers = args.length > 1 ? Map<String, dynamic>.from(args[1]) : <String, dynamic>{};
            result = await NetworkService.instance.get(url, headers: headers);
          } else if (method == 'post') {
            final url = args[0] as String;
            final data = args.length > 1 ? args[1] : null;
            final headers = args.length > 2 ? Map<String, dynamic>.from(args[2]) : <String, dynamic>{};
            result = await NetworkService.instance.post(url, data: data, headers: headers);
          }

          // 把结果返回给JS
          final jsCode = """
            if (globalThis._dartHttpCallback) {
              globalThis._dartHttpCallback(true, ${jsonEncode(result)});
              delete globalThis._dartHttpCallback;
            }
          """;
          await FlutterNodejs.instance.evaluateCode(jsCode);
        } catch (e) {
          // 把错误返回给JS
          final jsCode = """
            if (globalThis._dartHttpCallback) {
              globalThis._dartHttpCallback(false, '${e.toString().replaceAll("'", "\\'")}');
              delete globalThis._dartHttpCallback;
            }
          """;
          await FlutterNodejs.instance.evaluateCode(jsCode);
        }
      });

      // 注入Dart通信方法到JS全局
      await FlutterNodejs.instance.evaluateCode("""
        globalThis.sendHttpMessage = function(method, args) {
          sendMessage(JSON.stringify({
            method: method,
            args: args
          }));
        };
      """);

      _isInitialized = true;
      debugPrint('✅ Node.js运行时初始化完成，TVBox环境就绪');
    } catch (e) {
      _isInitialized = false;
      debugPrint('❌ Node.js初始化失败: $e');
      rethrow;
    }
  }

  /// 执行爬虫脚本，和原有接口完全一致，上层代码零修改
  Future<dynamic> executeScript(SpiderSource source, String method, List<dynamic> args) async {
    // 执行前确保引擎就绪
    await ensureInitialized();
    if (!_isInitialized) {
      throw Exception("Node.js引擎未就绪，请重试");
    }

    try {
      debugPrint('🚀 执行爬虫方法: $method');
      // 1. 加载远程JS脚本
      if (source.api?.isNotEmpty == true) {
        final remoteScript = await NetworkService.instance.get(source.api!);
        await FlutterNodejs.instance.evaluateCode(remoteScript);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // 2. 加载本地爬虫脚本，避免重复声明
      if (source.ext?.isNotEmpty == true) {
        final hasSpider = await FlutterNodejs.instance.evaluateCode("typeof MySpider !== 'undefined'");
        if (hasSpider.toString() != 'true') {
          await FlutterNodejs.instance.evaluateCode(source.ext!);
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // 3. 序列化参数，执行目标方法
      final argsJson = args.map((e) => jsonEncode(e)).join(',');
      final execCode = """
        (async () => {
          const spider = new MySpider();
          return await spider.$method($argsJson);
        })();
      """;

      // 4. 执行JS代码，获取返回结果
      final result = await FlutterNodejs.instance.evaluateCode(execCode);
      debugPrint('✅ 脚本执行成功');
      
      // 5. 解析返回结果，兼容JSON格式
      if (result is String) {
        try {
          return jsonDecode(result);
        } catch (_) {
          return result;
        }
      }
      return result;
    } catch (e) {
      debugPrint('❌ JS脚本执行异常: $e');
      await dispose();
      throw Exception("JS脚本执行异常: ${e.toString()}");
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    try {
      await FlutterNodejs.instance.stopEngine();
      _isInitialized = false;
      debugPrint('♻️ Node.js引擎已释放');
    } catch (e) {
      debugPrint('❌ Node.js释放失败: $e');
    }
  }
}
