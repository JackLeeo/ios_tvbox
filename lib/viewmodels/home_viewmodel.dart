import 'package:flutter/foundation.dart';
import '../core/spider_manager.dart';
import '../models/video_model.dart';

class HomeViewModel extends ChangeNotifier {
  List<VideoModel> videoList = [];
  bool isLoading = false;
  String? errorMessage;

  // 加载首页数据
  Future<void> loadHomeData() async {
    if (!SpiderManager.instance.hasSource) {
      errorMessage = "暂无可用数据源";
      notifyListeners();
      return;
    }

    _setLoading(true);
    errorMessage = null;

    try {
      videoList = await SpiderManager.instance.getHomeContent();
      if (videoList.isEmpty) {
        errorMessage = "暂无视频数据";
      }
    } catch (e) {
      errorMessage = "数据加载失败：${e.toString()}";
      debugPrint("首页数据加载失败: $e");
    } finally {
      _setLoading(false);
    }
  }

  // 刷新数据
  Future<void> refresh() async {
    await loadHomeData();
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
