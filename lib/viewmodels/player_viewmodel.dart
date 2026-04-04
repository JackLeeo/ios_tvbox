import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:ios_tvbox/core/spider_manager.dart';

class PlayerViewModel extends ChangeNotifier {
  late final Player player;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  PlayerViewModel() {
    player = Player();
  }

  // 初始化播放（修复setHttpHeaders错误，使用media_kit标准API设置请求头）
  Future<void> initPlay(String flag, String id) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      // 解析播放地址
      final result = await SpiderManager.instance.execute(
        "playerContent",
        [flag, id, []],
      );

      final String url = result['url'] ?? '';
      final Map<String, String> headers = Map<String, String>.from(result['header'] ?? {});

      if (url.isEmpty) {
        throw Exception("播放地址为空");
      }

      // 正确设置播放地址和HTTP头（media_kit标准实现）
      await player.open(
        Media.playable(
          url,
          httpHeaders: headers,
        ),
        play: true,
      );
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("播放初始化错误: $e");
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // 释放播放器资源
  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
