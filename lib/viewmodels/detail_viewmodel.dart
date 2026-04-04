import 'package:flutter/foundation.dart';
import '../core/spider_manager.dart';
import '../models/video_model.dart';

class DetailViewModel extends ChangeNotifier {
  VideoModel? videoDetail;
  bool isLoading = false;
  String? errorMessage;
  int currentFromIndex = 0;

  // 加载详情数据
  Future<void> loadDetail(String id) async {
    _setLoading(true);
    errorMessage = null;

    try {
      videoDetail = await SpiderManager.instance.getDetailContent(id);
      currentFromIndex = 0;
    } catch (e) {
      errorMessage = e.toString();
      debugPrint("详情数据加载失败: $e");
    } finally {
      _setLoading(false);
    }
  }

  // 切换播放线路
  void changePlayFrom(int index) {
    if (index < 0 || index >= (videoDetail?.playFrom?.length ?? 0)) return;
    currentFromIndex = index;
    notifyListeners();
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
