import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:async';
import '../models/spider_source.dart';
import './network_service.dart';

class JsEngine {
  WebViewController? _webViewController;
  bool _isInitialized = false;
  // JS-Dart异步请求映射表，处理http异步回调
  final Map<String, Completer<dynamic>> _pendingRequests = {};
  // 通道名常量
  static const String _channelName = "tvbox_http";
  // 页面加载完成标志
  final Completer<void> _pageLoadedCompleter = Completer<void>();

  // 单例模式，和原有接口完全一致
  static final JsEngine instance = JsEngine._internal();
  JsEngine._internal();

  /// 初始化JS运行环境，无头WebView后台加载，无UI侵入
  Future<void> init() async {
    if (_isInitialized && _webViewController != null) return;
    // 重置页面加载标志
    if (_pageLoadedCompleter.isCompleted) {
      _pageLoadedCompleter = Completer<void>();
    }

    // 1. 创建WebView控制器，适配4.13.1官方标准初始化方式
    _webViewController = WebViewController()
      // 开启JavaScript支持，必须配置
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // 背景透明，无头运行无UI
      ..setBackgroundColor(Colors.transparent)
      // 设置浏览器UA，适配爬虫场景
      ..setUserAgent(
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
      )
      // 配置页面导航监听，确保JS环境加载完成
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // 页面加载完成，标记JS环境就绪
            if (!_pageLoadedCompleter.isCompleted) {
              _pageLoadedCompleter.complete();
            }
          },
          onWebResourceError: (WebResourceError error) {
            // 页面加载失败处理
            if (!_pageLoadedCompleter.isCompleted) {
              _pageLoadedCompleter.completeError(Exception("WebView加载失败: ${error.description}"));
            }
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
            await _webViewController?.runJavaScript("""
              window._tvboxHttpCallback('$requestId', true, ${jsonEncode(result)});
            """);
          } catch (e) {
            // 把错误返回给JS
            final Map<String, dynamic> msgData = jsonDecode(message.message);
            final String requestId = msgData['requestId'];
            await _webViewController?.runJavaScript("""
              window._tvboxHttpCallback('$requestId', false, '${e.toString().replaceAll("'", "\\'")}');
            """);
          }
        },
      );

    // 2. 加载空白HTML，初始化JS全局环境（TVBox标准兼容）
    final initHtml = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>TVBox JS Runtime</title>
    </head>
    <body>
      <script type="text/javascript">
        // 全局变量兼容，和TVBox JS脚本标准完全一致
        var globalThis = window;
        var module = { exports: {} };
        var exports = module.exports;

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

        // 注入全局http工具，和原有JS脚本100%兼容，无需修改任何JS代码
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

        // 全局执行JS脚本的方法，供Dart侧调用
        window.tvboxExecuteScript = async function(scriptCode) {
          try {
            const result = await eval(scriptCode);
            return JSON.stringify({ success: true, data: result });
          } catch (e) {
            return JSON.stringify({ success: false, error: e.toString() });
          }
        };
      </script>
    </body>
    </html>
    """.replaceAll("$_channelName", _channelName);

    // 加载初始化HTML，完成JS环境准备
    await _webViewController!.loadHtmlString(initHtml);
    // 等待页面加载完成，确保JS环境完全就绪
    await _pageLoadedCompleter.future;

    _isInitialized = true;
  }

  /// 执行爬虫脚本方法，和原有接口完全一致，上层代码零改动
  Future<dynamic> executeScript(SpiderSource source, String method, List<dynamic> args) async {
    if (!_isInitialized || _webViewController == null) await init();

    try {
      // 1. 加载远程JS脚本
      if (source.api?.isNotEmpty == true) {
        final remoteScript = await NetworkService.instance.get(source.api!);
        await _webViewController!.runJavaScript(remoteScript);
      }

      // 2. 加载本地JS脚本（ext字段）
      if (source.ext?.isNotEmpty == true) {
        await _webViewController!.runJavaScript(source.ext!);
      }

      // 3. 序列化参数，执行目标爬虫方法
      final argsJson = args.map((e) => jsonEncode(e)).join(',');
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
    if (!_pageLoadedCompleter.isCompleted) {
      _pageLoadedCompleter.completeError(Exception("引擎已释放"));
    }
  }
}
