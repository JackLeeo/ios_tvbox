import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import './views/home_view.dart';
import './viewmodels/home_viewmodel.dart';
import './core/spider_manager.dart';
import './core/js_engine.dart';
import './core/python_engine.dart';
import './core/network_service.dart';
import './views/source_debugger.dart';
import './views/detail_view.dart';
import './views/player_view.dart';
import './models/spider_source.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化播放器核心
  MediaKit.ensureInitialized();

  // 初始化核心服务
  await NetworkService.instance.init();
  await JsEngine.instance.init();
  await PythonEngine.instance.init();

  // 内置默认测试源（完整无截断）
  await SpiderManager.instance.addSource(SpiderSource(
    key: "default_test",
    name: "内置测试源",
    type: 3,
    api: "",
    ext: """
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
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: const HomeView(),
        routes: {
          '/debug': (context) => const SourceDebugger(),
          '/detail': (context) => const DetailView(videoId: ''),
          '/player': (context) => const PlayerView(flag: '', id: '', title: ''),
        },
      ),
    );
  }
}
