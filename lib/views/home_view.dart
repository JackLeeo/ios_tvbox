import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/home_viewmodel.dart';
import './source_debugger.dart';
import './detail_view.dart';
import '../core/spider_manager.dart';
import '../models/spider_source.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _isInitDone = false;

  @override
  void initState() {
    super.initState();
    // 首帧渲染完成后，再做初始化，完全不阻塞UI显示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAppData();
    });
  }

  /// 首帧渲染完成后，再初始化数据，绝不阻塞启动
  Future<void> _initAppData() async {
    if (_isInitDone) return;
    try {
      // 初始化基础服务
      await SpiderManager.instance.init();
      // 添加内置测试源
      await _addDefaultTestSource();
      // 加载首页数据
      if (mounted) {
        await Provider.of<HomeViewModel>(context, listen: false).loadHomeData();
      }
      _isInitDone = true;
    } catch (e) {
      debugPrint('首页初始化失败：$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化失败：${e.toString()}')),
        );
      }
    }
  }

  /// 内置测试源，完全保留你原有逻辑
  Future<void> _addDefaultTestSource() async {
    if (SpiderManager.instance.hasSource) return;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("TVBox Flutter"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SourceDebugger()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => Provider.of<HomeViewModel>(context, listen: false).refresh(),
        child: Consumer<HomeViewModel>(
          builder: (context, vm, child) {
            // 加载中
            if (vm.isLoading && vm.videoList.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // 加载失败
            if (vm.errorMessage != null && vm.videoList.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(vm.errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: vm.loadHomeData,
                      child: const Text("重试"),
                    ),
                  ],
                ),
              );
            }

            // 视频列表
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width ~/ 180,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: vm.videoList.length,
              itemBuilder: (context, index) {
                final video = vm.videoList[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailView(videoId: video.id),
                      ),
                    );
                  },
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            child: Image.network(
                              video.pic,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(child: Icon(Icons.broken_image, size: 40));
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                video.remark,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
