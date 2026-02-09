import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

// Debug mode: set to true to see detailed LaTeX parsing errors
const bool kShowLatexDebug = false;

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
      onErrorFallback: (error) {
        if (kShowLatexDebug) {
          // Debug print the full failing latex string and error
          debugPrint('═══════════════════════════════════════════════════════');
          debugPrint('MATH_TEX_FAIL:');
          debugPrint('LaTeX: $singleLatex');
          debugPrint('Error: ${error.toString()}');
          debugPrint('═══════════════════════════════════════════════════════');
          
          // In debug mode, show expandable error with raw LaTeX
          return _LatexErrorWidget(
            latex: singleLatex,
            error: error.toString(),
            style: s,
          );
        } else {
          return Text(
            'Step contains unsupported formatting',
            style: s?.copyWith(color: const Color(0xFFFF9800)), // Orange color for user-facing error
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

    // Remove any accidental internal tags/markers (e.g., '<math_...>' or similar)
    applyIf(out.contains('<'), (s) => s.replaceAll(RegExp(r'<[^>]*>'), ''));

    // Replace Unicode math characters that break LaTeX parsing
    applyIf(out.contains('×'), (s) => s.replaceAll('×', r'\times'));
    applyIf(out.contains('·'), (s) => s.replaceAll('·', r'\cdot'));
    applyIf(out.contains('−'), (s) => s.replaceAll('−', '-')); // Unicode minus to ASCII hyphen
    
    // Replace non-breaking spaces with regular spaces
    applyIf(out.contains('\u00A0'), (s) => s.replaceAll('\u00A0', ' '));
    
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
    
    // Remove stray alignment markers (&) that might be left from aligned environments
    applyIf(out.contains('&'), (s) => s.replaceAll('&', ''));
    
    // Remove trailing \\\\ that might be left from aligned environments
    applyIf(out.endsWith(r'\\'), (s) => s.substring(0, s.length - 2).trim());

    if (kShowLatexDebug && changed) {
      debugPrint('LATEX_SANITIZE: $raw -> $out');
    }
    return out;
  }
}

/// Debug-only widget that displays LaTeX parsing errors with expandable raw content
class _LatexErrorWidget extends StatefulWidget {
  final String latex;
  final String error;
  final TextStyle? style;

  const _LatexErrorWidget({
    required this.latex,
    required this.error,
    this.style,
  });

  @override
  State<_LatexErrorWidget> createState() => _LatexErrorWidgetState();
}

class _LatexErrorWidgetState extends State<_LatexErrorWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: Colors.red,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Unable to render this math line (tap to ${_expanded ? 'hide' : 'show'} details)',
                  style: widget.style?.copyWith(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Raw LaTeX:',
                  style: widget.style?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  widget.latex,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Error:',
                  style: widget.style?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  widget.error,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
