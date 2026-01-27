import 'package:flutter/material.dart';

/// Log entry for the result log
class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;
  final String? category;

  LogEntry({
    required this.message,
    this.level = LogLevel.info,
    this.category,
  }) : timestamp = DateTime.now();

  Color get color => switch (level) {
        LogLevel.info => Colors.white70,
        LogLevel.success => Colors.green,
        LogLevel.warning => Colors.orange,
        LogLevel.error => Colors.red,
      };

  IconData get icon => switch (level) {
        LogLevel.info => Icons.info_outline,
        LogLevel.success => Icons.check_circle_outline,
        LogLevel.warning => Icons.warning_amber_outlined,
        LogLevel.error => Icons.error_outline,
      };
}

enum LogLevel { info, success, warning, error }

/// Global log controller
class LogController extends ChangeNotifier {
  final List<LogEntry> _entries = [];
  final int maxEntries;

  LogController({this.maxEntries = 100});

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void log(String message, {LogLevel level = LogLevel.info, String? category}) {
    _entries.insert(0, LogEntry(message: message, level: level, category: category));
    if (_entries.length > maxEntries) {
      _entries.removeLast();
    }
    notifyListeners();
  }

  void info(String message, {String? category}) =>
      log(message, level: LogLevel.info, category: category);

  void success(String message, {String? category}) =>
      log(message, level: LogLevel.success, category: category);

  void warning(String message, {String? category}) =>
      log(message, level: LogLevel.warning, category: category);

  void error(String message, {String? category}) =>
      log(message, level: LogLevel.error, category: category);

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
