import 'package:intl/intl.dart';

class DateUtils {
  static final DateFormat _defaultFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  // 格式化日期
  static String format(DateTime date, {String? pattern}) {
    if (pattern != null) {
      return DateFormat(pattern).format(date);
    }
    return _defaultFormat.format(date);
  }

  // 解析日期字符串
  static DateTime? parse(String str, {String? pattern}) {
    try {
      if (pattern != null) {
        return DateFormat(pattern).parse(str);
      }
      return _defaultFormat.parse(str);
    } catch (_) {
      return null;
    }
  }

  // 相对时间
  static String relativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return format(date, pattern: 'MM-dd');
    }
  }
}