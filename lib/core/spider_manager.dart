import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import './js_engine.dart';
import './python_engine.dart';
import '../models/spider_source.dart';
import '../models/video_model.dart';
import './network_service.dart';

class SpiderManager {
  final List<SpiderSource> _sourceList = [];
  SpiderSource? _currentSource;

  static final SpiderManager instance = SpiderManager._internal();
  SpiderManager._internal();

  // 对外暴露的只读属性
  List<SpiderSource> get sourceList => List.unmodifiable(_sourceList);
  SpiderSource? get currentSource => _currentSource;
  bool get hasSource => _sourceList.isNotEmpty && _currentSource != null;

  // 添加数据源
  Future<void> addSource(SpiderSource source) async {
    _sourceList.removeWhere((e) => e.key == source.key);
    _sourceList.add(source);
    _currentSource ??= source;
  }

  // 切换当前数据源
  void setCurrentSource(String key) {
    final target = _sourceList.firstWhere((e) => e.key == key);
    _currentSource = target;
  }

  // 删除数据源
  void removeSource(String key) {
    _sourceList.removeWhere((e) => e.key == key);
    if (_currentSource?.key == key) {
      _currentSource = _sourceList.isNotEmpty ? _sourceList.first : null;
    }
  }

  // 核心执行方法
  Future<Map<String, dynamic>> execute(String method, List<dynamic> args) async {
    if (_currentSource == null) {
      throw Exception("请先选择数据源");
    }

    switch (_currentSource!.type) {
      case 1:
        return await _executeType1(method, args);
      case 2:
        return await _executeType2(method, args);
      case 3:
        return await _executeType3(method, args);
      default:
        throw Exception("不支持的数据源类型: ${_currentSource!.type}");
    }
  }

  // 封装首页数据获取
  Future<List<VideoModel>> getHomeContent({bool filter = false}) async {
    final result = await execute("homeContent", [filter]);
    final list = result['list'] as List;
    return list.map((e) => VideoModel.fromJson(e)).toList();
  }

  // 封装详情数据获取
  Future<VideoModel> getDetailContent(String id) async {
    final result = await execute("detailContent", [id]);
    final list = result['list'] as List;
    return VideoModel.fromJson(list.first);
  }

  // 封装搜索数据获取
  Future<List<VideoModel>> searchContent(String wd, {bool quick = false, int pg = 1}) async {
    final result = await execute("searchContent", [wd, quick, pg]);
    final list = result['list'] as List;
    return list.map((e) => VideoModel.fromJson(e)).toList();
  }

  // Type1 标准JSON API源（TVBox最主流源类型，完整保留）
  Future<Map<String, dynamic>> _executeType1(String method, List<dynamic> args) async {
    final source = _currentSource!;
    final Map<String, dynamic> params = {
      "method": method,
      "filter": args.isNotEmpty ? args[0] : null,
      "tid": args.length > 1 ? args[1] : null,
      "pg": args.length > 2 ? args[2] : null,
      "extend": args.length > 3 ? args[3] : null,
      "wd": args.isNotEmpty ? args[0] : null,
      "quick": args.length > 1 ? args[1] : null,
      "flag": args.length > 1 ? args[1] : null,
      "id": args.length > 2 ? args[2] : null,
      "vipFlags": args.length > 3 ? args[3] : null,
    };
    params.removeWhere((key, value) => value == null);

    final response = await NetworkService.instance.get(source.api!, queryParameters: params);
    return Map<String, dynamic>.from(response);
  }

  // Type2 网页解析源（兼容兜底，无外部依赖，编译无错误）
  Future<Map<String, dynamic>> _executeType2(String method, List<dynamic> args) async {
    throw Exception("当前版本暂不支持Type2 XPath源，推荐使用Type1 JSON源或Type3 JS/Python脚本源");
  }

  // Type3 JS/Python动态脚本源（TVBox核心功能，完整保留）
  Future<Map<String, dynamic>> _executeType3(String method, List<dynamic> args) async {
    final source = _currentSource!;
    // 区分Python和JS脚本
    if (source.api?.endsWith(".py") == true || source.ext?.contains("class MySpider") != true) {
      return await PythonEngine.instance.executeScript(source, method, args);
    } else {
      return await JsEngine.instance.executeScript(source, method, args);
    }
  }
}
