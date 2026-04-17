import 'package:epubx/epubx.dart' hide Image;

/// 扁平化的章节结构,用于显示
class FlatChapter {
  final EpubChapter chapter;
  final int index;
  final int level; // 层级深度,0为顶层
  
  FlatChapter({
    required this.chapter,
    required this.index,
    required this.level,
  });
}
