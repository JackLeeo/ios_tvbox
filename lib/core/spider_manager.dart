import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:petitparser/petitparser.dart';
import './js_engine.dart';
import '../models/spider_source.dart';
import '../models/video_model.dart';
import './network_service.dart';

// ====================== XPath解析辅助 ======================
class XPathResult {
  final List<Node> nodes;
  final String string;

  XPathResult(this.nodes, this.string);

  Node? get node => nodes.isNotEmpty ? nodes.first : null;
  String? get attr => node?.attributes.values.isNotEmpty == true ? node!.attributes.values.first : null;
}

class XPathEvaluator {
  final Node _rootNode;

  XPathEvaluator(this._rootNode);

  XPathResult query(String xpath) {
    final parser = const XPathGrammarDefinition().build<dynamic>();
    final result = parser.parse(xpath);
    if (result is Failure) return XPathResult([], '');

    final String queryStr = result.value is String ? result.value as String : '';
    final nodes = _executeQuery(queryStr, [_rootNode]);
    final stringValue = nodes.isNotEmpty
        ? nodes.first is Text
            ? (nodes.first as Text).data
            : nodes.first.text ?? ''
        : '';
    return XPathResult(nodes, stringValue);
  }

  List<Node> _executeQuery(String query, List<Node> context) {
    final List<Node> res = [];
    if (query.startsWith('//')) {
      final tag = query.substring(2);
      for (var n in context) {
        if (n is Element) {
          res.addAll(n.querySelectorAll(tag));
        }
        if (n is Document) {
          res.addAll(n.querySelectorAll(tag));
        }
      }
    } else if (query.startsWith('@')) {
      final an = query.substring(1);
      for (var n in context) {
        if (n is Element && n.attributes.containsKey(an)) {
          res.add(Text(n.attributes[an]!));
        }
      }
    } else if (query == 'text()') {
      for (var n in context) {
        res.addAll(n.nodes.whereType<Text>());
      }
    } else {
      for (var n in context) {
        if (n is Element) {
          res.addAll(n.querySelectorAll(query));
        }
        if (n is Document) {
          res.addAll(n.querySelectorAll(query));
        }
      }
    }
    return res;
  }
}

class XPathGrammarDefinition extends GrammarDefinition {
  const XPathGrammarDefinition();
  @override
  Parser start() => ref0(path).end();
  Parser path() => ref0(step).plus().flatten();
  Parser step() => (ref0(root) | ref0(tag) | ref0(attr) | ref0(textFunc)).trim();
  Parser root() => string('//');
  Parser tag() => (letter() | word() | char('.') | char('*')).plus().flatten();
  Parser attr() => char('@') & word().plus().flatten();
  Parser textFunc() => string('text()');
}
// ===========================================================

class SpiderManager {
  final List<SpiderSource> _sourceList = [];
  SpiderSource? _currentSource;

  static final SpiderManager instance = SpiderManager._internal();
  SpiderManager._internal();

  List<SpiderSource> get sourceList => List.unmodifiable(_sourceList);
  SpiderSource? get currentSource => _currentSource;
  bool get hasSource => _sourceList.isNotEmpty && _currentSource != null;

  // 空初始化，兼容调用
  Future<void> init() async {}

  Future<void> addSource(SpiderSource source) async {
    _sourceList.removeWhere((e) => e.key == source.key);
    _sourceList.add(source);
    _currentSource ??= source;
  }

  void setCurrentSource(String key) {
    final t = _sourceList.firstWhere((e) => e.key == key, orElse: () => throw Exception("未找到key为$key的数据源"));
    _currentSource = t;
  }

  void removeSource(String key) {
    _sourceList.removeWhere((e) => e.key == key);
    if (_currentSource?.key == key) {
      _currentSource = _sourceList.firstOrNull;
    }
  }

  Future<Map<String, dynamic>> execute(String method, List<dynamic> args) async {
    if (_currentSource == null) throw Exception("请先选择数据源");
    switch (_currentSource!.type) {
      case 1: return await _executeType1(method, args);
      case 2: return await _executeType2(method, args);
      case 3: return await _executeType3(method, args);
      default: throw Exception("不支持的数据源类型:${_currentSource!.type}");
    }
  }

  // 统一字段兼容，解决测试源数据解析问题
  Future<List<VideoModel>> getHomeContent({bool filter = false}) async {
    final r = await execute("homeContent", [filter]);
    final list = r['list'] as List;
    return list.map((e) {
      Map<String, dynamic> jsonMap = Map<String, dynamic>.from(e);
      jsonMap['id'] = jsonMap['id'] ?? jsonMap['vod_id'];
      jsonMap['name'] = jsonMap['name'] ?? jsonMap['vod_name'];
      jsonMap['pic'] = jsonMap['pic'] ?? jsonMap['vod_pic'];
      jsonMap['remark'] = jsonMap['remark'] ?? jsonMap['vod_remarks'];
      jsonMap['des'] = jsonMap['des'] ?? jsonMap['vod_content'];
      return VideoModel.fromJson(jsonMap);
    }).toList();
  }

  Future<VideoModel> getDetailContent(String id) async {
    final r = await execute("detailContent", [id]);
    final list = r['list'] as List;
    return VideoModel.fromJson(list.first);
  }

