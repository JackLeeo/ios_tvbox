import 'package:flutter_js/flutter_js.dart';
import 'dart:convert';
import '../models/spider_source.dart';
import './network_service.dart';

class JsEngine {
  late final JavascriptRuntime _runtime;
  bool _isInitialized = false;

  static final JsEngine instance = JsEngine._internal();
  JsEngine._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    _runtime = getJavascriptRuntime();

    // 极简预置全局爬虫基类 + http 同步桥接(兼容所有老旧flutter_js)
    final initCode = r"""
    class CatVodSpider{constructor(){}async homeContent(f){return{}}async detailContent(i){return{}}}
    var http={get:(u,h)=>DartCallGet(u,h||{}),post:(d,t,h)=>DartCallPost(d,t,h||{})};
    """;
    _runtime.evaluate(initCode);

    // 绑定全局同步顶层方法，老旧版本唯一可用桥接方式
    _runtime.registerJavaScriptHandler("DartCallGet", (args) async {
      final url = args[0] as String;
      final headers = args.length>1 ? Map<String,dynamic>.from(args[1]) : null;
      return await NetworkService.instance.get(url,headers:headers);
    });
    _runtime.registerJavaScriptHandler("DartCallPost", (args) async {
      final url = args[0] as String;
      final data = args.length>1 ? args[1] : null;
      final headers = args.length>2 ? Map<String,dynamic>.from(args[2]) : null;
      return await NetworkService.instance.post(url,data:data,headers:headers);
    });

    _isInitialized = true;
  }

  Future<dynamic> executeScript(SpiderSource source, String method, List<dynamic> args) async {
    if(!_isInitialized) await init();
    if(source.ext?.isNotEmpty??false) _runtime.evaluate(source.ext!);

    final callJs = "(async()=>{let s=new MySpider;return JSON.stringify(await s.$method(...${jsonEncode(args)}))})()";
    final res = _runtime.evaluate(callJs);
    return jsonDecode(res.stringResult);
  }

  Future<void> dispose() async => _runtime.dispose();
}
