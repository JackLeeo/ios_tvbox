import 'package:flutter/foundation.dart';
import '../core/spider_manager.dart';
import '../models/video_model.dart';

class HomeViewModel extends ChangeNotifier {
  final SpiderManager _spiderManager;
  bool _isLoading = false;
  String? _error;
  List<VideoModel> _videoList = [];
  String? _currentSourceKey;

  HomeViewModel(this._spiderManager);

  // 状态 getter
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<VideoModel> get videoList => _videoList;
  String? get currentSourceKey => _currentSourceKey;

  // 切换源
  void setSource(String sourceKey) {
    // 校验源是否存在
    if (!_spiderManager.hasSource(sourceKey)) {
      _error = '源不存在: $sourceKey';
      notifyListeners();
      return;
    }
    _currentSourceKey = sourceKey;
    loadHomeData();
  }

  // 加载首页数据
  Future<void> loadHomeData() async {
    if (_currentSourceKey == null) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _spiderManager.getHomeContent(_currentSourceKey!);
      
      // 安全类型检查，避免CastError
      final rawList = result['list'];
      if (rawList is List) {
        final list = rawList
            .map((e) => VideoModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _videoList = list;
      } else {
        _error = '源返回数据格式错误';
        _videoList = [];
      }
    } catch (e) {
      _error = e.toString();
      _videoList = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 刷新
  Future<void> refresh() async {
    await loadHomeData();
  }
}