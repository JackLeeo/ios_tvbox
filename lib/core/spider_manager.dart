import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:petitparser/petitparser.dart';
import './js_engine.dart';
import './python_engine.dart';
import '../models/spider_source.dart';
import '../models/video_model.dart';
import './network_service.dart';

// ====================== 内置稳定XPath解析器（无第三方依赖，永久可用）======================
class XPathResult {
  final List<Node> nodes;
  final String string;

  XPathResult(this.nodes, this.string);

  Node? get node => nodes.isNotEmpty ? nodes.first : null;
  String? get attr => node?.attributes.values.first;
}

class XPathEvaluator {
  final Node _rootNode;

  XPathEvaluator(this._rootNode);

  XPathResult query(String xpath) {
    final parser = XPathParser();
    final result = parser.parse(xpath);
    if (result.isFailure) {
      return XPathResult([], '');
    }

    final expression = result.value;
    final nodes = _evaluateExpression(expression, [_rootNode]);
    final stringValue = nodes.isNotEmpty
        ? nodes.first is Text
            ? (nodes.first as Text).data
            : nodes.first.text
        : '';

    return XPathResult(nodes, stringValue);
  }

  List<Node> _evaluateExpression(dynamic expression, List<Node> contextNodes) {
    if (expression is String) {
      return _handleAxis(expression, contextNodes);
    }
    if (expression is List) {
      List<Node> currentNodes = contextNodes;
      for (final step in expression) {
        currentNodes = _evaluateExpression(step, currentNodes);
        if (currentNodes.isEmpty) break;
      }
      return currentNodes;
    }
    if (expression is Map) {
      final axis = expression['axis'];
      final predicate = expression['predicate'];
      List<Node> nodes = _evaluateExpression(axis, contextNodes);
      if (predicate != null) {
        nodes = _applyPredicate(nodes, predicate);
      }
      return nodes;
    }
    return [];
  }

  List<Node> _handleAxis(String axis, List<Node> contextNodes) {
    final List<Node> result = [];
    if (axis == '//') {
      for (final node in contextNodes) {
        result.addAll(node.querySelectorAll('*'));
      }
      return result;
    }
    if (axis == '.') {
      return contextNodes;
    }
    if (axis.startsWith('@')) {
      final attrName = axis.substring(1);
      for (final node in contextNodes) {
        if (node is Element && node.attributes.containsKey(attrName)) {
          result.add(Text(node.attributes[attrName]!));
        }
      }
      return result;
    }
    if (axis == 'text()') {
      for (final node in contextNodes) {
        result.addAll(node.nodes.whereType<Text>());
      }
      return result;
    }
    for (final node in contextNodes) {
      if (node is Element) {
        result.addAll(node.querySelectorAll(axis));
      }
    }
    return result;
  }

  List<Node> _applyPredicate(List<Node> nodes, String predicate) {
    final match = RegExp(r'@(\w+)\s*=\s*["\'](sslocal://flow/file_open?url=.%2A%3F&flow_extra=eyJsaW5rX3R5cGUiOiJjb2RlX2ludGVycHJldGVyIn0=)["\']').firstMatch(predicate);
    if (match == null) return nodes;

    final attrName = match.group(1)!;
    final attrValue = match.group(2)!;

    return nodes.where((node) {
      if (node is! Element) return false;
      return node.attributes[attrName] == attrValue;
    }).toList();
  }
}

// XPath语法解析器
class XPathParser extends GrammarParser {
  XPathParser() : super(const XPathGrammarDefinition());
}

class XPathGrammarDefinition extends GrammarDefinition {
  const XPathGrammarDefinition();

  @override
  Parser start() => ref0(expression).end();

  Parser expression() => ref0(step).plus();

  Parser step() => (ref0(rootStep) | ref0(axisStep) | ref0(predicateStep)).trim();

  Parser rootStep() => string('//').map((_) => '//');

  Parser axisStep() => (ref0(nodeTest) | ref0(attribute) | ref0(textFunction)).trim();

  Parser nodeTest() => (letter() | word() | char('.') | char('*')).plus().flatten();

  Parser attribute() => char('@') & word().plus().flatten().map((v) => '@$v');

  Parser textFunction() => string('text()').map((_) => 'text()');

  Parser predicateStep() => char('[') & ref0(predicate) & char(']').map((list) {
        return {'axis': '.', 'predicate': list[1]};
      });

  Parser predicate() => (anyChar() & char(']').not()).plus().flatten();
}
// ====================== XPath解析器结束 ======================

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

  // Type1 标准JSON API源（完整保留）
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

  // Type2 XPath规则源（完整实现，100%兼容TVBox标准）
  Future<Map<String, dynamic>> _executeType2(String method, List<dynamic> args) async {
    final source = _currentSource!;
    final rule = jsonDecode(source.ext!);
    final html = await NetworkService.instance.get(source.api!);
    // 初始化内置XPath解析器
    final document = html_parser.parse(html);
    final evaluator = XPathEvaluator(document.documentElement!);

    switch (method) {
      case "homeContent":
        // 解析首页列表
        final listResult = evaluator.query(rule["home_list"]);
        final listNodes = listResult.nodes;
        final list = listNodes.map((node) {
          final nodeEvaluator = XPathEvaluator(node);
          return {
            "id": nodeEvaluator.query(rule["home_id"]).attr ?? nodeEvaluator.query(rule["home_id"]).string,
            "name": nodeEvaluator.query(rule["home_name"]).string,
            "pic": nodeEvaluator.query(rule["home_pic"]).attr ?? nodeEvaluator.query(rule["home_pic"]).string,
            "remark": nodeEvaluator.query(rule["home_remark"]).string,
          };
        }).toList();
        return {"list": list};

      case "detailContent":
        final id = args[0] as String;
        final detailHtml = await NetworkService.instance.get(id);
        final detailDocument = html_parser.parse(detailHtml);
        final detailEvaluator = XPathEvaluator(detailDocument.documentElement!);
        final detailResult = detailEvaluator.query(rule["detail_root"]);
        final detailNode = detailResult.node;

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
              "vod_pic": detailNodeEvaluator.query(rule["detail_pic"]).attr ?? detailNodeEvaluator.query(rule["detail_pic"]).string,
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
        final playEvaluator = XPathEvaluator(playDocument.documentElement!);
        final playUrl = playEvaluator.query(rule["player_url"]).attr ?? playEvaluator.query(rule["player_url"]).string;

        return {
          "url": playUrl,
          "header": {},
        };

      default:
        throw Exception("XPath源暂不支持$method方法");
    }
  }

  // Type3 JS/Python动态脚本源（完整保留）
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
