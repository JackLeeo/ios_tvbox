import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;
import 'package:xpath_selector/xpath_selector.dart'; // 替换为xpath_selector
import '../models/spider_source.dart';
import '../models/video_model.dart';
import 'js_engine.dart';
import 'python_engine.dart';
import 'network_service.dart';

class SpiderManager {
  final JSEngine _jsEngine = JSEngine();
  final PythonEngine _pyEngine = PythonEngine();
  final NetworkService _network = NetworkService();
  final Map<String, SpiderSource> _sources = {};
  bool _isInitialized = false;

  // 初始化所有引擎
  Future<void> init() async {
    if (_isInitialized) return;
    await _jsEngine.init();
    await _pyEngine.init();
    _isInitialized = true;
  }

  // 添加爬虫源
  Future<void> addSource(SpiderSource source) async {
    if (!_isInitialized) await init();
    
    if (source.type == 3) {
      String? ext = source.ext;
      if (source.api.endsWith('.js') || source.api.endsWith('.py')) {
        final res = await _network.get(source.api, headers: source.headers);
        ext = res.data.toString();
      }
      source = source.copyWith(ext: ext);
    }
    
    _sources[source.key] = source;
  }

  // 批量添加源
  Future<void> addSources(List<SpiderSource> sources) async {
    for (var s in sources) {
      await addSource(s);
    }
  }

  // 检查源是否存在
  bool hasSource(String key) => _sources.containsKey(key);

  // 统一执行入口
  Future<Map<String, dynamic>> execute(
    String sourceKey, 
    String method, 
    List<dynamic> args
  ) async {
    final source = _sources[sourceKey];
    if (source == null) throw Exception('源不存在: $sourceKey');

    switch (source.type) {
      case 1: return await _executeType1(source, method, args);
      case 2: return await _executeType2(source, method, args);
      case 3: return await _executeType3(source, method, args);
      default: throw Exception('不支持的源类型: ${source.type}');
    }
  }

  // 执行type1 JSON源
  Future<Map<String, dynamic>> _executeType1(
    SpiderSource source, 
    String method, 
    List<dynamic> args
  ) async {
    final response = await _network.post(
      source.api,
      data: {'method': method, 'args': args},
      headers: source.headers,
    );
    return Map<String, dynamic>.from(response.data);
  }

  // 执行type2 XPath源（修改为xpath_selector API）
  Future<Map<String, dynamic>> _executeType2(
    SpiderSource source, 
    String method, 
    List<dynamic> args
  ) async {
    // 1. 获取XPath规则配置
    final configResponse = await _network.get(source.api, headers: source.headers);
    final config = Map<String, dynamic>.from(configResponse.data);
    
    // 2. 构造目标URL
    String url = config['url'] ?? '';
    if (method == 'categoryContent' && args.length >= 2) {
      final tid = args[0].toString();
      final pg = args[1];
      url = url.replaceAll('{tid}', tid).replaceAll('{pg}', pg.toString());
    } else if (method == 'detailContent' && args.isNotEmpty) {
      final id = args[0].toString();
      url = (config['detailUrl'] ?? '').replaceAll('{id}', id);
    }
    if (url.isEmpty) throw Exception('XPath源URL配置错误');
    
    // 3. 请求并解析HTML
    final response = await _network.get(url, headers: source.headers);
    final document = html.parse(response.data);
    final root = document.documentElement; // 根节点
    
    // 4. 用xpath_selector执行XPath查询
    final itemXPath = config['item'] ?? '';
    if (itemXPath.isEmpty) throw Exception('XPath规则配置错误');
    final items = XPathSelector(root).select(itemXPath).nodes; // 查询列表项
    
    // 5. 解析每个列表项的字段
    final list = <VideoModel>[];
    for (var item in items) {
      if (item == null) continue;
      
      // 提取name、pic、id（用xpath_selector的select方法）
      final nameNode = XPathSelector(item).select(config['name'] ?? '').text;
      final picNode = XPathSelector(item).select(config['pic'] ?? '').text;
      final idNode = XPathSelector(item).select(config['id'] ?? '').text;
      
      // 容错处理
      if (nameNode.isEmpty || idNode.isEmpty) continue;
      if (nameNode.first.isEmpty || idNode.first.isEmpty) continue;
      
      list.add(VideoModel(
        id: idNode.first,
        name: nameNode.first,
        pic: picNode.first,
      ));
    }
    
    return {
      'list': list.map((e) => e.toJson()).toList(),
      'page': args.length >= 2 ? args[1] : 1,
      'pagecount': 999,
    };
  }

  // 执行type3 脚本源
  Future<Map<String, dynamic>> _executeType3(
    SpiderSource source, 
    String method, 
    List<dynamic> args
  ) async {
    final ext = source.ext;
    if (ext == null) throw Exception('脚本内容为空');
    
    if (ext.contains('CatVodSpider') || (ext.contains('function') && !ext.contains('def '))) {
      return await _jsEngine.executeScript(ext, method, args);
    } else if (ext.contains('VodSpider') || (ext.contains('import') || ext.contains('def '))) {
      return await _pyEngine.executeScript(ext, method, args);
    }
    
    throw Exception('未知的type3脚本格式');
  }

  // 首页数据
  Future<Map<String, dynamic>> getHomeContent(String sourceKey) async {
    return await execute(sourceKey, 'homeContent', [false]);
  }

  // 分类数据
  Future<Map<String, dynamic>> getCategoryContent(
    String sourceKey, 
    String tid, 
    int page, 
    Map filter
  ) async {
    return await execute(sourceKey, 'categoryContent', [tid, page, false, filter]);
  }

  // 详情数据
  Future<Map<String, dynamic>> getDetailContent(String sourceKey, String id) async {
    return await execute(sourceKey, 'detailContent', [[id]]);
  }

  // 搜索数据
  Future<Map<String, dynamic>> searchContent(
    String sourceKey, 
    String key, 
    bool quick, 
    int page
  ) async {
    return await execute(sourceKey, 'searchContent', [key, quick, page]);
  }

  // 播放地址解析
  Future<Map<String, dynamic>> getPlayerContent(
    String sourceKey, 
    String flag, 
    String id, 
    List flags
  ) async {
    return await execute(sourceKey, 'playerContent', [flag, id, flags]);
  }

  // 获取所有源
  List<SpiderSource> get sources => _sources.values.toList();

  // 释放资源
  void dispose() {
    _jsEngine.dispose();
    _pyEngine.dispose();
  }
}