import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epubx/epubx.dart' hide Image;

import '../models/bookshelf_item.dart';
import 'logger_service.dart';

/// 书架服务 - 管理书架数据的持久化存储
class BookshelfService {
  static const String _bookshelfKey = 'bookshelf_data';
  static const String _bookshelfDir = 'epub_books';
  
  SharedPreferences? _prefs;
  Directory? _booksDirectory;
  final LoggerService _logger = LoggerService();
  
  /// 初始化服务
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _booksDirectory = await _getBooksDirectory();
  }
  
  /// 获取书籍存储目录
  Future<Directory> _getBooksDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/$_bookshelfDir');
    
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    
    return booksDir;
  }
  
  /// 获取所有书架中的书籍
  List<BookshelfItem> getAllBooks() {
    final String? jsonData = _prefs?.getString(_bookshelfKey);
    if (jsonData == null || jsonData.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonData);
      return jsonList.map((json) => BookshelfItem.fromJson(json)).toList();
    } catch (e) {
      _logger.error('解析书架数据失败: $e');
      return [];
    }
  }
  
  /// 添加书籍到书架
  Future<BookshelfItem?> addBook(String fileName, String filePath) async {
    try {
      // 读取文件内容
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }
      
      final fileBytes = await file.readAsBytes();
      
      // 计算MD5
      final md5 = _calculateMD5(fileBytes);
      
      // 检查是否已存在（通过MD5）
      if (isBookInShelfByMD5(md5)) {
        _logger.warning('书籍已存在于书架中: $fileName');
        return null; // 返回null表示重复
      }
      
      // 解析EPUB获取元数据
      final epubBook = await EpubReader.readBook(fileBytes);
      final title = epubBook.Title ?? fileName;
      final author = epubBook.AuthorList?.isNotEmpty == true 
          ? epubBook.AuthorList!.join(', ') 
          : null;
      
      // 提取封面
      String? coverImagePath;
      try {
        Uint8List? imageBytes;
        
        // 方法1: 尝试从 CoverImage 获取（如果它是 EpubByteContentFile）
        final coverImage = epubBook.CoverImage;
        if (coverImage != null) {
          try {
            // 使用动态类型检查是否是 EpubByteContentFile
            final dynamicCover = coverImage as dynamic;
            if (dynamicCover.Content is Uint8List) {
              imageBytes = dynamicCover.Content as Uint8List;
            }
          } catch (e) {
            _logger.debug('CoverImage 不是 EpubByteContentFile 类型: $e');
          }
        }
        
        // 方法2: 如果 CoverImage 无法获取，尝试从 Content.Images 中查找
        if (imageBytes == null || imageBytes.isEmpty) {
          final images = epubBook.Content?.Images;
          if (images != null && images.isNotEmpty) {
            // 尝试查找常见的封面图片名称
            final coverKeys = [
              'cover',
              'Cover',
              'COVER',
              'cover.jpg',
              'cover.png',
              'Cover.jpg',
              'Cover.png',
            ];
            
            for (final key in coverKeys) {
              if (images.containsKey(key)) {
                final imageFile = images[key];
                if (imageFile?.Content != null && imageFile!.Content!.isNotEmpty) {
                  imageBytes = Uint8List.fromList(imageFile.Content!);
                  _logger.debug('从 Content.Images 找到封面: $key');
                  break;
                }
              }
            }
            
            // 如果还没找到，使用第一张图片
            if ((imageBytes == null || imageBytes.isEmpty) && images.isNotEmpty) {
              final firstImage = images.values.first;
              if (firstImage.Content != null && firstImage.Content!.isNotEmpty) {
                imageBytes = Uint8List.fromList(firstImage.Content!);
                _logger.debug('使用第一张图片作为封面');
              }
            }
          }
        }
        
        // 保存封面图片
        if (imageBytes != null && imageBytes.isNotEmpty) {
          coverImagePath = await _saveCoverImage(md5, imageBytes);
        }
      } catch (e) {
        _logger.error('提取封面失败: $e');
      }
      
      // 复制文件到应用目录
      final String newFilePath = await _copyBookFile(filePath, fileName, md5);
      
      final book = BookshelfItem(
        id: md5, // 使用MD5作为ID
        fileName: fileName,
        filePath: newFilePath,
        md5: md5,
        addedDate: DateTime.now(),
        title: title,
        author: author,
        coverImagePath: coverImagePath,
      );
      
      final books = getAllBooks();
      books.add(book);
      
      await _saveBooks(books);
      return book;
    } catch (e) {
      _logger.error('添加书籍到书架失败: $e');
      return null;
    }
  }
  
  /// 从书架移除书籍
  Future<bool> removeBook(String bookId) async {
    try {
      final books = getAllBooks();
      final bookIndex = books.indexWhere((book) => book.id == bookId);
      
      if (bookIndex == -1) {
        return false;
      }
      
      final book = books[bookIndex];
      
      // 删除文件
      final file = File(book.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // 从列表中移除
      books.removeAt(bookIndex);
      await _saveBooks(books);
      
      return true;
    } catch (e) {
      _logger.error('从书架移除书籍失败: $e');
      return false;
    }
  }
  
  /// 更新书籍阅读进度
  Future<bool> updateReadingProgress(
    String bookId, {
    int? chapterIndex,
    double? fontSize,
    bool? darkMode,
  }) async {
    try {
      final books = getAllBooks();
      final bookIndex = books.indexWhere((book) => book.id == bookId);
      
      if (bookIndex == -1) {
        return false;
      }
      
      final book = books[bookIndex];
      books[bookIndex] = book.copyWith(
        lastReadChapterIndex: chapterIndex ?? book.lastReadChapterIndex,
        lastReadFontSize: fontSize ?? book.lastReadFontSize,
        lastReadDarkMode: darkMode ?? book.lastReadDarkMode,
        lastReadDate: DateTime.now(),
      );
      
      await _saveBooks(books);
      return true;
    } catch (e) {
      _logger.error('更新阅读进度失败: $e');
      return false;
    }
  }
  
  /// 根据ID获取书籍
  BookshelfItem? getBookById(String bookId) {
    final books = getAllBooks();
    try {
      return books.firstWhere((book) => book.id == bookId);
    } catch (e) {
      return null;
    }
  }
  
  /// 检查书籍是否已在书架中（通过MD5）
  bool isBookInShelfByMD5(String md5) {
    final books = getAllBooks();
    return books.any((book) => book.md5 == md5);
  }
  
  /// 检查书籍是否已在书架中（通过文件名，保留用于兼容）
  bool isBookInShelf(String fileName) {
    final books = getAllBooks();
    return books.any((book) => book.fileName == fileName);
  }
  
  /// 复制文件到应用目录
  Future<String> _copyBookFile(String sourcePath, String fileName, String md5) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('源文件不存在: $sourcePath');
    }
    
    // 使用MD5避免文件名冲突
    final safeFileName = '${md5}_$fileName';
    final destPath = '${_booksDirectory!.path}/$safeFileName';
    
    await sourceFile.copy(destPath);
    return destPath;
  }
  
  /// 保存封面图片
  Future<String?> _saveCoverImage(String md5, Uint8List imageBytes) async {
    try {
      final coverDir = Directory('${_booksDirectory!.path}/covers');
      if (!await coverDir.exists()) {
        await coverDir.create(recursive: true);
      }
      
      final coverPath = '${coverDir.path}/${md5}.jpg';
      final coverFile = File(coverPath);
      await coverFile.writeAsBytes(imageBytes);
      
      return coverPath;
    } catch (e) {
      _logger.error('保存封面失败: $e');
      return null;
    }
  }
  
  /// 计算文件MD5
  String _calculateMD5(Uint8List bytes) {
    final digest = md5.convert(bytes);
    return digest.toString();
  }
  
  /// 保存书架数据
  Future<void> _saveBooks(List<BookshelfItem> books) async {
    final jsonData = jsonEncode(books.map((book) => book.toJson()).toList());
    await _prefs?.setString(_bookshelfKey, jsonData);
  }
  
  /// 读取书籍文件内容
  Future<List<int>?> readBookFile(String bookId) async {
    final book = getBookById(bookId);
    if (book == null) {
      return null;
    }
    
    final file = File(book.filePath);
    if (!await file.exists()) {
      return null;
    }
    
    return await file.readAsBytes();
  }
}
