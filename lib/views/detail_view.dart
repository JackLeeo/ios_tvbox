import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../viewmodels/detail_viewmodel.dart';
import '../core/spider_manager.dart';
import '../models/video_model.dart';
import 'player_view.dart';

class DetailView extends StatelessWidget {
  final VideoModel video;
  const DetailView({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    final spiderManager = Provider.of<SpiderManager>(context, listen: false);
    
    return ChangeNotifierProvider(
      create: (_) => DetailViewModel(spiderManager, 'default', video.id)
        ..loadDetail(),
      child: Scaffold(
        appBar: AppBar(title: Text(video.name)),
        body: Consumer<DetailViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (vm.error != null) {
              return Center(
                child: Column(
                  children: [
                    Text(vm.error!),
                    TextButton(onPressed: vm.loadDetail, child: const Text('重试')),
                  ],
                ),
              );
            }

            final detail = vm.video ?? video;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 封面与基本信息
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: detail.pic,
                          width: 120,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(detail.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            if (detail.year != null) Text('年份: ${detail.year}'),
                            if (detail.type != null) Text('类型: ${detail.type}'),
                            if (detail.area != null) Text('地区: ${detail.area}'),
                            if (detail.lang != null) Text('语言: ${detail.lang}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 简介
                  if (detail.des != null) ...[
                    const Text('简介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(detail.des!),
                    const SizedBox(height: 16),
                  ],
                  // 播放列表
                  if (detail.playFrom != null && detail.playList != null) ...[
                    const Text('播放源', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    for (int i = 0; i < detail.playFrom!.length; i++) ...[
                      Text(detail.playFrom![i], style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildPlayItems(context, detail.playList![i]),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildPlayItems(BuildContext context, List<String> items) {
    return items.map((item) {
      final parts = item.split(r'$');
      final name = parts[0];
      final id = parts.length > 1 ? parts[1] : '';
      return ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerView(flag: 'default', id: id),
            ),
          );
        },
        child: Text(name),
      );
    }).toList();
  }
}