import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// 日志条目
class LogEntry {
  final DateTime timestamp;
  final Level level;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  @override
  String toString() {
    final levelStr = level.toString().split('.').last.toUpperCase();
    final timeStr = timestamp.toIso8601String().substring(11, 23);
    return '[$timeStr] [$levelStr] $message';
  }
}

/// 日志服务 - 单例模式
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  static const int maxQueueSize = 10000; // FIFO队列最大容量

  // FIFO队列用于缓存日志
  final Queue<LogEntry> _logQueue = Queue<LogEntry>();
  
  // Logger实例
  late Logger _logger;
  File? _logFile;
  
  // 监听器列表，用于实时更新UI
  final List<void Function()> _listeners = [];
  
  bool _initialized = false;

  /// 获取所有日志（从新到旧）
  List<LogEntry> get logs => _logQueue.toList().reversed.toList();
  
  /// 获取队列大小
  int get queueSize => _logQueue.length;

  /// 添加监听器
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  /// 通知所有监听器
  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        print('通知监听器失败: $e');
      }
    }
  }

  /// 初始化日志服务
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      _logFile = File('${logDir.path}/app_log.txt');
      
      // 配置Logger
      _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 0, // 不显示方法调用栈
          errorMethodCount: 3, // 错误时显示3层调用栈
          lineLength: 120,
          colors: true,
          printEmojis: true,
          dateTimeFormat: DateTimeFormat.dateAndTime,
        ),
        output: _buildFileOutput(),
        level: Level.debug,
      );
      
      _initialized = true;
      info('日志服务初始化完成');
    } catch (e) {
      print('日志服务初始化失败: $e');
    }
  }
  
  /// 构建文件输出
  MultiOutput _buildFileOutput() {
    return MultiOutput([
      ConsoleOutput(), // 控制台输出
      FileOutput(file: _logFile ?? File('')),
    ]);
  }



  /// 添加日志到FIFO队列
  void _addLogToQueue(Level level, String message) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
    );

    // 添加到队列尾部
    _logQueue.addLast(entry);
    
    // FIFO: 如果超过最大容量，移除最旧的日志
    while (_logQueue.length > maxQueueSize) {
      _logQueue.removeFirst();
    }

    // 通知监听器
    _notifyListeners();
  }

  /// 记录调试日志
  void debug(String message) {
    _addLogToQueue(Level.debug, message);
    _logger.d(message);
  }

  /// 记录信息日志
  void info(String message) {
    _addLogToQueue(Level.info, message);
    _logger.i(message);
  }

  /// 记录警告日志
  void warning(String message) {
    _addLogToQueue(Level.warning, message);
    _logger.w(message);
  }

  /// 记录错误日志
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _addLogToQueue(Level.error, message);
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// 清除所有日志
  Future<void> clearLogs() async {
    _logQueue.clear();
    
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
    
    _notifyListeners();
  }


}
