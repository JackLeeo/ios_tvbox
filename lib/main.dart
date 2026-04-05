import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// 【修复】导入dart:ui，PlatformDispatcher定义在此文件中
import 'dart:ui';
import 'package:provider/provider.dart';
import './views/home_view.dart';
import './viewmodels/home_viewmodel.dart';
import './views/source_debugger.dart';
import './views/detail_view.dart';
import './views/player_view.dart';

void main() {
  // 第一行仅初始化Flutter引擎绑定，无任何其他阻塞操作
  WidgetsFlutterBinding.ensureInitialized();

  // 全局异常捕获，兜底所有异常，避免白屏
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('=== Flutter框架异常 ===');
    debugPrint('异常内容：${details.exception}');
    debugPrint('异常堆栈：${details.stack}');
  };

  // 全局平台异常捕获
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('=== 全局运行异常 ===');
    debugPrint('异常内容：$error');
    debugPrint('异常堆栈：$stack');
    return true;
  };

  // 默认竖屏，支持横竖屏切换，适配手机端
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 【核心修复】启动时绝对不初始化任何原生引擎（media_kit、JS引擎等）
  // 所有耗时初始化全延后，完全不阻塞UI渲染

  // 立即启动App，无任何阻塞操作
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
        home: const HomeView(),
        // 完整保留你所有的路由配置
        routes: {
          '/debug': (context) => const SourceDebugger(),
          '/detail': (context) => const DetailView(videoId: ''),
          '/player': (context) => const PlayerView(flag: '', id: '', title: ''),
        },
      ),
    );
  }
}
