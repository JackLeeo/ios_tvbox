class VideoModel {
  final String id;
  final String name;
  final String cover;
  final String? url;

  VideoModel({
    required this.id,
    required this.name,
    required this.cover,
    this.url,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      cover: json['cover'] ?? '',
      url: json['url'],
    );
  }
}
