class CategoryModel {
  final String tid;
  final String name;
  final List<FilterModel>? filters;

  CategoryModel({
    required this.tid,
    required this.name,
    this.filters,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      tid: json['tid'] ?? '',
      name: json['name'] ?? '',
      filters: json['filters'] != null
          ? (json['filters'] as List)
              .map((e) => FilterModel.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tid': tid,
      'name': name,
      'filters': filters?.map((e) => e.toJson()).toList(),
    };
  }
}

class FilterModel {
  final String key;
  final String name;
  final List<FilterValue> values;

  FilterModel({
    required this.key,
    required this.name,
    required this.values,
  });

  factory FilterModel.fromJson(Map<String, dynamic> json) {
    return FilterModel(
      key: json['key'] ?? '',
      name: json['name'] ?? '',
      values: (json['values'] as List)
          .map((e) => FilterValue.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
      'values': values.map((e) => e.toJson()).toList(),
    };
  }
}

class FilterValue {
  final String n;
  final String v;

  FilterValue({required this.n, required this.v});

  factory FilterValue.fromJson(Map<String, dynamic> json) {
    return FilterValue(
      n: json['n'] ?? '',
      v: json['v'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'n': n,
      'v': v,
    };
  }
}

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

class VideoModel {
  final String id;
  final String name;
  final String pic;
  final String remark;
  final String? year;
  final String? area;
  final String? lang;
  final String? type;
  final String? des;
  final String? content;
  final List<String>? playFrom;
  final List<List<String>>? playUrl;
  final List<List<String>>? playList;

  // 兼容别名
  String? get remarks => remark;
  String? get title => name; // 新增：为视图提供title别名，兼容视图调用

  const VideoModel({
    required this.id,
    required this.name,
    required this.pic,
    this.remark = '',
    this.year,
    this.area,
    this.lang,
    this.type,
    this.des,
    this.content,
    this.playFrom,
    this.playUrl,
    this.playList,
  });

  // 从JSON解析（兼容TVBox全字段）
  factory VideoModel.fromJson(Map<String, dynamic> json) {
    // 解析播放地址
    List<List<String>>? parsedPlayUrl;
    if (json['vod_play_url'] != null) {
      final raw = json['vod_play_url'] as List;
      parsedPlayUrl = raw.map((item) {
        if (item is List) {
          return item.map((e) => e.toString()).toList();
        }
        return item.toString().split('#').map((e) => e.trim()).toList();
      }).toList();
    }

    return VideoModel(
      id: json['id']?.toString() ?? json['vod_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['vod_name']?.toString() ?? '',
      pic: json['pic']?.toString() ?? json['vod_pic']?.toString() ?? '',
      remark: json['remark']?.toString() ?? json['vod_remarks']?.toString() ?? '',
      year: json['year']?.toString() ?? json['vod_year']?.toString(),
      area: json['area']?.toString() ?? json['vod_area']?.toString(),
      lang: json['lang']?.toString() ?? json['vod_lang']?.toString(),
      type: json['type']?.toString() ?? json['vod_type']?.toString(),
      des: json['des']?.toString() ?? json['vod_content']?.toString(),
      content: json['content']?.toString() ?? json['vod_content']?.toString(),
      playFrom: json['vod_play_from'] != null
          ? (json['vod_play_from'] as List).map((e) => e.toString()).toList()
          : null,
      playUrl: parsedPlayUrl,
      playList: parsedPlayUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pic': pic,
      'remark': remark,
      'year': year,
      'area': area,
      'lang': lang,
      'type': type,
      'des': des,
      'content': content,
      'vod_play_from': playFrom,
      'vod_play_url': playUrl,
    };
  }
}
