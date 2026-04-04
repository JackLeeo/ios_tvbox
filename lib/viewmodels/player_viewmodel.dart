import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import '../core/spider_manager.dart';

class PlayerViewModel extends ChangeNotifier {
  late final Player player;
  bool isLoading = false;
  String? errorMessage;

  PlayerViewModel() {
    player = Player();
  }

  // 初始化播放
  Future<void> initPlay(String flag, String id) async {
    _setLoading(true);
    errorMessage = null;

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

      // media_kit标准构造函数
      await player.open(
        Media(
          url,
          httpHeaders: headers,
        ),
        play: true,
      );
    } catch (e) {
      errorMessage = e.toString();
      debugPrint("播放初始化失败: $e");
    } finally {
      _setLoading(false);
    }
  }

  // 播放/暂停
  void togglePlay() {
    if (player.state.playing) {
      player.pause();
    } else {
      player.play();
    }
    notifyListeners();
  }

  // 调整进度
  void seekTo(Duration position) {
    player.seek(position);
  }

  // 调整倍速
  void setSpeed(double speed) {
    player.setRate(speed);
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
