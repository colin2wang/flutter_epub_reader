import 'dart:typed_data';

import 'package:epubx/epubx.dart' hide Image;
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;

import '../code_block_widget.dart';

/// 阅读器内容组件 - 显示 EPUB 章节内容
class ReaderContent extends StatelessWidget {
  final EpubChapter? chapter;
  final double fontSize;
  final bool isDarkMode;
  final EpubBook? epubBook;

  const ReaderContent({
    super.key,
    required this.chapter,
    required this.fontSize,
    required this.isDarkMode,
    required this.epubBook,
  });

  @override
  Widget build(BuildContext context) {
    if (chapter == null) {
      return const Center(child: Text('没有内容'));
    }

    String? content = chapter!.HtmlContent;

    if (content == null || content.isEmpty) {
      return const Center(child: Text('章节内容为空'));
    }

    return Container(
      color: isDarkMode ? Colors.grey[900] : Colors.white,
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: HtmlWidget(
          content,
          customWidgetBuilder: (element) {
            // 处理代码块
            if (element.localName == 'pre') {
              return CodeBlockWidget(element: element);
            }
            // 处理图片
            if (element.localName == 'img') {
              return _buildEpubImage(element);
            }
            return null;
          },
          textStyle: TextStyle(
            fontSize: fontSize,
            height: 1.6, // 行高
            color: isDarkMode ? Colors.grey[300] : Colors.black87,
          ),
          onLoadingBuilder: (context, element, loadingProgress) {
            return const Center(child: CircularProgressIndicator());
          },
          onErrorBuilder: (context, element, error) {
            print('HTML 渲染错误: $error');
            return const Icon(Icons.error, color: Colors.red);
          },
        ),
      ),
    );
  }

  /// 构建 EPUB 内部图片
  Widget? _buildEpubImage(dom.Element element) {
    try {
      final src = element.attributes['src'];
      if (src == null || src.isEmpty || epubBook == null) {
        return null;
      }

      // 从 EPUB 内容中查找图片
      final images = epubBook!.Content?.Images;
      if (images == null) {
        return null;
      }

      // 尝试多种匹配方式
      EpubByteContentFile? imageFile;
      
      // 1. 直接匹配文件名
      imageFile = images[src];
      
      // 2. 如果没找到，尝试去除路径前缀
      if (imageFile == null) {
        final fileName = src.split('/').last;
        imageFile = images[fileName];
      }
      
      // 3. 如果还没找到，尝试匹配包含关系
      if (imageFile == null) {
        for (final entry in images.entries) {
          if (entry.key.contains(src) || src.contains(entry.key)) {
            imageFile = entry.value;
            break;
          }
        }
      }

      if (imageFile == null) {
        print('未找到图片: $src');
        return const Icon(Icons.broken_image, color: Colors.grey);
      }

      // 将图片数据转换为 base64
      final content = imageFile.Content;
      if (content == null || content.isEmpty) {
        return const Icon(Icons.broken_image, color: Colors.grey);
      }

      // 获取 MIME 类型
      String mimeType = 'image/png'; // 默认
      final mime = imageFile.ContentMimeType;
      if (mime != null && mime.isNotEmpty) {
        mimeType = mime;
      } else if (src.toLowerCase().endsWith('.jpg') || src.toLowerCase().endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (src.toLowerCase().endsWith('.gif')) {
        mimeType = 'image/gif';
      } else if (src.toLowerCase().endsWith('.svg')) {
        mimeType = 'image/svg+xml';
      }

      // 转换为 Uint8List
      final Uint8List imageBytes = content is Uint8List ? content : Uint8List.fromList(content);

      // 返回 Flutter Image 组件
      return Image.memory(
        imageBytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          print('图片加载错误: $error');
          return const Icon(Icons.broken_image, color: Colors.grey);
        },
      );
    } catch (e) {
      print('构建图片失败: $e');
      return const Icon(Icons.broken_image, color: Colors.grey);
    }
  }
}
