import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import 'package:html/dom.dart' as dom;

class CodeBlockWidget extends StatelessWidget {
  final dom.Element element;

  const CodeBlockWidget({
    super.key,
    required this.element,
  });

  @override
  Widget build(BuildContext context) {
    String codeText = _extractCodeText(element);
    String language = _detectLanguage(element);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 语言标签
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.code,
                  size: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  language.isNotEmpty ? language : 'code',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
          // 代码内容
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 48,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 行号列
                    _buildLineNumbers(codeText),
                    const SizedBox(width: 12),
                    // 代码内容列
                    Flexible(
                      child: _buildHighlightedCode(codeText, language, isDarkMode),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _extractCodeText(dom.Element element) {
    // 尝试获取 <code> 标签内的文本
    dom.Element? codeElement = element.querySelector('code');
    if (codeElement != null) {
      return codeElement.text.trim();
    }
    
    // 如果没有 <code> 标签，直接使用 <pre> 的文本
    return element.text.trim();
  }

  String _detectLanguage(dom.Element element) {
    // 从 class 属性中检测语言
    dom.Element? codeElement = element.querySelector('code');
    if (codeElement != null) {
      String? className = codeElement.className;
      if (className != null) {
        // 匹配类似 "language-java" 或 "lang-java" 的类名
        RegExp exp = RegExp(r'(?:language|lang)-(\w+)');
        Match? match = exp.firstMatch(className);
        if (match != null && match.groupCount > 0) {
          return match.group(1)!;
        }
      }
    }

    // 检查 pre 标签的 class
    String? className = element.className;
    if (className != null) {
      RegExp exp = RegExp(r'(?:language|lang)-(\w+)');
      Match? match = exp.firstMatch(className);
      if (match != null && match.groupCount > 0) {
        return match.group(1)!;
      }
    }

    return '';
  }

  Widget _buildHighlightedCode(String code, String language, bool isDarkMode) {
    try {
      if (language.isNotEmpty) {
        // 尝试使用指定的语言进行高亮
        var result = highlight.parse(code, language: language);
        return _buildRichText(result.nodes ?? [], isDarkMode);
      } else {
        // 如果没有指定语言，尝试常见语言
        final commonLanguages = ['dart', 'java', 'python', 'javascript', 'cpp', 'c'];
        for (var lang in commonLanguages) {
          try {
            var result = highlight.parse(code, language: lang);
            // 如果解析成功且有高亮节点，使用该语言
            if (result.nodes != null && result.nodes!.isNotEmpty) {
              return _buildRichText(result.nodes!, isDarkMode);
            }
          } catch (e) {
            // 继续尝试下一种语言
            continue;
          }
        }
      }
    } catch (e) {
      // 如果高亮失败，使用纯文本
    }

    // 回退到纯文本显示
    return Text(
      code,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: isDarkMode ? Colors.white : Colors.black87,
        height: 1.5,
      ),
      textAlign: TextAlign.left,
    );
  }

  Widget _buildRichText(List<Node> nodes, bool isDarkMode) {
    List<TextSpan> spans = _parseNodes(nodes, isDarkMode);
    return RichText(
      text: TextSpan(
        children: spans,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.5,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      textAlign: TextAlign.left,
    );
  }

  Widget _buildLineNumbers(String code) {
    int lineCount = code.split('\n').length;
    List<Widget> lineNumberWidgets = [];
    
    // 计算最大行号的宽度，确保所有行号右对齐且宽度一致
    final maxLineNumberWidth = '$lineCount'.length * 8.0 + 8; // 每个数字约8像素宽，加8像素padding
    
    for (int i = 1; i <= lineCount; i++) {
      lineNumberWidgets.add(
        SizedBox(
          width: maxLineNumberWidth,
          child: Text(
            '$i',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: lineNumberWidgets,
    );
  }

  List<TextSpan> _parseNodes(List<Node> nodes, bool isDarkMode) {
    List<TextSpan> spans = [];
    
    for (var node in nodes) {
      if (node.value != null) {
        // 普通文本节点
        spans.add(TextSpan(text: node.value));
      } else if (node.children != null) {
        // 有子节点的节点，递归处理
        Color? color = _getColorForClass(node.className, isDarkMode);
        List<TextSpan> childSpans = _parseNodes(node.children!, isDarkMode);
        
        if (color != null) {
          spans.add(TextSpan(
            children: childSpans,
            style: TextStyle(color: color),
          ));
        } else {
          spans.addAll(childSpans);
        }
      }
    }
    
    return spans;
  }

  Color? _getColorForClass(String? className, bool isDarkMode) {
    if (className == null) return null;

    // 根据语法高亮的类名映射颜色，区分深色和浅色模式
    if (isDarkMode) {
      // 深色模式颜色（VS Code Dark+ 风格）
      if (className.contains('keyword')) {
        return const Color(0xFF569CD6); // 蓝色 - 关键字
      } else if (className.contains('string')) {
        return const Color(0xFFCE9178); // 橙色 - 字符串
      } else if (className.contains('comment')) {
        return const Color(0xFF6A9955); // 绿色 - 注释
      } else if (className.contains('number')) {
        return const Color(0xFFB5CEA8); // 浅绿 - 数字
      } else if (className.contains('function') || className.contains('title')) {
        return const Color(0xFFDCDCAA); // 黄色 - 函数
      } else if (className.contains('class') || className.contains('type')) {
        return const Color(0xFF4EC9B0); // 青色 - 类名
      } else if (className.contains('variable') || className.contains('name')) {
        return const Color(0xFF9CDCFE); // 浅蓝 - 变量
      } else if (className.contains('meta') || className.contains('preprocessor')) {
        return const Color(0xFFC586C0); // 紫色 - 预处理
      }
    } else {
      // 浅色模式颜色（VS Code Light+ 风格）
      if (className.contains('keyword')) {
        return const Color(0xFF0000FF); // 深蓝色 - 关键字
      } else if (className.contains('string')) {
        return const Color(0xFFA31515); // 深红色 - 字符串
      } else if (className.contains('comment')) {
        return const Color(0xFF008000); // 绿色 - 注释
      } else if (className.contains('number')) {
        return const Color(0xFF098658); // 深绿色 - 数字
      } else if (className.contains('function') || className.contains('title')) {
        return const Color(0xFF795E26); // 棕色 - 函数
      } else if (className.contains('class') || className.contains('type')) {
        return const Color(0xFF267F99); // 青色 - 类名
      } else if (className.contains('variable') || className.contains('name')) {
        return const Color(0xFF001080); // 深蓝 - 变量
      } else if (className.contains('meta') || className.contains('preprocessor')) {
        return const Color(0xFFAF00DB); // 紫色 - 预处理
      }
    }

    return null;
  }
}
