import 'dart:convert';
import 'package:epubx/epubx.dart' hide Image;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/bookshelf_item.dart';
import 'models/flat_chapter.dart';
import 'services/bookshelf_service.dart';
import 'services/epub_parser_service.dart';
import 'services/logger_service.dart';
import 'services/preferences_service.dart';
import 'services/search_service.dart';
import 'widgets/reader_content.dart';
import 'widgets/reader_navigation_bar.dart';
import 'widgets/chapter_list_panel.dart';
import 'widgets/search_result_panel.dart';
import 'widgets/reader_settings_menu.dart';

class EpubViewer extends StatefulWidget {
  final Uint8List epubBytes;
  final String fileName;
  final String? filePath; // 可选的文件路径，用于加入书架
  final VoidCallback? onOpenLog; // 打开日志窗口的回调

  const EpubViewer({
    super.key,
    required this.epubBytes,
    required this.fileName,
    this.filePath,
    this.onOpenLog,
  });

  @override
  State<EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends State<EpubViewer> {
  // EPUB 数据
  List<FlatChapter>? _flatChapters;
  EpubBook? _epubBook;
  
  // 阅读状态
  int _currentChapterIndex = 0;
  bool _isLoading = true;
  String? _error;
  
  // UI 状态
  bool _isFullScreen = false;
  bool _showMenu = false;
  double _fontSize = 16.0;
  bool _isDarkMode = false;
  bool _showBottomBar = true;
  
  // 控制器和服务
  final TextEditingController _searchController = TextEditingController();
  final PreferencesService _preferencesService = PreferencesService();
  final BookshelfService _bookshelfService = BookshelfService();
  final LoggerService _logger = LoggerService();
  bool _isInBookshelf = false;

  @override
  void initState() {
    super.initState();
    _initializePreferences();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  /// 初始化偏好设置
  Future<void> _initializePreferences() async {
    await _preferencesService.initialize();
    await _bookshelfService.initialize();
    _loadSettings();
    _checkIfInBookshelf();
    await _loadEpub();
  }
  
  /// 检查书籍是否已在书架中
  void _checkIfInBookshelf() {
    setState(() {
      _isInBookshelf = _bookshelfService.isBookInShelf(widget.fileName);
    });
  }
  
  /// 加载保存的设置
  void _loadSettings() {
    setState(() {
      _fontSize = _preferencesService.loadFontSize(widget.fileName);
      _isDarkMode = _preferencesService.loadDarkMode(widget.fileName);
      _currentChapterIndex = _preferencesService.loadChapterIndex(widget.fileName);
      _showBottomBar = _preferencesService.loadShowBottomBar(widget.fileName);
    });
  }
  
  /// 保存当前设置
  Future<void> _saveSettings() async {
    await _preferencesService.saveAllSettings(
      widget.fileName,
      fontSize: _fontSize,
      isDarkMode: _isDarkMode,
      chapterIndex: _currentChapterIndex,
      showBottomBar: _showBottomBar,
    );
  }

  /// 加载 EPUB 文件
  Future<void> _loadEpub() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      final result = await EpubParserService.parseEpub(widget.epubBytes);
      
      if (mounted) {
        setState(() {
          _epubBook = result['book'] as EpubBook;
          _flatChapters = result['flatChapters'] as List<FlatChapter>;
          _validateChapterIndex();
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      _handleLoadError(e, stackTrace);
    }
  }
  
  /// 验证章节索引是否有效
  void _validateChapterIndex() {
    if (_flatChapters != null && _currentChapterIndex >= _flatChapters!.length) {
      _currentChapterIndex = 0;
    }
  }
  
  /// 处理加载错误
  void _handleLoadError(dynamic error, StackTrace stackTrace) {
    _logger.error('解析 EPUB 失败: $error');
    _logger.error('堆栈跟踪: $stackTrace');
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _error = '加载 ePub 文件失败:\n$error\n\n可能的原因:\n'
            '1. 文件格式不兼容\n'
            '2. 文件已损坏\n'
            '3. 文件有 DRM 保护\n'
            '4. EPUB 版本不支持\n'
            '5. 文件内容为空';
      });
    }
  }

