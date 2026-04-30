import 'dart:typed_data';

import 'package:epubx/epubx.dart' hide Image;

import '../models/flat_chapter.dart';
import 'logger_service.dart';

/// EPUB 解析服务
class EpubParserService {
  static final LoggerService _logger = LoggerService();
  
  /// 解析 EPUB 文件并返回扁平化的章节列表和书籍对象
  static Future<Map<String, dynamic>> parseEpub(Uint8List epubBytes) async {
    _logger.info('开始解析 EPUB 文件...');
    _logger.debug('文件大小: ${epubBytes.length} bytes');
    
    // 验证文件数据
    if (epubBytes.isEmpty) {
      throw Exception('文件内容为空');
    }
    
    // 检查文件头是否为有效的 ZIP/EPUB 格式
    if (epubBytes.length < 4) {
      throw Exception('文件格式无效：文件太小');
    }
    
    EpubBook book = await EpubReader.readBook(epubBytes);
    
    _logger.info('EPUB 解析成功');
    _logger.info('书名: ${book.Title}');
    _logger.debug('作者: ${book.Author}');
    _logger.info('章节数: ${book.Chapters?.length ?? 0}');
    if (book.Content?.Images != null) {
      _logger.debug('图片数: ${book.Content!.Images!.length}');
    }
    
    if (book.Chapters == null || book.Chapters!.isEmpty) {
      // 尝试从 Content 中获取内容
      _logger.warning('Chapters 为空,尝试从 Content 中读取...');
      if (book.Content != null && book.Content!.Html != null) {
        _logger.debug('HTML 文件数: ${book.Content!.Html!.length}');
        // 如果有 HTML 文件但没有 Chapters，尝试从 HTML 文件创建章节
        if (book.Content!.Html!.isNotEmpty) {
          _logger.info('使用 HTML 文件作为章节');
        }
      }
      throw Exception('该 EPUB 文件没有可识别的章节内容,可能是格式不兼容或文件损坏');
    }
    
    List<EpubChapter> chapters = book.Chapters!;
    
    // 打印章节信息用于调试
    _logger.info('原始章节数: ${chapters.length}');
    for (int i = 0; i < chapters.length; i++) {
      try {
        final anchor = chapters[i].Anchor ?? 'N/A';
        final isSplit = anchor.contains('_split_') || anchor.contains('_part_');
        _logger.debug('章节 $i: ${chapters[i].Title}, Anchor: $anchor, 内容长度: ${chapters[i].HtmlContent?.length ?? 0}${isSplit ? " [SPLIT]" : ""}');
        _printSubChapters(chapters[i], level: 1);
      } catch (e) {
        _logger.error('处理章节 $i 时出错: $e');
      }
    }
    
    // 创建扁平化的章节列表
    List<FlatChapter> flatChapters = [];
    try {
      _flattenChapters(chapters, flatChapters);
    } catch (e) {
      _logger.error('扁平化章节时出错: $e');
      throw Exception('处理章节结构失败: $e');
    }
    
    _logger.info('扁平化后章节总数: ${flatChapters.length}');
    
    // 统计分割文件信息
    int splitFileCount = 0;
    Map<String, int> splitGroups = {};
    for (final flatChapter in flatChapters) {
      if (_isSplitChapter(flatChapter.chapter)) {
        splitFileCount++;
        final groupId = _getSplitGroupId(flatChapter.chapter);
        if (groupId != null) {
          splitGroups[groupId] = (splitGroups[groupId] ?? 0) + 1;
        }
      }
    }
    
    if (splitFileCount > 0) {
      _logger.info('📄 检测到 $splitFileCount 个分割文件，分布在 ${splitGroups.length} 个章节组中');
      splitGroups.forEach((groupId, count) {
        _logger.debug('  - $groupId: $count 个 XHTML 文件');
      });
      _logger.info('✅ 翻页将按 XHTML 页面为准，总计 ${flatChapters.length} 页');
    } else {
      _logger.info('✅ 未检测到分割文件，总计 ${flatChapters.length} 页');
    }
    
    if (flatChapters.isEmpty) {
      throw Exception('没有可用的章节内容');
    }
    
    return {
      'book': book,
      'flatChapters': flatChapters,
    };
  }
  
