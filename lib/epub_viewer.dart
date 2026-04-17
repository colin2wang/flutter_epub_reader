import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'code_block_widget.dart';

/// 扁平化的章节结构,用于显示
class _FlatChapter {
  final EpubChapter chapter;
  final int index;
  final int level; // 层级深度,0为顶层
  
  _FlatChapter({
    required this.chapter,
    required this.index,
    required this.level,
  });
}

class EpubViewer extends StatefulWidget {
  final Uint8List epubBytes;
  final String fileName;

  const EpubViewer({
    super.key,
    required this.epubBytes,
    required this.fileName,
  });

  @override
  State<EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends State<EpubViewer> {
  List<_FlatChapter>? _flatChapters; // 扁平化的章节列表,包含所有层级
  int _currentChapterIndex = 0;
  bool _isLoading = true;
  String? _error;
  bool _isFullScreen = false; // 全屏模式标志
  double _fontSize = 16.0; // 字体大小，默认16
  bool _isDarkMode = false; // 夜间模式标志
  final TextEditingController _searchController = TextEditingController();
  bool _showMenu = false; // 控制菜单显示
  
  // SharedPreferences 实例
  SharedPreferences? _prefs;
  
  // 存储键名
  static const String _keyFontSize = 'font_size_';
  static const String _keyDarkMode = 'dark_mode_';
  static const String _keyChapterIndex = 'chapter_index_';

  @override
  void initState() {
    super.initState();
    _initializePreferences();
  }
  
  /// 初始化偏好设置
  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    
    // 加载保存的设置
    _loadSettings();
    
    // 加载 EPUB 文件
    await _loadEpub();
  }
  
