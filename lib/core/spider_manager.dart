import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:xpath/xpath.dart';
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

  // Type1 标准JSON API源
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

  // Type2 XPath规则源（适配新的xpath包，完全兼容原有规则）
  Future<Map<String, dynamic>> _executeType2(String method, List<dynamic> args) async {
    final source = _currentSource!;
    final rule = jsonDecode(source.ext!);
    final html = await NetworkService.instance.get(source.api!);
    // 新的XPath解析初始化
    final document = html_parser.parse(html);
    final evaluator = XPathEvaluator(document);

    switch (method) {
      case "homeContent":
        // 解析列表节点
        final listNodes = evaluator.query(rule["home_list"]).nodes;
        final list = listNodes.map((node) {
          final nodeEvaluator = XPathEvaluator(node);
          return {
            "id": nodeEvaluator.query(rule["home_id"]).node?.attributes['href'] ?? nodeEvaluator.query(rule["home_id"]).string,
            "name": nodeEvaluator.query(rule["home_name"]).string,
            "pic": nodeEvaluator.query(rule["home_pic"]).node?.attributes['src'] ?? nodeEvaluator.query(rule["home_pic"]).string,
            "remark": nodeEvaluator.query(rule["home_remark"]).string,
          };
        }).toList();
        return {"list": list};

      case "detailContent":
        final id = args[0] as String;
        final detailHtml = await NetworkService.instance.get(id);
        final detailDocument = html_parser.parse(detailHtml);
        final detailEvaluator = XPathEvaluator(detailDocument);
        final detailNode = detailEvaluator.query(rule["detail_root"]).node;

        if (detailNode == null) {
          throw Exception("未找到详情数据");
        }

        final detailNodeEvaluator = XPathEvaluator(detailNode);
        // 解析播放列表
        final playFrom = detailNodeEvaluator.query(rule["play_from"]).string.split("$$$");
        final playUrlRaw = detailNodeEvaluator.query(rule["play_url"]).string.split("$$$");
        final playList = playUrlRaw.map((item) {
          return item.split('#').map((e) => e.trim()).toList();
        }).toList();

        return {
          "list": [
            {
              "vod_id": id,
              "vod_name": detailNodeEvaluator.query(rule["detail_name"]).string,
              "vod_pic": detailNodeEvaluator.query(rule["detail_pic"]).node?.attributes['src'] ?? detailNodeEvaluator.query(rule["detail_pic"]).string,
              "vod_remarks": detailNodeEvaluator.query(rule["detail_remark"]).string,
              "vod_year": detailNodeEvaluator.query(rule["detail_year"]).string,
              "vod_area": detailNodeEvaluator.query(rule["detail_area"]).string,
              "vod_lang": detailNodeEvaluator.query(rule["detail_lang"]).string,
              "vod_content": detailNodeEvaluator.query(rule["detail_content"]).string,
              "vod_play_from": playFrom,
              "vod_play_url": playList,
            }
          ]
        };

      case "playerContent":
        final id = args[2] as String;
        final playHtml = await NetworkService.instance.get(id);
        final playDocument = html_parser.parse(playHtml);
        final playEvaluator = XPathEvaluator(playDocument);
        final playUrl = playEvaluator.query(rule["player_url"]).node?.attributes['src'] ?? playEvaluator.query(rule["player_url"]).string;

        return {
          "url": playUrl,
          "header": {},
        };

      default:
        throw Exception("XPath源暂不支持$method方法");
    }
  }

  // Type3 JS/Python脚本源
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
