import 'package:equatable/equatable.dart';

/// Holds mapping from a symbol key (e.g. "eps_0") to a LaTeX string (e.g. "\varepsilon_0").
/// This is presentation-only and should not affect numeric computations.
class LatexSymbolMap extends Equatable {
  final String source;
  final Map<String, String> symbols; // key -> latex

  const LatexSymbolMap({
    required this.source,
    required this.symbols,
  });

  factory LatexSymbolMap.fromJson(Map<String, dynamic> json) {
    final m = (json['symbols'] as Map<String, dynamic>? ?? const {})
        .map((k, v) => MapEntry(k, v.toString()));

    return LatexSymbolMap(
      source: (json['source'] as String?) ?? 'unknown',
      symbols: m,
    );
  }

  Map<String, dynamic> toJson() => {
        'source': source,
        'symbols': symbols,
      };

  /// Returns LaTeX if known; otherwise falls back to the raw symbol key.
  /// Normalizes subscripts/superscripts to brace form (e.g., n_0 -> n_{0}).
  String latexOf(String symbolKey) {
    final raw = symbols[symbolKey] ?? symbolKey;
    return _normalizeLatex(raw);
  }

  /// Sanitize a full equation string for rendering without mutating math structure.
  /// - If assets accidentally contain double-escaped commands (e.g., "\\\\frac"), unescape once.
  /// - Trims leading/trailing whitespace.
  /// This must NOT apply symbol-key normalization, which can corrupt full equations.
  String sanitizeEquationLatexForRender(String value) {
    var out = value.trim();
    if (out.contains('\\\\')) {
      out = out.replaceAll('\\\\', '\\');
    }
    if (out.contains('\\exp left')) {
      out = out.replaceAll('\\exp left', '\\exp\\left');
    }
    if (out.contains('\\{')) {
      out = out.replaceAll('\\{', '{');
    }
    if (out.contains('\\}')) {
      out = out.replaceAll('\\}', '}');
    }
    if (RegExp(r'_{[^}]*\\}').hasMatch(out)) {
      out = out.replaceAllMapped(
        RegExp(r'_{([^}]*)\\}'),
        (m) => '_{${m.group(1)}}',
      );
    }
    return out;
  }

  /// Ensure underscores and carets use braced arguments for consistent rendering.
  String _normalizeLatex(String value) {
    var out = value;
    out = out.replaceAllMapped(
      RegExp(r'_(?!\{)([A-Za-z0-9\\+\\-]+)'),
      (m) => '_{${m.group(1)}}',
    );
    out = out.replaceAllMapped(
      RegExp(r'\^(?!\{)([A-Za-z0-9\\+\\-]+)'),
      (m) => '^{${m.group(1)}}',
    );
    return out;
  }

  @override
  List<Object?> get props => [source, symbols];
}