  /// 跳转到下一章
  void _nextChapter() {
    final totalChapters = _flatChapters?.length ?? 0;
    _logger.debug('📖 尝试翻到下一章: 当前=$_currentChapterIndex, 总数=$totalChapters');
    
    if (_flatChapters == null || _currentChapterIndex >= _flatChapters!.length - 1) {
      _logger.debug('⚠️ 已经是最后一章，无法继续翻页');
      return;
    }
    
    final oldIndex = _currentChapterIndex;
    setState(() => _currentChapterIndex++);
    
    final chapter = _flatChapters![_currentChapterIndex].chapter;
    final chapterTitle = chapter.Title ?? '第${_currentChapterIndex + 1}章';
    final chapterDetails = _getChapterDetails(chapter);
    _logger.info('➡️ 翻页成功: [$oldIndex] -> [$_currentChapterIndex] "$chapterTitle" | $chapterDetails');
    _saveSettings();
  }

  /// 跳转到上一章
  void _previousChapter() {
    _logger.debug('📖 尝试翻到上一章: 当前=$_currentChapterIndex');
    
    if (_currentChapterIndex <= 0) {
      _logger.debug('⚠️ 已经是第一章，无法继续翻页');
      return;
    }
    
    final oldIndex = _currentChapterIndex;
    setState(() => _currentChapterIndex--);
    
    final chapter = _flatChapters![_currentChapterIndex].chapter;
    final chapterTitle = chapter.Title ?? '第${_currentChapterIndex + 1}章';
    final chapterDetails = _getChapterDetails(chapter);
    _logger.info('⬅️ 翻页成功: [$oldIndex] -> [$_currentChapterIndex] "$chapterTitle" | $chapterDetails');
    _saveSettings();
  }
  
  /// 跳转到指定章节
  void _jumpToChapter(int index) {
    final totalChapters = _flatChapters?.length ?? 0;
    _logger.debug('📖 尝试跳转到章节: index=$index, 总数=$totalChapters');
    
    if (index < 0 || index >= totalChapters) {
      _logger.warning('⚠️ 章节索引超出范围: $index (有效范围: 0-${totalChapters - 1})');
      return;
    }
    
    if (index == _currentChapterIndex) {
      _logger.debug('ℹ️ 已经在目标章节，无需跳转');
      return;
    }
    
    final oldIndex = _currentChapterIndex;
    setState(() => _currentChapterIndex = index);
    
    final chapter = _flatChapters![_currentChapterIndex].chapter;
    final chapterTitle = chapter.Title ?? '第${_currentChapterIndex + 1}章';
    final chapterDetails = _getChapterDetails(chapter);
    _logger.info('🎯 跳转成功: [$oldIndex] -> [$_currentChapterIndex] "$chapterTitle" | $chapterDetails');
    _saveSettings();
  }

