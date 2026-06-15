import 'package:epubx/epubx.dart' hide Image;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/flat_chapter.dart';
import 'services/bookshelf_service.dart';
import 'services/epub_parser_service.dart';
import 'services/logger_service.dart';
import 'services/preferences_service.dart';
import 'services/search_service.dart';
import 'widgets/chapter_list_panel.dart';
import 'widgets/reader_content.dart';
import 'widgets/reader_navigation_bar.dart';
import 'widgets/reader_settings_menu.dart';
import 'widgets/search_result_panel.dart';

/// EPUB 阅读器主页面
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

/// 逻辑章节分组 —— 一个顶级章节及其所有子章节构成一组
class _ChapterGroup {
  final FlatChapter topLevelChapter;
  final List<FlatChapter> subChapters;

  _ChapterGroup({
    required this.topLevelChapter,
    required this.subChapters,
  });

  /// 总页数 = 主章节 + 子章节数
  int get totalPages => 1 + subChapters.length;

  /// 获取组内指定偏移的 FlatChapter（0 = 主章节，1+ = 子章节）
  FlatChapter flatChapterAt(int subPageIndex) {
    if (subPageIndex <= 0) return topLevelChapter;
    return subChapters[subPageIndex - 1];
  }
}

class _EpubViewerState extends State<EpubViewer> {
  // EPUB 数据
  List<FlatChapter>? _flatChapters;
  EpubBook? _epubBook;

  // 逻辑章节分组
  List<_ChapterGroup>? _chapterGroups;

  // 阅读状态：逻辑组索引 + 组内页面偏移（0=主章节，1+=子章节）
  int _currentGroupIndex = 0;
  int _currentSubPageIndex = 0;
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

  // 防点击+滑动双重触发：记录最近一次通过点击翻页的时间
  DateTime? _lastTapTurnTime;

  // ReaderContent 的 GlobalKey，用于调用翻页方法
  final GlobalKey<ReaderContentState> _readerContentKey = GlobalKey<ReaderContentState>();

  // 每章滚动位置缓存（FlatChapter.index → 滚动偏移）
  final Map<int, double> _chapterScrollOffsets = {};

  // 当前章节的页信息
  int _currentPage = 0;
  int _totalPages = 1;

  /// 从扁平章节列表构建逻辑分组
  static List<_ChapterGroup> _buildGroups(List<FlatChapter> flatChapters) {
    final groups = <_ChapterGroup>[];
    int i = 0;
    while (i < flatChapters.length) {
      final subs = <FlatChapter>[];
      int j = i + 1;
      while (j < flatChapters.length && flatChapters[j].level > 0) {
        subs.add(flatChapters[j]);
        j++;
      }
      groups.add(_ChapterGroup(
        topLevelChapter: flatChapters[i],
        subChapters: subs,
      ));
      i = j;
    }
    return groups;
  }

  /// 获取当前正在显示的 FlatChapter
  FlatChapter _getCurrentFlatChapter() {
    final group = _chapterGroups![_currentGroupIndex];
    return group.flatChapterAt(_currentSubPageIndex);
  }

  /// 获取当前 FlatChapter 在扁平列表中的索引（用于持久化/缓存）
  int _getCurrentFlatIndex() {
    return _getCurrentFlatChapter().index;
  }

