class SpiderSource {
  final String key;
  final String name;
  final int type;
  final String? api;
  final String? ext;

  const SpiderSource({
    required this.key,
    required this.name,
    required this.type,
    this.api,
    this.ext,
  });

  // 从JSON解析
  factory SpiderSource.fromJson(Map<String, dynamic> json) {
    return SpiderSource(
      key: json['key'] as String,
      name: json['name'] as String,
      type: json['type'] as int,
      api: json['api'] as String?,
      ext: json['ext'] as String?,
    );
  }

  // 转JSON
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
      'type': type,
      'api': api,
      'ext': ext,
    };
  }
}
