import 'package:ios_tvbox/core/js_engine.dart';
import 'package:ios_tvbox/core/python_engine.dart';
import 'package:ios_tvbox/models/spider_source.dart';
import 'package:ios_tvbox/models/video_model.dart';
import 'package:ios_tvbox/core/network_service.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';
import 'dart:convert';

class SpiderManager {
  final List<SpiderSource> _sourceList = [];
  SpiderSource? _currentSource;

  static final SpiderManager instance = SpiderManager._internal();
  SpiderManager._internal();

  List<SpiderSource> get sourceList => List.unmodifiable(_sourceList);
  SpiderSource? get currentSource => _currentSource;

  Future<void> addSource(SpiderSource source) async {
    _sourceList.removeWhere((e) => e.key == source.key);
    _sourceList.add(source);
  }

  void setCurrentSource(String key) {
    _currentSource = _sourceList.firstWhere((e) => e.key == key);
  }

  Future<Map<String, dynamic>> execute(String method, List<dynamic> args) async {
    if (_currentSource == null) {
      throw Exception("未选择数据源");
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

  // type1 标准JSON API源
  Future<Map<String, dynamic>> _executeType1(String method, List<dynamic> args) async {
    final source = _currentSource!;
    final networkService = NetworkService.instance;
    final Map<String, dynamic> params = {
      "method": method,
      "filter": args.isNotEmpty ? args[0] : null,
      "tid": args.length > 1 ? args[1] : null,
      "pg": args.length > 2 ? args[2] : null,
      "extend": args.length > 3 ? args[3] : null,
      "wd": args.isNotEmpty ? args[0] : null,
      "flag": args.length > 1 ? args[1] : null,
      "id": args.length > 2 ? args[2] : null,
    };
    params.removeWhere((key, value) => value == null);

    final response = await networkService.get(source.api!, queryParameters: params);
    return Map<String, dynamic>.from(response);
  }

  // type2 XPath规则源
  Future<Map<String, dynamic>> _executeType2(String method, List<dynamic> args) async {
    final source = _currentSource!;
    final networkService = NetworkService.instance;
    final rule = jsonDecode(source.ext!); // ext字段存储XPath规则JSON配置

    // 1. 请求目标页面HTML
    final html = await networkService.get(source.api!);
    // 2. 正确初始化XPath解析器（修复未定义错误）
    final xpath = XPathSelector.html(html);

    // 3. 按规则解析数据（适配TVBox标准XPath规则）
    switch (method) {
      case "homeContent":
        final list = xpath.query(rule["home_list"]).nodes.map((node) {
          return {
            "id": node.query(rule["home_id"]).attr,
            "name": node.query(rule["home_name"]).text,
            "pic": node.query(rule["home_pic"]).attr,
            "remark": node.query(rule["home_remark"]).text,
          };
        }).toList();
        return {"list": list};
      case "detailContent":
        final detailNode = xpath.query(rule["detail_root"]).node;
        return {
          "list": [
            {
              "vod_name": detailNode?.query(rule["detail_name"]).text,
              "vod_pic": detailNode?.query(rule["detail_pic"]).attr,
              "vod_remarks": detailNode?.query(rule["detail_remark"]).text,
              "vod_content": detailNode?.query(rule["detail_content"]).text,
              "vod_play_from": detailNode?.query(rule["play_from"]).text.split("$$$"),
              "vod_play_url": detailNode?.query(rule["play_url"]).text.split("$$$"),
            }
          ]
        };
      default:
        throw Exception("XPath源暂不支持$method方法");
    }
  }

  // type3 JS/Python动态脚本源
  Future<Map<String, dynamic>> _executeType3(String method, List<dynamic> args) async {
    final source = _currentSource!;
    // 区分JS和Python脚本（按api后缀判断，.js为JS，.py为Python）
    if (source.api?.endsWith(".py") == true || source.ext?.startsWith("class MySpider") != true) {
      return await PythonEngine.instance.executeScript(source, method, args);
    } else {
      return await JsEngine.instance.executeScript(source, method, args);
    }
  }
}
