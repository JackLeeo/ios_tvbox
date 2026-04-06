import 'package:flutter/material.dart';
import 'package:flutter_js/flutter_js.dart';
import 'dart:convert';
import 'dart:async';
import '../models/spider_source.dart';
import './network_service.dart';
class JsEngine {
  FlutterJs? _jsEngine;
  JsRuntime? _runtime;
  bool _isInitialized = false;
  bool _isEnvReady = false;
  // 单例模式
  static final JsEngine instance = JsEngine._internal();
  JsEngine._internal();
  /// 懒加载初始化，仅在需要时执行
  Future<void> ensureInitialized() async {
    if (_isInitialized && _runtime != null && _isEnvReady) return;
    await init();
  }
  /// 初始化JS引擎，基于FlutterJS（Node.js环境）替代WebView
  Future<void> init({int retryCount = 0}) async {
    // 最大重试3次
    if (retryCount > 3) {
      throw Exception("JS引擎初始化失败，已重试3次");
    }
    // 重复初始化防护
    if (_isInitialized) {
      await dispose();
    }
    _isEnvReady = false;
    try {
      debugPrint('🚀 开始初始化Node.js JS引擎...');
      // 1. 创建FlutterJS引擎和运行时
      _jsEngine = getJavascriptRuntime();
      _runtime = _jsEngine!.runtime;
      // 2. 注册Dart方法到JS，提供http工具
      _jsEngine!.registerAsyncFunction('dartHttpGet', (args) async {
        final url = args[0] as String;
        final headers = args.length > 1 ? Map<String, dynamic>.from(args[1]) : <String, dynamic>{};
        try {
          final result = await NetworkService.instance.get(url, headers: headers);
          return jsonEncode(result);
        } catch (e) {
          throw Exception(e.toString());
        }
      });
      _jsEngine!.registerAsyncFunction('dartHttpPost', (args) async {
        final url = args[0] as String;
        final data = args.length > 1 ? args[1] : null;
        final headers = args.length > 2 ? Map<String, dynamic>.from(args[2]) : <String, dynamic>{};
        try {
          final result = await NetworkService.instance.post(url, data: data, headers: headers);
          return jsonEncode(result);
        } catch (e) {
          throw Exception(e.toString());
        }
      });
      // 3. 初始化JS全局环境，兼容浏览器和Node.js两种环境的脚本
      final initScript = """
        // 全局变量兼容，同时支持浏览器环境和Node.js环境的脚本
        globalThis = global;
        window = global;
        document = {
          createElement: () => ({
            setAttribute: () => {},
            src: '',
            onload: null
          }),
          getElementById: () => null
        };
        navigator = { userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15' };
        module = { exports: {} };
        exports = module.exports;
        console = {
          log: (...args) => { print('[JS] ' + args.map(a => JSON.stringify(a)).join(' ')); },
          error: (...args) => { print('[JS Error] ' + args.map(a => JSON.stringify(a)).join(' ')); }
        };
        // 全局错误捕获
        if (process) {
          process.on('uncaughtException', function(err) {
            console.error('全局JS错误:', err);
          });
        }
        // 爬虫基类
        if (global.CatVodSpider) delete global.CatVodSpider;
        global.CatVodSpider = class CatVodSpider {
          constructor() {}
          async homeContent(filter) { return {}; }
          async homeVideoContent() { return {}; }
          async categoryContent(tid, pg, filter, extend) { return {}; }
          async detailContent(ids) { return {}; }
          async searchContent(wd, quick, pg) { return {}; }
          async playerContent(flag, id, vipFlags) { return {}; }
          async liveContent() { return {}; }
        }
        // 全局http工具，兼容原来的接口
        const http = {
          get: async function(url, headers) {
            const result = await dartHttpGet(url, headers || {});
            return JSON.parse(result);
          },
          post: async function(url, data, headers) {
            const result = await dartHttpPost(url, data, headers || {});
            return JSON.parse(result);
          }
        };
        global.http = http;
        window.http = http;
        // 暴露执行脚本的方法，兼容原来的接口
        global.tvboxRunScript = async function(scriptCode) {
          try {
            // 先清理旧的爬虫类
            if (global.MySpider) delete global.MySpider;
            // 执行脚本
            let fn;
            if (typeof scriptCode === 'function') {
              fn = scriptCode;
            } else {
              fn = new Function(scriptCode);
            }
            const result = await fn();
            return {
              success: true,
              data: result
            };
          } catch (e) {
            console.error('脚本执行失败:', e);
            return {
              success: false,
              data: e.toString()
            };
          }
        };
        // 健康检查工具
        global.tvboxHealthCheck = function() {
          return "ok";
        };
      """;
      // 执行初始化脚本
      final initResult = _jsEngine!.evaluate(initScript);
      if (initResult.isError) {
        throw Exception("初始化JS环境失败: ${initResult.error}");
      }
      debugPrint('✅ JS环境初始化脚本执行完成');
      // 检查环境是否就绪
      final checkResult = _jsEngine!.evaluate("typeof tvboxRunScript !== 'undefined' && typeof tvboxHealthCheck !== 'undefined'");
      if (checkResult.isError || checkResult.stringResult != 'true') {
        throw Exception("TVBox运行环境加载失败，核心函数未就绪");
      }
      final healthResult = _jsEngine!.evaluate("tvboxHealthCheck()");
      if (healthResult.stringResult != 'ok') {
        throw Exception("JS引擎健康检查失败");
      }
      // 标记初始化完成
      _isInitialized = true;
      _isEnvReady = true;
      debugPrint('✅ Node.js JS引擎全量初始化完成，所有功能就绪');
    } catch (e) {
      _isInitialized = false;
      _isEnvReady = false;
      debugPrint('❌ JS引擎初始化失败: $e');
      await Future.delayed(const Duration(milliseconds: 300));
      await init(retryCount: retryCount + 1);
    }
  }
  /// 执行原始JS代码，带异常捕获
  Future<dynamic> executeRawScript(String script) async {
    if (!_isEnvReady || _jsEngine == null) {
      throw Exception("JS引擎未就绪");
    }
    try {
      final result = _jsEngine!.evaluate(script);
      if (result.isError) {
        throw Exception(result.error);
      }
      return result.stringResult;
    } catch (e) {
      debugPrint('❌ 原始JS执行失败: $e');
      rethrow;
    }
  }
  /// 执行爬虫脚本，基于Node.js JS引擎
  Future<dynamic> executeScript(SpiderSource source, String method, List<dynamic> args, {int retryCount = 0}) async {
    // 最大重试2次
    const maxRetry = 2;
    if (retryCount > maxRetry) {
      throw Exception("JS脚本执行失败，已重试$maxRetry次");
    }
    // 执行前确保引擎就绪
    await ensureInitialized();
    if (!_isEnvReady || _jsEngine == null) {
      throw Exception("JS引擎环境未就绪，请重试");
    }
    try {
      debugPrint('🚀 开始执行爬虫方法: $method, 重试次数: $retryCount');
      // 1. 加载远程JS脚本
      if (source.api?.isNotEmpty == true) {
        debugPrint('📥 开始加载远程JS脚本');
        final remoteScript = await NetworkService.instance.get(source.api!);
        final evalResult = _jsEngine!.evaluate(remoteScript);
        if (evalResult.isError) {
          throw Exception("远程JS脚本加载失败: ${evalResult.error}");
        }
        debugPrint('✅ 远程JS脚本加载完成');
      }
      // 2. 加载本地爬虫脚本
      if (source.ext?.isNotEmpty == true) {
        debugPrint('📥 开始加载本地爬虫脚本');
        // 先检查MySpider是否已存在，避免重复加载
        final hasSpiderResult = _jsEngine!.evaluate("typeof global.MySpider !== 'undefined'");
        if (hasSpiderResult.stringResult != 'true') {
          final evalResult = _jsEngine!.evaluate(source.ext!);
          if (evalResult.isError) {
            throw Exception("本地JS脚本加载失败: ${evalResult.error}");
          }
          debugPrint('✅ 本地爬虫脚本加载完成');
        } else {
          debugPrint('ℹ️ 本地爬虫脚本已存在，跳过加载');
        }
      }
      // 3. 序列化参数，生成执行代码
      final argsJson = args.map((e) => jsonEncode(e)).join(',');
      final execCode = """
        (async () => {
          const spider = new MySpider();
          const result = await spider.$method($argsJson);
          return tvboxRunScript(() => result);
        })();
      """;
      debugPrint('📝 执行代码: $execCode');
      // 4. 执行脚本
      final execResult = _jsEngine!.evaluate(execCode);
      if (execResult.isError) {
        throw Exception("JS执行失败: ${execResult.error}");
      }
      // 解析结果
      final resultJson = jsonDecode(execResult.stringResult);
      final bool success = resultJson['success'];
      final dynamic data = resultJson['data'];
      if (!success) {
        throw Exception(data ?? 'JS脚本执行失败');
      }
      debugPrint('✅ 脚本执行成功');
      return data;
    } catch (e) {
      debugPrint('❌ 脚本执行异常: $e, 重试次数: $retryCount');
      // 超时或错误自动重试
      if (retryCount < maxRetry) {
        await dispose();
        await Future.delayed(const Duration(milliseconds: 300));
        return await executeScript(source, method, args, retryCount: retryCount + 1);
      }
      await dispose();
      throw Exception("JS脚本执行异常: ${e.toString()}");
    }
  }
  /// 释放资源
  Future<void> dispose() async {
    if (_jsEngine != null) {
      _jsEngine!.dispose();
      _jsEngine = null;
      _runtime = null;
    }
    _isInitialized = false;
    _isEnvReady = false;
    debugPrint('♻️ JS引擎资源已释放');
  }
}
