import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/detail_viewmodel.dart';
import './player_view.dart';

class DetailView extends StatefulWidget {
  final String videoId;

  const DetailView({super.key, required this.videoId});

  @override
  State<DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<DetailView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DetailViewModel>(context, listen: false).loadDetail(widget.videoId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DetailViewModel(),
      child: Scaffold(
        appBar: AppBar(title: const Text("视频详情")),
        body: Consumer<DetailViewModel>(
          builder: (context, vm, child) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (vm.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(vm.errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => vm.loadDetail(widget.videoId),
                      child: const Text("重试"),
                    ),
                  ],
                ),
              );
            }

            if (vm.videoDetail == null) {
              return const Center(child: Text("暂无数据"));
            }

            final video = vm.videoDetail!;
            final playFrom = video.playFrom ?? <String>[];
            final playList = video.playUrl ?? <List<String>>[];
            
            // 核心修复：删掉无用空合并，直接安全判断，消除警告
            List<String> currentPlayList = [];
            if (playFrom.isNotEmpty && vm.currentFromIndex >= 0 && playList.length > vm.currentFromIndex) {
              currentPlayList = playList[vm.currentFromIndex];
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          video.pic,
                          width: 120,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox(
                              width: 120,
                              height: 180,
                              child: Icon(Icons.broken_image, size: 40),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video.name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text("年份：${video.year ?? '未知'}"),
                            Text("地区：${video.area ?? '未知'}"),
                            Text("语言：${video.lang ?? '未知'}"),
                            Text("状态：${video.remarks ?? '未知'}"),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "剧情简介",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // 【修复116行2个空安全错误】先判断非空，再加?.isNotEmpty，兜底空字符串
                  Text(
                    (video.content?.isNotEmpty ?? false) ? video.content! : "暂无简介",
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  if (playFrom.isNotEmpty)
                    const Text(
                      "播放线路",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  if (playFrom.isNotEmpty) const SizedBox(height: 8),
                  if (playFrom.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(playFrom.length, (index) {
                          final isSelected = index == vm.currentFromIndex;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected ? Colors.blue : Colors.grey[800],
                              ),
                              onPressed: () => vm.changePlayFrom(index),
                              child: Text(playFrom[index]),
                            ),
                          );
                        }),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (currentPlayList.isNotEmpty)
                    const Text(
                      "播放集数",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  if (currentPlayList.isNotEmpty) const SizedBox(height: 8),
                  if (currentPlayList.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(currentPlayList.length, (index) {
                        final item = currentPlayList[index].split(r'$');
                        final title = item.first;
                        final url = item.length > 1 ? item.last : item.first;
                        return ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlayerView(
                                  flag: playFrom[vm.currentFromIndex],
                                  id: url,
                                  title: title,
                                ),
                              ),
                            );
                          },
                          child: Text(title),
                        );
                      }),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