  /// 从保存的扁平索引恢复分组位置
  void _restorePositionFromFlatIndex(int flatIndex) {
    final groups = _chapterGroups;
    if (groups == null || groups.isEmpty) return;
    for (int g = 0; g < groups.length; g++) {
      final group = groups[g];
      if (group.topLevelChapter.index == flatIndex) {
        _currentGroupIndex = g;
        _currentSubPageIndex = 0;
        return;
      }
      for (int s = 0; s < group.subChapters.length; s++) {
        if (group.subChapters[s].index == flatIndex) {
          _currentGroupIndex = g;
          _currentSubPageIndex = s + 1;
          return;
        }
      }
    }
    // 未找到则重置
    _currentGroupIndex = 0;
    _currentSubPageIndex = 0;
  }

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
      _currentGroupIndex = _preferencesService.loadChapterIndex(widget.fileName);
      _showBottomBar = _preferencesService.loadShowBottomBar(widget.fileName);
      _chapterScrollOffsets.addAll(_preferencesService.loadScrollOffsets(widget.fileName));
    });
  }

  /// 保存所有设置
  Future<void> _saveSettings() async {
    await _preferencesService.saveAllSettings(
      widget.fileName,
      fontSize: _fontSize,
      isDarkMode: _isDarkMode,
      chapterIndex: _currentGroupIndex,
      showBottomBar: _showBottomBar,
    );
    // 持久化滚动位置
    await _preferencesService.saveScrollOffsets(widget.fileName, _chapterScrollOffsets);
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
          _chapterGroups = _buildGroups(_flatChapters!);
          // 从保存的扁平索引恢复分组位置（兼容旧版保存的 _currentChapterIndex）
          final savedFlatIndex = _currentGroupIndex;
          _restorePositionFromFlatIndex(savedFlatIndex);
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      _handleLoadError(e, stackTrace);
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

  /// 向前翻一页（组内子页面优先，耗尽后进入下一组）
  void _nextPage() {
    final groups = _chapterGroups;
    if (groups == null || groups.isEmpty) return;

    final group = groups[_currentGroupIndex];

    // 组内还有子页面 → 前进到子页面
    if (_currentSubPageIndex + 1 < group.totalPages) {
      final oldSub = _currentSubPageIndex;
      setState(() {
        _currentSubPageIndex++;
        _currentPage = 0;
      });
      final chapter = _getCurrentFlatChapter().chapter;
      _logger.info('➡️ 组内翻页: 组[$_currentGroupIndex] 子页[$oldSub] -> [$_currentSubPageIndex] "${chapter.Title}"');
      _saveSettings();
      return;
    }

    // 组内已翻完 → 进入下一组
    if (_currentGroupIndex >= groups.length - 1) {
      _logger.debug('⚠️ 已经是最后一组，无法继续翻页');
      return;
    }

    final oldGroup = _currentGroupIndex;
    setState(() {
      _currentGroupIndex++;
      _currentSubPageIndex = 0;
      _currentPage = 0;
    });
    final chapter = _getCurrentFlatChapter().chapter;
    final chapterTitle = chapter.Title ?? '第${_currentGroupIndex + 1}章';
    _logger.info('➡️ 进入下一组: [$oldGroup] -> [$_currentGroupIndex] "$chapterTitle"');
    _saveSettings();
  }

  /// 向后翻一页（组内回退，回退到头则进入上一组）
  void _previousPage() {
    final groups = _chapterGroups;
    if (groups == null || groups.isEmpty) return;

    // 组内还有前一个子页面 → 回退
    if (_currentSubPageIndex > 0) {
      final oldSub = _currentSubPageIndex;
      setState(() {
        _currentSubPageIndex--;
        _currentPage = 0;
      });
      final chapter = _getCurrentFlatChapter().chapter;
      _logger.info('⬅️ 组内回退: 组[$_currentGroupIndex] 子页[$oldSub] -> [$_currentSubPageIndex] "${chapter.Title}"');
      _saveSettings();
      return;
    }

    // 组内已到开头 → 进入上一组
    if (_currentGroupIndex <= 0) {
      _logger.debug('⚠️ 已经是第一组，无法继续回退');
      return;
    }

    final oldGroup = _currentGroupIndex;
    setState(() {
      _currentGroupIndex--;
      _currentSubPageIndex = groups[_currentGroupIndex].totalPages - 1;
      _currentPage = 0;
    });
    final chapter = _getCurrentFlatChapter().chapter;
    final chapterTitle = chapter.Title ?? '第${_currentGroupIndex + 1}章';
    _logger.info('⬅️ 回到上一组: [$oldGroup] -> [$_currentGroupIndex] "$chapterTitle"');
    _saveSettings();
  }

  /// 跳转到指定章节（根据 FlatChapter.index 找到对应组+子页）
  void _jumpToChapter(int flatIndex) {
    final groups = _chapterGroups;
    if (groups == null || groups.isEmpty) return;

    for (int g = 0; g < groups.length; g++) {
      final group = groups[g];
      if (group.topLevelChapter.index == flatIndex) {
        if (g == _currentGroupIndex && _currentSubPageIndex == 0) {
          _logger.debug('ℹ️ 已经在目标章节，无需跳转');
          return;
        }
        final oldGroup = _currentGroupIndex;
        setState(() {
          _currentGroupIndex = g;
          _currentSubPageIndex = 0;
          _currentPage = 0;
        });
        final title = group.topLevelChapter.chapter.Title ?? '第${g + 1}章';
        _logger.info('🎯 跳转成功: [$oldGroup] -> [$g] "$title"');
        _saveSettings();
        return;
      }
      for (int s = 0; s < group.subChapters.length; s++) {
        if (group.subChapters[s].index == flatIndex) {
          if (g == _currentGroupIndex && _currentSubPageIndex == s + 1) {
            _logger.debug('ℹ️ 已经在目标子页面，无需跳转');
            return;
          }
          final oldGroup = _currentGroupIndex;
          setState(() {
            _currentGroupIndex = g;
            _currentSubPageIndex = s + 1;
            _currentPage = 0;
          });
          final title = group.subChapters[s].chapter.Title ?? '子页${s + 1}';
          _logger.info('🎯 跳转到子页: [$oldGroup] -> [$g] "$title"');
          _saveSettings();
          return;
        }
      }
    }
    _logger.warning('⚠️ 未找到 flatIndex=$flatIndex，无法跳转');
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
                '请返回主页，重新选择文件并点击"添加到书架"。',
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
        currentChapterIndex: _getCurrentFlatIndex(),
        onChapterSelected: _jumpToChapter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isFullScreen) {
          _toggleFullScreen();
        }
      },
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
      builder: (context, constraints) => Listener(
        onPointerDown: (event) {
          // 使用 Listener 接收原始指针事件，不经过手势竞技场，避免与滑动/双击手势冲突
          if (!_showMenu) {
            _handleTap(event.localPosition.dx, constraints.maxWidth);
          }
        },
        child: GestureDetector(
          onDoubleTap: _toggleMenu,
          onHorizontalDragEnd: _handleSwipe,
          child: Stack(
            children: [
              _buildReaderContent(),
              if (_showMenu) _buildSettingsMenu(),
            ],
          ),
        ),
      ),
    );
  }

  /// 处理点击事件 - 按视口分页
  void _handleTap(double tapX, double screenWidth) {
    final edgeWidth = screenWidth * 0.2;

    _logger.debug('👆 点击事件: x=$tapX, 屏幕宽度=$screenWidth, 边缘宽度=$edgeWidth');

    if (tapX < edgeWidth) {
      // 左侧点击：上一页（章节内）
      _logger.debug('👈 点击左侧区域 (${(tapX/screenWidth*100).toStringAsFixed(1)}%)，触发上一页');
      _lastTapTurnTime = DateTime.now();

      final readerState = _readerContentKey.currentState;
      if (readerState != null && !readerState.goToPrevPage()) {
        // 已到章节开头，跨到上一页（可能是回退到上一组或组内回退）
        _previousPage();
      }
    } else if (tapX > screenWidth - edgeWidth) {
      // 右侧点击：下一页（章节内）
      _logger.debug('👉 点击右侧区域 (${(tapX/screenWidth*100).toStringAsFixed(1)}%)，触发下一页');
      _lastTapTurnTime = DateTime.now();

      final readerState = _readerContentKey.currentState;
      if (readerState != null && !readerState.goToNextPage()) {
        // 已到章节末尾，跨到下一页（可能是下一组或组内子页面）
        _nextPage();
      }
    } else {
      _logger.debug('👆 点击中间区域，不触发翻页');
    }
  }

  /// 处理滑动手势 - 保持跨章翻页
  void _handleSwipe(DragEndDetails details) {
    // 如果刚通过点击触发了翻页（300ms内），忽略后续的滑动事件
    if (_lastTapTurnTime != null &&
        DateTime.now().difference(_lastTapTurnTime!).inMilliseconds < 300) {
      _logger.debug('💨 忽略滑动: 刚通过点击翻页（${DateTime.now().difference(_lastTapTurnTime!).inMilliseconds}ms前），防止双重触发');
      _lastTapTurnTime = null;
      return;
    }

    const double minVelocity = 200;
    final velocity = details.primaryVelocity;

    if (velocity == null) {
      _logger.debug('💨 滑动事件: 速度为null，忽略');
      return;
    }

    _logger.debug('💨 滑动事件: 速度=$velocity, 阈值=$minVelocity');

    if (velocity < -minVelocity) {
      _logger.debug('💨 左滑（速度=${velocity.toStringAsFixed(0)}），触发下一页');
      _nextPage();
    } else if (velocity > minVelocity) {
      _logger.debug('💨 右滑（速度=${velocity.toStringAsFixed(0)}），触发上一页');
      _previousPage();
    } else {
      _logger.debug('💨 滑动速度不足（|${velocity.toStringAsFixed(0)}| < $minVelocity），忽略');
    }
  }

  /// 构建阅读器内容
  Widget _buildReaderContent() {
    final flatChapter = _getCurrentFlatChapter();
    return ReaderContent(
      key: _readerContentKey,
      chapter: flatChapter.chapter,
      fontSize: _fontSize,
      isDarkMode: _isDarkMode,
      epubBook: _epubBook,
      initialScrollOffset: _chapterScrollOffsets[flatChapter.index] ?? 0,
      onPageChanged: (page) {
        setState(() {
          _currentPage = page;
        });
      },
      onScrollOffsetChanged: (offset) {
        _chapterScrollOffsets[flatChapter.index] = offset;
      },
      onReachedChapterEnd: _nextPage,
      onReachedChapterStart: _previousPage,
      onTotalPagesChanged: (totalPages) {
        setState(() {
          _totalPages = totalPages;
        });
      },
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
    final groups = _chapterGroups;
    final totalGroupCount = groups?.length ?? 0;
    return ReaderNavigationBar(
      currentIndex: _currentGroupIndex,
      totalCount: totalGroupCount,
      currentPage: _currentPage,
      totalPages: _totalPages,
      isDarkMode: _isDarkMode,
      onPrevious: (_currentGroupIndex > 0 || _currentSubPageIndex > 0) ? _previousPage : null,
      onNext: (_currentGroupIndex < totalGroupCount - 1 ||
               _currentSubPageIndex < (groups?[_currentGroupIndex].totalPages ?? 1) - 1)
          ? _nextPage
          : null,
    );
  }

}
