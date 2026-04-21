import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'epub_viewer.dart';
import 'models/bookshelf_item.dart';
import 'services/bookshelf_service.dart';
import 'services/logger_service.dart';
import 'widgets/bookshelf_page.dart';
import 'widgets/log_viewer_page.dart';

void main() {
  runApp(const EpubReaderApp());
}

class EpubReaderApp extends StatelessWidget {
  const EpubReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ePub Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const EpubHomePage(),
    );
  }
}

class EpubHomePage extends StatefulWidget {
  const EpubHomePage({super.key});

  @override
  State<EpubHomePage> createState() => _EpubHomePageState();
}

class _EpubHomePageState extends State<EpubHomePage> {
  String? _fileName;
  bool _isLoading = false;
  static const platform = MethodChannel('com.colin2wang.epub_reader/file');
  final BookshelfService _bookshelfService = BookshelfService();
  final LoggerService _loggerService = LoggerService();

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
    _initializeBookshelf();
  }

  /// 初始化书架服务
  Future<void> _initializeBookshelf() async {
    await _bookshelfService.initialize();
    // 初始化日志服务
    await _loggerService.initialize();
  }

  void _setupMethodChannel() {
    // 设置方法调用处理器，接收来自原生代码的文件
    platform.setMethodCallHandler((call) async {
      if (call.method == 'openFile') {
        final args = call.arguments as Map<dynamic, dynamic>;
        final String fileName = args['fileName'] as String;
        final Uint8List fileBytes = args['fileBytes'] as Uint8List;
        
        _loggerService.info('收到来自原生代码的文件: $fileName, 大小: ${fileBytes.length} bytes');
        
        if (mounted) {
          _openFileFromNative(fileName, fileBytes);
        }
      }
    });
  }

  void _openFileFromNative(String fileName, Uint8List fileBytes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EpubViewer(
          epubBytes: fileBytes,
          fileName: fileName,
        ),
      ),
    );
  }

  /// 打开书架页面
  void _openBookshelf() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookshelfPage(
          onBookSelected: _openBookFromShelf,
          onAddBook: _openEpubFile,
        ),
      ),
    ).then((_) {
      // 从书架页面返回时，不需要特殊处理
    });
  }

  /// 从书架打开书籍
  Future<void> _openBookFromShelf(BookshelfItem book) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final fileBytes = await _bookshelfService.readBookFile(book.id);
      
      if (fileBytes == null || fileBytes.isEmpty) {
        throw Exception('无法读取书籍文件');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // 关闭书架页面
        Navigator.pop(context);

        // 打开阅读器
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EpubViewer(
              epubBytes: Uint8List.fromList(fileBytes),
              fileName: book.fileName,
              filePath: book.filePath,
            ),
          ),
        );
        
        // 从阅读器返回后，如果需要可以做一些处理
      }
    } catch (e) {
      _loggerService.error('打开书籍失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('打开书籍失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _openEpubFile() async {
    try {
      setState(() {
        _isLoading = true;
      });

      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
        withData: true, // 确保文件内容被加载到内存
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        
        // 验证文件名
        if (file.name.isEmpty) {
          throw Exception('文件名无效');
        }
        
        Uint8List fileBytes;
        String? filePath;
        
        // 优先使用 bytes，如果为 null 则从路径读取文件
        if (file.bytes != null && file.bytes!.isNotEmpty) {
          fileBytes = file.bytes!;
          filePath = file.path; // 保存文件路径用于添加到书架
          _loggerService.info('从内存加载文件: ${file.name}, 大小: ${fileBytes.length} bytes');
        } else if (file.path != null && file.path!.isNotEmpty) {
          try {
            final sourceFile = File(file.path!);
            if (!await sourceFile.exists()) {
              throw Exception('文件不存在: ${file.path}');
            }
            fileBytes = await sourceFile.readAsBytes();
            filePath = file.path;
            _loggerService.info('从路径加载文件: ${file.name}, 大小: ${fileBytes.length} bytes');
          } catch (e) {
            throw Exception('读取文件失败: $e');
          }
        } else {
          throw Exception('无法获取文件数据');
        }
        
        // 验证文件大小
        if (fileBytes.isEmpty) {
          throw Exception('文件内容为空');
        }
        
        if (mounted) {
          setState(() {
            _fileName = file.name;
            _isLoading = false;
          });
          
          // 询问用户是否添加到书架
          final addToShelf = await _showAddToShelfDialog(file.name);
          
          if (addToShelf == true && filePath != null) {
            // 添加到书架
            await _addToShelf(file.name, filePath);
            
            // 询问用户是否要打开图书
            final shouldOpen = await _showOpenBookDialog(file.name);
            
            if (shouldOpen == true) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EpubViewer(
                    epubBytes: fileBytes,
                    fileName: _fileName!,
                    filePath: filePath,
                  ),
                ),
              );
            }
          } else {
            // 不添加到书架，直接打开
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EpubViewer(
                  epubBytes: fileBytes,
                  fileName: _fileName!,
                  filePath: filePath,
                ),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      _loggerService.error('打开文件时出错: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('打开文件失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 显示添加到书架对话框
  Future<bool?> _showAddToShelfDialog(String fileName) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加到书架'),
        content: Text('是否将 "$fileName" 添加到书架？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('不添加'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('添加到书架'),
          ),
        ],
      ),
    );
  }

  /// 显示是否打开图书对话框
  Future<bool?> _showOpenBookDialog(String fileName) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加成功'),
        content: Text('"$fileName" 已添加到书架\n\n是否现在打开阅读？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('稍后阅读'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('立即打开'),
          ),
        ],
      ),
    );
  }

  /// 添加书籍到书架
  Future<void> _addToShelf(String fileName, String filePath) async {
    try {
      final book = await _bookshelfService.addBook(fileName, filePath);
      
      if (mounted) {
        if (book != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已添加到书架: $fileName')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加到书架失败')),
          );
        }
      }
    } catch (e) {
      _loggerService.error('添加到书架失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加到书架失败: $e')),
        );
      }
    }
  }

  /// 打开日志窗口
  void _openLogViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LogViewerPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ePub Reader'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmarks),
            onPressed: _openBookshelf,
            tooltip: '我的书架',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _openLogViewer,
            tooltip: '运行日志',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'ePub 阅读器',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            if (_fileName != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '上次打开: $_fileName',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _openEpubFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('选择 ePub 文件'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openBookshelf,
              icon: const Icon(Icons.bookmarks),
              label: const Text('我的书架'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '支持显示代码块和语法高亮',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
