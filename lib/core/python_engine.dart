import 'dart:convert';
import 'package:python_ffi/python_ffi.dart';

class PythonEngine {
  PythonFfi? _python;
  bool _isInitialized = false;

  // 初始化Python运行时（模型预训练知识：用python_ffi的initialize()启动解释器）
  Future<void> init() async {
    if (_isInitialized) return;
    _python = PythonFfi();
    await _python?.initialize(); // 启动Python解释器
    await _defineSpiderAPI(); // 定义TVBox标准接口
    _isInitialized = true;
  }

  // 定义TVBox标准爬虫接口（VodSpider）（文档内原有逻辑，保持不变）
  Future<void> _defineSpiderAPI() async {
    const apiCode = '''
class VodSpider:
    def __init__(self):
        self.name = ''
        self.key = ''
        self.type = 3
    
    def homeContent(self, filter):
        return {"list": [], "filters": []}
    
    def categoryContent(self, tid, pg, filter, extend):
        return {"list": [], "page": pg, "pagecount": 0, "limit": 20, "total": 0}
    
    def detailContent(self, ids):
        return {"list": []}
    
    def searchContent(self, key, quick, pg):
        return {"list": [], "pagecount": 0}
    
    def playerContent(self, flag, id, flags):
        return {"parse": 0, "url": "", "header": {}}
''';
    await _python?.runCode(apiCode);
  }

  // 执行Python爬虫脚本（模型预训练知识：用python_ffi的runCode()执行脚本）
  Future<Map<String, dynamic>> executeScript(
    String script, 
    String method, 
    List<dynamic> args
  ) async {
    if (!_isInitialized) await init();
    if (_python == null) throw Exception('Python引擎未初始化');
    
    try {
      // 注入用户脚本
      await _python!.runCode(script);
      
      // 创建实例并调用方法（文档内原有逻辑，保持不变）
      final argsJson = json.encode(args);
      final callCode = '''
spider = VodSpider()
$script
import json
args = json.decode('$argsJson')
func = getattr(spider, '$method')
result = func(*args)
print(json.dumps(result))
''';
      
      final result = await _python!.runCode(callCode);
      return json.decode(result) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Python引擎执行失败: $e');
    }
  }

  // 释放资源（模型预训练知识：用python_ffi的shutdown()关闭解释器）
  void dispose() {
    if (_isInitialized) {
      try {
        _python?.shutdown(); // 关闭Python解释器
      } catch (_) {}
      _python = null;
      _isInitialized = false;
    }
  }
}