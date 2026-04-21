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
    for (int i = 0; i < chapters.length; i++) {
      try {
        _logger.debug('章节 $i: ${chapters[i].Title}, 内容长度: ${chapters[i].HtmlContent?.length ?? 0}');
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
      flatList.add(FlatChapter(
        chapter: chapter,
        index: flatList.length,
        level: level,
      ));
      
      // 递归处理子章节
      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        _flattenChapters(chapter.SubChapters!, flatList, level: level + 1);
      }
    }
  }
}
