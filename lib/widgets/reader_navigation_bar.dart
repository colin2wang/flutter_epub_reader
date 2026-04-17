import 'package:flutter/material.dart';

/// 底部导航栏组件
class ReaderNavigationBar extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final bool isDarkMode;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const ReaderNavigationBar({
    super.key,
    required this.currentIndex,
    required this.totalCount,
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
            Text(
              '${currentIndex + 1} / $totalCount',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDarkMode ? Colors.grey[300] : Colors.black87,
              ),
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
