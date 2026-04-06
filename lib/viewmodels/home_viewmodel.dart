import 'package:flutter/foundation.dart';
import '../core/spider_manager.dart';
import '../models/video_model.dart';

class HomeViewModel extends ChangeNotifier {
  List<VideoModel> videoList = [];
  bool loading = false;
  String? error;

  // 加载首页数据（方法名更新为视图使用的loadData）
  Future<void> loadData() async {
    if (!SpiderManager.instance.hasSource) {
      error = "暂无可用数据源";
      notifyListeners();
      return;
    }

    _setLoading(true);
    error = null;

    try {
      videoList = await SpiderManager.instance.getHomeContent();
      if (videoList.isEmpty) {
        error = "暂无视频数据";
      }
    } catch (e) {
      error = "数据加载失败：${e.toString()}";
      debugPrint("首页数据加载失败: $e");
    } finally {
      _setLoading(false);
    }
  }

  // 刷新数据
  Future<void> refresh() async {
    await loadData();
  }

  void _setLoading(bool value) {
    loading = value;
    notifyListeners();
  }
}
