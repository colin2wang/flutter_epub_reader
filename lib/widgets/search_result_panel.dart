import 'package:flutter/material.dart';

/// 搜索结果面板组件
class SearchResultPanel extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final Function(int) onResultSelected;

  const SearchResultPanel({
    super.key,
    required this.results,
    required this.onResultSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '找到 ${results.length} 个结果',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              final chapter = result['chapter'];
              final level = result['level'] as int;
              final chapterIndex = result['index'] as int;
              
              return ListTile(
                contentPadding: EdgeInsets.only(
                  left: 16.0 + level * 16.0,
                  right: 16.0,
                ),
                title: Text(
                  chapter.Title ?? 'Chapter ${chapterIndex + 1}',
                  style: TextStyle(
                    fontSize: level == 0 ? 16 : 14,
                  ),
                ),
                subtitle: Text(
                  '点击跳转',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onResultSelected(chapterIndex);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
