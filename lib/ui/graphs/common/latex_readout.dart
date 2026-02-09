import 'package:flutter/material.dart';

import '../../../core/solver/number_formatter.dart';
import '../../widgets/latex_text.dart';

/// Shared formatter helpers for chart readouts and tooltips.
class LatexReadoutFormatter {
  /// Textbook scientific notation (always scientific) with no units.
  static String sci(double value, {int sigFigs = 3}) {
    final fmt = NumberFormatter(
      significantFigures: sigFigs,
      sciThresholdExp: -1000, // force sci form
    );
    final out = fmt.formatLatex(value);
    _guard(out);
    return out;
  }

  /// Format a plain unit token into \mathrm{...} (renderer-safe upright units).
  static String unitText(String unit) {
    final trimmed = unit.trim();
    if (trimmed.isEmpty) return '';
    final out = r'\mathrm{' + trimmed + r'}';
    _guard(out);
    return out;
  }

  /// Format value with a unit expressed in \text{...}.
  static String valueWithUnitText(
    double value, {
    required String unit,
    int sigFigs = 3,
    bool forceSci = true,
  }) {
    final numStr = forceSci
        ? sci(value, sigFigs: sigFigs)
        : NumberFormatter(significantFigures: sigFigs).formatLatex(value);
    if (unit.isEmpty) return numStr;
    final out = '$numStr\\,${unitText(unit)}';
    _guard(out);
    return out;
  }

  /// Build a simple equation-like readout: label = value [unit].
  static String equation({
    required String labelLatex,
    required String valueLatex,
    String unit = '',
  }) {
    final unitPart = unit.isEmpty ? '' : '\\,${unitText(unit)}';
    final out = '$labelLatex = $valueLatex$unitPart';
    _guard(out);
    return out;
  }

  static void _guard(String latex) {
    assert(!latex.contains('<span'), 'HTML leaked into LaTeX source: $latex');
    assert(!latex.contains('class='), 'HTML leaked into LaTeX source: $latex');
    assert(!latex.contains('katex'), 'KaTeX HTML leaked into LaTeX: $latex');
    assert(!latex.contains('mord'), 'KaTeX HTML leaked into LaTeX: $latex');
  }
}

/// Simple reusable readout row: renders label/value via LatexText.
class LatexReadoutRow extends StatelessWidget {
  final String labelLatex;
  final String valueLatex;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final double labelWidth;

  const LatexReadoutRow({
    super.key,
    required this.labelLatex,
    required this.valueLatex,
    this.labelStyle,
    this.valueStyle,
    this.labelWidth = 160,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: LatexText(
              labelLatex,
              style: labelStyle ?? const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: LatexText(
              valueLatex,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}
