import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';

class CacheService {
  static Database? _db;
  static SharedPreferences? _prefs;

  // 初始化
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    // 初始化数据库
    _db = await openDatabase(
      join(await getDatabasesPath(), 'tvbox_cache.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE videos(id TEXT PRIMARY KEY, data TEXT, timestamp INTEGER)',
        );
      },
      version: 1,
    );
  }

  // 缓存视频详情
  static Future<void> cacheVideo(VideoModel video) async {
    final data = {
      'id': video.id,
      // 使用JSON序列化存储，避免toString导致的解析错误
      'data': jsonEncode(video.toJson()),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await _db?.insert(
      'videos',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 获取缓存的视频
  static Future<VideoModel?> getCachedVideo(String id) async {
    final maps = await _db?.query(
      'videos',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps != null && maps.isNotEmpty) {
      // 检查缓存有效期（24小时）
      final timestamp = maps.first['timestamp'] as int;
      if (DateTime.now().millisecondsSinceEpoch - timestamp > 24 * 60 * 60 * 1000) {
        return null;
      }
      // 正确解析JSON数据
      final dataJson = maps.first['data'] as String;
      final dataMap = jsonDecode(dataJson) as Map<String, dynamic>;
      return VideoModel.fromJson(dataMap);
    }
    return null;
  }

  // 保存用户配置
  static Future<void> saveConfig(String key, dynamic value) async {
    if (value is String) {
      await _prefs?.setString(key, value);
    } else if (value is bool) {
      await _prefs?.setBool(key, value);
    } else if (value is int) {
      await _prefs?.setInt(key, value);
    } else if (value is Map) {
      await _prefs?.setString(key, jsonEncode(value));
    }
  }

  // 获取用户配置
  static T? getConfig<T>(String key) {
    if (T == Map) {
      final str = _prefs?.getString(key);
      if (str != null) {
        return jsonDecode(str) as T?;
      }
      return null;
    }
    return _prefs?.get(key) as T?;
  }
}