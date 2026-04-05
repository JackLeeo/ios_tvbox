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

  // JS执行结果回调映射表
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

  /// 【重构】彻底解决超时问题的初始化逻辑
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
    final Completer<void> pageLoadedCompleter = Completer<void>();

    try {
      debugPrint('🚀 开始初始化JS引擎...');
      // 1. 创建WebViewController
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setUserAgent(
          "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        )
        // 【核心修复1】先注册通道，再加载HTML，确保JS执行时通道已存在
        ..addJavaScriptChannel(
          _execChannelName,
          onMessageReceived: (JavaScriptMessage message) {
            try {
              debugPrint('📥 收到JS执行结果: ${message.message.substring(0, 100)}');
              final Map<String, dynamic> result = jsonDecode(message.message);
              final String execId = result['execId'];
              final bool success = result['success'];
              final dynamic data = result['data'];

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
              // 解析失败也必须结束等待，避免超时
              final Map<String, dynamic> result = jsonDecode(message.message);
              final String execId = result['execId'];
              if (_pendingExecutions.containsKey(execId)) {
                final completer = _pendingExecutions.remove(execId)!;
                completer.completeError(Exception("执行结果解析失败: $e"));
              }
            }
          },
        )
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

              final jsCode = """
                if (window._tvboxHttpCallback) {
                  window._tvboxHttpCallback('$requestId', true, ${jsonEncode(result)});
                }
              """;
              await _webViewController?.runJavaScript(jsCode);
            } catch (e) {
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
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) async {
              debugPrint('✅ HTML页面加载完成: $url');
              if (!pageLoadedCompleter.isCompleted) {
                pageLoadedCompleter.complete();
              }
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('❌ WebView资源错误: ${error.description}, 错误码: ${error.errorCode}');
              if (!pageLoadedCompleter.isCompleted) {
                pageLoadedCompleter.completeError(Exception("WebView加载失败: ${error.description}"));
              }
              _isEnvReady = false;
            },
            onNavigationRequest: (NavigationRequest request) {
              return NavigationDecision.navigate;
            },
          ),
        );

      // 2. 加载完整的TVBox运行环境HTML（合并两阶段加载，减少时序问题）
      final fullEnvHtml = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>TVBox JS Runtime</title>
      </head>
      <body>
        <script type="text/javascript">
          // 全局变量兼容
          var globalThis = window;
          var module = { exports: {} };
          var exports = module.exports;

          // 【核心修复2】全局错误捕获，任何JS错误都打印日志
          window.onerror = function(message, source, lineno, colno, error) {
            console.error('全局JS错误:', message, error);
            return false;
          };

          // 爬虫基类
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

          // 【核心修复3】100%确保回调，无论成功失败
          window.tvboxRunScript = function(scriptCode) {
            const execId = (++window._tvboxExecId).toString();
            console.log('开始执行脚本, execId:', execId);
            
            // 立即执行，用try-catch包裹所有逻辑，绝对不能中断
            (async () => {
              try {
                // 先清理旧的爬虫类
                if (window.MySpider) delete window.MySpider;
                console.log('清理旧MySpider完成');
                
                // 执行脚本
                console.log('开始执行业务脚本');
                const result = await eval(scriptCode);
                console.log('脚本执行成功, 结果:', JSON.stringify(result).substring(0, 200));
                
                // 成功回调，必须执行
                $_execChannelName.postMessage(JSON.stringify({
                  execId: execId,
                  success: true,
                  data: result
                }));
                console.log('成功回调已发送');
              } catch (e) {
                console.error('脚本执行失败:', e);
                // 失败回调，必须执行，哪怕JSON序列化失败也有兜底
                try {
                  $_execChannelName.postMessage(JSON.stringify({
                    execId: execId,
                    success: false,
                    data: e.toString()
                  }));
                } catch (jsonError) {
                  $_execChannelName.postMessage(JSON.stringify({
                    execId: execId,
                    success: false,
                    data: 'JS执行失败，JSON序列化异常'
                  }));
                }
              }
            })();
            
            return execId;
          };

          // 【健康检查工具】验证通道是否正常
          window.tvboxHealthCheck = function() {
            return "ok";
          };
        </script>
      </body>
      </html>
      """
          .replaceAll("\$_execChannelName", _execChannelName)
          .replaceAll("\$_httpChannelName", _httpChannelName);

      // 加载HTML
      await _webViewController!.loadHtmlString(fullEnvHtml);
      await pageLoadedCompleter.future.timeout(const Duration(seconds: 10));
      debugPrint('✅ HTML加载完成，等待JS环境就绪');

      // 3. 循环检测核心函数是否就绪
      bool envReady = false;
      int envCheckCount = 0;
      while (!envReady && envCheckCount < 50) {
        try {
          final result = await _webViewController!.runJavaScriptReturningResult("typeof window.tvboxRunScript !== 'undefined' && typeof window.tvboxHealthCheck !== 'undefined'");
          if (result.toString() == "true") {
            // 执行健康检查，验证JS执行正常
            final healthResult = await _webViewController!.runJavaScriptReturningResult("window.tvboxHealthCheck()");
            if (healthResult.toString() == "ok") {
              envReady = true;
              break;
            }
          }
        } catch (e) {
          debugPrint('⏳ 运行环境就绪检测中... 第${envCheckCount+1}次');
        }
        await Future.delayed(const Duration(milliseconds: 100));
        envCheckCount++;
      }

      if (!envReady) {
        throw Exception("TVBox运行环境加载失败，核心函数未就绪");
      }

      // 标记初始化完成
      _isInitialized = true;
      _isEnvReady = true;
      debugPrint('✅ JS引擎全量初始化完成，所有功能就绪');
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
    if (!_isEnvReady || _webViewController == null) {
      throw Exception("JS引擎未就绪");
    }
    try {
      return await _webViewController!.runJavaScriptReturningResult(script);
    } catch (e) {
      debugPrint('❌ 原始JS执行失败: $e');
      rethrow;
    }
  }

  /// 【重构】执行爬虫脚本，彻底解决超时问题
  Future<dynamic> executeScript(SpiderSource source, String method, List<dynamic> args, {int retryCount = 0}) async {
    // 最大重试2次
    const maxRetry = 2;
    if (retryCount > maxRetry) {
      throw Exception("JS脚本执行失败，已重试$maxRetry次");
    }

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
      debugPrint('🚀 开始执行爬虫方法: $method, execId: $execId, 重试次数: $retryCount');

      // 1. 加载远程JS脚本
      if (source.api?.isNotEmpty == true) {
        debugPrint('📥 开始加载远程JS脚本');
        final remoteScript = await NetworkService.instance.get(source.api!);
        await _webViewController!.runJavaScript(remoteScript);
        await Future.delayed(const Duration(milliseconds: 100));
        debugPrint('✅ 远程JS脚本加载完成');
      }

      // 2. 加载本地爬虫脚本
      if (source.ext?.isNotEmpty == true) {
        debugPrint('📥 开始加载本地爬虫脚本');
        // 先检查MySpider是否已存在，避免重复加载
        final hasSpider = await executeRawScript("typeof window.MySpider !== 'undefined'");
        if (hasSpider.toString() != 'true') {
          await _webViewController!.runJavaScript(source.ext!);
          await Future.delayed(const Duration(milliseconds: 200));
          debugPrint('✅ 本地爬虫脚本加载完成');
        } else {
          debugPrint('ℹ️ 本地爬虫脚本已存在，跳过加载');
        }
      }

      // 3. 序列化参数，生成执行代码
      final argsJson = args.map((e) => jsonEncode(e)).join(',');
      final execCode = """
        const spider = new MySpider();
        return await spider.$method($argsJson);
      """;
      debugPrint('📝 执行代码: $execCode');

      // 4. 执行脚本
      await _webViewController!.runJavaScript("""
        window.tvboxRunScript(${jsonEncode(execCode)});
      """);

      // 5. 等待执行结果，【优化】缩短超时时间到15秒，避免长时间等待
      final result = await execCompleter.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception("JS脚本执行超时"),
      );

      _pendingExecutions.remove(execId);
      debugPrint('✅ 脚本执行成功，execId: $execId');
      return result;
    } catch (e) {
      _pendingExecutions.remove(execId);
      debugPrint('❌ 脚本执行异常: $e, 重试次数: $retryCount');
      
      // 超时自动重试
      if (e.toString().contains("超时") && retryCount < maxRetry) {
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
    if (_webViewController != null) {
      await _webViewController!.clearCache();
      await _webViewController!.clearLocalStorage();
      _webViewController = null;
    }
    // 强制结束所有等待中的执行，避免内存泄漏和永久等待
    _pendingExecutions.forEach((key, completer) {
      if (!completer.isCompleted) {
        completer.completeError(Exception("JS引擎已释放"));
      }
    });
    _pendingExecutions.clear();
    _pendingHttpRequests.clear();
    _isInitialized = false;
    _isEnvReady = false;
    debugPrint('♻️ JS引擎资源已释放');
  }
}
