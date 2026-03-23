import 'package:flutter/material.dart';
import '../../widgets/latex_text.dart';

/// A widget that renders text with inline LaTeX tokens.
/// 
/// Usage:
/// ```dart
/// LatexRichText.parse(
///   'The bandgap $E_g$ affects carrier concentration $n_i$.',
///   style: TextStyle(fontSize: 14),
/// )
/// ```
/// 
/// Tokens wrapped in $ symbols are rendered as LaTeX inline math.
class LatexRichText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double latexScale;

  const LatexRichText(
    this.text, {
    super.key,
    this.style,
    this.latexScale = 1.0,
  });

  /// Parse text and render mixed plain text + LaTeX inline
  factory LatexRichText.parse(
    String text, {
    Key? key,
    TextStyle? style,
    double latexScale = 1.0,
  }) {
    return LatexRichText(
      text,
      key: key,
      style: style,
      latexScale: latexScale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    final parts = _parseInlineLatex(text);

    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }

    // If only one part and it's plain text, render as Text widget
    if (parts.length == 1 && !parts[0].isLatex) {
      return Text(parts[0].content, style: baseStyle);
    }

    // Mix of text and LaTeX - use Wrap to handle inline layout
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts.map((part) {
        if (part.isLatex) {
          return LatexText(
            part.content,
            style: baseStyle,
            scale: latexScale,
          );
        } else {
          return Text(part.content, style: baseStyle);
        }
      }).toList(),
    );
  }

  List<_TextPart> _parseInlineLatex(String input) {
    final parts = <_TextPart>[];
    final buffer = StringBuffer();
    var inLatex = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];

      if (char == r'$') {
        // Flush current buffer
        if (buffer.isNotEmpty) {
          parts.add(_TextPart(buffer.toString(), isLatex: inLatex));
          buffer.clear();
        }
        inLatex = !inLatex;
      } else {
        buffer.write(char);
      }
    }

    // Flush remaining
    if (buffer.isNotEmpty) {
      parts.add(_TextPart(buffer.toString(), isLatex: inLatex));
    }

    return parts;
  }
}

class _TextPart {
  final String content;
  final bool isLatex;

  _TextPart(this.content, {required this.isLatex});
}
