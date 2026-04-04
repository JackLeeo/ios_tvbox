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
        await player.open(Media(_playUrl!, headers: _headers));
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