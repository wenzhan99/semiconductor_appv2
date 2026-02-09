import 'dart:math' as math;

/// Plain-text scientific notation formatter with fixed significant figures.
class TextNumberFormatter {
  static String sci(double value, {int sigFigs = 3}) {
    if (value.isNaN || value.isInfinite) return '--';
    if (value == 0) return '0';

    final absVal = value.abs();
    final exponent = (math.log(absVal) / math.ln10).floor();
    final mantissa = value / math.pow(10, exponent);

    final digits = sigFigs - 1;
    final mantissaStr = mantissa.toStringAsFixed(digits);

    return '$mantissaStr×10^$exponent';
  }

  static String withUnit(double value, String unit, {int sigFigs = 3}) {
    final numStr = sci(value, sigFigs: sigFigs);
    return unit.isEmpty ? numStr : '$numStr $unit';
  }
}
