import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:epubx/epubx.dart' hide Image;
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;

import '../code_block_widget.dart';

/// 阅读器内容组件 - 显示 EPUB 章节内容，支持视口分页
class ReaderContent extends StatefulWidget {
  final EpubChapter? chapter;
  final double fontSize;
  final bool isDarkMode;
  final EpubBook? epubBook;

  /// 初始滚动偏移量（用于恢复阅读位置）
  final double initialScrollOffset;

  /// 页数变化回调
  final ValueChanged<int>? onPageChanged;

  /// 滚动偏移变化回调
  final ValueChanged<double>? onScrollOffsetChanged;

  /// 章节边界回调：已到达章节末尾
  final VoidCallback? onReachedChapterEnd;

  /// 章节边界回调：已到达章节开头
  final VoidCallback? onReachedChapterStart;

  /// 总页数变化回调
  final ValueChanged<int>? onTotalPagesChanged;

  const ReaderContent({
    super.key,
    required this.chapter,
    required this.fontSize,
    required this.isDarkMode,
    required this.epubBook,
    this.initialScrollOffset = 0,
    this.onPageChanged,
    this.onScrollOffsetChanged,
    this.onReachedChapterEnd,
    this.onReachedChapterStart,
    this.onTotalPagesChanged,
  });

  @override
  State<ReaderContent> createState() => ReaderContentState();
}

/// 公开的 State 类，供父组件通过 GlobalKey 访问翻页方法
class ReaderContentState extends State<ReaderContent> {
  late ScrollController _scrollController;
  double _pageSize = 0;
  int _currentPage = 0;
  int _totalPages = 1;
  bool _ready = false;
  bool _restoringScroll = false;

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    // 初始化时确保滚动到顶部（后续由 _restoreScrollPosition 覆盖）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePageInfo();
      _restoreScrollPosition();
    });
  }

  @override
  void didUpdateWidget(ReaderContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter != widget.chapter) {
      // 章节变化：新章节的滚动位置由 next/prev 方法恢复
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updatePageInfo();
        _restoreScrollPosition();
      });
    } else if (oldWidget.fontSize != widget.fontSize) {
      // 字号变化：重新计算页数
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updatePageInfo();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_ready || _restoringScroll || !_scrollController.hasClients) return;
    final newPage = (_scrollController.offset / _pageSize).round();
    if (newPage != _currentPage) {
      setState(() {
        _currentPage = newPage;
      });
      widget.onPageChanged?.call(_currentPage);
    }
    // 实时通知父组件滚动偏移
    widget.onScrollOffsetChanged?.call(_scrollController.offset);
  }

  void _updatePageInfo() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final viewportHeight = _scrollController.position.viewportDimension;
    if (viewportHeight <= 0) return;

    _pageSize = viewportHeight;
    _totalPages = maxScroll > 0 ? (maxScroll / _pageSize).ceil() + 1 : 1;
    widget.onTotalPagesChanged?.call(_totalPages);

    if (!_restoringScroll) {
      _currentPage = (_scrollController.offset / _pageSize).round().clamp(0, _totalPages - 1) as int;
    }
    _ready = true;
  }

  /// 恢复到保存的滚动位置
  void _restoreScrollPosition() {
    if (widget.initialScrollOffset > 0 && _scrollController.hasClients) {
      _restoringScroll = true;
      final clamped = widget.initialScrollOffset.clamp(0, _scrollController.position.maxScrollExtent) as double;
      _scrollController.jumpTo(clamped);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoringScroll = false;
        _updatePageInfo();
      });
    } else {
      _restoringScroll = false;
    }
  }

  /// 下一页，返回 false 表示已到章节末尾
  bool goToNextPage() {
    if (!_ready || !_scrollController.hasClients) return true;

    final nextOffset = (_currentPage + 1) * _pageSize;
    if (nextOffset >= _scrollController.position.maxScrollExtent) {
      widget.onReachedChapterEnd?.call();
      return false; // 已到章节末尾
    }

    _scrollController.animateTo(
      nextOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
    return true;
  }

  /// 上一页，返回 false 表示已到章节开头
  bool goToPrevPage() {
    if (!_ready || !_scrollController.hasClients) return true;

    final prevOffset = (_currentPage - 1) * _pageSize;
    if (prevOffset < 0) {
      widget.onReachedChapterStart?.call();
      return false; // 已到章节开头
    }

    _scrollController.animateTo(
      prevOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chapter == null) {
      return const Center(child: Text('没有内容'));
    }

    String? content = widget.chapter!.HtmlContent;

    if (content == null || content.isEmpty) {
      return const Center(child: Text('章节内容为空'));
    }

    return SafeArea(
      child: Container(
        color: widget.isDarkMode ? Colors.grey[900] : Colors.white,
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: _buildContent(content),
      ),
    );
  }

  Widget _buildContent(String content) {
    return SingleChildScrollView(
      controller: _scrollController,
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
          fontSize: widget.fontSize,
          height: 1.6,
          color: widget.isDarkMode ? Colors.grey[300] : Colors.black87,
        ),
        onLoadingBuilder: (context, element, loadingProgress) {
          return const Center(child: CircularProgressIndicator());
        },
        onErrorBuilder: (context, element, error) {
          developer.log('HTML 渲染错误', error: error);
          return const Icon(Icons.error, color: Colors.red);
        },
      ),
    );
  }

  /// 构建 EPUB 内部图片
  Widget? _buildEpubImage(dom.Element element) {
    try {
      final src = element.attributes['src'];
      if (src == null || src.isEmpty || widget.epubBook == null) {
        return null;
      }

      // 从 EPUB 内容中查找图片
      final images = widget.epubBook!.Content?.Images;
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
        developer.log('未找到图片', name: 'ReaderContent', error: src);
        return const Icon(Icons.broken_image, color: Colors.grey);
      }

      // 将图片数据转换为 base64
      final content = imageFile.Content;
      if (content == null || content.isEmpty) {
        return const Icon(Icons.broken_image, color: Colors.grey);
      }

      // 获取 MIME 类型（用于调试）
      final mime = imageFile.ContentMimeType;
      if (mime != null && mime.isNotEmpty) {
        developer.log('图片MIME类型', name: 'ReaderContent', error: mime);
      }

      // 转换为 Uint8List
      final Uint8List imageBytes = content is Uint8List ? content : Uint8List.fromList(content);

      // 返回 Flutter Image 组件
      return Image.memory(
        imageBytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          developer.log('图片加载错误', error: error, stackTrace: stackTrace);
          return const Icon(Icons.broken_image, color: Colors.grey);
        },
      );
    } catch (e, stackTrace) {
      developer.log('构建图片失败', error: e, stackTrace: stackTrace);
      return const Icon(Icons.broken_image, color: Colors.grey);
    }
  }
}
