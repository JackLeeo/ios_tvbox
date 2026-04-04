import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ios_tvbox/views/home_view.dart';
import 'package:ios_tvbox/viewmodels/home_viewmodel.dart';
import 'package:ios_tvbox/core/spider_manager.dart';
import 'package:ios_tvbox/core/js_engine.dart';
import 'package:ios_tvbox/core/python_engine.dart';
import 'package:ios_tvbox/views/source_debugger.dart';
import 'package:ios_tvbox/views/detail_view.dart';
import 'package:ios_tvbox/views/player_view.dart';
import 'package:ios_tvbox/models/spider_source.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化引擎
  await JsEngine.instance.init();
  await PythonEngine.instance.init();

  // 内置默认测试源，保障首次启动可正常运行
  await SpiderManager.instance.addSource(SpiderSource(
    key: "test_source",
    name: "测试源",
    type: 3,
    api: "",
    ext: """
class MySpider extends CatVodSpider {
  async homeContent(filter) {
    return {
      list: [
        {
          id: '1',
          name: '测试视频1',
          pic: 'https://via.placeholder.com/300x400',
          remark: '测试'
        },
        {
          id: '2',
          name: '测试视频2',
          pic: 'https://via.placeholder.com/300x400',
          remark: '测试'
        }
      ]
    };
  }
  async detailContent(ids) {
    return {
      list: [
        {
          vod_name: '测试视频',
          vod_pic: 'https://via.placeholder.com/300x400',
          vod_content: '这是一个测试视频',
          vod_play_from: ['测试线路'],
          vod_play_url: ['测试$https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4']
        }
      ]
    };
  }
  async playerContent(flag, id, vipFlags) {
    return {
      url: id,
      header: {}
    };
  }
}
""",
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        ),
        home: const HomeView(),
        routes: {
          '/debug': (context) => const SourceDebugger(),
          '/detail': (context) => const DetailView(),
          '/player': (context) => const PlayerView(),
        },
      ),
    );
  }
}
