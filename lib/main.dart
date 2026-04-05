import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:ui';
import './views/home_view.dart';
import './viewmodels/home_viewmodel.dart';
import './core/spider_manager.dart';
import './core/js_engine.dart';
import './core/network_service.dart';
import './views/source_debugger.dart';
import './views/detail_view.dart';
import './views/player_view.dart';
import './models/spider_source.dart';

// 全局异常捕获，彻底拦截所有未处理异常，避免白屏
void main() {
  // 第一行必须初始化Flutter引擎绑定，核心基础
  WidgetsFlutterBinding.ensureInitialized();

  // 全局Flutter框架异常捕获
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('=== Flutter框架异常 ===');
    debugPrint('异常内容：${details.exception}');
    debugPrint('异常堆栈：${details.stack}');
  };

  // 全局平台/Isolate异常捕获
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('=== 全局运行异常 ===');
    debugPrint('异常内容：$error');
    debugPrint('异常堆栈：$stack');
    return true;
  };

  // 强制横屏，适配TVBox场景
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 【关键修复】仅同步初始化无阻塞的播放器核心，其他所有初始化全延后
  MediaKit.ensureInitialized();

  // 立即启动App渲染，绝不阻塞主线程
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 初始化状态管理
  bool _initCompleted = false;
  String? _initErrorMsg;
  bool _isInitRunning = false;

  @override
  void initState() {
    super.initState();
    // 【关键修复】首帧渲染完成后，再执行初始化，完全不阻塞UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAppCore();
    });
  }

  // 分阶段异步初始化，绝对不阻塞主线程
  Future<void> _initAppCore() async {
    // 避免重复初始化
    if (_isInitRunning || _initCompleted) return;
    _isInitRunning = true;

    try {
      // 第一阶段：初始化基础网络服务
      await NetworkService.instance.init();
      if (mounted) setState(() {});

      // 第二阶段：初始化核心管理器，不初始化JS引擎（延后到用户使用时）
      await SpiderManager.instance.init();
      if (mounted) setState(() {});

      // 第三阶段：添加内置测试源，无阻塞
      await _addDefaultTestSource();
      if (mounted) setState(() {});

      // 全部初始化完成，刷新UI
      if (mounted) {
        setState(() {
          _initCompleted = true;
          _initErrorMsg = null;
          _isInitRunning = false;
        });
      }
    } catch (e, stack) {
      // 异常兜底，哪怕初始化失败也不会白屏
      debugPrint('App初始化失败：$e');
      debugPrint('初始化失败堆栈：$stack');
      if (mounted) {
        setState(() {
          _initErrorMsg = e.toString();
          _isInitRunning = false;
        });
      }
    }
  }

  // 添加内置测试源，和你的原有逻辑完全一致
  Future<void> _addDefaultTestSource() async {
    await SpiderManager.instance.addSource(const SpiderSource(
      key: "default_test",
      name: "内置测试源",
      type: 3,
      api: "",
      ext: """
class CatVodSpider {
  constructor() {}
  async homeContent(filter) { return {}; }
  async detailContent(ids) { return {}; }
  async playerContent(flag, id, vipFlags) { return {}; }
  async searchContent(wd, quick, pg) { return {}; }
}

class MySpider extends CatVodSpider {
  async homeContent(filter) {
    return {
      list: [
        {
          id: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          name: '测试视频-大兔子邦尼',
          pic: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Big_buck_bunny_poster_big.jpg/800px-Big_buck_bunny_poster_big.jpg',
          remark: '测试视频',
          year: '2008',
          area: '美国',
          lang: '英语',
          des: '这是一个开源测试视频，用于验证播放器功能'
        },
        {
          id: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
          name: '大象之梦',
          pic: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/07/ElephantsDream.jpg/800px-ElephantsDream.jpg',
          remark: '测试视频',
          year: '2006',
          area: '荷兰',
          lang: '英语',
          des: '世界上第一部开源电影'
        }
      ]
    };
  }

  async detailContent(ids) {
    return {
      list: [
        {
          vod_id: ids,
          vod_name: ids.includes('BigBuckBunny') ? '大兔子邦尼' : '大象之梦',
          vod_pic: ids.includes('BigBuckBunny') 
            ? 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Big_buck_bunny_poster_big.jpg/800px-Big_buck_bunny_poster_big.jpg'
            : 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/07/ElephantsDream.jpg/800px-ElephantsDream.jpg',
          vod_remarks: '测试视频',
          vod_year: ids.includes('BigBuckBunny') ? '2008' : '2006',
          vod_area: ids.includes('BigBuckBunny') ? '美国' : '荷兰',
          vod_lang: '英语',
          vod_content: ids.includes('BigBuckBunny') 
            ? '这是一个开源测试视频，用于验证播放器功能' 
            : '世界上第一部开源电影',
          vod_play_from: ['默认线路'],
          vod_play_url: [
            ['正片\$' + ids]
          ]
        }
      ]
    };
  }

  async playerContent(flag, id, vipFlags) {
    return {
      url: id,
      header: {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1'
      },
      isDirect: true
    };
  }

  async searchContent(wd, quick, pg) {
    return { list: [] };
  }
}
""",
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
      ],
      child: MaterialApp(
        title: 'TVBox Flutter',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF121212),
        ),
        debugShowCheckedModeBanner: false,
        home: _buildLaunchPage(),
        // 完全保留你原有路由配置
        routes: {
          '/debug': (context) => const SourceDebugger(),
          '/detail': (context) => const DetailView(videoId: ''),
          '/player': (context) => const PlayerView(flag: '', id: '', title: ''),
        },
      ),
    );
  }

  // 启动页逻辑，绝对不会白屏
  Widget _buildLaunchPage() {
    // 初始化失败：显示错误提示+重试按钮
    if (_initErrorMsg != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                const SizedBox(height: 20),
                const Text(
                  '应用初始化失败',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  _initErrorMsg!,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    backgroundColor: Colors.blue,
                  ),
                  onPressed: () {
                    setState(() {
                      _initErrorMsg = null;
                    });
                    _initAppCore();
                  },
                  child: const Text('重新初始化', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 初始化中：显示加载页，绝不会白屏
    if (!_initCompleted) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 3),
              const SizedBox(height: 24),
              Text(
                _isInitRunning ? 'TVBox 初始化中...' : '准备初始化...',
                style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    // 初始化完成：进入首页，完全保留你原有逻辑
    return const HomeView();
  }
}
