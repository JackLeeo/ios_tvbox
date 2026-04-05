import 'package:flutter/foundation.dart';
import '../core/spider_manager.dart';
import '../models/video_model.dart';

class HomeViewModel extends ChangeNotifier {
  List<VideoModel> videoList = [];
  bool isLoading = false;
  String? errorMessage;

  // 加载首页数据
  Future<void> loadHomeData() async {
    // 修复：添加初始化完成校验，避免启动时调用异常
    if (!SpiderManager.instance.hasSource) {
      errorMessage = "请先添加数据源，内置测试源加载中...";
      notifyListeners();
      // 等待1秒重试，确保测试源添加完成
      await Future.delayed(const Duration(seconds: 1));
      if (!SpiderManager.instance.hasSource) {
        errorMessage = "未找到可用数据源，请在设置中添加";
        notifyListeners();
        return;
      }
    }

    _setLoading(true);
    errorMessage = null;

    try {
      videoList = await SpiderManager.instance.getHomeContent();
      // 修复：空列表兜底提示
      if (videoList.isEmpty) {
        errorMessage = "暂无视频数据，请检查数据源";
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
