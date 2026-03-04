import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

// Debug mode: set to true to see detailed LaTeX parsing errors
const bool kShowLatexDebug = false;

class LatexText extends StatelessWidget {
  final String tex;
  final TextStyle? style;
  final bool displayMode;
  final double scale;

  const LatexText(
    this.tex, {
    super.key,
    this.style,
    this.displayMode = false,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyMedium;
    final s = (base == null || scale == 1.0)
        ? base
        : base.copyWith(fontSize: (base.fontSize ?? 14) * scale);
    final sanitized = _sanitize(tex);

    if (sanitized.contains('\n')) {
      final lines = sanitized
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (lines.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: lines
            .map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _buildSingle(line, s),
                ))
            .toList(),
      );
    }

    return _buildSingle(sanitized, s);
  }

  Widget _buildSingle(String texLine, TextStyle? s) {
    assert(!texLine.contains('\n'));
    return Math.tex(
      texLine,
      mathStyle: displayMode ? MathStyle.display : MathStyle.text,
      textStyle: s,
      onErrorFallback: (error) {
        if (kDebugMode || kShowLatexDebug) {
          debugPrint('LaTeX parse failed for: $texLine');
        }
        if (kShowLatexDebug) {
          return _LatexErrorWidget(
              latex: texLine, error: error.toString(), style: s);
        }
        return Text(
          'Step contains unsupported formatting',
          style: s?.copyWith(color: const Color(0xFFFF9800)),
        );
      },
    );
  }

  String _sanitize(String input) {
    var out = input.trim();

    // Strip surrounding inline math delimiters
    if (out.length > 4 && out.startsWith(r'\(') && out.endsWith(r'\)')) {
      out = out.substring(2, out.length - 2).trim();
    }
    if (out.length > 2 && out.startsWith(r'$') && out.endsWith(r'$')) {
      out = out.substring(1, out.length - 1).trim();
    }

    // Some upstream strings arrive JSON-escaped (for example `\\mathrm`).
    // Normalize only command-style escapes so TeX line breaks (`\\`) remain intact.
    out = out.replaceAllMapped(
      RegExp(r'\\{2,}(?=[A-Za-z])'),
      (_) => r'\',
    );
    // flutter_math_fork does not support \AA directly; normalize to supported accent form.
    out = out.replaceAll(r'\AA', r'\mathring{A}');
    out = out.replaceAll(r'\aa', r'\mathring{a}');

    // Normalize only specific unicode math glyphs to TeX.
    // Do not rewrite plain ASCII tokens (for example "x"), which corrupts
    // valid math identifiers like x, k_x, max, etc.
    out = out.replaceAll('\u00A0', ' ');
    out = out.replaceAll('\u2212', '-'); // unicode minus
    out = out.replaceAll('\u00d7', r'\times '); // multiplication sign
    out = out.replaceAll('\u22c5', r'\cdot '); // dot operator
    out = out.replaceAll('\u00b7', r'\cdot '); // middle dot

    return out;
  }
}

class _LatexErrorWidget extends StatelessWidget {
  final String latex;
  final String error;
  final TextStyle? style;

  const _LatexErrorWidget(
      {required this.latex, required this.error, this.style});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Latex failed', style: style?.copyWith(color: Colors.red)),
        const SizedBox(height: 4),
        SelectableText(latex,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
        const SizedBox(height: 4),
        SelectableText(error,
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 10, color: Colors.red)),
      ],
    );
  }
}
