import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter/services.dart' show rootBundle;

class JSEngine {
  JavascriptRuntime? _runtime;
  final Dio _dio = Dio();
  final Map<String, String> _injectedLibs = {};
  bool _isInitialized = false;

  // 初始化引擎（注入工具库）
  Future<void> init() async {
    if (_isInitialized) return;
    _runtime = getJavascriptRuntime();
    await _injectLibs();
    _defineSpiderAPI();
    _exposeDartMethods();
    _isInitialized = true;
  }

  // 注入JS工具库（CryptoJS、lodash、cheerio）
  Future<void> _injectLibs() async {
    final libs = {
      'crypto-js': 'assets/js/crypto-js.min.js',
      'lodash': 'assets/js/lodash.min.js',
      'cheerio': 'assets/js/cheerio.min.js',
    };
    for (var entry in libs.entries) {
      final code = await rootBundle.loadString(entry.value);
      _runtime?.evaluate(code);
      _injectedLibs[entry.key] = code;
    }
  }

  // 暴露Dart网络请求方法给JS
  void _exposeDartMethods() {
    _runtime?.addMethod('request', (arguments) async {
      try {
        final args = arguments[0] as Map<dynamic, dynamic>;
        final url = args['url'] as String;
        final options = args['options'] as Map<dynamic, dynamic>?;
        
        final response = await _dio.request(
          url,
          options: Options(
            method: options?['method'] ?? 'GET',
            headers: options?['headers']?.map((k, v) => 
              MapEntry(k.toString(), v.toString())
            ),
            data: options?['data'],
          ),
        );
        
        return response.data;
      } catch (e) {
        throw Exception('网络请求失败: $e');
      }
    });
  }

  // 定义TVBox标准爬虫接口（CatVodSpider）
  void _defineSpiderAPI() {
    const apiCode = '''
      class CatVodSpider {
        constructor() {
          this.name = '';
          this.key = '';
          this.type = 3;
        }
        async homeContent(filter) { return { list: [], filters: [] }; }
        async categoryContent(tid, pg, filter, extend) { 
          return { list: [], page: pg, pagecount: 0, limit: 20, total: 0 }; 
        }
        async detailContent(ids) { return { list: [] }; }
        async searchContent(key, quick, pg) { return { list: [], pagecount: 0 }; }
        async playerContent(flag, id, flags) { return { parse: 0, url: '', header: {} }; }
      }
      globalThis.CatVodSpider = CatVodSpider;
    ''';
    _runtime?.evaluate(apiCode);
  }

  // 执行JS爬虫脚本
  Future<Map<String, dynamic>> executeScript(
    String script, 
    String method, 
    List<dynamic> args
  ) async {
    if (!_isInitialized) await init();
    if (_runtime == null) throw Exception('JS引擎未初始化');
    
    try {
      // 创建爬虫实例并注入用户脚本
      _runtime!.evaluate('''
        const spider = new CatVodSpider();
        $script;
        globalThis.currentSpider = spider;
      ''');
      
      // 安全参数传递：双层JSON序列化，彻底解决特殊字符语法错误
      final argsStr = args.map((e) => 'JSON.parse(${json.encode(json.encode(e))})').join(',');
      
      // 异步调用目标方法
      final result = await _runtime!.evaluateAsync('''
        (async () => await globalThis.currentSpider.$method($argsStr))()
      ''');
      
      if (result.isError) {
        throw Exception('JS执行错误: ${result.stringResult}');
      }
      
      return Map<String, dynamic>.from(result.rawResult);
    } catch (e) {
      throw Exception('JS引擎执行失败: $e');
    }
  }

  // 释放资源
  void dispose() {
    if (_isInitialized && _runtime != null) {
      try {
        _runtime?.dispose();
      } catch (_) {}
      _runtime = null;
      _isInitialized = false;
    }
  }
}