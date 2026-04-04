import 'package:flutter/material.dart';
import 'package:ios_tvbox/core/spider_manager.dart';
import 'package:ios_tvbox/models/spider_source.dart';
import 'package:ios_tvbox/models/video_model.dart';
import 'dart:convert';

class SourceDebugger extends StatefulWidget {
  const SourceDebugger({super.key});

  @override
  State<SourceDebugger> createState() => _SourceDebuggerState();
}

class _SourceDebuggerState extends State<SourceDebugger> {
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController(text: '3');
  final _apiController = TextEditingController();
  final _extController = TextEditingController();

  String? _testResult;
  bool _isTesting = false;

  Future<void> _testSource() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final source = SpiderSource(
        key: _keyController.text.trim(),
        name: _nameController.text.trim(),
        type: int.parse(_typeController.text.trim()),
        api: _apiController.text.trim(),
        ext: _extController.text.trim(),
      );

      // 先添加源
      await SpiderManager.instance.addSource(source);
      SpiderManager.instance.setCurrentSource(source.key);

      // 测试homeContent方法
      final result = await SpiderManager.instance.execute("homeContent", [false]);

      // 验证返回数据格式
      if (result['list'] is! List) {
        throw Exception("返回数据格式错误，list字段不是数组");
      }

      // 验证视频数据格式
      if (result['list'].isNotEmpty) {
        final firstItem = result['list'][0];
        if (firstItem is! Map) {
          throw Exception("列表项不是对象格式");
        }
        if (firstItem['id'] == null || firstItem['name'] == null) {
          throw Exception("视频数据缺少id或name字段");
        }
        // 验证VideoModel解析正常
        VideoModel.fromJson(firstItem);
      }

      setState(() {
        _testResult = "✅ 源测试通过！\n返回数据：\n${const JsonEncoder.withIndent('  ').convert(result)}";
      });
    } catch (e) {
      setState(() {
        _testResult = "❌ 源测试失败！\n错误信息：\n$e";
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  Future<void> _saveSource() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final source = SpiderSource(
        key: _keyController.text.trim(),
        name: _nameController.text.trim(),
        type: int.parse(_typeController.text.trim()),
        api: _apiController.text.trim(),
        ext: _extController.text.trim(),
      );

      await SpiderManager.instance.addSource(source);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("源保存成功！")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("源保存失败：$e")),
      );
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _nameController.dispose();
    _typeController.dispose();
    _apiController.dispose();
    _extController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("源调试工具")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _keyController,
                decoration: const InputDecoration(labelText: "源唯一标识(key)"),
                validator: (v) => v?.isEmpty == true ? "请输入key" : null,
                // 修复废弃参数：value替换为initialValue
                initialValue: _keyController.text,
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "源名称"),
                validator: (v) => v?.isEmpty == true ? "请输入源名称" : null,
                initialValue: _nameController.text,
              ),
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(labelText: "源类型(type)"),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty == true) return "请输入源类型";
                  final type = int.tryParse(v!);
                  if (type == null || type < 1 || type > 3) {
                    return "源类型只能是1、2、3";
                  }
                  return null;
                },
                initialValue: _typeController.text,
              ),
              TextFormField(
                controller: _apiController,
                decoration: const InputDecoration(labelText: "API地址/远程脚本地址"),
                initialValue: _apiController.text,
              ),
              TextFormField(
                controller: _extController,
                decoration: const InputDecoration(labelText: "脚本内容/规则配置"),
                maxLines: 10,
                initialValue: _extController.text,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _isTesting ? null : _testSource,
                    child: _isTesting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("测试源"),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _saveSource,
                    child: const Text("保存源"),
                  ),
                ],
              ),
              if (_testResult != null) ...[
                const SizedBox(height: 16),
                const Text("测试结果：", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_testResult!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
