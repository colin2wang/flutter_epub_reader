import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import 'code_block_widget.dart';

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
  EpubBook? _book;
  List<EpubChapter>? _chapters;
  int _currentChapterIndex = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEpub();
  }

  Future<void> _loadEpub() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      EpubBook book = await EpubReader.readBook(widget.epubBytes);
      List<EpubChapter> chapters = book.Chapters!;

      setState(() {
        _book = book;
        _chapters = chapters;
        _currentChapterIndex = 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '加载 ePub 文件失败: $e';
      });
    }
  }

  void _nextChapter() {
    if (_chapters != null && _currentChapterIndex < _chapters!.length - 1) {
      setState(() {
        _currentChapterIndex++;
      });
    }
  }

  void _previousChapter() {
    if (_currentChapterIndex > 0) {
      setState(() {
        _currentChapterIndex--;
      });
    }
  }

  void _showChapterList() {
    if (_chapters == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: _chapters!.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(
              _chapters![index].Title ?? 'Chapter ${index + 1}',
              style: TextStyle(
                color: index == _currentChapterIndex
                    ? Theme.of(context).colorScheme.primary
                    : null,
                fontWeight: index == _currentChapterIndex
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _currentChapterIndex = index;
              });
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName,
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _showChapterList,
            tooltip: '章节列表',
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
              : _buildContent(),
      bottomNavigationBar: _buildNavigation(),
    );
  }

  Widget _buildContent() {
    if (_chapters == null || _currentChapterIndex >= _chapters!.length) {
      return const Center(child: Text('没有内容'));
    }

    EpubChapter chapter = _chapters![_currentChapterIndex];
    String? content = chapter.HtmlContent;

    if (content == null || content.isEmpty) {
      return const Center(child: Text('章节内容为空'));
    }

    return SingleChildScrollView(
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
            textStyle: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    if (_chapters == null) return const SizedBox.shrink();

    return Container(
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
            '${_currentChapterIndex + 1} / ${_chapters!.length}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _currentChapterIndex < _chapters!.length - 1
                ? _nextChapter
                : null,
            tooltip: '下一章',
          ),
        ],
      ),
    );
  }
}
