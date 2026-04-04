import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/spider_manager.dart';
import '../models/spider_source.dart';

class SourceDebuggerView extends StatefulWidget {
  const SourceDebuggerView({super.key});

  @override
  State<SourceDebuggerView> createState() => _SourceDebuggerViewState();
}

class _SourceDebuggerViewState extends State<SourceDebuggerView> {
  final TextEditingController _apiController = TextEditingController();
  final TextEditingController _extController = TextEditingController();
  int _type = 3;
  String? _result;
  bool _isTesting = false;

  Future<void> _testSource() async {
    setState(() {
      _isTesting = true;
      _result = null;
    });

    try {
      final spiderManager = Provider.of<SpiderManager>(context, listen: false);
      
      // 生成唯一测试key，避免覆盖已有源
      final debugKey = 'debug_${DateTime.now().millisecondsSinceEpoch}';
      
      // 创建测试源
      final source = SpiderSource(
        key: debugKey,
        name: 'Debug Source',
        type: _type,
        api: _apiController.text,
        ext: _extController.text.isNotEmpty ? _extController.text : null,
      );
      
      await spiderManager.addSource(source);
      
      // 测试首页方法
      final result = await spiderManager.getHomeContent(debugKey);
      
      // 安全序列化结果
      final safeResult = _deepConvertToMap(result);
      setState(() {
        _result = jsonEncode(safeResult);
      });
    } catch (e) {
      setState(() {
        _result = '错误: $e';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  // 深度转换为可序列化的Map
  dynamic _deepConvertToMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k, _deepConvertToMap(v)));
    } else if (value is List) {
      return value.map((e) => _deepConvertToMap(e)).toList();
    } else if (value is VideoModel) {
      return value.toJson();
    } else {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('源调试工具')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 源类型选择
            DropdownButtonFormField<int>(
              value: _type,
              decoration: const InputDecoration(labelText: '源类型'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('type1 JSON')),
                DropdownMenuItem(value: 2, child: Text('type2 XPath')),
                DropdownMenuItem(value: 3, child: Text('type3 Spider')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 16),
            // API地址
            TextField(
              controller: _apiController,
              decoration: const InputDecoration(
                labelText: 'API地址',
                hintText: '输入源的API地址',
                border: OutlineInputBorder(),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 16),
            // 脚本内容
            if (_type == 3)
              TextField(
                controller: _extController,
                decoration: const InputDecoration(
                  labelText: '脚本内容(可选)',
                  hintText: '输入base64或明文脚本',
                  border: OutlineInputBorder(),
                ),
                maxLines: 8,
              ),
            const SizedBox(height: 16),
            // 测试按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isTesting ? null : _testSource,
                child: _isTesting
                    ? const CircularProgressIndicator()
                    : const Text('测试源'),
              ),
            ),
            const SizedBox(height: 16),
            // 结果展示
            if (_result != null) ...[
              const Text('测试结果', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_result!, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}