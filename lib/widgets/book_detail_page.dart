import 'dart:io';
import 'package:flutter/material.dart';
import '../models/bookshelf_item.dart';
import '../services/bookshelf_service.dart';

/// 书籍详情页面
class BookDetailPage extends StatefulWidget {
  final BookshelfItem book;
  final VoidCallback? onBookRemoved;

  const BookDetailPage({
    super.key,
    required this.book,
    this.onBookRemoved,
  });

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final BookshelfService _bookshelfService = BookshelfService();

  @override
  void initState() {
    super.initState();
    _bookshelfService.initialize();
  }

  /// 打开书籍阅读
  void _openBook() {
    Navigator.pop(context, widget.book); // 返回书籍对象
  }

  /// 从书架移除
  Future<void> _removeFromShelf() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要从书架中删除 "${widget.book.fileName}" 吗？\n此操作不可恢复。'),
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
      final success = await _bookshelfService.removeBook(widget.book.id);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已删除: ${widget.book.fileName}')),
          );
          
          // 通知父页面刷新
          widget.onBookRemoved?.call();
          
          // 关闭详情页
          Navigator.pop(context, null);
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
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书籍详情'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _removeFromShelf,
            tooltip: '从书架移除',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图片
            Center(
              child: Container(
                width: 200,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildCoverImage(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 书籍标题
            Text(
              widget.book.title ?? widget.book.fileName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // 作者
            if (widget.book.author != null) ...[
              Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.book.author!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            // 文件名
            Row(
              children: [
                const Icon(Icons.description, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.book.fileName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 分隔线
            const Divider(thickness: 1),
            const SizedBox(height: 16),
            
            // 阅读进度
            if (widget.book.lastReadChapterIndex != null && widget.book.lastReadChapterIndex! > 0) ...[
              _buildInfoRow(
                Icons.check_circle,
                '阅读进度',
                '第 ${widget.book.lastReadChapterIndex! + 1} 章',
                Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
            ],
            
            // 添加时间
            _buildInfoRow(
              Icons.add_circle,
              '添加时间',
              _formatDate(widget.book.addedDate),
            ),
            const SizedBox(height: 12),
            
            // 最后阅读时间
            if (widget.book.lastReadDate != null) ...[
              _buildInfoRow(
                Icons.access_time,
                '最后阅读',
                _formatDate(widget.book.lastReadDate!),
              ),
              const SizedBox(height: 12),
            ],
            
            // MD5
            _buildInfoRow(
              Icons.fingerprint,
              '文件MD5',
              widget.book.md5.substring(0, 16) + '...',
              Colors.grey,
              12,
            ),
            
            const SizedBox(height: 32),
            
            // 打开书籍按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _openBook,
                icon: const Icon(Icons.menu_book, size: 24),
                label: const Text(
                  '打开书籍',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
  Widget _buildCoverImage() {
    if (widget.book.coverImagePath != null && File(widget.book.coverImagePath!).existsSync()) {
      return Image.file(
        File(widget.book.coverImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultCover();
        },
      );
    }
    
    return _buildDefaultCover();
  }

  /// 构建默认封面
  Widget _buildDefaultCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.7),
            Theme.of(context).colorScheme.secondary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 64,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.book.title ?? widget.book.fileName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, [
    Color? iconColor,
    double fontSize = 14,
  ]) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor ?? Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

