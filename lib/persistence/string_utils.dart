import 'dart:convert';
import 'package:crypto/crypto.dart';

class StringUtils {
  // MD5加密
  static String md5(String input) {
    final bytes = utf8.encode(input);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  // Base64编码
  static String base64Encode(String input) {
    return base64.encode(utf8.encode(input));
  }

  // Base64解码
  static String? base64Decode(String input) {
    try {
      // 补全padding
      final padLength = (4 - input.length % 4) % 4;
      input = input.padRight(input.length + padLength, '=');
      final bytes = base64.decode(input);
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  // 移除HTML标签
  static String removeHtmlTag(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  // 截断字符串
  static String truncate(String str, int maxLength) {
    if (str.length <= maxLength) return str;
    return '${str.substring(0, maxLength)}...';
  }
}