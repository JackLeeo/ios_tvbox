import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/home_viewmodel.dart';
import '../core/log_service.dart';
import '../models/video_model.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text("TVBox")),
      body: Stack(
        children: [
          // 主内容区域
          vm.loading
              ? const Center(child: CircularProgressIndicator())
              : vm.error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          vm.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: vm.videoList.length,
                      itemBuilder: (ctx, i) {
                        final item = vm.videoList[i];
                        return Card(
                          clipBehavior: Clip.hardEdge,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Image.network(
                                  item.pic ?? '',
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: Text(
                                  item.title ?? '',
                                  maxLines: 1,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          // 日志悬浮面板
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 160,
            child: Container(
              color: Colors.black.withValues(alpha: 0.9), // 修复弃用API
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "JS执行日志",
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => AppLogService.instance.clear(),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 20)),
                        child: const Text("清空", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.grey, height: 1),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: AppLogService.instance,
                      builder: (_, __) {
                        final logs = AppLogService.instance.logs;
                        return ListView.builder(
                          reverse: true,
                          itemCount: logs.length,
                          itemBuilder: (_, idx) {
                            final line = logs[logs.length - 1 - idx];
                            return Text(
                              line,
                              style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
