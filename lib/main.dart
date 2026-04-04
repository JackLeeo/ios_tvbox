import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/spider_manager.dart';
import 'viewmodels/home_viewmodel.dart';
import 'views/home_view.dart';
import 'views/source_debugger.dart';
import 'views/detail_view.dart';
import 'views/player_view.dart';
import 'models/video_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 初始化Flutter绑定（异步操作必需）
  
  // 初始化爬虫管理器（核心引擎）
  final SpiderManager spiderManager = SpiderManager();
  await spiderManager.init(); // 启动JS/Python引擎
  
  // 运行应用（MultiProvider包裹全局状态）
  runApp(
    MultiProvider(
      providers: [
        Provider<SpiderManager>.value(value: spiderManager), // 全局爬虫管理器
        ChangeNotifierProvider(create: (ctx) => HomeViewModel(spiderManager)), // 首页状态
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TVBox Flutter',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const HomeView(), // 首页
        '/debug': (ctx) => const SourceDebuggerView(), // 源调试工具
        '/detail': (ctx) => DetailView(video: ModalRoute.of(ctx)!.settings.arguments as VideoModel), // 详情页（传参）
        '/player': (ctx) => PlayerView(
              flag: ModalRoute.of(ctx)!.settings.arguments['flag'] as String,
              id: ModalRoute.of(ctx)!.settings.arguments['id'] as String,
            ), // 播放页（传参）
      },
    );
  }
}