/// 书架书籍数据模型
class BookshelfItem {
  final String id; // 唯一标识符（基于MD5）
  final String fileName; // 文件名
  final String filePath; // 文件路径（用于从存储读取）
  final String md5; // 文件MD5值，用于去重
  final DateTime addedDate; // 添加到书架的日期
  final int? lastReadChapterIndex; // 最后阅读的章节索引
  final double? lastReadFontSize; // 最后使用的字体大小
  final bool? lastReadDarkMode; // 最后使用的夜间模式设置
  final DateTime? lastReadDate; // 最后阅读时间
  final String? coverImagePath; // 封面图片路径
  final String? title; // 书籍标题
  final String? author; // 作者

  BookshelfItem({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.md5,
    required this.addedDate,
    this.lastReadChapterIndex,
    this.lastReadFontSize,
    this.lastReadDarkMode,
    this.lastReadDate,
    this.coverImagePath,
    this.title,
    this.author,
  });

  /// 从 JSON 创建实例
  factory BookshelfItem.fromJson(Map<String, dynamic> json) {
    return BookshelfItem(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      filePath: json['filePath'] as String,
      md5: json['md5'] as String,
      addedDate: DateTime.parse(json['addedDate'] as String),
      lastReadChapterIndex: json['lastReadChapterIndex'] as int?,
      lastReadFontSize: (json['lastReadFontSize'] as num?)?.toDouble(),
      lastReadDarkMode: json['lastReadDarkMode'] as bool?,
      lastReadDate: json['lastReadDate'] != null 
          ? DateTime.parse(json['lastReadDate'] as String) 
          : null,
      coverImagePath: json['coverImagePath'] as String?,
      title: json['title'] as String?,
      author: json['author'] as String?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'md5': md5,
      'addedDate': addedDate.toIso8601String(),
      'lastReadChapterIndex': lastReadChapterIndex,
      'lastReadFontSize': lastReadFontSize,
      'lastReadDarkMode': lastReadDarkMode,
      'lastReadDate': lastReadDate?.toIso8601String(),
      'coverImagePath': coverImagePath,
      'title': title,
      'author': author,
    };
  }

  /// 复制并修改部分属性
  BookshelfItem copyWith({
    String? id,
    String? fileName,
    String? filePath,
    String? md5,
    DateTime? addedDate,
    int? lastReadChapterIndex,
    double? lastReadFontSize,
    bool? lastReadDarkMode,
    DateTime? lastReadDate,
    String? coverImagePath,
    String? title,
    String? author,
  }) {
    return BookshelfItem(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      md5: md5 ?? this.md5,
      addedDate: addedDate ?? this.addedDate,
      lastReadChapterIndex: lastReadChapterIndex ?? this.lastReadChapterIndex,
      lastReadFontSize: lastReadFontSize ?? this.lastReadFontSize,
      lastReadDarkMode: lastReadDarkMode ?? this.lastReadDarkMode,
      lastReadDate: lastReadDate ?? this.lastReadDate,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      title: title ?? this.title,
      author: author ?? this.author,
    );
  }
}
