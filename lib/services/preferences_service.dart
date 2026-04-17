import 'package:shared_preferences/shared_preferences.dart';

/// 偏好设置服务 - 管理阅读器的用户偏好
class PreferencesService {
  static const String _keyFontSize = 'font_size_';
  static const String _keyDarkMode = 'dark_mode_';
  static const String _keyChapterIndex = 'chapter_index_';
  static const String _keyShowBottomBar = 'show_bottom_bar_';
  
  SharedPreferences? _prefs;
  
  /// 初始化服务
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// 获取 SharedPreferences 实例
  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('PreferencesService 尚未初始化，请先调用 initialize()');
    }
    return _prefs!;
  }
  
  /// 生成基于文件名的唯一键
  String _getFileKey(String fileName) {
    return fileName.hashCode.toString();
  }
  
  /// 加载字体大小
  double loadFontSize(String fileName) {
    final String fileKey = _getFileKey(fileName);
    return prefs.getDouble(_keyFontSize + fileKey) ?? 16.0;
  }
  
  /// 保存字体大小
  Future<void> saveFontSize(String fileName, double fontSize) async {
    final String fileKey = _getFileKey(fileName);
    await prefs.setDouble(_keyFontSize + fileKey, fontSize);
  }
  
  /// 加载夜间模式设置
  bool loadDarkMode(String fileName) {
    final String fileKey = _getFileKey(fileName);
    return prefs.getBool(_keyDarkMode + fileKey) ?? false;
  }
  
  /// 保存夜间模式设置
  Future<void> saveDarkMode(String fileName, bool isDarkMode) async {
    final String fileKey = _getFileKey(fileName);
    await prefs.setBool(_keyDarkMode + fileKey, isDarkMode);
  }
  
  /// 加载章节索引
  int loadChapterIndex(String fileName) {
    final String fileKey = _getFileKey(fileName);
    return prefs.getInt(_keyChapterIndex + fileKey) ?? 0;
  }
  
  /// 保存章节索引
  Future<void> saveChapterIndex(String fileName, int chapterIndex) async {
    final String fileKey = _getFileKey(fileName);
    await prefs.setInt(_keyChapterIndex + fileKey, chapterIndex);
  }
  
  /// 加载是否显示底部导航栏
  bool loadShowBottomBar(String fileName) {
    final String fileKey = _getFileKey(fileName);
    return prefs.getBool(_keyShowBottomBar + fileKey) ?? true;
  }
  
  /// 保存是否显示底部导航栏
  Future<void> saveShowBottomBar(String fileName, bool showBottomBar) async {
    final String fileKey = _getFileKey(fileName);
    await prefs.setBool(_keyShowBottomBar + fileKey, showBottomBar);
  }
  
  /// 保存所有设置
  Future<void> saveAllSettings(String fileName, {
    required double fontSize,
    required bool isDarkMode,
    required int chapterIndex,
    bool? showBottomBar,
  }) async {
    final String fileKey = _getFileKey(fileName);
    await prefs.setDouble(_keyFontSize + fileKey, fontSize);
    await prefs.setBool(_keyDarkMode + fileKey, isDarkMode);
    await prefs.setInt(_keyChapterIndex + fileKey, chapterIndex);
    if (showBottomBar != null) {
      await prefs.setBool(_keyShowBottomBar + fileKey, showBottomBar);
    }
  }
}
