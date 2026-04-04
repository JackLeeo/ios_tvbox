class VideoModel {
  final String id;
  final String name;
  final String pic;
  final String? year;
  final String? type;
  final String? lang;
  final String? area;
  final String? des;
  final String? remarks;
  final String? actor;
  final String? director;
  final List<String>? playFrom;
  final List<List<String>>? playList; // 兼容嵌套结构：[[线路1$id1, 线路2$id2], ...]

  VideoModel({
    required this.id,
    required this.name,
    required this.pic,
    this.year,
    this.type,
    this.lang,
    this.area,
    this.des,
    this.remarks,
    this.actor,
    this.director,
    this.playFrom,
    this.playList,
  });

  // 从JSON解析，兼容TVBox标准字段
  factory VideoModel.fromJson(Map<String, dynamic> json) {
    // 处理播放源
    List<String>? playFrom;
    List<List<String>>? playList;
    
    // 兼容标准vod字段
    final rawPlayFrom = json['playFrom'] ?? json['vod_play_from'];
    final rawPlayUrl = json['playList'] ?? json['vod_play_url'];
    
    if (rawPlayFrom != null && rawPlayUrl != null) {
      if (rawPlayFrom is String) {
        playFrom = rawPlayFrom.split('$$');
      } else if (rawPlayFrom is List) {
        playFrom = rawPlayFrom.map((e) => e.toString()).toList();
      }
      
      if (rawPlayUrl is String) {
        playList = [rawPlayUrl.split('#')];
      } else if (rawPlayUrl is List) {
        // 处理嵌套列表结构
        playList = rawPlayUrl.map((e) {
          if (e is String) {
            return e.split('#');
          } else if (e is List) {
            return e.map((item) => item.toString()).toList();
          }
          return [];
        }).toList();
      }
    }

    return VideoModel(
      id: json['id'] ?? json['vod_id'] ?? '',
      name: json['name'] ?? json['vod_name'] ?? '',
      pic: json['pic'] ?? json['vod_pic'] ?? '',
      year: json['year'] ?? json['vod_year']?.toString(),
      type: json['type'] ?? json['vod_type']?.toString(),
      lang: json['lang'] ?? json['vod_lang']?.toString(),
      area: json['area'] ?? json['vod_area']?.toString(),
      des: json['des'] ?? json['vod_content']?.toString(),
      remarks: json['remarks'] ?? json['vod_remarks']?.toString(),
      actor: json['actor'] ?? json['vod_actor']?.toString(),
      director: json['director'] ?? json['vod_director']?.toString(),
      playFrom: playFrom,
      playList: playList,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pic': pic,
      'year': year,
      'type': type,
      'lang': lang,
      'area': area,
      'des': des,
      'remarks': remarks,
      'actor': actor,
      'director': director,
      'playFrom': playFrom,
      'playList': playList,
    };
  }
}