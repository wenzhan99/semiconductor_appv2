import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Widget for rendering LaTeX equations with fallback to plain text.
class FormulaLatexView extends StatelessWidget {
  final String latex;
  final TextStyle? textStyle;
  final bool inline;

  const FormulaLatexView({
    super.key,
    required this.latex,
    this.textStyle,
    this.inline = true,
  });

  @override
  Widget build(BuildContext context) {
    if (latex.isEmpty) {
      return const SizedBox.shrink();
    }

    try {
      return Math.tex(
        latex,
        textStyle: textStyle ?? const TextStyle(fontSize: 14),
        mathStyle: inline ? MathStyle.text : MathStyle.display,
      );
    } catch (e) {
      // Fallback to plain text if LaTeX parsing fails
      return Text(
        latex,
        style: textStyle ??
            const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
            ),
      );
    }
  }
}



