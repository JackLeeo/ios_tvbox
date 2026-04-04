import 'dart:convert';
import 'package:crypto/crypto.dart';

class StringUtils {
  // MD5加密
  static String md5Encode(String str) {
    final bytes = utf8.encode(str);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  // Base64编码
  static String base64Encode(String str) {
    final bytes = utf8.encode(str);
    return base64.encode(bytes);
  }

  // Base64解码
  static String base64Decode(String str) {
    final bytes = base64.decode(str);
    return utf8.decode(bytes);
  }

  // 过滤HTML标签
  static String stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  // 相对时间格式化
  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
