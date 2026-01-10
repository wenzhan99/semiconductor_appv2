/// Safe parser for numeric input that handles scientific notation correctly.
class InputNumberParser {
  /// Parse a flexible numeric string, handling:
  /// - Normal decimals: 0.146, -12.3
  /// - Scientific notation: 2.37e-31, 1e9, 1.0E+3
  /// - With whitespace/commas (sanitized)
  /// 
  /// Returns null if invalid. Never strips '-' after 'e' or 'E'.
  static double? parseFlexibleDouble(String raw) {
    if (raw.isEmpty) return null;
    
    // Sanitize: remove whitespace and commas only
    var cleaned = raw
        .trim()
        .replaceAll(' ', '')
        .replaceAll(',', '')
        // Strip common stray prime/backtick characters that appear from copy/paste (e.g., 3.55e-31`)
        .replaceAll(RegExp(r"[`´’′]"), '');
    
    if (cleaned.isEmpty) return null;
    
    // Try parsing directly (double.tryParse handles scientific notation)
    final value = double.tryParse(cleaned);
    if (value != null) {
      // Reject NaN/Infinity explicitly so we can show a targeted validation error.
      if (!value.isFinite) return null;
      return value;
    }
    
    // Optional: handle LaTeX-style "2.37 \times 10^{-31}"
    // This is a fallback for edge cases
    final latexPattern = RegExp(r'^([+-]?\d+\.?\d*)\s*[×x*]\s*10\s*[\^]\s*([+-]?\d+)$');
    final latexMatch = latexPattern.firstMatch(cleaned);
    if (latexMatch != null) {
      final mantissa = double.tryParse(latexMatch.group(1)!);
      final exponent = int.tryParse(latexMatch.group(2)!);
      if (mantissa != null && exponent != null) {
        final v = mantissa * _pow(10.0, exponent);
        if (!v.isFinite) return null;
        return v;
      }
    }
    
    return null;
  }
  
  static double _pow(double base, int exponent) {
    if (exponent == 0) return 1.0;
    if (exponent < 0) return 1.0 / _pow(base, -exponent);
    var result = base;
    for (int i = 1; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
