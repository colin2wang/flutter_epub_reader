import 'package:flutter/material.dart';

/// 阅读器设置菜单组件
class ReaderSettingsMenu extends StatelessWidget {
  final double fontSize;
  final bool isDarkMode;
  final bool isFullScreen;
  final bool showBottomBar;
  final Function(double) onFontSizeChange;
  final VoidCallback onToggleDarkMode;
  final VoidCallback onToggleFullScreen;
  final VoidCallback onToggleBottomBar;
  final VoidCallback onSearch;
  final VoidCallback onShowChapterList;
  final VoidCallback onClose;

  const ReaderSettingsMenu({
    super.key,
    required this.fontSize,
    required this.isDarkMode,
    required this.isFullScreen,
    required this.showBottomBar,
    required this.onFontSizeChange,
    required this.onToggleDarkMode,
    required this.onToggleFullScreen,
    required this.onToggleBottomBar,
    required this.onSearch,
    required this.onShowChapterList,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题栏
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '阅读设置',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
                tooltip: '关闭',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 字体调整
        ListTile(
          leading: const Icon(Icons.text_fields),
          title: const Text('字体大小'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => onFontSizeChange(-2.0),
                tooltip: '减小字体',
              ),
              Text(
                '${fontSize.toInt()}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.grey[300] : Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => onFontSizeChange(2.0),
                tooltip: '增大字体',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 夜间模式
        ListTile(
          leading: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
          title: Text(isDarkMode ? '日间模式' : '夜间模式'),
          trailing: Switch(
            value: isDarkMode,
            onChanged: (value) => onToggleDarkMode(),
          ),
          onTap: onToggleDarkMode,
        ),
        const Divider(height: 1),
        // 搜索
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('搜索'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onSearch,
        ),
        const Divider(height: 1),
        // 章节列表
        ListTile(
          leading: const Icon(Icons.list),
          title: const Text('章节列表'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onShowChapterList,
        ),
        const Divider(height: 1),
        // 全屏模式
        ListTile(
          leading: Icon(isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
          title: Text(isFullScreen ? '退出全屏' : '全屏模式'),
          trailing: Switch(
            value: isFullScreen,
            onChanged: (value) => onToggleFullScreen(),
          ),
          onTap: onToggleFullScreen,
        ),
        const Divider(height: 1),
        // 底部导航栏显示开关
        ListTile(
          leading: const Icon(Icons.view_agenda),
          title: const Text('底部导航栏'),
          subtitle: const Text(
            '显示页码和方向键',
            style: TextStyle(fontSize: 12),
          ),
          trailing: Switch(
            value: showBottomBar,
            onChanged: (value) => onToggleBottomBar(),
          ),
          onTap: onToggleBottomBar,
        ),
      ],
    );
  }
}
