import 'dart:async';
import 'package:flutter/foundation.dart';
import 'js_engine.dart';
import 'python_engine.dart';
import 'network_service.dart';
import '../models/spider_source.dart';

class SpiderManager {
  // 单例实例
  static final SpiderManager instance = SpiderManager._internal();
  SpiderManager._internal();

  // 已添加的爬虫源列表
  final List<SpiderSource> _sourceList = [];
  List<SpiderSource> get sourceList => List.unmodifiable(_sourceList);

  // 当前选中的源
  SpiderSource? _currentSource;
  SpiderSource? get currentSource => _currentSource;

  // 引擎初始化
  Future<void> init() async {
    await JSEngine.instance.init();
    await PythonEngine.instance.init();
  }

  // 添加爬虫源（核心方法，修复空安全）
  Future<void> addSource(SpiderSource source) async {
    _sourceList.removeWhere((e) => e.key == source.key);
    _sourceList.add(source);
  }

  // 移除爬虫源
  void removeSource(String sourceKey) {
    _sourceList.removeWhere((e) => e.key == sourceKey);
  }

  // 切换当前选中源
  void setCurrentSource(String sourceKey) {
    try {
      _currentSource = _sourceList.firstWhere((e) => e.key == sourceKey);
    } catch (e) {
      if (kDebugMode) {
        print('切换源失败：未找到key为$sourceKey的源');
      }
      _currentSource = null;
    }
  }

  // 统一入口：获取首页内容
  Future<Map<String, dynamic>?> getHomeContent({bool filter = false}) async {
    final source = _currentSource;
    if (source == null) {
      if (kDebugMode) print('未选中任何爬虫源');
      return null;
    }

    switch (source.type) {
      case 1:
        return await _executeType1(source);
      case 2:
        return await _executeType2(source);
      case 3:
        return await _executeType3(source, filter: filter);
      default:
        if (kDebugMode) print('不支持的源类型：${source.type}');
        return null;
    }
  }

  // 执行type1 标准JSON API源（修复空安全报错的核心位置）
  Future<Map<String, dynamic>?> _executeType1(SpiderSource source) async {
    try {
      // 空安全修复：可空字段给默认空字符串，避免String?赋值给String
      final String api = source.api ?? '';
      if (api.isEmpty) {
        if (kDebugMode) print('type1源api地址为空，无法执行请求');
        return null;
      }
      final response = await NetworkService.instance.get(api);
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      if (kDebugMode) print('type1源执行失败：$e');
      return null;
    }
  }

  // 执行type2 XPath规则源（同步修复空安全）
  Future<Map<String, dynamic>?> _executeType2(SpiderSource source) async {
    try {
      // 空安全修复：可空字段给默认空字符串
      final String api = source.api ?? '';
      final String extRule = source.ext ?? '';
      if (api.isEmpty || extRule.isEmpty) {
        if (kDebugMode) print('type2源api地址或XPath规则为空');
        return null;
      }
      final response = await NetworkService.instance.get(api);
      final htmlContent = response.data.toString();
      // 此处保留你原有XPath解析的完整业务逻辑
      return {};
    } catch (e) {
      if (kDebugMode) print('type2源执行失败：$e');
      return null;
    }
  }

  // 执行type3 JS/Python动态脚本源（同步修复空安全）
  Future<Map<String, dynamic>?> _executeType3(SpiderSource source, {bool filter = false}) async {
    try {
      // 空安全修复：可空字段给默认空字符串
      final String scriptContent = source.ext ?? '';
      if (scriptContent.isEmpty) {
        if (kDebugMode) print('type3源脚本内容为空');
        return null;
      }
      // 兼容CatJS规范执行脚本，保留原有逻辑
      final result = await JSEngine.instance.executeScript(
        scriptContent,
        method: 'homeContent',
        params: [filter],
      );
      return result as Map<String, dynamic>?;
    } catch (e) {
      if (kDebugMode) print('type3源执行失败：$e');
      return null;
    }
  }

  // 源调试工具专用：测试源配置
  Future<Map<String, dynamic>?> testSource(SpiderSource source) async {
    _currentSource = source;
    return await getHomeContent();
  }

  // 清空所有源
  void clearAllSources() {
    _sourceList.clear();
    _currentSource = null;
  }
}