  Future<List<VideoModel>> searchContent(String wd, {bool quick = false, int pg = 1}) async {
    final r = await execute("searchContent", [wd, quick, pg]);
    final list = r['list'] as List;
    return list.map((e) {
      Map<String, dynamic> jsonMap = Map<String, dynamic>.from(e);
      jsonMap['id'] = jsonMap['id'] ?? jsonMap['vod_id'];
      jsonMap['name'] = jsonMap['name'] ?? jsonMap['vod_name'];
      jsonMap['pic'] = jsonMap['pic'] ?? jsonMap['vod_pic'];
      jsonMap['remark'] = jsonMap['remark'] ?? jsonMap['vod_remarks'];
      return VideoModel.fromJson(jsonMap);
    }).toList();
  }

  // Type1 接口源处理
  Future<Map<String, dynamic>> _executeType1(String method, List<dynamic> args) async {
    final source = _currentSource!;
    final Map<String, dynamic> params = {};

    final safeApi = source.api ?? '';
    if (safeApi.isEmpty) {
      throw Exception("数据源API地址不能为空");
    }
    final response = await NetworkService.instance.get(safeApi, queryParameters: params);
    return Map<String, dynamic>.from(response);
  }

  // Type2 XPath源处理
  Future<Map<String, dynamic>> _executeType2(String method, List<dynamic> args) async {
    final source = _currentSource!;
    final ext = source.ext ?? '';
    if (ext.isEmpty) {
      throw Exception("XPath规则为空");
    }
    final rule = jsonDecode(ext);
    final api = source.api ?? '';
    if (api.isEmpty) {
      throw Exception("接口地址不能为空");
    }

    final html = await NetworkService.instance.get(api);
    final doc = html_parser.parse(html);
    final eva = XPathEvaluator(doc);

    switch (method) {
      case "homeContent":
        final listRule = rule["home_list"] ?? '';
        final listNodes = eva.query(listRule).nodes;
        final list = listNodes.map((node) {
          final ne = XPathEvaluator(node);
          final idRaw = ne.query(rule["home_id"] ?? '');
          final nameRaw = ne.query(rule["home_name"] ?? '');
          final picRaw = ne.query(rule["home_pic"] ?? '');
          final remarkRaw = ne.query(rule["home_remark"] ?? '');
          return {
            "id": idRaw.attr ?? idRaw.string,
            "name": nameRaw.string,
            "pic": picRaw.attr ?? picRaw.string,
            "remark": remarkRaw.string,
          };
        }).toList();
        return {"list": list};

      case "detailContent":
        final id = args[0] as String;
        final detailHtml = await NetworkService.instance.get(id);
        final detailDoc = html_parser.parse(detailHtml);
        final detailEva = XPathEvaluator(detailDoc);
        final detailRootRule = rule["detail_root"] ?? '';
        final detailNode = detailEva.query(detailRootRule).node;
        if (detailNode == null) {
          throw Exception("未找到详情节点");
        }

        final dnEva = XPathEvaluator(detailNode);
        final playFromRaw = dnEva.query(rule["play_from"] ?? '').string.split(r'$$$');
        final playUrlRaw = dnEva.query(rule["play_url"] ?? '').string.split(r'$$$');
        final playList = playUrlRaw.map((i) {
          return i.split('#').map((e) => e.trim()).toList();
        }).toList();

        final nameStr = dnEva.query(rule["detail_name"] ?? '').string;
        final picStr = dnEva.query(rule["detail_pic"] ?? '').attr ?? dnEva.query(rule["detail_pic"] ?? '').string;
        final remarkStr = dnEva.query(rule["detail_remark"] ?? '').string;
        final yearStr = dnEva.query(rule["detail_year"] ?? '').string;
        final areaStr = dnEva.query(rule["detail_area"] ?? '').string;
        final langStr = dnEva.query(rule["detail_lang"] ?? '').string;
        final contentStr = dnEva.query(rule["detail_content"] ?? '').string;

        return {
          "list": [
            {
              "vod_id": id,
              "vod_name": nameStr,
              "vod_pic": picStr,
              "vod_remarks": remarkStr,
              "vod_year": yearStr,
              "vod_area": areaStr,
              "vod_lang": langStr,
              "vod_content": contentStr,
              "vod_play_from": playFromRaw,
              "vod_play_url": playList,
            }
          ]
        };

      case "playerContent":
        final pid = args[2] as String;
        final playHtml = await NetworkService.instance.get(pid);
        final playDoc = html_parser.parse(playHtml);
        final playEva = XPathEvaluator(playDoc);
        final playerRule = rule["player_url"] ?? '';
        final playRes = playEva.query(playerRule);
        final playUrl = playRes.attr ?? playRes.string;
        return {"url": playUrl, "header": {}};

      default:
        throw Exception("XPath源暂不支持当前方法");
    }
  }

  // 【核心修复】Type3 JS源处理，适配懒加载JS引擎
  Future<Map<String, dynamic>> _executeType3(String method, List<dynamic> args) async {
    final source = _currentSource!;
    // 执行前确保JS引擎懒加载初始化完成，环境就绪
    await JsEngine.instance.ensureInitialized();
    return await JsEngine.instance.executeScript(source, method, args);
  }
}
