import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  // 第一行必须初始化引擎绑定
  WidgetsFlutterBinding.ensureInitialized();

  // 全局异常捕获，兜底所有异常
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('=== Flutter框架异常 ===');
    debugPrint('异常内容：${details.exception}');
    debugPrint('异常堆栈：${details.stack}');
  };

  // 【修正】默认竖屏，支持横竖屏切换，完全适配手机端
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 立即启动App，无任何阻塞初始化
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TVBox Flutter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      debugShowCheckedModeBanner: false,
      home: const TestHomePage(),
    );
  }
}

// 极简测试首页，无任何复杂依赖
class TestHomePage extends StatelessWidget {
  const TestHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("TVBox 渲染测试")),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 80),
            SizedBox(height: 20),
            Text(
              "✅ 安全基础版渲染正常！",
              style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "如果能看到这段文字，说明竖屏配置完全正常，无白屏问题",
              style: TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
