import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:async';
import '../models/spider_source.dart';
import './network_service.dart';

class JsEngine {
  WebViewController? _webViewController;
  bool _isInitialized = false;
  bool _isEnvReady = false; // 【核心新增】标记JS全局环境是否完全就绪
  // JS-Dart异步请求映射表，处理http异步回调
  final Map<String, Completer<dynamic>> _pendingRequests = {};
  // 通道名常量
  static const String _channelName = "tvbox_http";
  late Completer<void> _pageLoadedCompleter;

  // 单例模式，和原有接口完全一致
  static final JsEngine instance = JsEngine._internal();
  JsEngine._internal();

  /// 懒加载初始化，仅在需要时执行，绝不阻塞启动
  Future<void> ensureInitialized() async {
    if (_isInitialized && _webViewController != null && _isEnvReady) return;
    await init();
  }

  /// 初始化JS运行环境，无头WebView后台加载，适配iOS无签名环境
  Future<void> init() async {
    // 重复初始化防护，先释放旧资源
    if (_isInitialized) {
      await dispose();
    }
    _pageLoadedCompleter = Completer<void>();
    _isEnvReady = false;

    try {
      // 1. 创建WebView控制器，【核心适配iOS】开启所有必要权限
      _webViewController = WebViewController()
        // 强制开启JavaScript支持，iOS端必须显式配置
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        // 背景透明，无头运行无UI
        ..setBackgroundColor(Colors.transparent)
        // 【iOS适配】设置标准Safari UA，避免无签名环境下的权限限制
        ..setUserAgent(
          "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        )
        // 【iOS适配】开启本地文件访问权限，解决无签名环境下的页面加载限制
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) async {
              // 页面加载完成后，额外等待JS上下文初始化完成
              await Future.delayed(const Duration(milliseconds: 300));
              if (!_pageLoadedCompleter.isCompleted) {
                _pageLoadedCompleter.complete();
              }
              // 标记环境就绪
              _isEnvReady = true;
              debugPrint('✅ JS引擎环境初始化完成，可执行脚本');
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('❌ WebView资源加载错误: ${error.description}, 错误码: ${error.errorCode}');
              if (!_pageLoadedCompleter.isCompleted) {
                _pageLoadedCompleter.completeError(Exception("WebView加载失败: ${error.description}"));
              }
              _isEnvReady = false;
            },
            onHttpError: (HttpResponseError error) {
              debugPrint('❌ WebView HTTP错误: 状态码${error.response?.statusCode}');
            },
            // 【iOS适配】允许所有导航，解决本地页面的跳转限制
            onNavigationRequest: (NavigationRequest request) {
              return NavigationDecision.navigate;
            },
          ),
        )
        // 注册JS-Dart通信通道，处理JS发起的http请求
        ..addJavaScriptChannel(
          _channelName,
          onMessageReceived: (JavaScriptMessage message) async {
            try {
              final Map<String, dynamic> msgData = jsonDecode(message.message);
              final String requestId = msgData['requestId'];
              final String method = msgData['method'];
              final List<dynamic> args = msgData['args'] ?? [];

              dynamic result;
              // 处理JS发起的http请求
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

              // 把请求结果返回给JS
              final jsCode = """
                if (window._tvboxHttpCallback) {
                  window._tvboxHttpCallback('$requestId', true, ${jsonEncode(result)});
                }
              """;
              await _webViewController?.runJavaScript(jsCode);
            } catch (e) {
              // 把错误返回给JS
              final Map<String, dynamic> msgData = jsonDecode(message.message);
              final String requestId = msgData['requestId'];
              final errorMsg = e.toString().replaceAll("'", "\\'").replaceAll("\n", "\\n").replaceAll("\r", "\\r");
              final jsCode = """
                if (window._tvboxHttpCallback) {
                  window._tvboxHttpCallback('$requestId', false, '$errorMsg');
                }
              """;
              await _webViewController?.runJavaScript(jsCode);
            }
          },
        );

      // 2. 加载初始化HTML，【核心修复】完善JS全局环境，避免重复声明报错
      final initHtml = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>TVBox JS Runtime</title>
      </head>
      <body>
        <script type="text/javascript">
          // 全局变量兼容，和TVBox JS脚本标准完全一致
          var globalThis = window;
          var module = { exports: {} };
          var exports = module.exports;

          // 【核心修复】先清理旧的类定义，避免重复声明语法错误
          if (window.CatVodSpider) delete window.CatVodSpider;
          if (window.MySpider) delete window.MySpider;

          // TVBox标准爬虫基类，所有自定义脚本继承此类
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

          // 待处理的http请求回调映射
          window._tvboxHttpPending = {};
          // http请求完成回调
          window._tvboxHttpCallback = function(requestId, success, data) {
            const pending = window._tvboxHttpPending[requestId];
            if (pending) {
              delete window._tvboxHttpPending[requestId];
              if (success) pending.resolve(data);
              else pending.reject(data);
            }
          };

