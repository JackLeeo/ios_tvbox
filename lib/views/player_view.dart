import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../viewmodels/player_viewmodel.dart';

class PlayerView extends StatefulWidget {
  final String flag;
  final String id;
  final String title;

  const PlayerView({
    super.key,
    required this.flag,
    required this.id,
    required this.title,
  });

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  late final VideoController _videoController;

  @override
  void initState() {
    super.initState();
    final vm = Provider.of<PlayerViewModel>(context, listen: false);
    _videoController = VideoController(vm.player);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      vm.initPlay(widget.flag, widget.id);
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PlayerViewModel(),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Consumer<PlayerViewModel>(
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
                      onPressed: () => vm.initPlay(widget.flag, widget.id),
                      child: const Text("重试"),
                    ),
                  ],
                ),
              );
            }

            return SizedBox.expand(
              child: Video(
                controller: _videoController,
                controls: MaterialVideoControls,
              ),
            );
          },
        ),
      ),
    );
  }
}
