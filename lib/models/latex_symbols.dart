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
  String latexOf(String symbolKey) => symbols[symbolKey] ?? symbolKey;

  @override
  List<Object?> get props => [source, symbols];
}



