# ePub Reader - Flutter 电子书阅读器

一个功能完整的 ePub 电子书阅读工具，支持代码块的正确显示和语法高亮。

## 功能特性

- 打开和阅读 ePub 格式电子书
- 章节导航和切换
- 支持代码块显示
- 代码语法高亮（支持多种编程语言）
- 响应式界面设计
- 支持 Android、Windows 平台

## 依赖包

本项目使用了以下主要依赖：

- **epubx**: ePub 文件解析
- **file_picker**: 文件选择器
- **flutter_widget_from_html**: HTML 内容渲染
- **highlight**: 代码语法高亮
- **html**: HTML 解析

## 使用方法

1. **安装依赖**
   ```bash
   flutter pub get
   ```

2. **运行应用**
   ```bash
   flutter run
   ```

3. **打开 ePub 文件**
   - 点击主界面的"选择 ePub 文件"按钮
   - 从设备中选择要阅读的 .epub 文件
   - 应用会自动加载并显示书籍内容

4. **阅读功能**
   - 使用底部导航栏的左右箭头切换章节
   - 点击右上角的列表图标查看章节列表
   - 代码块会自动识别并显示语法高亮

## 代码块支持

阅读器能够正确识别和显示 ePub 文件中的代码块，包括：

- 自动检测代码语言（通过 `class="language-xxx"` 或 `class="lang-xxx"`）
- 支持多种编程语言的语法高亮：
  - Java, Python, JavaScript, C/C++
  - HTML, CSS, SQL
  - 以及其他 highlight.js 支持的语言
- 深色主题代码显示
- 可选择的代码文本

## 项目结构

```
lib/
├── main.dart                 # 应用入口和主页
├── epub_viewer.dart          # ePub 阅读器主组件
└── code_block_widget.dart    # 代码块显示组件
```

## 注意事项

### Android 权限

在 Android 设备上使用时，需要在系统设置中授予存储权限以访问 ePub 文件。

### Windows 开发者模式

在 Windows 上运行时，需要启用开发者模式以支持插件符号链接：
1. 打开设置
2. 进入"更新和安全" > "开发者选项"
3. 启用"开发者模式"

## 技术实现

### 代码高亮实现

代码块组件使用 `highlight` 包进行语法分析，并根据不同的语法元素应用相应的颜色：

- 关键字：蓝色
- 字符串：橙色
- 注释：绿色
- 数字：浅绿色
- 函数名：黄色
- 类名：青色
- 变量名：浅蓝色

### HTML 渲染

使用 `flutter_widget_from_html` 包渲染 ePub 中的 HTML 内容，并通过自定义 widget 构建器处理代码块元素。

## 未来改进方向

- [ ] 添加书签功能
- [ ] 支持字体大小调整
- [ ] 支持夜间模式
- [ ] 添加搜索功能
- [ ] 记住阅读进度
- [ ] 支持更多文件格式（PDF, MOBI等）

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！
