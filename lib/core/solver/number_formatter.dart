import 'dart:math' as math;

/// Formats numbers for display in LaTeX and plain text.
class NumberFormatter {
  final int significantFigures;
  final int sciThresholdExp; // use sci if |exp| >= threshold

  const NumberFormatter({
    this.significantFigures = 3,
    this.sciThresholdExp = 3,
  });

  /// Format a number to LaTeX (textbook scientific notation).
  /// Example: 0.0000259 -> 2.59 \\times 10^{-5}
  /// Uses floor() for exponent to ensure mantissa stays in [1, 10).
  String formatLatex(double value) {
    if (!value.isFinite) {
      if (value.isNaN) return r'\mathrm{NaN}';
      return value.isNegative ? r'-\infty' : r'\infty';
    }
    if (value == 0) return '0';

    final sign = value < 0 ? '-' : '';
    final abs = value.abs();

    // exponent = floor(log10(abs)) ensures mantissa in [1,10)
    var exp = (math.log(abs) / math.ln10).floor();
    var mantissa = abs / math.pow(10, exp);

    final useNormal = exp.abs() < sciThresholdExp && abs >= 1e-3 && abs < 1e3;
    if (useNormal) {
      final normal = _toSigString(abs, significantFigures);
      return '$sign$normal';
    }

    var m = _roundToSig(mantissa, significantFigures);
    // If rounding pushed mantissa to 10, renormalize.
    if (m >= 10) {
      m /= 10;
      exp += 1;
    }
    final mantissaStr = _toSigString(m, significantFigures);
    return exp == 0 ? '$sign$mantissaStr' : '$sign$mantissaStr \\times 10^{${exp}}';
  }

  /// Format a number to LaTeX with unit, e.g.
  /// 8.85e-12, "F/m" -> 8.85 \\times 10^{-12}\\,\\mathrm{F}\\,\\mathrm{m}^{-1}
  String formatLatexWithUnit(double value, String unit) {
    final v = formatLatex(value);
    final u = _normalizeUnitLatex(formatLatexUnit(unit));
    if (u.isEmpty) return v;
    return '$v\\,$u';
  }

  /// Convert unit strings into LaTeX-friendly form.
  /// Examples:
  /// "cm^-3" -> "cm^{-3}"
  /// "m^-1"  -> "m^{-1}"
  /// "J*s"   -> "J\\cdot s"
  /// "1/m"   -> "m^{-1}"
  /// "eV"    -> "eV" (special case, wrap in text mode)
  String formatLatexUnit(String unit) {
    var u = unit.trim();
    if (u.isEmpty) return '';

    u = u.replaceAll(' ', '');

    // Special handling for eV - keep as is, will be wrapped in \text{}
    if (u == 'eV') {
      return 'eV';
    }

    // "1/m" -> "m^{-1}"
    if (u.startsWith('1/')) {
      final denom = u.substring(2);
      u = '$denom^{-1}';
    }

    // Normalize caret exponents like m^-3 -> m^{-3}
    final expRegex = RegExp(r'\^(-?\d+)');
    u = u.replaceAllMapped(expRegex, (m) => '^{${m.group(1)}}');

    // Replace "*": J*s -> J\cdot s (but handle carefully with exponents)
    u = u.replaceAll('*', r'\cdot ');

    return u;
  }

  /// Plain text scientific notation (for logs/debug).
  String formatPlainText(double value) {
    if (!value.isFinite) {
      if (value.isNaN) return 'NaN';
      return value.isNegative ? '-ƒ^z' : 'ƒ^z';
    }
    if (value == 0) return '0';

    final sign = value < 0 ? '-' : '';
    final abs = value.abs();

    var exp = (math.log(abs) / math.ln10).floor();
    var mantissa = abs / math.pow(10, exp);

    final useNormal = exp.abs() < sciThresholdExp && abs >= 1e-3 && abs < 1e3;
    if (useNormal) {
      final normal = _toSigString(abs, significantFigures);
      return '$sign$normal';
    }

    var m = _roundToSig(mantissa, significantFigures);
    if (m >= 10) {
      m /= 10;
      exp += 1;
    }
    final mantissaStr = _toSigString(m, significantFigures);
    return exp == 0 ? '$sign$mantissaStr' : '$sign$mantissaStr x 10^$exp';
  }

