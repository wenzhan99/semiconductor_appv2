import 'dart:math' as math;

/// Formats numbers to LaTeX-friendly strings for charts/readouts.
class LatexNumberFormatter {
  static const _times = r'\times';
  static const _thinSpace = r'\,';
  static const _rm = r'\mathrm';

  /// Format a number to LaTeX scientific notation with specified significant figures.
  /// Example: 0.0000259 -> 2.59 \times 10^{-5}
  static String toScientific(double value, {int sigFigs = 3}) {
    if (value.isNaN || value.isInfinite) return '---';
    if (value == 0) return '0';

    final absValue = value.abs();
    final exponent = (math.log(absValue) / math.ln10).floor();
    final mantissa = value / math.pow(10, exponent);

    // Round mantissa to significant figures
    final factor = math.pow(10, sigFigs - 1);
    final rounded = (mantissa * factor).round() / factor;

    final mantissaStr = _formatMantissa(rounded, sigFigs);
    if (exponent == 0) return mantissaStr;

    return '$mantissaStr$_times 10^{$exponent}';
  }

  /// Unicode scientific notation (no LaTeX) for tooltips/Text widgets.
  static String toUnicodeSci(double value, {int sigFigs = 3}) {
    if (value.isNaN || value.isInfinite) return '--';
    if (value == 0) return '0';
    final absValue = value.abs();
    final exponent = (math.log(absValue) / math.ln10).floor();
    final mantissa = value / math.pow(10, exponent);
    final factor = math.pow(10, sigFigs - 1);
    final rounded = (mantissa * factor).round() / factor;
    final mantissaStr = rounded
        .toStringAsFixed(sigFigs - 1)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
    if (exponent == 0) return mantissaStr;
    return '$mantissaStr\u00d710^$exponent';
  }

  /// Format for axis ticks (cleaner format).
  static String toAxisLabel(double value, {bool preferScientific = false}) {
    if (value.isNaN || value.isInfinite) return '';
    if (value == 0) return '0';

    final absValue = value.abs();
    final exponent = (math.log(absValue) / math.ln10).floor();

    // For small exponents, use regular notation
    if (!preferScientific && exponent >= -2 && exponent <= 3) {
      return value.toStringAsFixed(math.max(0, 2 - exponent));
    }

    // Use scientific notation
    final mantissa = value / math.pow(10, exponent);
    if (mantissa == 1.0 || mantissa == -1.0) {
      return mantissa < 0 ? '-10^{$exponent}' : '10^{$exponent}';
    }

    return '${mantissa.toStringAsFixed(1)}$_times 10^{$exponent}';
  }

  /// Format for log scale axis (just show 10^n)
  static String toLogAxisLabel(double logValue) {
    final exp = logValue.round();
    return '10^{$exp}';
  }

  /// Format with unit in LaTeX. The [unitLatex] should be a LaTeX snippet, e.g. r'\mathrm{m^{-1}}'.
  static String valueWithUnit(double value,
      {required String unitLatex, int sigFigs = 3}) {
    final numStr = toScientific(value, sigFigs: sigFigs);
    final normalizedUnit = _normalizeUnit(unitLatex);
    if (normalizedUnit.isEmpty) return numStr;
    return '$numStr$_thinSpace$normalizedUnit';
  }

  /// Backwards-compatible alias for [valueWithUnit].
  static String withUnit(double value, String unit, {int sigFigs = 3}) =>
      valueWithUnit(value, unitLatex: unit, sigFigs: sigFigs);

  static String _formatMantissa(double value, int sigFigs) {
    if (value == value.round()) {
      return value.round().toString();
    }

    // Determine decimal places needed
    final str = value.toStringAsFixed(sigFigs + 2);
    final cleaned = double.parse(str).toString();
    return cleaned;
  }

  static String _normalizeUnit(String unitLatex) {
    final trimmed = unitLatex.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith(r'\mathrm') ||
        trimmed.startsWith(r'\text') ||
        trimmed.startsWith('\\')) {
      return trimmed;
    }
    return '$_rm{$trimmed}';
  }
}
