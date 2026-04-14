import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/nodejs_engine.dart';
import '../models/category_model.dart';
import '../models/video_model.dart';

class HomeViewModel with ChangeNotifier {
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<CategoryModel> _categories = [];
  List<CategoryModel> get categories => _categories;

  List<VideoModel> _videos = [];
  List<VideoModel> get videos => _videos;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final engine = NodeJsEngine.instance;
      final dio = engine.dioClient;
      
      // 请求首页分类接口
      final catRes = await dio.get('/category');
      _categories = (catRes.data as List)
          .map((e) => CategoryModel.fromJson(e))
          .toList();
      
      // 默认加载第一个分类的视频
      if(_categories.isNotEmpty) {
        await loadCategoryVideos(0);
      }
    } catch(e) {
      debugPrint('Load home data error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategoryVideos(int index) async {
    _isLoading = true;
    _currentIndex = index;
    notifyListeners();

    try {
      final engine = NodeJsEngine.instance;
      final dio = engine.dioClient;
      final cateId = _categories[index].id;
      
      // 请求分类下的视频列表
      final res = await dio.get('/list?cate=$cateId');
      _videos = (res.data as List)
          .map((e) => VideoModel.fromJson(e))
          .toList();
    } catch(e) {
      debugPrint('Load category videos error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
