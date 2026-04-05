// 【修复】导入foundation，debugPrint定义在此文件中
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// media_kit 懒加载管理器，彻底解决启动白屏问题
class MediaKitManager {
  static bool _isInitialized = false;

  static final MediaKitManager instance = MediaKitManager._internal();
  MediaKitManager._internal();

  /// 播放前才调用初始化，确保不阻塞启动渲染
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    try {
      // 仅在用户点击播放时，才初始化播放器引擎
      MediaKit.ensureInitialized();
      _isInitialized = true;
      debugPrint('✅ media_kit 懒加载初始化完成');
    } catch (e) {
      debugPrint('❌ media_kit 初始化失败：$e');
      rethrow;
    }
  }

  /// 释放资源
  void dispose() {
    _isInitialized = false;
  }
}
