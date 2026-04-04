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
