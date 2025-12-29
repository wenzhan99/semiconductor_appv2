import 'formula.dart';
import 'formula_variable.dart';
import 'formula_constant.dart';
import '../constants/latex_symbols.dart';

/// Extension methods for Formula to provide resolved variables and constants.
extension FormulaExtensions on Formula {
  /// Get resolved variables list (always returns a list, even if variables is null).
  List<FormulaVariable> get variablesResolved {
    if (variables != null) {
      return variables!;
    }
    return [];
  }

  /// Get resolved constants list (always returns a list, even if constantsUsed is null).
  List<FormulaConstant> get constantsUsedResolved {
    if (constantsUsed != null) {
      return constantsUsed!;
    }
    return [];
  }
}

/// Extension methods for FormulaVariable to provide display helpers.
extension FormulaVariableExtensions on FormulaVariable {
  /// Get display name using LaTeX symbol map if available.
  String displayName(LatexSymbolMap latexMap) {
    final latex = latexMap.latexOf(key);
    // If LaTeX is different from key, prefer LaTeX; otherwise use name
    if (latex != key && latex.isNotEmpty) {
      return latex;
    }
    return name.isNotEmpty ? name : key;
  }

  /// Get unit label for display.
  String get unitLabel {
    if (siUnit.isNotEmpty) {
      return siUnit;
    }
    if (preferredUnits.isNotEmpty) {
      return preferredUnits.first;
    }
    return '';
  }
}



