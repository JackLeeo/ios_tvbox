import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../core/media_kit_manager.dart';
import '../core/spider_manager.dart';

class PlayerView extends StatefulWidget {
  final String flag;
  final String id;
  final String title;

  const PlayerView({
    super.key,
    required this.flag,
    required this.id,
    required this.title,
  });

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  // 播放器控制器，延迟初始化
  late final Player _player;
  late final VideoController _videoController;
  bool _isInitLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    // 进入页面后，再初始化播放器，绝不阻塞启动
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPlayer();
    });
  }

  /// 懒加载初始化播放器，仅在进入播放页时执行
  Future<void> _initPlayer() async {
    try {
      setState(() {
        _isInitLoading = true;
        _errorMsg = null;
      });

      // 【核心修复】播放前才初始化media_kit引擎，启动时完全不碰
      await MediaKitManager.instance.ensureInitialized();

      // 解析播放地址
      final playInfo = await SpiderManager.instance.execute(
        "playerContent",
        [widget.flag, widget.id, false],
      );
      final String playUrl = playInfo['url'] ?? '';
      final Map<String, String> headers = Map<String, String>.from(playInfo['header'] ?? {});

      if (playUrl.isEmpty) {
        throw Exception("未获取到播放地址");
      }

      // 【修复】1.x版本media_kit初始化写法
      _player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 32 * 1024 * 1024, // 32MB缓冲
        ),
      );
      _videoController = VideoController(_player);

      // 【修复】1.x版本用open()方法，替代高版本的setMedia，同时设置自动播放
      await _player.open(
        Media(
          playUrl,
          httpHeaders: headers,
        ),
        play: true, // 直接自动播放，无需单独调用play()
      );

      setState(() {
        _isInitLoading = false;
      });
    } catch (e) {
      debugPrint('播放器初始化失败：$e');
      setState(() {
        _errorMsg = e.toString();
        _isInitLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // 【修复】1.x版本只需释放Player，VideoController随Player自动释放，无需单独dispose
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // 加载中
    if (_isInitLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              '播放器初始化中...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // 加载失败
    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
              const SizedBox(height: 20),
              Text(
                '播放失败：$_errorMsg',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _initPlayer,
                child: const Text('重试'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    // 播放器界面
    return Video(
      controller: _videoController,
      controls: MaterialVideoControls,
      fit: BoxFit.contain,
    );
  }
}
