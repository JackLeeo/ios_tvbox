import 'package:python_ffi/python_ffi.dart';
import 'dart:convert';
import '../models/spider_source.dart';
import './network_service.dart';

class PythonEngine {
  bool _isInitialized = false;

  static final PythonEngine instance = PythonEngine._internal();
  PythonEngine._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    // 适配python_ffi 0.4.4 正确初始化API
    await PythonFfi.initialize();
    _isInitialized = true;
  }

  Future<dynamic> executeScript(SpiderSource source, String method, List<dynamic> args) async {
    if (!_isInitialized) await init();

    // 加载远程脚本
    if (source.api?.isNotEmpty == true) {
      final remoteScript = await NetworkService.instance.get(source.api!);
      PythonFfi.instance.exec(remoteScript);
    }

    // 加载本地脚本
    if (source.ext?.isNotEmpty == true) {
      PythonFfi.instance.exec(source.ext!);
    }

    // 执行目标方法
    final argsJson = args.map((e) => jsonEncode(e)).join(',');
    final execCode = """
import json
spider = MySpider()
result = spider.${method}(${argsJson})
print(json.dumps(result))
""";

    // 执行代码并捕获输出
    final output = StringBuffer();
    final errorOutput = StringBuffer();

    // 捕获stdout和stderr
    PythonFfi.instance.stdout.listen((data) => output.write(data));
    PythonFfi.instance.stderr.listen((data) => errorOutput.write(data));

    // 执行代码
    PythonFfi.instance.exec(execCode);

    // 等待输出完成
    await Future.delayed(const Duration(milliseconds: 100));

    final stderr = errorOutput.toString();
    final stdout = output.toString();

    if (stderr.isNotEmpty) {
      throw Exception("Python脚本执行失败: $stderr");
    }

    try {
      return jsonDecode(stdout);
    } catch (e) {
      throw Exception("Python返回数据解析失败: $e, 原始数据: $stdout");
    }
  }

  Future<void> dispose() async {
    // 适配python_ffi 0.4.4 正确释放API
    PythonFfi.instance.finalize();
    _isInitialized = false;
  }
}
