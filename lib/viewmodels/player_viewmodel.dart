import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import '../core/spider_manager.dart';

class PlayerViewModel extends ChangeNotifier {
  final SpiderManager _spiderManager;
  final String sourceKey;
  final Player player = Player();

  bool _isLoading = false;
  String? _error;
  String? _playUrl;
  Map<String, String>? _headers;

  PlayerViewModel(this._spiderManager, this.sourceKey);

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get playUrl => _playUrl;
  Map<String, String>? get headers => _headers;

  // 加载播放地址
  Future<void> loadPlayUrl(String flag, String id, List flags) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _spiderManager.getPlayerContent(sourceKey, flag, id, flags);
      _playUrl = result['url'];
      _headers = Map<String, String>.from(result['header'] ?? {});
      
      // 开始播放
      if (_playUrl != null) {
        // 修复：兼容 media_kit 1.2.6 旧版本，移除不存在的 headers 命名参数
        // 先设置播放器全局请求头，完整保留防盗链/鉴权头功能
        if (_headers != null && _headers!.isNotEmpty) {
          player.setHttpHeaders(_headers!);
        }
        await player.open(Media(_playUrl!));
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
