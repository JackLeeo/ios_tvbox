import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../viewmodels/player_viewmodel.dart';
import '../core/spider_manager.dart';

class PlayerView extends StatelessWidget {
  final String flag;
  final String id;
  const PlayerView({super.key, required this.flag, required this.id});

  @override
  Widget build(BuildContext context) {
    final spiderManager = Provider.of<SpiderManager>(context, listen: false);
    
    return ChangeNotifierProvider(
      create: (_) => PlayerViewModel(spiderManager, 'default')
        ..loadPlayUrl(flag, id, []),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<PlayerViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            if (vm.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(vm.error!, style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => vm.loadPlayUrl(flag, id, []),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            }

            return Video(
              controller: VideoController(vm.player),
              controls: MaterialVideoControls, // 内置全屏、进度、音量控制
              fit: BoxFit.contain,
            );
          },
        ),
      ),
    );
  }
}