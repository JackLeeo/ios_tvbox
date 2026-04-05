class SpiderSource {
  final String key;
  final String name;
  final int type;
  final String? api; // 远程脚本地址，可选可空
  final String? ext; // 脚本内容/规则，可选可空

  const SpiderSource({
    required this.key,
    required this.name,
    required this.type,
    this.api,
    this.ext,
  });

  // 复制对象方法，保留原有配置能力
  SpiderSource copyWith({
    String? key,
    String? name,
    int? type,
    String? api,
    String? ext,
  }) {
    return SpiderSource(
      key: key ?? this.key,
      name: name ?? this.name,
      type: type ?? this.type,
      api: api ?? this.api,
      ext: ext ?? this.ext,
    );
  }

  // JSON序列化
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
      'type': type,
      'api': api,
      'ext': ext,
    };
  }

  // JSON反序列化
  factory SpiderSource.fromJson(Map<String, dynamic> json) {
    return SpiderSource(
      key: json['key'] as String,
      name: json['name'] as String,
      type: json['type'] as int,
      api: json['api'] as String?,
      ext: json['ext'] as String?,
    );
  }
}
