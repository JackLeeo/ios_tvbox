import 'dart:convert';

class SpiderSource {
  final String key;         // 源唯一标识
  final String name;         // 源名称
  final int type;            // 源类型（1=JSON, 2=XPath, 3=Spider）
  final String api;          // 源地址
  final String? jar;         // type3-JAR包（Android兼容）
  final String? ext;         // type3-脚本内容
  final Map<String, String>? headers; // 请求头
  final bool searchable;     // 是否支持搜索
  final bool quickSearch;    // 是否支持快速搜索

  SpiderSource({
    required this.key,
    required this.name,
    required this.type,
    required this.api,
    this.jar,
    this.ext,
    this.headers,
    this.searchable = true,
    this.quickSearch = false,
  });

  // 从JSON解析，自动处理base64编码的ext
  factory SpiderSource.fromJson(Map<String, dynamic> json) {
    String? ext = json['ext'];
    
    // 自动解码base64的脚本内容
    if (ext != null) {
      try {
        // 正确补全base64 padding，避免过度添加
        String rawExt = ext;
        final padLength = (4 - rawExt.length % 4) % 4;
        rawExt = rawExt.padRight(rawExt.length + padLength, '=');
        final bytes = base64.decode(rawExt);
        ext = utf8.decode(bytes);
      } catch (_) {
        // 解码失败则保留原始内容
      }
    }

    // 安全转换headers，确保所有value都是String
    Map<String, String>? headers;
    if (json['headers'] != null) {
      headers = {};
      final rawHeaders = json['headers'] as Map;
      for (var entry in rawHeaders.entries) {
        headers[entry.key.toString()] = entry.value.toString();
      }
    }

    return SpiderSource(
      key: json['key'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 1,
      api: json['api'] ?? '',
      jar: json['jar'],
      ext: ext,
      headers: headers,
      searchable: json['searchable'] ?? true,
      quickSearch: json['quickSearch'] ?? false,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
      'type': type,
      'api': api,
      'jar': jar,
      'ext': ext,
      'headers': headers,
      'searchable': searchable,
      'quickSearch': quickSearch,
    };
  }

  // 复制修改
  SpiderSource copyWith({
    String? key,
    String? name,
    int? type,
    String? api,
    String? jar,
    String? ext,
    Map<String, String>? headers,
    bool? searchable,
    bool? quickSearch,
  }) {
    return SpiderSource(
      key: key ?? this.key,
      name: name ?? this.name,
      type: type ?? this.type,
      api: api ?? this.api,
      jar: jar ?? this.jar,
      ext: ext ?? this.ext,
      headers: headers ?? this.headers,
      searchable: searchable ?? this.searchable,
      quickSearch: quickSearch ?? this.quickSearch,
    );
  }
}