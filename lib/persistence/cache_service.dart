import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ios_tvbox/models/video_model.dart';
import 'dart:convert';

class CacheService {
  static Database? _db;
  static SharedPreferences? _prefs;
  static const String _videoCacheTable = 'video_cache';

  static final CacheService instance = CacheService._internal();
  CacheService._internal();

  // 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _initDatabase();
  }

  // 初始化数据库
  Future<void> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tvbox_cache.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_videoCacheTable (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            create_time INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // 缓存视频详情（24小时有效期）
  Future<void> cacheVideoDetail(VideoModel video) async {
    if (_db == null) await _initDatabase();
    await _db?.delete(
      _videoCacheTable,
      where: 'id = ?',
      whereArgs: [video.id],
    );
    await _db?.insert(
      _videoCacheTable,
      {
        'id': video.id,
        'data': jsonEncode(video.toJson()),
        'create_time': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // 获取缓存的视频详情
  Future<VideoModel?> getVideoCache(String id) async {
    if (_db == null) await _initDatabase();
    final result = await _db?.query(
      _videoCacheTable,
      where: 'id = ? AND create_time > ?',
      whereArgs: [id, DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch],
    );

    if (result == null || result.isEmpty) return null;
    final data = result.first['data'] as String;
    return VideoModel.fromJson(jsonDecode(data));
  }

  // 清理过期缓存
  Future<void> cleanExpiredCache() async {
    if (_db == null) await _initDatabase();
    await _db?.delete(
      _videoCacheTable,
      where: 'create_time < ?',
      whereArgs: [DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch],
    );
  }

  // 存储用户配置
  Future<void> saveConfig(String key, String value) async {
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();
    await _prefs?.setString(key, value);
  }

  // 获取用户配置
  String? getConfig(String key) {
    return _prefs?.getString(key);
  }

  // 删除用户配置
  Future<void> removeConfig(String key) async {
    await _prefs?.remove(key);
  }
}
