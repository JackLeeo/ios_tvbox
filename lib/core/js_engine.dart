import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:async';
import '../models/spider_source.dart';
import './network_service.dart';

class JsEngine {
  WebViewController? _webViewController;
  bool _isInitialized = false;
  final Map<String, Completer<dynamic>> _pendingRequests = {};
  static const String _channelName = "tvbox_http";
  late Completer<void> _pageLoadedCompleter;

  static final JsEngine instance = JsEngine._internal();
  JsEngine._internal();

  // 【关键修复】懒加载初始化，只有用户点击播放/使用爬虫时才初始化，绝不启动时初始化
  Future<void> ensureInitialized() async {
    if (_isInitialized && _webViewController != null) return;
    await init();
  }

  // 初始化JS运行环境，仅在需要时调用
  Future<void> init() async {
    if (_isInitialized) {
      await dispose();
    }
    _pageLoadedCompleter = Completer<void>();

    try {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setUserAgent(
          "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              if (!_pageLoadedCompleter.isCompleted) {
                _pageLoadedCompleter.complete();
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (!_pageLoadedCompleter.isCompleted) {
                _pageLoadedCompleter.completeError(Exception("WebView加载失败: ${error.description}"));
              }
            },
          ),
        )
        ..addJavaScriptChannel(
          _channelName,
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
        );

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
          var globalThis = window;
          var module = { exports: {} };
          var exports = module.exports;

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

          window._tvboxHttpPending = {};
          window._tvboxHttpCallback = function(requestId, success, data) {
            const pending = window._tvboxHttpPending[requestId];
            if (pending) {
              delete window._tvboxHttpPending[requestId];
              if (success) pending.resolve(data);
              else pending.reject(data);
            }
          };

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

          window._tvboxRequestId = 0;

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
      """.replaceAll("\$_channelName", _channelName);

      await _webViewController!.loadHtmlString(initHtml);
      await _pageLoadedCompleter.future.timeout(const Duration(seconds: 10));
      await Future.delayed(const Duration(milliseconds: 300));

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  // 执行脚本前先确保引擎初始化完成
  Future<dynamic> executeScript(SpiderSource source, String method, List<dynamic> args) async {
    // 【关键修复】执行前才初始化，绝不启动时卡死主线程
    await ensureInitialized();

    try {
      if (source.api?.isNotEmpty == true) {
        final remoteScript = await NetworkService.instance.get(source.api!);
        await _webViewController!.runJavaScript(remoteScript);
      }

      if (source.ext?.isNotEmpty == true) {
        await _webViewController!.runJavaScript(source.ext!);
      }

      final argsJson = args.map((e) => jsonEncode(e)).join(',');
      final execCode = """
        (async () => {
          const spider = new MySpider();
          return await spider.$method($argsJson);
        })();
      """;

      final jsResult = await _webViewController!.runJavaScriptReturningResult("""
        window.tvboxExecuteScript(${jsonEncode(execCode)})
      """);

      final Map<String, dynamic> resultData = jsonDecode(jsResult.toString());
      if (resultData['success'] != true) {
        throw Exception(resultData['error'] ?? 'JS脚本执行失败');
      }

      return resultData['data'];
    } catch (e) {
      throw Exception("JS脚本执行异常: ${e.toString()}");
    }
  }

  // 释放资源
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
