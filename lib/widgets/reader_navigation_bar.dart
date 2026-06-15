import 'package:flutter/material.dart';

/// 底部导航栏组件 - 显示页码和翻页方向键
class ReaderNavigationBar extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final bool isDarkMode;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const ReaderNavigationBar({
    super.key,
    required this.currentIndex,
    required this.totalCount,
    this.currentPage = 0,
    this.totalPages = 1,
    required this.isDarkMode,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onPrevious,
              tooltip: '上一章',
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '第 ${currentIndex + 1} 章 / 共 $totalCount 章',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDarkMode ? Colors.grey[400] : Colors.black54,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '第 ${currentPage + 1} / $totalPages 页',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? Colors.grey[300] : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: onNext,
              tooltip: '下一章',
            ),
          ],
        ),
      ),
    );
  }
}
