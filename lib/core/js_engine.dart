import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:async';
import '../models/spider_source.dart';
import './network_service.dart';

class JsEngine {
  WebViewController? _webViewController;
  bool _isInitialized = false;
  bool _isEnvReady = false;

  // 【核心重构】JS执行结果回调映射表，替代Promise返回
  final Map<String, Completer<dynamic>> _pendingExecutions = {};
  // HTTP请求回调映射表
  final Map<String, Completer<dynamic>> _pendingHttpRequests = {};

  // 通道名常量
  static const String _execChannelName = "tvbox_exec_result";
  static const String _httpChannelName = "tvbox_http";

  // 单例模式
  static final JsEngine instance = JsEngine._internal();
  JsEngine._internal();

  /// 懒加载初始化，仅在需要时执行
  Future<void> ensureInitialized() async {
    if (_isInitialized && _webViewController != null && _isEnvReady) return;
    await init();
  }

  /// 【完全重构】初始化JS运行环境，适配iOS无签名环境
  Future<void> init() async {
    // 重复初始化防护，先彻底释放旧资源
    if (_isInitialized) {
      await dispose();
    }
    _isEnvReady = false;
    final Completer<void> pageLoadedCompleter = Completer<void>();

    try {
      // 1. 创建WebView控制器，【iOS专属优化】开启所有JS权限，规避无签名环境限制
      _webViewController = WebViewController()
        // 强制开启JavaScript，iOS端显式声明
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        // 背景透明，无头运行
        ..setBackgroundColor(Colors.transparent)
        // 【iOS适配】标准Safari UA，绕过无签名环境的权限拦截
        ..setUserAgent(
          "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        )
        // 【iOS适配】禁用内容安全策略，允许内联JS执行
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) async {
              // 页面加载完成后，等待JS上下文初始化
              await Future.delayed(const Duration(milliseconds: 300));
              if (!pageLoadedCompleter.isCompleted) {
                pageLoadedCompleter.complete();
              }
              _isEnvReady = true;
              debugPrint('✅ JS引擎环境就绪，可执行脚本');
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('❌ WebView资源错误: ${error.description}, 错误码: ${error.errorCode}');
              if (!pageLoadedCompleter.isCompleted) {
                pageLoadedCompleter.completeError(Exception("WebView加载失败: ${error.description}"));
              }
              _isEnvReady = false;
            },
            // 允许所有导航，解除iOS本地页面限制
            onNavigationRequest: (NavigationRequest request) {
              return NavigationDecision.navigate;
            },
          ),
        )
        // 【核心重构1】注册JS执行结果返回通道，替代Promise
        ..addJavaScriptChannel(
          _execChannelName,
          onMessageReceived: (JavaScriptMessage message) {
            try {
              final Map<String, dynamic> result = jsonDecode(message.message);
              final String execId = result['execId'];
              final bool success = result['success'];
              final dynamic data = result['data'];

              // 找到对应的等待器，返回结果
              if (_pendingExecutions.containsKey(execId)) {
                final completer = _pendingExecutions.remove(execId)!;
                if (success) {
                  completer.complete(data);
                } else {
                  completer.completeError(Exception(data ?? 'JS脚本执行失败'));
                }
              }
            } catch (e) {
              debugPrint('❌ 执行结果解析失败: $e');
            }
          },
        )
        // 【核心重构2】注册HTTP请求通道，和执行通道分离
        ..addJavaScriptChannel(
          _httpChannelName,
          onMessageReceived: (JavaScriptMessage message) async {
            try {
              final Map<String, dynamic> msgData = jsonDecode(message.message);
              final String requestId = msgData['requestId'];
              final String method = msgData['method'];
              final List<dynamic> args = msgData['args'] ?? [];

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

              // 把HTTP结果返回给JS
              final jsCode = """
                if (window._tvboxHttpCallback) {
                  window._tvboxHttpCallback('$requestId', true, ${jsonEncode(result)});
                }
              """;
              await _webViewController?.runJavaScript(jsCode);
            } catch (e) {
              // 把HTTP错误返回给JS
              final Map<String, dynamic> msgData = jsonDecode(message.message);
              final String requestId = msgData['requestId'];
              final errorMsg = e.toString().replaceAll("'", "\\'").replaceAll("\n", "\\n");
              final jsCode = """
                if (window._tvboxHttpCallback) {
                  window._tvboxHttpCallback('$requestId', false, '$errorMsg');
                }
              """;
              await _webViewController?.runJavaScript(jsCode);
            }
          },
        );

      // 2. 【核心重构】初始化HTML，彻底解决async函数Promise问题，所有执行通过通道返回
      final initHtml = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta http-equiv="Content-Security-Policy" content="default-src * 'unsafe-inline' 'unsafe-eval' data: blob:;">
        <title>TVBox JS Runtime</title>
      </head>
      <body>
        <script type="text/javascript">
          // 全局变量兼容
          var globalThis = window;
          var module = { exports: {} };
          var exports = module.exports;

          // 【修复】用window赋值替代class声明，彻底避免重复声明语法错误
          if (window.CatVodSpider) delete window.CatVodSpider;
          window.CatVodSpider = class CatVodSpider {
            constructor() {}
            async homeContent(filter) { return {}; }
            async homeVideoContent() { return {}; }
            async categoryContent(tid, pg, filter, extend) { return {}; }
            async detailContent(ids) { return {}; }
            async searchContent(wd, quick, pg) { return {}; }
            async playerContent(flag, id, vipFlags) { return {}; }
            async liveContent() { return {}; }
          }

          // HTTP请求相关
          window._tvboxHttpPending = {};
          window._tvboxHttpCallback = function(requestId, success, data) {
            const pending = window._tvboxHttpPending[requestId];
            if (pending) {
              delete window._tvboxHttpPending[requestId];
              if (success) pending.resolve(data);
              else pending.reject(data);
            }
          };

