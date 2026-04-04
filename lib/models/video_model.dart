class VideoModel {
  final String id;
  final String name;
  final String pic;
  final String remark;
  final String? content;
  final List<String>? playFrom;
  final List<List<String>>? playUrl;

  VideoModel({
    required this.id,
    required this.name,
    required this.pic,
    this.remark = '',
    this.content,
    this.playFrom,
    this.playUrl,
  });

  // 从JSON解析数据（修复语法错误和类型转换错误）
  factory VideoModel.fromJson(Map<String, dynamic> json) {
    // 处理播放地址的类型转换，兼容TVBox标准格式
    List<List<String>>? parsedPlayUrl;
    if (json['vod_play_url'] != null) {
      final rawPlayUrl = json['vod_play_url'] as List;
      parsedPlayUrl = rawPlayUrl.map((item) {
        if (item is List) {
          return item.map((e) => e.toString()).toList();
        }
        // 兼容TVBox标准的#分隔播放地址格式
        return item.toString().split('#').map((e) => e.trim()).toList();
      }).toList();
    }

    return VideoModel(
      id: json['id']?.toString() ?? json['vod_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['vod_name']?.toString() ?? '',
      pic: json['pic']?.toString() ?? json['vod_pic']?.toString() ?? '',
      remark: json['remark']?.toString() ?? json['vod_remarks']?.toString() ?? '',
      content: json['content']?.toString() ?? json['vod_content']?.toString(),
      playFrom: json['vod_play_from'] != null
          ? (json['vod_play_from'] as List).map((e) => e.toString()).toList()
          : null,
      playUrl: parsedPlayUrl,
    );
  }

  // 转JSON格式
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pic': pic,
      'remark': remark,
      'content': content,
      'vod_play_from': playFrom,
      'vod_play_url': playUrl,
    };
  }
}
