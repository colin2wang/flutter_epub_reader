import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/logger_service.dart';

/// 日志窗口页面
class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  final LoggerService _loggerService = LoggerService();
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  Level? _filterLevel;

  @override
  void initState() {
    super.initState();
    // 添加监听器以实时更新UI
    _loggerService.addListener(_onLogUpdated);
  }

  @override
  void dispose() {
    _loggerService.removeListener(_onLogUpdated);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogUpdated() {
    if (mounted) {
      setState(() {});
      
      // 如果启用了自动滚动，滚动到底部
      if (_autoScroll && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  /// 获取过滤后的日志列表
  List<LogEntry> get _filteredLogs {
    final logs = _loggerService.logs;
    if (_filterLevel == null) {
      return logs;
    }
    return logs.where((log) => log.level == _filterLevel).toList();
  }

  /// 清除日志
  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有日志吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _loggerService.clearLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日志已清除')),
        );
      }
    }
  }

  /// 切换自动滚动
  void _toggleAutoScroll() {
    setState(() {
      _autoScroll = !_autoScroll;
    });
  }

  /// 设置过滤级别
  void _setFilterLevel(Level? level) {
    setState(() {
      _filterLevel = level;
    });
  }

  /// 获取日志级别的图标
  IconData _getLevelIcon(Level level) {
    switch (level) {
      case Level.debug:
        return Icons.bug_report;
      case Level.info:
        return Icons.info;
      case Level.warning:
        return Icons.warning;
      case Level.error:
      case Level.fatal:
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  /// 获取日志级别的颜色
  Color _getLevelColor(Level level) {
    switch (level) {
      case Level.debug:
        return Colors.grey;
      case Level.info:
        return Colors.blue;
      case Level.warning:
        return Colors.orange;
      case Level.error:
      case Level.fatal:
        return Colors.red;
      default:
        return Colors.black87;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _filteredLogs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('运行日志'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 自动滚动开关
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.arrow_downward : Icons.pause,
            ),
            onPressed: _toggleAutoScroll,
            tooltip: _autoScroll ? '禁用自动滚动' : '启用自动滚动',
          ),
          // 清除日志按钮
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
            tooltip: '清除日志',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
        children: [
          // 过滤栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Text('过滤:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(null, '全部'),
                        _buildFilterChip(Level.debug, '调试'),
                        _buildFilterChip(Level.info, '信息'),
                        _buildFilterChip(Level.warning, '警告'),
                        _buildFilterChip(Level.error, '错误'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 日志列表
          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notes,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filterLevel == null
                              ? '暂无日志'
                              : '没有${_getLevelText(_filterLevel!)}级别的日志',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      return _buildLogItem(log);
                    },
                  ),
          ),
          
          // 底部状态栏
          Container(
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: FutureBuilder<int>(
              future: _loggerService.getLogFileSize(),
              builder: (context, snapshot) {
                final fileSize = snapshot.data ?? 0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '共 ${filteredLogs.length} 条日志',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '日志大小: ${_loggerService.formatFileSize(fileSize)} / 10 MB',
                      style: TextStyle(
                        fontSize: 12,
                        color: fileSize > 8 * 1024 * 1024
                            ? Colors.orange
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
    );
  }

  /// 构建过滤芯片
  Widget _buildFilterChip(Level? level, String label) {
    final isSelected = _filterLevel == level;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _setFilterLevel(level),
        showCheckmark: false,
        backgroundColor: Colors.white,
        selectedColor: _getLevelColor(level ?? Level.info).withOpacity(0.2),
      ),
    );
  }

  /// 构建日志项
  Widget _buildLogItem(LogEntry log) {
    final levelColor = _getLevelColor(log.level);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 级别图标
          Icon(
            _getLevelIcon(log.level),
            size: 16,
            color: levelColor,
          ),
          const SizedBox(width: 8),
          
          // 时间戳
          SizedBox(
            width: 90,
            child: Text(
              _formatTime(log.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // 日志消息
          Expanded(
            child: SelectableText(
              log.message,
              style: TextStyle(
                fontSize: 13,
                color: log.level == Level.error || log.level == Level.fatal
                    ? Colors.red[700]
                    : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }

  /// 获取级别文本
  String _getLevelText(Level level) {
    switch (level) {
      case Level.debug:
        return '调试';
      case Level.info:
        return '信息';
      case Level.warning:
        return '警告';
      case Level.error:
      case Level.fatal:
        return '错误';
      default:
        return '信息';
    }
  }
}
