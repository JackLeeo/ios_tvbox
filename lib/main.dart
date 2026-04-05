import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import './views/home_view.dart';
import './viewmodels/home_viewmodel.dart';
import './views/source_debugger.dart';
import './views/detail_view.dart';
import './views/player_view.dart';

void main() {
  // 第一行必须初始化引擎绑定
  WidgetsFlutterBinding.ensureInitialized();

  // 全局异常捕获，兜底所有异常
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('=== Flutter框架异常 ===');
    debugPrint('异常内容：${details.exception}');
    debugPrint('异常堆栈：${details.stack}');
  };

  // 默认竖屏，支持横竖屏切换，适配手机端
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 仅初始化无阻塞的播放器核心，其他所有功能全延后
  MediaKit.ensureInitialized();

  // 立即启动App，绝对不阻塞渲染
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 仅注册Provider，不做任何初始化操作
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
        // 直接显示首页，无任何前置加载逻辑
        home: const HomeView(),
        // 保留你所有的路由配置
        routes: {
          '/debug': (context) => const SourceDebugger(),
          '/detail': (context) => const DetailView(videoId: ''),
          '/player': (context) => const PlayerView(flag: '', id: '', title: ''),
        },
      ),
    );
  }
}
