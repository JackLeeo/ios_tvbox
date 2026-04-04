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
    // 正确初始化PythonFFI（使用公开API，非测试专用）
    await PythonFfi.initialize();
    _isInitialized = true;
  }

  Future<dynamic> executeScript(SpiderSource source, String method, List<dynamic> args) async {
    if (!_isInitialized) await init();

    final pythonModule = PythonModule();
    // 加载爬虫脚本
    if (source.ext?.isNotEmpty == true) {
      await pythonModule.runString(source.ext!);
    }
    if (source.api?.isNotEmpty == true) {
      final networkService = NetworkService.instance;
      final remoteScript = await networkService.get(source.api!);
      await pythonModule.runString(remoteScript);
    }

    // 执行目标方法
    final argsStr = args.map((e) => jsonEncode(e)).join(',');
    final result = await pythonModule.runString("""
import json
spider = MySpider()
result = spider.${method}(${argsStr})
print(json.dumps(result))
""");

    if (result.stderr.isNotEmpty) {
      throw Exception("Python脚本执行错误: ${result.stderr}");
    }
    return jsonDecode(result.stdout);
  }

  Future<void> dispose() async {
    PythonFfi.finalize();
    _isInitialized = false;
  }
}
