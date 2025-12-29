import '../constants/latex_symbols.dart';

/// Builds a fully substituted LaTeX equation by replacing symbol tokens with
/// formatted numeric values (optionally wrapped in parentheses to preserve
/// factor grouping).
String buildSubstitutionEquation({
  required String equationLatex,
  required LatexSymbolMap latexMap,
  required Map<String, String> substitutionMap,
  bool wrapValuesWithParens = false,
}) {
  var result = equationLatex;

  final replacements = <_Replacement>[];
  for (final entry in substitutionMap.entries) {
    final key = entry.key;
    final replacement = wrapValuesWithParens ? '(${entry.value})' : entry.value;
    final latexSymbol = latexMap.latexOf(key);
    if (latexSymbol.isEmpty) continue;
    replacements.add(_Replacement(token: latexSymbol, replacement: replacement));
    final braceStripped = latexSymbol.replaceAll(RegExp(r'\{([^}]*)\}'), r'\1');
    if (braceStripped != latexSymbol) {
      replacements.add(_Replacement(token: braceStripped, replacement: replacement));
    }
  }

  // Protect longer tokens first to avoid partial matches (e.g., n_{0} before n).
  replacements.sort((a, b) => b.token.length.compareTo(a.token.length));

  for (final repl in replacements) {
    final escaped = RegExp.escape(repl.token);
    final pattern = repl.token.startsWith('\\')
        ? RegExp('$escaped(?![A-Za-z])')
        : RegExp('(?<![A-Za-z0-9])$escaped(?![A-Za-z0-9])');
    result = result.replaceAll(pattern, repl.replacement);
  }

  return result;
}

class _Replacement {
  final String token;
  final String replacement;

  _Replacement({required this.token, required this.replacement});
}
