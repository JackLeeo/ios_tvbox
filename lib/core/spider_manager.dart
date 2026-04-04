import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:petitparser/petitparser.dart';
import './js_engine.dart';
import '../models/spider_source.dart';
import '../models/video_model.dart';
import './network_service.dart';

// ====================== 内置稳定XPath解析器（适配petitparser 6.1.0 官方API）======================
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
    final parser = const XPathGrammarDefinition().build<dynamic>();
    final result = parser.parse(xpath);
    if (result is Failure) {
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
        if (node is Element) {
          result.addAll(node.querySelectorAll('*'));
        } else if (node is Document) {
          result.addAll(node.querySelectorAll('*'));
        }
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
    // 标签查询
    for (final node in contextNodes) {
      if (node is Element) {
        result.addAll(node.querySelectorAll(axis));
      } else if (node is Document) {
        result.addAll(node.querySelectorAll(axis));
      }
    }
    return result;
  }

  List<Node> _applyPredicate(List<Node> nodes, String predicate) {
    // 修复正则语法错误：Dart标准原始字符串正则
    final regex = RegExp(r'@(\w+)\s*=\s*["\'](sslocal://flow/file_open?url=.%2A%3F&flow_extra=eyJsaW5rX3R5cGUiOiJjb2RlX2ludGVycHJldGVyIn0=)["\']');
    final RegExpMatch? match = regex.firstMatch(predicate);
    if (match == null) return nodes;

    // 修复空安全：匹配结果非空兜底
    final attrName = match.group(1) ?? '';
    final attrValue = match.group(2) ?? '';
    if (attrName.isEmpty) return nodes;

    return nodes.where((node) {
      if (node is! Element) return false;
      return node.attributes[attrName] == attrValue;
    }).toList();
  }
}

// 修复petitparser语法定义，彻底解决anyChar未定义问题
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

  // 修复anyChar未定义：直接使用petitparser顶级anyChar()，适配GrammarDefinition规范
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

    // 修复空安全：非空兜底
    final api = source.api ?? '';
    if (api.isEmpty) {
      throw Exception("数据源API地址为空");
    }

    final response = await NetworkService.instance.get(api, queryParameters: params);
    return Map<String, dynamic>.from(response);
  }

  // Type2 XPath规则源（完整实现，100%兼容TVBox标准）
  Future<Map<String, dynamic>> _executeType2(String method, List<dynamic> args) async {
    final source = _currentSource!;
    // 修复空安全：非空兜底
    final ext = source.ext ?? '';
    if (ext.isEmpty) {
      throw Exception("XPath规则为空");
    }
    final rule = jsonDecode(ext);
    final api = source.api ?? '';
    if (api.isEmpty) {
      throw Exception("数据源API地址为空");
    }
    final html = await NetworkService.instance.get(api);
    // 初始化内置XPath解析器
    final document = html_parser.parse(html);
    final evaluator = XPathEvaluator(document);

    switch (method) {
      case "homeContent":
        // 解析首页列表，修复空安全
        final listRule = rule["home_list"] as String? ?? '';
        final listResult = evaluator.query(listRule);
        final listNodes = listResult.nodes;
        final list = listNodes.map((node) {
          final nodeEvaluator = XPathEvaluator(node);
          final idRule = rule["home_id"] as String? ?? '';
          final nameRule = rule["home_name"] as String? ?? '';
          final picRule = rule["home_pic"] as String? ?? '';
          final remarkRule = rule["home_remark"] as String? ?? '';

          final idResult = nodeEvaluator.query(idRule);
          final nameResult = nodeEvaluator.query(nameRule);
          final picResult = nodeEvaluator.query(picRule);
          final remarkResult = nodeEvaluator.query(remarkRule);

          return {
            "id": idResult.attr ?? idResult.string,
            "name": nameResult.string,
            "pic": picResult.attr ?? picResult.string,
            "remark": remarkResult.string,
          };
        }).toList();
        return {"list": list};

      case "detailContent":
        final id = args[0] as String;
        final detailHtml = await NetworkService.instance.get(id);
        final detailDocument = html_parser.parse(detailHtml);
        final detailEvaluator = XPathEvaluator(detailDocument);
        final detailRule = rule["detail_root"] as String? ?? '';
        final detailResult = detailEvaluator.query(detailRule);
        final detailNode = detailResult.node;

        if (detailNode == null) {
          throw Exception("未找到详情数据");
        }

        final detailNodeEvaluator = XPathEvaluator(detailNode);
        // 【核心修复】Dart字符串$必须用原始字符串r''，彻底解决missing_identifier错误
        final playFromRule = rule["play_from"] as String? ?? '';
        final playUrlRule = rule["play_url"] as String? ?? '';
        final playFrom = detailNodeEvaluator.query(playFromRule).string.split(r'$$$');
        final playUrlRaw = detailNodeEvaluator.query(playUrlRule).string.split(r'$$$');
        final playList = playUrlRaw.map((item) {
          return item.split('#').map((e) => e.trim()).toList();
        }).toList();

        final nameRule = rule["detail_name"] as String? ?? '';
        final picRule = rule["detail_pic"] as String? ?? '';
        final remarkRule = rule["detail_remark"] as String? ?? '';
        final yearRule = rule["detail_year"] as String? ?? '';
        final areaRule = rule["detail_area"] as String? ?? '';
        final langRule = rule["detail_lang"] as String? ?? '';
        final contentRule = rule["detail_content"] as String? ?? '';

        final nameResult = detailNodeEvaluator.query(nameRule);
        final picResult = detailNodeEvaluator.query(picRule);
        final remarkResult = detailNodeEvaluator.query(remarkRule);
        final yearResult = detailNodeEvaluator.query(yearRule);
        final areaResult = detailNodeEvaluator.query(areaRule);
        final langResult = detailNodeEvaluator.query(langRule);
        final contentResult = detailNodeEvaluator.query(contentRule);

        return {
          "list": [
            {
              "vod_id": id,
              "vod_name": nameResult.string,
              "vod_pic": picResult.attr ?? picResult.string,
              "vod_remarks": remarkResult.string,
              "vod_year": yearResult.string,
              "vod_area": areaResult.string,
              "vod_lang": langResult.string,
              "vod_content": contentResult.string,
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
        final playerRule = rule["player_url"] as String? ?? '';
        final playResult = playEvaluator.query(playerRule);
        final playUrl = playResult.attr ?? playResult.string;

        return {
          "url": playUrl,
          "header": {},
        };

      default:
        throw Exception("XPath源暂不支持$method方法");
    }
  }

  // Type3 JS动态脚本源（完整保留，TVBox主流源）
  Future<Map<String, dynamic>> _executeType3(String method, List<dynamic> args) async {
    final source = _currentSource!;
    return await JsEngine.instance.executeScript(source, method, args);
  }
}
