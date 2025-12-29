import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

const bool kShowLatexDebug = true;

class LatexText extends StatelessWidget {
  final String latex;
  final TextStyle? style;
  final bool displayMode;
  final double scale;

  const LatexText(
    this.latex, {
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
    final sanitized = _sanitizeLine(latex);
    
    // HARD INVARIANT: MathTex MUST receive exactly ONE math expression (no newline).
    // If latex contains '\n', split it into separate lines BEFORE rendering.
    if (sanitized.contains('\n')) {
      final parts = sanitized.split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      
      if (parts.isEmpty) {
        return const SizedBox.shrink();
      }
      
      // Render each part separately
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: parts.map((part) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildSingleLine(part, s),
          );
        }).toList(),
      );
    }
    
    // Single line - render directly
    return _buildSingleLine(sanitized, s);
  }
  
  Widget _buildSingleLine(String singleLatex, TextStyle? s) {
    // Assert: singleLatex must not contain '\n'
    assert(!singleLatex.contains('\n'), 'LatexText._buildSingleLine received string with newline: $singleLatex');
    
    return Math.tex(
      singleLatex,
      mathStyle: displayMode ? MathStyle.display : MathStyle.text,
      textStyle: s,
      // Avoid showing raw LaTeX when parsing fails; show a friendly fallback instead.
      onErrorFallback: (_) {
        if (kShowLatexDebug) {
          // Debug print the full failing latex string
          debugPrint('MATH_TEX_FAIL: $singleLatex');
          
          // Create a truncated preview (first 120 chars)
          final preview = singleLatex.length > 120 
              ? '${singleLatex.substring(0, 120)}...' 
              : singleLatex;
          
          return Text(
            'Unable to render this math line: $preview',
            style: s,
          );
        } else {
          return Text(
            'Unable to render this math line',
            style: s,
          );
        }
      },
    );
  }

  /// Fixes common malformed patterns before handing off to Math.tex.
  String _sanitizeLine(String raw) {
    var out = raw.trim();
    var changed = false;

    void applyIf(bool condition, String Function(String) fn) {
      if (!condition) return;
      final next = fn(out);
      if (next != out) {
        changed = true;
        out = next;
      }
    }

    // Collapse accidental double escapes (\\frac -> \frac).
    applyIf(out.contains('\\\\'), (s) => s.replaceAll('\\\\', '\\'));

    // Repair missing backslash before \left in exp.
    applyIf(out.contains('\\exp left'), (s) => s.replaceAll('\\exp left', '\\exp\\left'));

    // Remove stray escaped braces like \{ or \}.
    applyIf(out.contains('\\{'), (s) => s.replaceAll('\\{', '{'));
    applyIf(out.contains('\\}'), (s) => s.replaceAll('\\}', '}'));

    // Clean patterns like N_{v\} -> N_{v}
    applyIf(
      RegExp(r'_{[^}]*\\}').hasMatch(out),
      (s) => s.replaceAllMapped(
        RegExp(r'_{([^}]*)\\}'),
        (m) => '_{${m.group(1)}}',
      ),
    );

    if (kShowLatexDebug && changed) {
      debugPrint('LATEX_SANITIZE: $raw -> $out');
    }
    return out;
  }
}
