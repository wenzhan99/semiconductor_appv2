import 'dart:math' as math;

/// Maps internal symbol keys to LaTeX-safe strings.
class LatexSymbolMapLocal {
  static const Map<String, String> symbols = {
    'Eg': r'E_g',
    'ni': r'n_i',
    'Nc': r'N_c',
    'Nv': r'N_v',
    'Ef': r'E_F',
    'Ec': r'E_c',
    'Ev': r'E_v',
    'mn_star': r'm_n^{*}',
    'mp_star': r'm_p^{*}',
    'mu_n': r'\mu_n',
    'mu_p': r'\mu_p',
    'rho': r'\rho',
    'eps': r'\varepsilon',
    'k': r'k',
    'T': r'T',
    'V': r'V',
  };

  static String resolve(String key, {String fallback = ''}) {
    return symbols[key] ?? fallback;
  }
}

/// Formats scientific numbers into LaTeX strings.
class ScientificLatexFormatter {
  static String sci(double value, {int sigFigs = 3}) {
    if (value.isNaN || value.isInfinite) return '--';
    if (value == 0) return '0';
    final absVal = value.abs();
    final exponent = (math.log(absVal) / math.ln10).floor();
    final mantissa = value / math.pow(10, exponent);
    final digits = sigFigs - 1;
    final mantissaStr = mantissa.toStringAsFixed(digits);
    return '$mantissaStr\\times 10^{$exponent}';
  }

  static String logTick(int exp) => '10^{$exp}';

  static String withUnit(double value, String unitLatex, {int sigFigs = 3}) {
    final numStr = sci(value, sigFigs: sigFigs);
    if (unitLatex.isEmpty) return numStr;
    return '$numStr\\,\\mathrm{$unitLatex}';
  }
}

class LatexUnitFormatter {
  static const Map<String, String> _unitLatex = {
    'cm^-3': r'cm^{-3}',
    'm^-3': r'm^{-3}',
    'K': r'K',
    'eV': r'eV',
    'J': r'J',
    'V/m': r'V\,m^{-1}',
    'A/m^2': r'A\,m^{-2}',
    'um': r'\mu m',
  };

  static String unit(String unit) => _unitLatex[unit] ?? unit;
}
