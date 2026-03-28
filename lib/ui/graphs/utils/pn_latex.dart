import 'dart:math' as math;

class PnLatex {
  const PnLatex._();

  static const String rhoPlot = r'\rho(x)';
  static const String ePlot = r'E(x)';
  static const String vPlot = r'V(x)';
  static const String ecPlot = r'E_c(x)';
  static const String evPlot = r'E_v(x)';
  static const String eiPlot = r'E_i(x)';
  static const String efnPlot = r'E_{Fn}(x)';
  static const String efpPlot = r'E_{Fp}(x)';

  static const String unitCmNeg3 = r'\mathrm{cm^{-3}}';
  static const String unitMNeg3 = r'\mathrm{m^{-3}}';
  static const String unitCPerM3 = r'\mathrm{C\,m^{-3}}';
  static const String unitVPerM = r'\mathrm{V\,m^{-1}}';
  static const String unitV = r'\mathrm{V}';
  static const String unitK = r'\mathrm{K}';
  static const String unitEv = r'\mathrm{eV}';
  static const String unitUm = r'\mu\mathrm{m}';

  static String withUnit(String symbolTex, String unitTex) {
    // LatexText/Math.tex expects a pure math expression (no surrounding $...$).
    return '$symbolTex\\,($unitTex)';
  }

  static String depletionPlotTex(String plotId) {
    switch (plotId) {
      case 'rho(x)':
        return rhoPlot;
      case 'E(x)':
        return ePlot;
      case 'V(x)':
        return vPlot;
      default:
        return plotId;
    }
  }

  static String bandSeriesTex(int barIndex) {
    switch (barIndex) {
      case 0:
        return ecPlot;
      case 1:
        return evPlot;
      case 2:
        return eiPlot;
      case 3:
        return efnPlot;
      case 4:
        return efpPlot;
      default:
        return r'E(x)';
    }
  }

  static String bandSeriesPlain(int barIndex) {
    switch (barIndex) {
      case 0:
        return 'Ec(x)';
      case 1:
        return 'Ev(x)';
      case 2:
        return 'Ei(x)';
      case 3:
        return 'EFn(x)';
      case 4:
        return 'EFp(x)';
      default:
        return 'E(x)';
    }
  }

  static const Map<String, String> _superscripts = {
    '-': '\u207B',
    '+': '\u207A',
    '0': '\u2070',
    '1': '\u00B9',
    '2': '\u00B2',
    '3': '\u00B3',
    '4': '\u2074',
    '5': '\u2075',
    '6': '\u2076',
    '7': '\u2077',
    '8': '\u2078',
    '9': '\u2079',
  };

  static String unicodeScientific(double value, {int sigFigs = 3}) {
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
    final expSup = _toSuperscript(exponent);
    return '$mantissaStr\u00D710$expSup';
  }

  static String _toSuperscript(int exponent) {
    final chars = exponent.toString().split('');
    final buf = StringBuffer();
    for (final ch in chars) {
      final mapped = _superscripts[ch];
      if (mapped == null) return '^$exponent';
      buf.write(mapped);
    }
    return buf.toString();
  }
}
