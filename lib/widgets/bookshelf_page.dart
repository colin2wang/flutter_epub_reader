import 'dart:io';
import 'package:flutter/material.dart';
import '../models/bookshelf_item.dart';
import '../services/bookshelf_service.dart';
import 'book_detail_page.dart';

/// 书架页面 - 显示和管理书架中的书籍
class BookshelfPage extends StatefulWidget {
  final Function(BookshelfItem) onBookSelected;
  final VoidCallback onAddBook;
  final VoidCallback? onBooksChanged; // 书籍变化时的回调
  final VoidCallback? onOpenLog; // 打开日志窗口的回调

  const BookshelfPage({
    super.key,
    required this.onBookSelected,
    required this.onAddBook,
    this.onBooksChanged,
    this.onOpenLog,
  });

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> with WidgetsBindingObserver {
  final BookshelfService _bookshelfService = BookshelfService();
  List<BookshelfItem> _books = [];
  bool _isLoading = true;
  
  // 排序相关状态
  SortOption _currentSortOption = SortOption.addedDateDesc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBooks();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  /// 监听应用生命周期变化
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 应用恢复时刷新书架
      _loadBooks();
    }
  }

  /// 加载书架数据
  Future<void> _loadBooks() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    await _bookshelfService.initialize();
    
    if (mounted) {
      setState(() {
        _books = _bookshelfService.getAllBooks();
        _sortBooks(); // 应用排序
        _isLoading = false;
      });
      
      // 通知外部书架数据已更新
      widget.onBooksChanged?.call();
    }
  }
  
  /// 对书籍列表进行排序
  void _sortBooks() {
    switch (_currentSortOption) {
      case SortOption.addedDateAsc:
        _books.sort((a, b) => a.addedDate.compareTo(b.addedDate));
        break;
      case SortOption.addedDateDesc:
        _books.sort((a, b) => b.addedDate.compareTo(a.addedDate));
        break;
      case SortOption.lastReadDateAsc:
        _books.sort((a, b) {
          if (a.lastReadDate == null && b.lastReadDate == null) return 0;
          if (a.lastReadDate == null) return 1;
          if (b.lastReadDate == null) return -1;
          return a.lastReadDate!.compareTo(b.lastReadDate!);
        });
        break;
      case SortOption.lastReadDateDesc:
        _books.sort((a, b) {
          if (a.lastReadDate == null && b.lastReadDate == null) return 0;
          if (a.lastReadDate == null) return 1;
          if (b.lastReadDate == null) return -1;
          return b.lastReadDate!.compareTo(a.lastReadDate!);
        });
        break;
      case SortOption.titleAsc:
        _books.sort((a, b) {
          final titleA = (a.title ?? a.fileName).toLowerCase();
          final titleB = (b.title ?? b.fileName).toLowerCase();
          return titleA.compareTo(titleB);
        });
        break;
      case SortOption.titleDesc:
        _books.sort((a, b) {
          final titleA = (a.title ?? a.fileName).toLowerCase();
          final titleB = (b.title ?? b.fileName).toLowerCase();
          return titleB.compareTo(titleA);
        });
        break;
      case SortOption.authorAsc:
        _books.sort((a, b) {
          final authorA = (a.author ?? '').toLowerCase();
          final authorB = (b.author ?? '').toLowerCase();
          return authorA.compareTo(authorB);
        });
        break;
      case SortOption.authorDesc:
        _books.sort((a, b) {
          final authorA = (a.author ?? '').toLowerCase();
          final authorB = (b.author ?? '').toLowerCase();
          return authorB.compareTo(authorA);
        });
        break;
      case SortOption.readingProgress:
        _books.sort((a, b) {
          final progressA = a.lastReadChapterIndex ?? -1;
          final progressB = b.lastReadChapterIndex ?? -1;
          return progressB.compareTo(progressA); // 有进度的在前
        });
        break;
    }
  }
  
  /// 显示排序选项对话框
  Future<void> _showSortOptions() async {
    final selectedOption = await showDialog<SortOption>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('排序方式'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: SortOption.values.map((option) {
              return RadioListTile<SortOption>(
                title: Text(_getSortOptionName(option)),
                value: option,
                groupValue: _currentSortOption,
                onChanged: (value) {
                  if (value != null) {
                    Navigator.pop(context, value);
                  }
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    
    if (selectedOption != null && selectedOption != _currentSortOption) {
      setState(() {
        _currentSortOption = selectedOption;
        _sortBooks();
      });
    }
  }
  
  /// 获取排序选项的显示名称
  String _getSortOptionName(SortOption option) {
    switch (option) {
      case SortOption.addedDateAsc:
        return '添加时间（最早）';
      case SortOption.addedDateDesc:
        return '添加时间（最新）';
      case SortOption.lastReadDateAsc:
        return '阅读时间（最早）';
      case SortOption.lastReadDateDesc:
        return '阅读时间（最近）';
      case SortOption.titleAsc:
        return '书名（A-Z）';
      case SortOption.titleDesc:
        return '书名（Z-A）';
      case SortOption.authorAsc:
        return '作者（A-Z）';
      case SortOption.authorDesc:
        return '作者（Z-A）';
      case SortOption.readingProgress:
        return '阅读进度（已读优先）';
    }
  }

  /// 打开书籍详情页
  Future<void> _showBookDetail(BookshelfItem book) async {
    final result = await Navigator.push<BookshelfItem>(
      context,
      MaterialPageRoute(
        builder: (context) => BookDetailPage(
          book: book,
          onBookRemoved: _loadBooks,
        ),
      ),
    );
    
    // 无论是否返回结果，都刷新书架（因为可能在详情页删除了书籍）
    if (mounted) {
      await _loadBooks();
      
      // 如果从详情页返回并选择打开书籍
      if (result != null) {
        widget.onBookSelected(result);
      }
    }
  }

  /// 删除书籍
  Future<void> _deleteBook(BookshelfItem book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要从书架中删除 "${book.fileName}" 吗？\n此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _bookshelfService.removeBook(book.id);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已删除: ${book.fileName}')),
          );
          await _loadBooks();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除失败')),
          );
        }
      }
    }
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '今天';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: widget.onOpenLog,
            tooltip: '运行日志',
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
            tooltip: '排序',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: widget.onAddBook,
            tooltip: '添加书籍',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBooks,
            tooltip: '刷新',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
        children: [
          // 显示当前排序方式
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.sort, size: 16),
                const SizedBox(width: 8),
                Text(
                  '排序: ${_getSortOptionName(_currentSortOption)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showSortOptions,
                  icon: const Icon(Icons.swap_vert, size: 16),
                  label: const Text('更改'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAddBook,
        icon: const Icon(Icons.add),
        label: const Text('添加书籍'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_books.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadBooks,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: _books.length,
        itemBuilder: (context, index) {
          final book = _books[index];
          return _buildBookCard(book);
        },
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 100,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            '书架是空的',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击"+"按钮添加EPUB书籍',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: widget.onAddBook,
            icon: const Icon(Icons.add),
            label: const Text('添加第一本书'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建树籍卡片
  Widget _buildBookCard(BookshelfItem book) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showBookDetail(book),
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 书籍封面
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildCoverImage(book),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 书名
                  Text(
                    book.title ?? book.fileName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 添加时间或最后阅读时间
                  Text(
                    book.lastReadDate != null
                        ? '最近阅读: ${_formatDate(book.lastReadDate!)}'
                        : '添加于: ${_formatDate(book.addedDate)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 阅读进度提示
                  if (book.lastReadChapterIndex != null && book.lastReadChapterIndex! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '继续阅读',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // 删除按钮
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _deleteBook(book),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建封面图片
  Widget _buildCoverImage(BookshelfItem book) {
    if (book.coverImagePath != null && File(book.coverImagePath!).existsSync()) {
      return Image.file(
        File(book.coverImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultCover(book);
        },
      );
    }
    
    return _buildDefaultCover(book);
  }
  
  /// 构建默认封面
  Widget _buildDefaultCover(BookshelfItem book) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.menu_book,
          size: 48,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 排序选项枚举
enum SortOption {
  addedDateAsc,      // 添加时间（最早）
  addedDateDesc,     // 添加时间（最新）
  lastReadDateAsc,   // 阅读时间（最早）
  lastReadDateDesc,  // 阅读时间（最近）
  titleAsc,          // 书名（A-Z）
  titleDesc,         // 书名（Z-A）
  authorAsc,         // 作者（A-Z）
  authorDesc,        // 作者（Z-A）
  readingProgress,   // 阅读进度（已读优先）
}

