import 'package:flutter/material.dart';

import '../models/flat_chapter.dart';

/// 章节列表面板组件
class ChapterListPanel extends StatelessWidget {
  final List<FlatChapter> flatChapters;
  final int currentChapterIndex;
  final Function(int) onChapterSelected;

  const ChapterListPanel({
    super.key,
    required this.flatChapters,
    required this.currentChapterIndex,
    required this.onChapterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: flatChapters.length,
      itemBuilder: (context, index) {
        final flatChapter = flatChapters[index];
        final chapter = flatChapter.chapter;
        final level = flatChapter.level;
        
        return ListTile(
          contentPadding: EdgeInsets.only(
            left: 16.0 + level * 16.0, // 根据层级缩进
            right: 16.0,
          ),
          title: Row(
            children: [
              if (level > 0)
                Icon(
                  Icons.arrow_right,
                  size: 16,
                  color: Colors.grey,
                ),
              Expanded(
                child: Text(
                  chapter.Title ?? 'Chapter ${index + 1}',
                  style: TextStyle(
                    color: index == currentChapterIndex
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    fontWeight: index == currentChapterIndex
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: level == 0 ? 16 : 14, // 子章节字体稍小
                  ),
                ),
              ),
            ],
          ),
          onTap: () {
            Navigator.pop(context);
            onChapterSelected(index);
          },
        );
      },
    );
  }
}