  /// 切换全屏模式
  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    
    SystemChrome.setEnabledSystemUIMode(
      _isFullScreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  /// 调整字体大小
  void _changeFontSize(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(12.0, 32.0);
    });
    _saveSettings();
  }

  /// 切换夜间模式
  void _toggleDarkMode() {
    setState(() => _isDarkMode = !_isDarkMode);
    _saveSettings();
  }

  /// 切换底部导航栏显示
  void _toggleBottomBar() {
    setState(() => _showBottomBar = !_showBottomBar);
    _saveSettings();
  }

  /// 添加或移除书架
  Future<void> _toggleBookshelf() async {
    if (_isInBookshelf) {
      // 从书架移除
      try {
        final book = _bookshelfService.getAllBooks().firstWhere(
          (b) => b.fileName == widget.fileName,
        );
        
        final success = await _bookshelfService.removeBook(book.id);
        
        if (mounted) {
          setState(() => _isInBookshelf = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已从书架移除: ${widget.fileName}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('书籍不在书架中')),
          );
        }
      }
    } else {
      // 添加到书架
      if (widget.filePath != null && widget.filePath!.isNotEmpty) {
        try {
          final book = await _bookshelfService.addBook(widget.fileName, widget.filePath!);
          
          if (mounted) {
            if (book != null) {
              setState(() => _isInBookshelf = true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已添加到书架: ${widget.fileName}')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('添加到书架失败')),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('添加到书架失败: $e')),
            );
          }
        }
      } else {
        // 没有文件路径，需要先保存文件
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('添加到书架'),
              content: const Text(
                '当前打开的文件无法直接添加到书架。\n\n'
                '请返回主页，重新选择文件并点击“添加到书架”。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  /// 切换菜单显示
  void _toggleMenu() {
    setState(() => _showMenu = !_showMenu);
  }

  /// 显示搜索对话框
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: '输入搜索关键词',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) {
            Navigator.pop(context);
            _performSearch(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performSearch(_searchController.text);
            },
            child: const Text('搜索'),
          ),
        ],
      ),
    );
  }

  /// 执行搜索
  void _performSearch(String query) {
    if (query.isEmpty || _flatChapters == null) return;

    final results = SearchService.searchInChapters(query, _flatChapters!);

    if (results.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        builder: (context) => SearchResultPanel(
          results: results,
          onResultSelected: _jumpToChapter,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到匹配的内容')),
      );
    }
  }

  /// 显示章节列表面板
  void _showChapterList() {
    if (_flatChapters == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => ChapterListPanel(
        flatChapters: _flatChapters!,
        currentChapterIndex: _currentChapterIndex,
        onChapterSelected: _jumpToChapter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Theme(
        data: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
        child: Scaffold(
          appBar: _buildAppBar(),
          body: _buildBody(),
          bottomNavigationBar: _showBottomBar ? _buildBottomNavigationBar() : null,
        ),
      ),
    );
  }
  
  /// 处理返回按钮
  Future<bool> _handleWillPop() async {
    if (_isFullScreen) {
      _toggleFullScreen();
      return false;
    }
    return true;
  }
  
  /// 构建应用栏
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        widget.fileName,
        style: const TextStyle(fontSize: 16),
      ),
      backgroundColor: _isDarkMode 
          ? Colors.grey[900] 
          : Theme.of(context).colorScheme.inversePrimary,
      actions: [
        IconButton(
          icon: Icon(
            _isInBookshelf ? Icons.bookmark : Icons.bookmark_border,
            color: _isInBookshelf ? Colors.amber : null,
          ),
          onPressed: _toggleBookshelf,
          tooltip: _isInBookshelf ? '从书架移除' : '加入书架',
        ),
        IconButton(
          icon: const Icon(Icons.bug_report),
          onPressed: widget.onOpenLog,
          tooltip: '运行日志',
        ),
        IconButton(
          icon: const Icon(Icons.list),
          onPressed: _showChapterList,
          tooltip: '章节列表',
        ),
        IconButton(
          icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
          onPressed: _toggleFullScreen,
          tooltip: _isFullScreen ? '退出全屏' : '全屏模式',
        ),
      ],
    );
  }
  
  /// 构建主体内容
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onTapDown: (details) => _handleTap(details, constraints.maxWidth),
        onDoubleTap: _toggleMenu,
        onHorizontalDragEnd: _handleSwipe,
        child: Stack(
          children: [
            _buildReaderContent(),
            if (_showMenu) _buildSettingsMenu(),
          ],
        ),
      ),
    );
  }
  
  /// 处理点击事件
  void _handleTap(TapDownDetails details, double screenWidth) {
    final tapX = details.localPosition.dx;
    final edgeWidth = screenWidth * 0.2;
    
    _logger.debug('👆 点击事件: x=$tapX, 屏幕宽度=$screenWidth, 边缘宽度=$edgeWidth');
    
    if (tapX < edgeWidth) {
      _logger.debug('👈 点击左侧区域 (${(tapX/screenWidth*100).toStringAsFixed(1)}%)，触发上一章');
      _previousChapter();
    } else if (tapX > screenWidth - edgeWidth) {
      _logger.debug('👉 点击右侧区域 (${(tapX/screenWidth*100).toStringAsFixed(1)}%)，触发下一章');
      _nextChapter();
    } else {
      _logger.debug('👆 点击中间区域，不触发翻页');
    }
  }
  
  /// 处理滑动手势
  void _handleSwipe(DragEndDetails details) {
    const double minVelocity = 300;
    final velocity = details.primaryVelocity;
    
    if (velocity == null) {
      _logger.debug('💨 滑动事件: 速度为null，忽略');
      return;
    }
    
    _logger.debug('💨 滑动事件: 速度=$velocity, 阈值=$minVelocity');
    
    if (velocity < -minVelocity) {
      _logger.debug('💨 左滑（速度=${velocity.toStringAsFixed(0)}），触发下一章');
      _nextChapter();
    } else if (velocity > minVelocity) {
      _logger.debug('💨 右滑（速度=${velocity.toStringAsFixed(0)}），触发上一章');
      _previousChapter();
    } else {
      _logger.debug('💨 滑动速度不足（|${velocity.toStringAsFixed(0)}| < $minVelocity），忽略');
    }
  }
  
  /// 构建阅读器内容
  Widget _buildReaderContent() {
    return ReaderContent(
      chapter: _flatChapters![_currentChapterIndex].chapter,
      fontSize: _fontSize,
      isDarkMode: _isDarkMode,
      epubBook: _epubBook,
    );
  }
  
  /// 构建设置菜单
  Widget _buildSettingsMenu() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _toggleMenu,
        child: Container(
          color: Colors.black.withOpacity(0.3),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {}, // 阻止事件穿透
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.grey[850] : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ReaderSettingsMenu(
                    fontSize: _fontSize,
                    isDarkMode: _isDarkMode,
                    isFullScreen: _isFullScreen,
                    showBottomBar: _showBottomBar,
                    onFontSizeChange: _changeFontSize,
                    onToggleDarkMode: _toggleDarkMode,
                    onToggleFullScreen: _toggleFullScreen,
                    onToggleBottomBar: _toggleBottomBar,
                    onSearch: () {
                      _toggleMenu();
                      _showSearchDialog();
                    },
                    onShowChapterList: () {
                      _toggleMenu();
                      _showChapterList();
                    },
                    onClose: _toggleMenu,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// 构建底部导航栏
  Widget _buildBottomNavigationBar() {
    return ReaderNavigationBar(
      currentIndex: _currentChapterIndex,
      totalCount: _flatChapters?.length ?? 0,
      isDarkMode: _isDarkMode,
      onPrevious: _currentChapterIndex > 0 ? _previousChapter : null,
      onNext: _currentChapterIndex < (_flatChapters?.length ?? 0) - 1 ? _nextChapter : null,
    );
  }
  
  /// 获取章节的 XHTML 文件名
  String _getXhtmlFileName(EpubChapter chapter) {
    // 尝试从章节对象中获取文件路径信息
    try {
      // 方法1: 尝试访问 Anchor（通常是文件路径）
      if (chapter.Anchor != null && chapter.Anchor!.isNotEmpty) {
        final anchor = chapter.Anchor!;
        // Anchor 格式可能是 "part0000.xhtml#chapter1" 或 "part0000.xhtml"
        final fileName = anchor.split('#').first.split('/').last.split('\\').last;
        if (fileName.isNotEmpty) {
          return fileName;
        }
      }
      
      // 方法2: 如果以上方法都失败，返回章节标题作为标识
      final title = chapter.Title ?? '未知章节';
      return title;
    } catch (e) {
      _logger.debug('无法获取 XHTML 文件名: $e');
      return 'unknown';
    }
  }
  
  /// 获取章节的详细信息（包括文件分割情况）
  String _getChapterDetails(EpubChapter chapter) {
    final xhtmlFile = _getXhtmlFileName(chapter);
    final contentLength = chapter.HtmlContent?.length ?? 0;
    
    // 检查是否有 split 标记（表示是被分割的文件）
    final isSplit = xhtmlFile.contains('_split_') || xhtmlFile.contains('_part_');
    
    if (isSplit) {
      return '$xhtmlFile (${contentLength} chars, split)';
    } else {
      return '$xhtmlFile (${contentLength} chars)';
    }
  }


}
