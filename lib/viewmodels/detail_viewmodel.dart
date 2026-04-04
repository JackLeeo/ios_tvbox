import 'package:flutter/foundation.dart';
import '../core/spider_manager.dart';
import '../models/video_model.dart';

class DetailViewModel extends ChangeNotifier {
  final SpiderManager _spiderManager;
  final String sourceKey;
  final String videoId;

  bool _isLoading = false;
  String? _error;
  VideoModel? _video;

  DetailViewModel(this._spiderManager, this.sourceKey, this.videoId);

  bool get isLoading => _isLoading;
  String? get error => _error;
  VideoModel? get video => _video;

  // 加载详情数据
  Future<void> loadDetail() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _spiderManager.getDetailContent(sourceKey, videoId);
      final list = result['list'];
      if (list is List && list.isNotEmpty) {
        _video = VideoModel.fromJson(Map<String, dynamic>.from(list.first));
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}