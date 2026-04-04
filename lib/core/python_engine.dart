import 'package:python_ffi/python_ffi.dart';
import 'package:ios_tvbox/models/spider_source.dart';
import 'package:ios_tvbox/core/network_service.dart';
import 'dart:convert';

class PythonEngine {
  bool _isInitialized = false;

  static final PythonEngine instance = PythonEngine._internal();
  PythonEngine._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    // 适配python_ffi 0.6.0 正确初始化API
    await PythonFfi.instance.initialize();
    _isInitialized = true;
  }

  Future<dynamic> executeScript(SpiderSource source, String method, List<dynamic> args) async {
    if (!_isInitialized) await init();

    // 加载远程脚本
    if (source.api?.isNotEmpty == true) {
      final remoteScript = await NetworkService.instance.get(source.api!);
      PythonFfi.instance.runString(remoteScript);
    }

    // 加载本地脚本
    if (source.ext?.isNotEmpty == true) {
      PythonFfi.instance.runString(source.ext!);
    }

    // 执行目标方法
    final argsJson = args.map((e) => jsonEncode(e)).join(',');
    final execCode = """
import json
spider = MySpider()
result = spider.${method}(${argsJson})
print(json.dumps(result))
""";

    final execResult = PythonFfi.instance.runString(execCode);
    if (execResult.stderr.isNotEmpty) {
      throw Exception("Python脚本执行失败: ${execResult.stderr}");
    }

    try {
      return jsonDecode(execResult.stdout);
    } catch (e) {
      throw Exception("Python返回数据解析失败: $e, 原始数据: ${execResult.stdout}");
    }
  }

  Future<void> dispose() async {
    // 适配python_ffi正确释放API
    PythonFfi.instance.finalize();
    _isInitialized = false;
  }
}
