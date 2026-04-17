import 'package:epubx/epubx.dart' hide Image;

import '../models/flat_chapter.dart';

/// 搜索服务 - 处理 EPUB 内容的搜索功能
class SearchService {
  /// 在所有章节中搜索文本
  static List<Map<String, dynamic>> searchInChapters(
    String query,
    List<FlatChapter> flatChapters,
  ) {
    if (query.isEmpty) return [];
    
    List<Map<String, dynamic>> results = [];
    
    for (int i = 0; i < flatChapters.length; i++) {
      final chapter = flatChapters[i].chapter;
      final content = chapter.HtmlContent ?? '';
      
      // 简单的文本搜索（不区分大小写）
      if (content.toLowerCase().contains(query.toLowerCase())) {
        // 找到匹配的章节
        results.add({
          'index': i,
          'chapter': chapter,
          'level': flatChapters[i].level,
        });
      }
    }
    
    return results;
  }
}