  /// 递归打印子章节
  static void _printSubChapters(EpubChapter chapter, {required int level}) {
    if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
      for (var subChapter in chapter.SubChapters!) {
        _logger.debug('${'  ' * level}子章节: ${subChapter.Title}, 内容长度: ${subChapter.HtmlContent?.length ?? 0}');
        _printSubChapters(subChapter, level: level + 1);
      }
    }
  }
  
  /// 将嵌套的章节结构扁平化
  static void _flattenChapters(List<EpubChapter> chapters, List<FlatChapter> flatList, {int level = 0}) {
    for (var chapter in chapters) {
      // 检查章节是否有实质内容
      final content = chapter.HtmlContent ?? '';
      // 移除 HTML 标签后检查是否有文本内容
      final textContent = _stripHtmlTags(content);
      final hasContent = textContent.trim().isNotEmpty;
      final hasSubChapters = chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty;
      
      // 获取 Anchor 信息用于调试
      final anchor = chapter.Anchor ?? 'N/A';
      final isSplit = anchor.contains('_split_') || anchor.contains('_part_');
      
      _logger.debug('扁平化处理: "${chapter.Title}" - Anchor: $anchor, 原始长度: ${content.length}, 文本长度: ${textContent.length}, 有子章节: $hasSubChapters${isSplit ? " [SPLIT]" : ""}');
      
      // 只添加有内容或有子章节的章节
      if (hasContent || hasSubChapters) {
        flatList.add(FlatChapter(
          chapter: chapter,
          index: flatList.length,
          level: level,
        ));
        
        if (!hasContent && hasSubChapters) {
          _logger.debug('✓ 章节 "${chapter.Title}" 无文本内容，但有 ${chapter.SubChapters!.length} 个子章节，保留作为容器');
        } else if (hasContent) {
          final splitTag = isSplit ? ' [SPLIT]' : '';
          _logger.debug('✓ 章节 "${chapter.Title}" 有内容，已添加$splitTag');
        }
      } else {
        _logger.debug('✗ 跳过空章节: "${chapter.Title}" (Anchor: $anchor, 原始长度: ${content.length}, 文本长度: ${textContent.length})');
      }
      
      // 递归处理子章节
      if (hasSubChapters) {
        _flattenChapters(chapter.SubChapters!, flatList, level: level + 1);
      }
    }
  }
  
  /// 检查章节是否是分割文件的一部分
  static bool _isSplitChapter(EpubChapter chapter) {
    final anchor = chapter.Anchor ?? '';
    return anchor.contains('_split_') || anchor.contains('_part_');
  }
  
  /// 获取分割文件的组ID（例如 part0009_split_000.html -> part0009）
  static String? _getSplitGroupId(EpubChapter chapter) {
    final anchor = chapter.Anchor ?? '';
    if (!anchor.contains('_split_')) return null;
    
    // 提取 split 前的部分，如 "part0009_split_000.html" -> "part0009"
    final match = RegExp(r'(part\d+)_split_').firstMatch(anchor);
    return match?.group(1);
  }
  
  /// 移除 HTML 标签，提取纯文本
  static String _stripHtmlTags(String html) {
    if (html.isEmpty) return '';
    
    // 简单的 HTML 标签移除（适用于大多数情况）
    String text = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    
    // 解码常见的 HTML 实体
    text = text.replaceAll('&nbsp;', ' ')
               .replaceAll('&lt;', '<')
               .replaceAll('&gt;', '>')
               .replaceAll('&amp;', '&')
               .replaceAll('&quot;', '"')
               .replaceAll('&#39;', "'");
    
    // 移除多余的空白
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return text;
  }
}