  /// Format a number to LaTeX with full precision (for intermediate calculations).
  /// Shows more significant figures than the default formatter.
  String formatLatexFullPrecision(double value) {
    if (!value.isFinite) {
      if (value.isNaN) return r'\mathrm{NaN}';
      return value.isNegative ? r'-\infty' : r'\infty';
    }
    if (value == 0) return '0';

    final sign = value < 0 ? '-' : '';
    final abs = value.abs();

    // exponent = floor(log10(abs)) ensures mantissa in [1,10)
    var exp = (math.log(abs) / math.ln10).floor();
    var mantissa = abs / math.pow(10, exp);

    // Use 9 significant figures for full precision
    var m = _roundToSig(mantissa, 9);
    if (m >= 10) {
      m /= 10;
      exp += 1;
    }
    final mantissaStr = _toSigString(m, 9);
    return exp == 0 ? '$sign$mantissaStr' : '$sign$mantissaStr \\times 10^{${exp}}';
  }

  /// Format a number to LaTeX with unit, using full precision.
  String formatLatexWithUnitFullPrecision(double value, String unit) {
    final v = formatLatexFullPrecision(value);
    final u = _normalizeUnitLatex(formatLatexUnit(unit));
    if (u.isEmpty) return v;
    return '$v\\,$u';
  }

  /// Create a new formatter with a different significant figure count.
  NumberFormatter withSigFigs(int sigFigs) => NumberFormatter(
        significantFigures: sigFigs,
        sciThresholdExp: sciThresholdExp,
      );

  /// Round a value to the requested significant figures (numeric).
  double toSigFigs(double value, {int sigFigs = 3}) => _roundToSig(value, sigFigs);

  /// Always return scientific notation with LaTeX \times 10^{n}.
  String sciToLatex(double value, {int sigFigs = 3}) {
    final forcedSci = NumberFormatter(significantFigures: sigFigs, sciThresholdExp: -1000);
    return forcedSci.formatLatex(value);
  }

  /// Convenience helper for value + optional unit with configurable sig figs.
  String valueLatex(double value, {String unit = '', int sigFigs = 3, bool forceSci = false}) {
    final fmt = forceSci
        ? NumberFormatter(significantFigures: sigFigs, sciThresholdExp: -1000)
        : withSigFigs(sigFigs);
    final v = fmt.formatLatex(value);
    final u = _normalizeUnitLatex(fmt.formatLatexUnit(unit));
    if (u.isEmpty) return v;
    return '$v\\,$u';
  }

  double _roundToSig(double x, int sig) {
    if (x == 0) return 0;
    final exp = (math.log(x.abs()) / math.ln10).floor();
    final scale = math.pow(10, sig - 1 - exp);
    return (x * scale).round() / scale;
  }

  String _toSigString(double x, int sig) {
    if (x == 0) return '0';
    final rounded = _roundToSig(x, sig);
    var str = rounded.toStringAsPrecision(sig);
    if (str.contains('e') || str.contains('E')) {
      final parts = str.split(RegExp('[eE]'));
      final mantissa = parts[0];
      final exp = int.tryParse(parts[1]) ?? 0;
      return '$mantissa \\times 10^{${exp}}';
    }
    return str;
  }

  /// Wrap unit tokens in \mathrm{} with exponents outside the \mathrm{} group.
  String _normalizeUnitLatex(String unitLatex) {
    if (unitLatex.isEmpty) return '';

    // Tokenize units so we don't wrap operators like \cdot in \mathrm{}.
    final normalized = unitLatex.replaceAllMapped(
      RegExp(r'(\\cdot|[A-Za-z]+)(\^\{-?\d+\})?'),
      (m) {
        final token = m.group(1)!;
        final exp = m.group(2);
        if (token == r'\cdot') {
          return r'\cdot';
        }
        if (exp != null) {
          final expVal = exp.substring(2, exp.length - 1); // strip ^{ }
          return r'\mathrm{' + token + '}^{' + expVal + '}';
        }
        return r'\mathrm{' + token + '}';
      },
    );

    return normalized;
  }
}