  /// 加载保存的设置
  void _loadSettings() {
    // 生成基于文件名的唯一键
    final String fileKey = widget.fileName.hashCode.toString();
    
    setState(() {
      _fontSize = _prefs?.getDouble(_keyFontSize + fileKey) ?? 16.0;
      _isDarkMode = _prefs?.getBool(_keyDarkMode + fileKey) ?? false;
      _currentChapterIndex = _prefs?.getInt(_keyChapterIndex + fileKey) ?? 0;
    });
    
    // 3秒后自动隐藏菜单提示
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showMenu = false;
        });
      }
    });
  }
  
  /// 保存设置
  Future<void> _saveSettings() async {
    if (_prefs == null) return;
    
    final String fileKey = widget.fileName.hashCode.toString();
    
    await _prefs?.setDouble(_keyFontSize + fileKey, _fontSize);
    await _prefs?.setBool(_keyDarkMode + fileKey, _isDarkMode);
    await _prefs?.setInt(_keyChapterIndex + fileKey, _currentChapterIndex);
  }

  Future<void> _loadEpub() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('开始解析 EPUB 文件...');
      print('文件大小: ${widget.epubBytes.length} bytes');
      
      EpubBook book = await EpubReader.readBook(widget.epubBytes);
      
      print('EPUB 解析成功');
      print('书名: ${book.Title}');
      print('作者: ${book.Author}');
      print('章节数: ${book.Chapters?.length ?? 0}');
      
      if (book.Chapters == null || book.Chapters!.isEmpty) {
        // 尝试从 Content 中获取内容
        print('Chapters 为空,尝试从 Content 中读取...');
        if (book.Content != null && book.Content!.Html != null) {
          print('HTML 文件数: ${book.Content!.Html!.length}');
        }
        throw Exception('该 EPUB 文件没有可识别的章节内容,可能是格式不兼容或文件损坏');
      }
      
      List<EpubChapter> chapters = book.Chapters!;
      
      // 打印章节信息用于调试
      for (int i = 0; i < chapters.length; i++) {
        print('章节 $i: ${chapters[i].Title}, 内容长度: ${chapters[i].HtmlContent?.length ?? 0}');
        _printSubChapters(chapters[i], level: 1);
      }
      
      // 创建扁平化的章节列表
      List<_FlatChapter> flatChapters = [];
      _flattenChapters(chapters, flatChapters);
      
      print('扁平化后章节总数: ${flatChapters.length}');

      setState(() {
        _flatChapters = flatChapters;
        // 保持已加载的章节索引，但如果超出范围则重置为0
        if (_currentChapterIndex >= flatChapters.length) {
          _currentChapterIndex = 0;
        }
        _isLoading = false;
        _showMenu = true; // 首次加载时显示菜单提示
      });
    } catch (e, stackTrace) {
      print('解析 EPUB 失败: $e');
      print('堆栈跟踪: $stackTrace');
      setState(() {
        _isLoading = false;
        _error = '加载 ePub 文件失败:\n$e\n\n可能的原因:\n1. 文件格式不兼容\n2. 文件已损坏\n3. 文件有 DRM 保护\n4. EPUB 版本不支持';
      });
    }
  }
  
  /// 递归打印子章节
  void _printSubChapters(EpubChapter chapter, {required int level}) {
    if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
      for (var subChapter in chapter.SubChapters!) {
        print('${'  ' * level}子章节: ${subChapter.Title}, 内容长度: ${subChapter.HtmlContent?.length ?? 0}');
        _printSubChapters(subChapter, level: level + 1);
      }
    }
  }
  
  /// 将嵌套的章节结构扁平化
  void _flattenChapters(List<EpubChapter> chapters, List<_FlatChapter> flatList, {int level = 0}) {
    for (var chapter in chapters) {
      flatList.add(_FlatChapter(
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

  void _nextChapter() {
    if (_flatChapters != null && _currentChapterIndex < _flatChapters!.length - 1) {
      setState(() {
        _currentChapterIndex++;
      });
      _saveSettings(); // 保存阅读进度
    }
  }

  void _previousChapter() {
    if (_currentChapterIndex > 0) {
      setState(() {
        _currentChapterIndex--;
      });
      _saveSettings(); // 保存阅读进度
    }
  }

  /// 切换全屏模式
  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    
    if (_isFullScreen) {
      // 进入全屏模式：隐藏状态栏和导航栏
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      // 退出全屏模式：显示状态栏和导航栏
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  /// 调整字体大小
  void _changeFontSize(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(12.0, 32.0); // 限制在12-32之间
    });
    _saveSettings(); // 保存字体设置
  }

  /// 切换夜间模式
  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    _saveSettings(); // 保存夜间模式设置
  }

  /// 切换菜单显示
  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });
  }

  /// 搜索功能
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

    List<Map<String, dynamic>> results = [];
    
    for (int i = 0; i < _flatChapters!.length; i++) {
      final chapter = _flatChapters![i].chapter;
      final content = chapter.HtmlContent ?? '';
      
      // 简单的文本搜索（不区分大小写）
      if (content.toLowerCase().contains(query.toLowerCase())) {
        // 找到匹配的章节
        results.add({
          'index': i,
          'chapter': chapter,
          'level': _flatChapters![i].level,
        });
      }
    }

    // 显示搜索结果
    if (results.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        builder: (context) => Column(
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
                  final chapter = result['chapter'] as EpubChapter;
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
                      setState(() {
                        _currentChapterIndex = chapterIndex;
                      });
                      _saveSettings(); // 保存阅读进度
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到匹配的内容')),
      );
    }
  }

  void _showChapterList() {
    if (_flatChapters == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: _flatChapters!.length,
        itemBuilder: (context, index) {
          final flatChapter = _flatChapters![index];
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
                      color: index == _currentChapterIndex
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      fontWeight: index == _currentChapterIndex
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
              setState(() {
                _currentChapterIndex = index;
              });
              _saveSettings(); // 保存阅读进度
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 如果在全屏模式，先退出全屏
        if (_isFullScreen) {
          _toggleFullScreen();
          return false;
        }
        return true;
      },
      child: Theme(
        data: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
        child: Scaffold(
          appBar: _isFullScreen ? null : AppBar(
            title: Text(
              widget.fileName,
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: _isDarkMode 
                ? Colors.grey[900] 
                : Theme.of(context).colorScheme.inversePrimary,
            actions: [
              // 简化AppBar，只保留章节列表和全屏按钮
              // 其他功能已移至点击中间区域弹出的菜单中
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
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onTapDown: (details) {
                            // 获取点击位置的横坐标
                            final double screenWidth = constraints.maxWidth;
                            final double tapX = details.localPosition.dx;
                            
                            // 定义边缘区域宽度（屏幕宽度的20%）
                            final double edgeWidth = screenWidth * 0.2;
                            
                            // 点击左边缘：上一页
                            if (tapX < edgeWidth) {
                              _previousChapter();
                            }
                            // 点击右边缘：下一页
                            else if (tapX > screenWidth - edgeWidth) {
                              _nextChapter();
                            }
                            // 点击中间区域：显示/隐藏菜单
                            else {
                              _toggleMenu();
                            }
                          },
                          onHorizontalDragEnd: (details) {
                            // 检测水平滑动速度
                            const double minVelocity = 300; // 最小滑动速度
                            
                            if (details.primaryVelocity == null) return;
                            
                            // 向左滑动（下一页）
                            if (details.primaryVelocity! < -minVelocity) {
                              _nextChapter();
                            }
                            // 向右滑动（上一页）
                            else if (details.primaryVelocity! > minVelocity) {
                              _previousChapter();
                            }
                          },
                          child: Stack(
                            children: [
                              _buildContent(),
                              // 浮动菜单 - 居中显示
                              if (_showMenu)
                                Positioned.fill(
                                  child: GestureDetector(
                                    onTap: () {
                                      // 点击背景关闭菜单
                                      _toggleMenu();
                                    },
                                    child: Container(
                                      color: Colors.black.withOpacity(0.3),
                                      alignment: Alignment.center,
                                      child: GestureDetector(
                                        onTap: () {}, // 阻止事件穿透到背景
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context).size.width * 0.85,
                                          ),
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
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                                // 标题栏
                                                Padding(
                                                  padding: const EdgeInsets.all(16.0),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        '阅读设置',
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                          color: _isDarkMode ? Colors.white : Colors.black87,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.close),
                                                        onPressed: _toggleMenu,
                                                        tooltip: '关闭',
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Divider(height: 1),
                                                // 字体调整
                                                ListTile(
                                                  leading: const Icon(Icons.text_fields),
                                                  title: const Text('字体大小'),
                                                  trailing: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(Icons.remove_circle_outline),
                                                        onPressed: () => _changeFontSize(-2.0),
                                                        tooltip: '减小字体',
                                                      ),
                                                      Text(
                                                        '${_fontSize.toInt()}',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: _isDarkMode ? Colors.grey[300] : Colors.black87,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.add_circle_outline),
                                                        onPressed: () => _changeFontSize(2.0),
                                                        tooltip: '增大字体',
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Divider(height: 1),
                                                // 夜间模式
                                                ListTile(
                                                  leading: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
                                                  title: Text(_isDarkMode ? '日间模式' : '夜间模式'),
                                                  trailing: Switch(
                                                    value: _isDarkMode,
                                                    onChanged: (value) => _toggleDarkMode(),
                                                  ),
                                                  onTap: _toggleDarkMode,
                                                ),
                                                const Divider(height: 1),
                                                // 搜索
                                                ListTile(
                                                  leading: const Icon(Icons.search),
                                                  title: const Text('搜索'),
                                                  trailing: const Icon(Icons.chevron_right),
                                                  onTap: () {
                                                    _toggleMenu();
                                                    _showSearchDialog();
                                                  },
                                                ),
                                                const Divider(height: 1),
                                                // 章节列表
                                                ListTile(
                                                  leading: const Icon(Icons.list),
                                                  title: const Text('章节列表'),
                                                  trailing: const Icon(Icons.chevron_right),
                                                  onTap: () {
                                                    _toggleMenu();
                                                    _showChapterList();
                                                  },
                                                ),
                                                const Divider(height: 1),
                                                // 全屏模式
                                                ListTile(
                                                  leading: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
                                                  title: Text(_isFullScreen ? '退出全屏' : '全屏模式'),
                                                  trailing: Switch(
                                                    value: _isFullScreen,
                                                    onChanged: (value) => _toggleFullScreen(),
                                                  ),
                                                  onTap: _toggleFullScreen,
                                                ),
                                              ],
                                            ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
          bottomNavigationBar: _isFullScreen ? null : _buildNavigation(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_flatChapters == null || _currentChapterIndex >= _flatChapters!.length) {
      return const Center(child: Text('没有内容'));
    }

    final flatChapter = _flatChapters![_currentChapterIndex];
    EpubChapter chapter = flatChapter.chapter;
    String? content = chapter.HtmlContent;

    if (content == null || content.isEmpty) {
      return const Center(child: Text('章节内容为空'));
    }

    return Container(
      color: _isDarkMode ? Colors.grey[900] : Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (chapter.Title != null && chapter.Title!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  chapter.Title!,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: _fontSize + 4, // 标题比正文大4号
                      ),
                ),
              ),
            HtmlWidget(
              content,
              customWidgetBuilder: (element) {
                // 处理代码块
                if (element.localName == 'pre') {
                  return CodeBlockWidget(element: element);
                }
                return null;
              },
              textStyle: TextStyle(
                fontSize: _fontSize,
                height: 1.6, // 行高
                color: _isDarkMode ? Colors.grey[300] : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation() {
    if (_flatChapters == null) return const SizedBox.shrink();

    return Container(
      color: _isDarkMode ? Colors.grey[850] : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _currentChapterIndex > 0 ? _previousChapter : null,
            tooltip: '上一章',
          ),
          Text(
            '${_currentChapterIndex + 1} / ${_flatChapters!.length}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _isDarkMode ? Colors.grey[300] : Colors.black87,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _currentChapterIndex < _flatChapters!.length - 1
                ? _nextChapter
                : null,
            tooltip: '下一章',
          ),
        ],
      ),
    );
  }
}
