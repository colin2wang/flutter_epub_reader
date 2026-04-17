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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
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
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  language.isNotEmpty ? language : 'code',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.grey),
          // 代码内容
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildHighlightedCode(codeText, language),
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

  Widget _buildHighlightedCode(String code, String language) {
    try {
      if (language.isNotEmpty) {
        // 尝试使用指定的语言进行高亮
        var result = highlight.parse(code, language: language);
        return _buildRichText(result.nodes ?? []);
      } else {
        // 如果没有指定语言，尝试常见语言
        final commonLanguages = ['dart', 'java', 'python', 'javascript', 'cpp', 'c'];
        for (var lang in commonLanguages) {
          try {
            var result = highlight.parse(code, language: lang);
            // 如果解析成功且有高亮节点，使用该语言
            if (result.nodes != null && result.nodes!.isNotEmpty) {
              return _buildRichText(result.nodes!);
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
    return SelectableText(
      code,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: Colors.white,
        height: 1.5,
      ),
    );
  }

  Widget _buildRichText(List<Node> nodes) {
    List<TextSpan> spans = _parseNodes(nodes);
    return SelectableText.rich(
      TextSpan(
        children: spans,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  List<TextSpan> _parseNodes(List<Node> nodes) {
    List<TextSpan> spans = [];
    
    for (var node in nodes) {
      if (node.value != null) {
        // 普通文本节点
        spans.add(TextSpan(text: node.value));
      } else if (node.children != null) {
        // 有子节点的节点，递归处理
        Color? color = _getColorForClass(node.className);
        List<TextSpan> childSpans = _parseNodes(node.children!);
        
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

  Color? _getColorForClass(String? className) {
    if (className == null) return null;

    // 根据语法高亮的类名映射颜色
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

    return null;
  }
}
