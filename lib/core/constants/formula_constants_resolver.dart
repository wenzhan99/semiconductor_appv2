import '../formulas/formula_definition.dart';
import '../formulas/formula_extensions.dart';
import '../models/workspace.dart';
import 'constants_repository.dart';

/// Determines and resolves constants needed by a formula using a single pipeline.
class FormulaConstantsResolver {
  final ConstantsRepository _constantsRepo;

  const FormulaConstantsResolver(this._constantsRepo);

  /// Collect all constant keys referenced by the formula (explicit + from expressions).
  Set<String> requiredKeys(FormulaDefinition formula) {
    final keys = <String>{};

    // 1) Explicit constants list from JSON.
    keys.addAll(formula.constantsUsedResolved.map((c) => c.key));

    // 2) Any identifiers in compute expressions that are not declared variables.
    final variableKeys = formula.variablesResolved.map((v) => v.key).toSet();
    final expressions = formula.compute?.values ?? const <String>[];
    for (final expr in expressions) {
      for (final id in _extractIdentifiers(expr)) {
        if (!variableKeys.contains(id)) {
          keys.add(id);
        }
      }
    }

    return keys;
  }

  /// Resolve constants for the given formula using canonical keys + SymbolValues.
  Map<String, SymbolValue> resolveConstants(FormulaDefinition formula) {
    final keys = requiredKeys(formula);
    return _constantsRepo.resolveConstants(keys);
  }

  Iterable<String> _extractIdentifiers(String expression) sync* {
    // Simple identifier extraction - mirrors FormulaSolver._extractVariables.
    final pattern = RegExp(r'\b([a-zA-Z_][a-zA-Z0-9_]*)\b');
    final matches = pattern.allMatches(expression);
    const functions = {'sqrt', 'pow', 'sin', 'cos', 'tan', 'ln', 'log', 'exp', 'pi'};

    for (final match in matches) {
      final name = match.group(1)!;
      if (!functions.contains(name) && name != 'pi') {
        yield name;
      }
    }
  }
}
