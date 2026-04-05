import 'package:flutter/foundation.dart';

class AppLogService extends ChangeNotifier {
  static final AppLogService instance = AppLogService._internal();
  AppLogService._internal();

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  void log(String msg) {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final logLine = "[$timeStr] $msg";
    _logs.add(logLine);
    if (_logs.length > 80) _logs.removeAt(0);
    notifyListeners();
    debugPrint(logLine);
  }
}
