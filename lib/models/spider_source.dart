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

  factory SpiderSource.fromJson(Map<String, dynamic> json) {
    return SpiderSource(
      key: json['key'] as String,
      name: json['name'] as String,
      type: json['type'] as int,
      api: json['api'] as String?,
      ext: json['ext'] as String?,
    );
  }

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