          // 注入全局http工具，和原有JS脚本100%兼容
          const http = {
            get: async function(url, headers) {
              return new Promise((resolve, reject) => {
                const requestId = (++window._tvboxRequestId || 1).toString();
                window._tvboxHttpPending[requestId] = { resolve, reject };
                $_channelName.postMessage(JSON.stringify({
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
                $_channelName.postMessage(JSON.stringify({
                  requestId: requestId,
                  method: 'post',
                  args: [url, data, headers || {}]
                }));
              });
            }
          };

          // 全局请求ID计数器
          window._tvboxRequestId = 0;

          // 【核心修复】全局执行JS脚本的方法，内置try-catch，避免原生异常
          window.tvboxExecuteScript = async function(scriptCode) {
            try {
              // 执行前清理旧的MySpider定义，避免重复声明
              if (window.MySpider) delete window.MySpider;
              const result = await eval(scriptCode);
              return JSON.stringify({ success: true, data: result });
            } catch (e) {
              console.error('JS脚本执行错误:', e);
              return JSON.stringify({ success: false, error: e.toString() });
            }
          };
        </script>
      </body>
      </html>
      """.replaceAll("\$_channelName", _channelName);

      // 加载初始化HTML
      await _webViewController!.loadHtmlString(initHtml);
      // 等待页面加载+JS环境完全就绪，加超时兜底
      await _pageLoadedCompleter.future.timeout(const Duration(seconds: 15));
      // 额外等待JS上下文稳定，适配iOS无签名环境
      await Future.delayed(const Duration(milliseconds: 500));

      _isInitialized = true;
      debugPrint('✅ JS引擎初始化完成');
    } catch (e) {
      _isInitialized = false;
      _isEnvReady = false;
      debugPrint('❌ JS引擎初始化失败: $e');
      rethrow;
    }
  }

  /// 执行爬虫脚本方法，和原有接口完全一致，上层代码零改动
  Future<dynamic> executeScript(SpiderSource source, String method, List<dynamic> args) async {
    // 执行前确保引擎完全就绪
    await ensureInitialized();
    // 额外校验环境是否就绪，不就绪直接抛出明确错误
    if (!_isEnvReady || _webViewController == null) {
      throw Exception("JS引擎环境未就绪，请重试");
    }

    try {
      // 1. 加载远程JS脚本（如果有）
      if (source.api?.isNotEmpty == true) {
        final remoteScript = await NetworkService.instance.get(source.api!);
        // 远程脚本用单独的方法执行，避免污染全局环境
        await _webViewController!.runJavaScript("""
          (async () => {
            ${remoteScript.toString()}
          })();
        """);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 2. 加载本地JS脚本（ext字段），【核心修复】仅在MySpider不存在时执行，避免重复声明
      if (source.ext?.isNotEmpty == true) {
        // 先检查MySpider是否已存在，不存在再执行ext脚本
        final hasSpider = await _webViewController!.runJavaScriptReturningResult("""
          typeof window.MySpider !== 'undefined'
        """);
        if (hasSpider.toString() != 'true') {
          await _webViewController!.runJavaScript(source.ext!);
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      // 3. 【核心修复】严格转义参数，避免iOS端解析失败
      final argsJson = args.map((e) => jsonEncode(e)).join(',');
      // 执行目标爬虫方法，用try-catch包裹，避免原生异常
      final execCode = """
        (async () => {
          const spider = new MySpider();
          return await spider.$method($argsJson);
        })();
      """;

      // 4. 执行JS代码，获取返回结果
      final jsResult = await _webViewController!.runJavaScriptReturningResult("""
        window.tvboxExecuteScript(${jsonEncode(execCode)})
      """);

      // 5. 解析返回结果
      final Map<String, dynamic> resultData = jsonDecode(jsResult.toString());
      if (resultData['success'] != true) {
        throw Exception(resultData['error'] ?? 'JS脚本执行失败');
      }

      return resultData['data'];
    } catch (e) {
      debugPrint('❌ JS脚本执行异常: $e');
      // 执行失败重置引擎，避免后续调用持续报错
      await dispose();
      throw Exception("JS脚本执行异常: ${e.toString()}");
    }
  }

  /// 释放资源，和原有接口完全一致
  Future<void> dispose() async {
    if (_webViewController != null) {
      await _webViewController!.clearCache();
      await _webViewController!.clearLocalStorage();
      _webViewController = null;
    }
    _pendingRequests.clear();
    _isInitialized = false;
    _isEnvReady = false;
    if (!_pageLoadedCompleter.isCompleted) {
      _pageLoadedCompleter.completeError(Exception("引擎已释放"));
    }
  }
}
