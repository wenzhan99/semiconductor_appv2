import 'package:flutter/foundation.dart';

import '../constants/latex_symbols.dart';

/// Builds a fully substituted LaTeX equation by replacing symbol tokens with
/// formatted numeric values (optionally wrapped in parentheses to preserve
/// factor grouping).
String buildSubstitutionEquation({
  required String equationLatex,
  required LatexSymbolMap latexMap,
  required Map<String, String> substitutionMap,
  bool wrapValuesWithParens = false,
  String? debugLabel,
}) {
  var result = equationLatex;

  final replacements = <_Replacement>[];
  for (final entry in substitutionMap.entries) {
    // Skip meta keys that are not real symbols.
    if (entry.key.startsWith('__meta__')) continue;

    final key = entry.key;
    final replacement = wrapValuesWithParens ? '(${entry.value})' : entry.value;
    final latexSymbol = latexMap.latexOf(key);
    if (latexSymbol.isEmpty) continue;
    final braceStripped = latexSymbol.replaceAll(RegExp(r'\{([^}]*)\}'), r'\1');
    // Only add replacements for tokens that actually appear in the equation to avoid false warnings
    final tokenUsed =
        result.contains(latexSymbol) || (braceStripped != latexSymbol && result.contains(braceStripped));
    if (!tokenUsed) continue;

    replacements.add(_Replacement(token: latexSymbol, replacement: replacement));
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
        // Allow replacement even when immediately followed by another symbol (e.g., kT),
        // while still requiring a boundary on the left to avoid hitting substrings.
        : RegExp('(?<![A-Za-z0-9])$escaped');
    result = result.replaceAll(pattern, repl.replacement);
  }

  // Diagnostics: log any symbols that still appear unsubstituted even though a value existed.
  // IMPORTANT: Only check for ACTUAL symbol tokens, not letters inside LaTeX commands.
  // For example, 'c' in '\frac' or 'q' in '\sqrt' should NOT be flagged.
  final missingTokens = <String>[];
  for (final repl in replacements) {
    // Skip if token is a single letter that might be part of LaTeX commands
    // Common LaTeX commands: \frac (c), \sqrt (q), \right (h), \left (e), etc.
    final isSingleLetter = repl.token.length == 1 && RegExp(r'^[a-z]$').hasMatch(repl.token);
    if (isSingleLetter) {
      // For single letters, only check if they appear as standalone symbols
      // Use word boundary check to avoid matching command internals
      final pattern = RegExp(r'(?<![\\A-Za-z])' + RegExp.escape(repl.token) + r'(?![A-Za-z])');
      if (pattern.hasMatch(result)) {
        missingTokens.add(repl.token);
      }
    } else {
      // For multi-character tokens, use original logic
      final braceStripped = repl.token.replaceAll(RegExp(r'\\{?'), '').replaceAll(RegExp(r'[{}]'), '');
      if (result.contains(repl.token) || (braceStripped.isNotEmpty && result.contains(braceStripped))) {
        missingTokens.add(repl.token);
      }
    }
  }
  if (missingTokens.isNotEmpty) {
    final label = debugLabel != null ? '[$debugLabel] ' : '';
    debugPrint('${label}Substitution warning: unresolved tokens ${missingTokens.join(", ")} in "$equationLatex"');
  }

  return result;
}

class _Replacement {
  final String token;
  final String replacement;

  _Replacement({required this.token, required this.replacement});
}
