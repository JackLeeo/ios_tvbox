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

// 全局异常捕获：彻底解决Release模式下异常导致的白屏/崩溃
void main() {
  // 第一行必须初始化Flutter引擎绑定，核心修复白屏基础
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

  // 强制横屏：适配TVBox播放场景，避免屏幕方向错乱导致的渲染异常
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 初始化播放器核心（同步初始化，无阻塞，media_kit官方要求）
  MediaKit.ensureInitialized();

  // 先启动App渲染，再异步执行初始化，彻底解决主线程阻塞白屏
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 初始化状态管理，避免启动白屏
  bool _initCompleted = false;
  String? _initErrorMsg;

  @override
  void initState() {
    super.initState();
    // 首帧渲染完成后，再执行耗时初始化，完全不阻塞UI渲染
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAppCore();
    });
  }

  // 核心服务异步初始化，完全保留你原有初始化逻辑
  Future<void> _initAppCore() async {
    try {
      // 串行初始化核心服务，避免并发初始化导致的内存溢出/异常
      await NetworkService.instance.init();
      await JsEngine.instance.init();

      // 完全保留你原有内置测试源，仅修复JS脚本兼容+链接报错问题
      await SpiderManager.instance.addSource(const SpiderSource(
        key: "default_test",
        name: "内置测试源",
        type: 3,
        api: "",
        // 修复1：补充CatVodSpider基类定义，解决JS执行失败导致的解析报错
        // 修复2：补充播放请求User-Agent，解决CDN拦截导致的link fetch error
        // 修复3：规范字段匹配，解决图片链接被错误解析导致的网页解析失败
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
          vod_id: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          vod_name: '测试视频-大兔子邦尼',
          vod_pic: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Big_buck_bunny_poster_big.jpg/800px-Big_buck_bunny_poster_big.jpg',
          vod_remarks: '测试视频',
          vod_year: '2008',
          vod_area: '美国',
          vod_lang: '英语',
          vod_content: '这是一个开源测试视频，用于验证播放器功能'
        },
        {
          vod_id: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
          vod_name: '大象之梦',
          vod_pic: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/07/ElephantsDream.jpg/800px-ElephantsDream.jpg',
          vod_remarks: '测试视频',
          vod_year: '2006',
          vod_area: '荷兰',
          vod_lang: '英语',
          vod_content: '世界上第一部开源电影'
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

      // 初始化完成，刷新UI进入首页
      if (mounted) {
        setState(() {
          _initCompleted = true;
          _initErrorMsg = null;
        });
      }
    } catch (e, stack) {
      // 异常兜底：初始化失败也不会白屏，显示错误提示+重试按钮
      debugPrint('App初始化失败：$e');
      debugPrint('初始化失败堆栈：$stack');
      if (mounted) {
        setState(() {
          _initErrorMsg = e.toString();
        });
      }
    }
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
        // 核心修复：启动页状态管理，彻底避免初始化过程中白屏
        home: _buildLaunchPage(),
        // 完全保留你原有路由配置，补全语法闭合
        routes: {
          '/debug': (context) => const SourceDebugger(),
          '/detail': (context) => const DetailView(videoId: ''),
          '/player': (context) => const PlayerView(flag: '', id: '', title: ''),
        },
      ),
    );
  }

  // 启动页：根据初始化状态显示对应页面，彻底解决白屏
  Widget _buildLaunchPage() {
    // 初始化失败：显示错误提示+重试按钮，不会白屏
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

    // 初始化中：显示加载页，不会白屏
    if (!_initCompleted) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 3),
              SizedBox(height: 24),
              Text(
                'TVBox 初始化中...',
                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
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