          // 全局http工具
          const http = {
            get: async function(url, headers) {
              return new Promise((resolve, reject) => {
                const requestId = (++window._tvboxRequestId || 1).toString();
                window._tvboxHttpPending[requestId] = { resolve, reject };
                $_httpChannelName.postMessage(JSON.stringify({
                  requestId: requestId,
                  method: 'get',
                  args: [url, headers || {}]
                }));
              });
            },
            post: async function(url, data, headers) {
              return new Promise((resolve, reject) => {
                const requestId = (++window._tvboxRequestId || 1).toString();
                window._tvboxHttpPending[requestId] = { resolve, reject };
                $_httpChannelName.postMessage(JSON.stringify({
                  requestId: requestId,
                  method: 'post',
                  args: [url, data, headers || {}]
                }));
              });
            }
          };

          window._tvboxRequestId = 0;
          window._tvboxExecId = 0;

          // 【核心重构】全局执行方法，通过通道返回结果，不返回Promise
          window.tvboxRunScript = function(scriptCode) {
            const execId = (++window._tvboxExecId).toString();
            (async () => {
              try {
                // 执行前清理旧的爬虫类，避免重复声明
                if (window.MySpider) delete window.MySpider;
                // 执行脚本
                const result = await eval(scriptCode);
                // 执行成功，通过通道返回结果
                $_execChannelName.postMessage(JSON.stringify({
                  execId: execId,
                  success: true,
                  data: result
                }));
              } catch (e) {
                console.error('JS执行错误:', e);
                // 执行失败，通过通道返回错误
                $_execChannelName.postMessage(JSON.stringify({
                  execId: execId,
                  success: false,
                  data: e.toString()
                }));
              }
            })();
            return execId;
          };
        </script>
      </body>
      </html>
      """
          .replaceAll("\$_execChannelName", _execChannelName)
          .replaceAll("\$_httpChannelName", _httpChannelName);

      // 加载初始化HTML
      await _webViewController!.loadHtmlString(initHtml);
      // 等待页面加载完成，加超时兜底
      await pageLoadedCompleter.future.timeout(const Duration(seconds: 15));
      // 额外等待JS上下文稳定
      await Future.delayed(const Duration(milliseconds: 500));

      // 【iOS验证】执行最简单的JS，确认环境完全可用
      await _runSimpleTest();

      _isInitialized = true;
      debugPrint('✅ JS引擎初始化完成，测试通过');
    } catch (e) {
      _isInitialized = false;
      _isEnvReady = false;
      debugPrint('❌ JS引擎初始化失败: $e');
      rethrow;
    }
  }

  /// 【iOS验证】执行最简单的JS，确认环境可用
  Future<void> _runSimpleTest() async {
    final testResult = await executeRawScript("1 + 1");
    if (testResult.toString() != "2") {
      throw Exception("JS引擎测试失败，无法正常执行脚本");
    }
    debugPrint('✅ JS引擎基础测试通过');
  }

  /// 执行原始JS代码，返回同步结果
  Future<dynamic> executeRawScript(String script) async {
    if (!_isEnvReady || _webViewController == null) {
      throw Exception("JS引擎未就绪");
    }
    return await _webViewController!.runJavaScriptReturningResult(script);
  }

  /// 【核心重构】执行爬虫脚本，完全适配iOS，无Promise问题
  Future<dynamic> executeScript(SpiderSource source, String method, List<dynamic> args) async {
    // 执行前确保引擎就绪
    await ensureInitialized();
    if (!_isEnvReady || _webViewController == null) {
      throw Exception("JS引擎环境未就绪，请重试");
    }

    // 生成唯一执行ID
    final String execId = DateTime.now().millisecondsSinceEpoch.toString();
    final Completer<dynamic> execCompleter = Completer<dynamic>();
    _pendingExecutions[execId] = execCompleter;

    try {
      // 1. 加载远程JS脚本（如果有）
      if (source.api?.isNotEmpty == true) {
        final remoteScript = await NetworkService.instance.get(source.api!);
        await _webViewController!.runJavaScript(remoteScript);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 2. 加载本地爬虫脚本（ext字段），仅在不存在时加载
      if (source.ext?.isNotEmpty == true) {
        final hasSpider = await executeRawScript("typeof window.MySpider !== 'undefined'");
        if (hasSpider.toString() != 'true') {
          await _webViewController!.runJavaScript(source.ext!);
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      // 3. 【核心】序列化参数，生成执行代码
      final argsJson = args.map((e) => jsonEncode(e)).join(',');
      final execCode = """
        const spider = new MySpider();
        return await spider.$method($argsJson);
      """;

      // 4. 执行脚本，通过通道获取结果
      await _webViewController!.runJavaScript("""
        window.tvboxRunScript(${jsonEncode(execCode)});
      """);

      // 5. 等待执行结果返回，加超时兜底
      final result = await execCompleter.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception("JS脚本执行超时"),
      );

      // 执行完成，清理等待器
      _pendingExecutions.remove(execId);
      return result;
    } catch (e) {
      // 执行失败，清理等待器
      _pendingExecutions.remove(execId);
      debugPrint('❌ JS脚本执行异常: $e');
      // 失败重置引擎，避免后续持续报错
      await dispose();
      throw Exception("JS脚本执行异常: ${e.toString()}");
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_webViewController != null) {
      await _webViewController!.clearCache();
      await _webViewController!.clearLocalStorage();
      _webViewController = null;
    }
    _pendingExecutions.clear();
    _pendingHttpRequests.clear();
    _isInitialized = false;
    _isEnvReady = false;
  }
}
