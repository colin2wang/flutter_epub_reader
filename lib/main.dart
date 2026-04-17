import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'epub_viewer.dart';

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

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
  }

  void _setupMethodChannel() {
    // 设置方法调用处理器，接收来自原生代码的文件
    platform.setMethodCallHandler((call) async {
      if (call.method == 'openFile') {
        final args = call.arguments as Map<dynamic, dynamic>;
        final String fileName = args['fileName'] as String;
        final Uint8List fileBytes = args['fileBytes'] as Uint8List;
        
        print('收到来自原生代码的文件: $fileName, 大小: ${fileBytes.length} bytes');
        
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
        
        // 优先使用 bytes，如果为 null 则从路径读取文件
        if (file.bytes != null && file.bytes!.isNotEmpty) {
          fileBytes = file.bytes!;
          print('从内存加载文件: ${file.name}, 大小: ${fileBytes.length} bytes');
        } else if (file.path != null && file.path!.isNotEmpty) {
          try {
            final sourceFile = File(file.path!);
            if (!await sourceFile.exists()) {
              throw Exception('文件不存在: ${file.path}');
            }
            fileBytes = await sourceFile.readAsBytes();
            print('从路径加载文件: ${file.name}, 大小: ${fileBytes.length} bytes');
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
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EpubViewer(
                epubBytes: fileBytes,
                fileName: _fileName!,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('打开文件时出错: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ePub Reader'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
