import '../core/constants/constants_repository.dart';
import '../core/constants/latex_symbols.dart';
import '../core/formulas/formula.dart';
import '../core/formulas/formula_repository.dart';
import '../core/formulas/formula_extensions.dart';
import '../core/models/workspace.dart';
import '../core/solver/formula_solver.dart';
import '../core/solver/step_latex_builder.dart';

class Step3AuditResult {
  final String formulaId;
  final String formulaName;
  final String solveFor;
  final bool passed;
  final List<String> missingSymbols;
  final String substitutionPreview;

  const Step3AuditResult({
    required this.formulaId,
    required this.formulaName,
    required this.solveFor,
    required this.passed,
    required this.missingSymbols,
    required this.substitutionPreview,
  });
}

/// Developer-only audit tool to verify Step 3 substitution completeness for PN junction formulas.
class Step3AuditRunner {
  Step3AuditRunner({
    required this.formulas,
    required this.constants,
    required this.latexMap,
  });

  final FormulaRepository formulas;
  final ConstantsRepository constants;
  final LatexSymbolMap latexMap;

  static const List<String> _pnFormulaIds = [
    'pn_built_in_potential',
    'pn_depletion_width',
    'pn_depletion_width_xn',
    'pn_depletion_width_xp',
    'pn_peak_field',
    'pn_peak_field_charge_form_n_side',
    'pn_peak_field_charge_form_p_side',
    'pn_depletion_charge_per_area',
    'pn_junction_cap_per_area',
    'pn_junction_cap_total',
    'pn_minority_electrons_p_type',
    'pn_minority_holes_n_type',
    'pn_diode_equation',
  ];

  /// Default SI input set used for auditing.
  static const Map<String, SymbolValue> _defaultInputs = {
    'T': SymbolValue(value: 300, unit: 'K', source: SymbolSource.user),
    'n_i': SymbolValue(value: 1.0e16, unit: 'm^-3', source: SymbolSource.user),
    'N_A': SymbolValue(value: 1.0e23, unit: 'm^-3', source: SymbolSource.user),
    'N_D': SymbolValue(value: 5.0e22, unit: 'm^-3', source: SymbolSource.user),
    'eps_s': SymbolValue(value: 1.035e-10, unit: 'F/m', source: SymbolSource.user),
    'A': SymbolValue(value: 1.0e-4, unit: 'm^2', source: SymbolSource.user),
    'V_dep': SymbolValue(value: 0.7, unit: 'V', source: SymbolSource.user),
    'W': SymbolValue(value: 3.0e-7, unit: 'm', source: SymbolSource.user),
    'x_n': SymbolValue(value: 3.0e-7, unit: 'm', source: SymbolSource.user),
    'x_p': SymbolValue(value: 3.0e-8, unit: 'm', source: SymbolSource.user),
    'E_max': SymbolValue(value: 1.0e6, unit: 'V/m', source: SymbolSource.user),
    'C_j': SymbolValue(value: 1.0e-6, unit: 'F', source: SymbolSource.user),
    'V': SymbolValue(value: 0.5, unit: 'V', source: SymbolSource.user),
  };

  Future<List<Step3AuditResult>> runPnAudit() async {
    await formulas.preloadAll();
    await constants.load();
    final solver = FormulaSolver(formulaRepo: formulas, constantsRepo: constants);

    final results = <Step3AuditResult>[];
    for (final formulaId in _pnFormulaIds) {
      final formula = formulas.getFormulaById(formulaId);
      if (formula == null || formula.solvableFor == null) continue;
      for (final solveFor in formula.solvableFor!) {
        results.add(await _runCase(
          solver: solver,
          formula: formula,
          solveFor: solveFor,
        ));
      }
    }
    return results;
  }

  Future<Step3AuditResult> _runCase({
    required FormulaSolver solver,
    required Formula formula,
    required String solveFor,
  }) async {
    final overrides = _buildOverrides(formula);
    final result = solver.solve(
      formulaId: formula.id,
      solveFor: solveFor,
      workspaceGlobals: const {},
      panelOverrides: overrides,
      latexMap: latexMap,
    );

    final steps = result.stepsLatex;
    if (steps == null) {
      return Step3AuditResult(
        formulaId: formula.id,
        formulaName: formula.name,
        solveFor: solveFor,
        passed: false,
        missingSymbols: const ['No steps generated'],
        substitutionPreview: '—',
      );
    }

    final step3Math = _extractStepMath(steps, 3);
    final substitutionPreview = step3Math.join(' ');
    if (step3Math.isEmpty) {
      return Step3AuditResult(
        formulaId: formula.id,
        formulaName: formula.name,
        solveFor: solveFor,
        passed: false,
        missingSymbols: const ['Step 3 missing'],
        substitutionPreview: '—',
      );
    }

    final missing = _findMissingSymbols(
      formula: formula,
      solveFor: solveFor,
      substitutionBlock: substitutionPreview,
    );

    return Step3AuditResult(
      formulaId: formula.id,
      formulaName: formula.name,
      solveFor: solveFor,
      passed: missing.isEmpty,
      missingSymbols: missing,
      substitutionPreview: substitutionPreview,
    );
  }

  Map<String, SymbolValue> _buildOverrides(Formula formula) {
    final overrides = <String, SymbolValue>{};
    final vars = formula.variablesResolved;
    for (final v in vars) {
      final provided = _defaultInputs[v.key];
      if (provided != null) {
        overrides[v.key] = provided;
      }
    }
    return overrides;
  }

  List<String> _extractStepMath(StepLatex steps, int stepNumber) {
    final items = steps.workingItems;
    final heading = 'Step $stepNumber';
    final start = items.indexWhere(
      (item) =>
          (item.type == StepItemType.text && item.value.contains(heading)) ||
          (item.type == StepItemType.math && item.latex.contains(heading)),
    );
    if (start == -1) return const [];
    final next = items.skip(start + 1).toList().indexWhere(
      (item) =>
          (item.type == StepItemType.text && item.value.startsWith('Step ')) ||
          (item.type == StepItemType.math && item.latex.contains(r'\textbf{Step')),
    );
    final end = next == -1 ? items.length : start + 1 + next;
    return items
        .sublist(start + 1, end)
        .where((i) => i.type == StepItemType.math)
        .map((e) => e.latex)
        .toList();
  }

  List<String> _findMissingSymbols({
    required Formula formula,
    required String solveFor,
    required String substitutionBlock,
  }) {
    final missing = <String>[];

    final knownKeys = <String>{};
    knownKeys.addAll(formula.variablesResolved.map((v) => v.key));
    knownKeys.addAll(_defaultInputs.keys);
    knownKeys.add('q'); // ensure q is always checked when present

    for (final key in knownKeys) {
      if (key == solveFor) continue;
      if (key.startsWith('__meta__')) continue;
      final latexSym = latexMap.renderSymbol(key, warnOnFallback: false);
      if (latexSym.isEmpty) continue;
      final pattern = RegExp('(?<![A-Za-z0-9])${RegExp.escape(latexSym)}(?![A-Za-z0-9])');
      if (pattern.hasMatch(substitutionBlock)) {
        missing.add(latexSym);
      }
    }

    return missing;
  }
}
