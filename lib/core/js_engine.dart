import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:async';
import '../models/spider_source.dart';
import './network_service.dart';
import './log_service.dart';

class JsEngine {
  WebViewController? _controller;
  bool _ready = false;
  final Map<String, Completer<dynamic>> _tasks = {};

  static final JsEngine instance = JsEngine._internal();
  JsEngine._internal();

  final _log = AppLogService.instance.log;

  Future<void> ensureInitialized() async {
    if (_ready && _controller != null) {
      _log("JS引擎：已就绪，直接复用");
      return;
    }
    _log("JS引擎：开始初始化流程");
    await _init();
  }

  Future<void> _init() async {
    try {
      await dispose();
      _log("销毁旧JS引擎实例");

      final completer = Completer<void>();
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel(
          "jsResult",
          onMessageReceived: (msg) {
            try {
              final data = jsonDecode(msg.message);
              final taskId = data['id'];
              final success = data['ok'] == true;
              if (success) {
                _log("JS任务[$taskId]：执行成功");
              } else {
                _log("JS任务[$taskId]：执行失败 - ${data['error'] ?? '未知错误'}");
              }
              final task = _tasks.remove(taskId);
              if (success) {
                task?.complete(data['data']);
              } else {
                task?.completeError(Exception(data['error'] ?? 'JS执行失败'));
              }
            } catch (e) {
              _log("JS回调解析异常：$e");
            }
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              _log("WebView运行环境：加载完成");
              completer.complete();
            },
            onWebResourceError: (err) {
              _log("WebView加载错误：${err.description}");
              completer.completeError(err);
            },
          ),
        )
        ..loadHtmlString('''
<!DOCTYPE html>
<html>
<body style="background:#000;margin:0"></body>
<script>
window.onerror = function(msg){
  try{jsResult.postMessage(JSON.stringify({id:_lastId,ok:false,error:msg}))}catch(e){}
};
async function run(taskId,code){
  _lastId = taskId;
  try{
    let result = await eval(code);
    jsResult.postMessage(JSON.stringify({id:taskId,ok:true,data:result}));
  }catch(e){
    jsResult.postMessage(JSON.stringify({id:taskId,ok:false,error:e.toString()}));
  }
}
</script>
</html>
''');

      _log("等待WebView环境初始化...");
      await completer.future.timeout(const Duration(seconds: 25));
      _ready = true;
      _log("JS引擎：初始化完成，可执行脚本");
    } catch (e) {
      _ready = false;
      _log("JS引擎初始化失败：$e");
      rethrow;
    }
  }

  Future<dynamic> executeScript(SpiderSource source, String method, List<dynamic> args) async {
    _log("================ 执行爬虫方法 ================");
    _log("执行方法：$method | 数据源：${source.name}");

    await ensureInitialized();
    if (!_ready || _controller == null) {
      _log("错误：JS引擎未就绪");
      throw Exception("JS引擎未就绪");
    }

    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    _log("生成任务ID：$taskId");
    final completer = Completer<dynamic>();
    _tasks[taskId] = completer;

    try {
      if (source.ext?.isNotEmpty == true) {
        _log("开始加载内置爬虫脚本");
        await _controller!.runJavaScript(source.ext!);
        await Future.delayed(const Duration(milliseconds: 200));
        _log("爬虫脚本：加载完成");
      } else {
        _log("无内置爬虫脚本，跳过加载");
      }

      final argStr = args.map((e) => jsonEncode(e)).join(',');
      final execCode = "new MySpider().$method($argStr)";
      _log("拼接执行代码完成，准备调用JS");

      _log("提交JS执行任务：$taskId");
      await _controller!.runJavaScript("run('$taskId', `$execCode`)");

      _log("等待JS执行结果（超时30秒）...");
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _log("任务[$taskId]：执行超时（30秒无响应）");
          throw Exception("JS脚本执行超时");
        },
      );
    } catch (e) {
      _tasks.remove(taskId);
      _log("任务执行异常：$e");
      throw Exception("JS脚本执行异常：$e");
    }
  }

  Future<void> dispose() async {
    _log("释放JS引擎资源");
    for (final c in _tasks.values) {
      if (!c.isCompleted) c.completeError("engine disposed");
    }
    _tasks.clear();
    _controller = null;
    _ready = false;
  }
}
