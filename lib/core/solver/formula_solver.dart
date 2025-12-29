import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../constants/constants_repository.dart';
import '../constants/formula_constants_resolver.dart';
import '../constants/latex_symbols.dart';
import '../formulas/formula_definition.dart';
import '../formulas/formula_repository.dart';
import '../formulas/formula_variable.dart';
import '../models/workspace.dart';
import 'expression_evaluator.dart';
import 'number_formatter.dart';
import 'step_latex_builder.dart';
import 'symbol_context.dart';
import 'unit_converter.dart';

/// Result of solving a formula.
class SolveResult extends Equatable {
  final PanelStatus status;
  final Map<String, SymbolValue> outputs;
  final String? errorMessage;
  final StepLatex? stepsLatex;
  final String? notice;

  const SolveResult({
    required this.status,
    required this.outputs,
    this.errorMessage,
    this.stepsLatex,
    this.notice,
  });

  @override
  List<Object?> get props => [status, outputs, errorMessage, stepsLatex, notice];
}

/// Solver for evaluating formulas.
class FormulaSolver {
  final FormulaRepository _formulaRepo;
  final ConstantsRepository _constantsRepo;
  final ExpressionEvaluator _evaluator;

  FormulaSolver({
    required FormulaRepository formulaRepo,
    required ConstantsRepository constantsRepo,
    ExpressionEvaluator? evaluator,
  })  : _formulaRepo = formulaRepo,
        _constantsRepo = constantsRepo,
        _evaluator = evaluator ?? const ExpressionEvaluator();

  /// Solve a formula for a target variable.
  SolveResult solve({
    required String formulaId,
    required String solveFor,
    required Map<String, SymbolValue> workspaceGlobals,
    required Map<String, SymbolValue> panelOverrides,
    LatexSymbolMap? latexMap,
  }) {
    // Get formula definition
    final formula = _formulaRepo.getFormulaById(formulaId);
    if (formula == null) {
      return SolveResult(
        status: PanelStatus.error,
        outputs: const {},
        errorMessage: 'Formula not found: $formulaId',
      );
    }

    // Check if formula can be solved for the target
    if (formula.solvableFor == null || !formula.solvableFor!.contains(solveFor)) {
      return SolveResult(
        status: PanelStatus.error,
        outputs: const {},
        errorMessage: 'Formula cannot be solved for: $solveFor',
      );
    }

    // Get compute expression
    final computeExpr = formula.compute?[solveFor];
    if (computeExpr == null) {
      return SolveResult(
        status: PanelStatus.error,
        outputs: const {},
        errorMessage: 'No compute expression for: $solveFor',
      );
    }

    // Build symbol context (merge constants -> globals -> overrides)
    final constantsResolver = FormulaConstantsResolver(_constantsRepo);
    final resolvedConstants = constantsResolver.resolveConstants(formula);
    final context = SymbolContext(_constantsRepo);
    context.mergeIn(
      constants: resolvedConstants,
      globals: workspaceGlobals,
      overrides: panelOverrides,
    );

    // Validate required inputs
    final requiredVars = _extractVariables(computeExpr);
    final missingVars = <String>[];
    for (final varName in requiredVars) {
      if (!context.hasSymbol(varName)) {
        missingVars.add(varName);
      }
    }

    if (missingVars.isNotEmpty) {
      return SolveResult(
        status: PanelStatus.needsInputs,
        outputs: const {},
        errorMessage: 'Missing required inputs: ${missingVars.join(", ")}',
      );
    }

    // Validate variable constraints (e.g. T > 0) to avoid silent non-physical results.
    final constraintError = _validateConstraints(
      formula: formula,
      requiredVars: requiredVars,
      context: context,
    );
    if (constraintError != null) {
      return SolveResult(
        status: PanelStatus.error,
        outputs: const {},
        errorMessage: constraintError,
      );
    }

    // Validate formula-specific domain rules that are not captured by simple constraints.
    final customError = _validateCustomConstraints(
      formula: formula,
      solveFor: solveFor,
      context: context,
    );
    if (customError != null) {
      return SolveResult(
        status: PanelStatus.error,
        outputs: const {},
        errorMessage: customError,
      );
    }

    // Evaluate expression (with overrides for compensated majority cases)
    final custom = _tryMajorityCustomSolve(
      formula: formula,
      solveFor: solveFor,
      context: context,
    );
    if (custom.error != null) {
      return SolveResult(
        status: PanelStatus.error,
        outputs: const {},
        errorMessage: custom.error,
      );
    }

    double computedValue;
    if (custom.value != null) {
      computedValue = custom.value!;
    } else {
      final evaluationResult = _evaluator.evaluate(computeExpr, context);
      if (evaluationResult.error != null) {
        return SolveResult(
          status: PanelStatus.error,
          outputs: const {},
          errorMessage: _cleanEvalError(evaluationResult.error!),
        );
      }
      computedValue = evaluationResult.value!;
    }

    // Validate the computed output against variable constraints (e.g., positivity).
    final outputConstraintError = _validateOutputConstraint(
      formula: formula,
      variableKey: solveFor,
      value: computedValue,
    );
    if (outputConstraintError != null) {
      return SolveResult(
        status: PanelStatus.error,
        outputs: const {},
        errorMessage: outputConstraintError,
      );
    }

    // Get output unit from formula variable definition
    final outputVar = formula.variables?.firstWhere(
      (v) => v.key == solveFor,
      orElse: () => throw StateError('Variable not found in formula'),
    );
    final outputUnit = outputVar?.siUnit ?? '';

    // Create output
    final outputs = {
      solveFor: SymbolValue(
        value: computedValue,
        unit: outputUnit,
        source: SymbolSource.computed,
      ),
    };

    // Build LaTeX steps if latex map provided
    StepLatex? stepsLatex;
    if (latexMap != null) {
      final builder = StepLaTeXBuilder(
        latexMap: latexMap,
        formatter: const NumberFormatter(significantFigures: 3, sciThresholdExp: 3),
      );
      stepsLatex = builder.build(formula, solveFor, context, outputs, showUnitsInSubstitution: true);

      final unitConverter = UnitConverter(_constantsRepo);
      final primaryEnergyUnit = panelOverrides['__meta__E_unit']?.unit ?? 'J';

      final canonicalWorking = builder.tryBuildModuleSteps(
        formula,
        solveFor,
        context,
        outputs,
        unitConverter,
        primaryEnergyUnit: primaryEnergyUnit,
      );

      if (canonicalWorking != null) {
        final aligned = canonicalWorking
            .where((item) => item.type == StepItemType.math)
            .map((item) => item.latex)
            .join(r'\\');
        final base = stepsLatex;
        stepsLatex = StepLatex(
          formulaLatex: base.formulaLatex,
          substitutionLatex: base.substitutionLatex,
          resultLatex: base.resultLatex,
          alignedWorking: aligned.isNotEmpty ? aligned : null,
          workingItems: canonicalWorking,
        );
      } else {
        const canonicalIds = {
          'parabolic_band_dispersion',
          'effective_mass_from_curvature',
          'dos_Nc_effective_density_conduction',
          'dos_Nv_effective_density_valence',
          'dos_fermi_dirac_probability',
          'intrinsic_concentration_from_dos',
          'dos_stats_midgap_energy',
          'dos_stats_intrinsic_fermi_level',
          'carrier_electron_concentration_n0',
          'carrier_hole_concentration_p0',
          'mass_action_law',
          'doped_n_type_majority',
          'doped_p_type_majority',
          'charge_neutrality_equilibrium',
          'ct_f1_electron_drift_velocity',
          'ct_f2_hole_drift_velocity',
          'ct_f3_electron_drift_current_density',
          'ct_f4_hole_drift_current_density',
          'ct_f5_electron_diffusion_current_density',
          'ct_f6_hole_diffusion_current_density',
          'ct_f7_einstein_relation_electrons',
          'ct_f8_einstein_relation_holes',
          'ct_f9_conductivity',
          'ct_f10_resistivity',
        };
        if (canonicalIds.contains(formula.id)) {
          print('Warning: missing canonical step template for ${formula.id} (solveFor=$solveFor)');
        }
      }
    }

    return SolveResult(
      status: PanelStatus.solved,
      outputs: outputs,
      stepsLatex: stepsLatex,
      notice: custom.notice,
    );
  }

  String _cleanEvalError(String raw) {
    // Avoid leaking "Exception:" prefix; keep message user-friendly.
    return raw.replaceFirst('Exception: ', '');
  }


  List<String> _extractVariables(String expression) {
    // Simple variable extraction - finds identifiers that are not functions
    final pattern = RegExp(r'\b([a-zA-Z_][a-zA-Z0-9_]*)\b');
    final matches = pattern.allMatches(expression);
    final variables = <String>{};

    final functions = {'sqrt', 'pow', 'sin', 'cos', 'tan', 'ln', 'log', 'exp', 'pi'};

    for (final match in matches) {
      final name = match.group(1)!;
      if (!functions.contains(name) && name != 'pi') {
        variables.add(name);
      }
    }

    return variables.toList();
  }

  String? _validateConstraints({
    required FormulaDefinition formula,
    required List<String> requiredVars,
    required SymbolContext context,
  }) {
    // Only validate constraints for variables that exist in the formula definition.
    final vars = formula.variables ?? const [];
    for (final key in requiredVars) {
      FormulaVariable? varDef;
      try {
        varDef = vars.firstWhere((v) => v.key == key);
      } catch (_) {
        varDef = null;
      }
      if (varDef == null) continue;

      final constraints = varDef.constraints;
      if (constraints == null) continue;

      final type = constraints['type']?.toString();
      final value = context.getValue(key);
      if (value == null) continue;

      final error = _constraintError(key: key, type: type, value: value, subject: 'input');
      if (error != null) return error;
    }
    return null;
  }

  String? _validateOutputConstraint({
    required FormulaDefinition formula,
    required String variableKey,
    required double value,
  }) {
    // Allow n_i == 0 for compensated majority ill-conditioned cases.
    if ((formula.id == 'doped_p_type_majority' || formula.id == 'doped_n_type_majority') &&
        variableKey == 'n_i' &&
        value >= 0) {
      return null;
    }
    final vars = formula.variables ?? const [];
    FormulaVariable? varDef;
    try {
      varDef = vars.firstWhere((v) => v.key == variableKey);
    } catch (_) {
      varDef = null;
    }
    if (varDef == null) return null;

    final constraints = varDef.constraints;
    if (constraints == null) return null;

    final type = constraints['type']?.toString();
    return _constraintError(key: variableKey, type: type, value: value, subject: 'result');
  }

  String? _constraintError({
    required String key,
    required String? type,
    required double value,
    required String subject,
  }) {
    if (type == null || type.isEmpty) return null;

    switch (type) {
      case 'positive':
        if (!(value > 0)) {
          return 'Invalid $subject: $key must be > 0.';
        }
        break;
      case 'nonnegative':
        if (value < 0) {
          return 'Invalid $subject: $key must be ≥ 0.';
        }
        break;
      case 'nonzero':
        if (value == 0) {
          return 'Invalid $subject: $key must be non-zero.';
        }
        break;
      case 'finite':
        if (!value.isFinite) {
          return 'Invalid $subject: $key must be a finite number.';
        }
        break;
      case 'unit_interval':
        if (value < 0 || value > 1) {
          return 'Invalid $subject: $key must be in [0, 1].';
        }
        break;
      case 'open_unit_interval':
        if (value <= 0 || value >= 1) {
          return 'Invalid $subject: $key must be in (0, 1).';
        }
        break;
      default:
        // Unknown constraint type: ignore (non-fatal).
        break;
    }
    return null;
  }

  String? _validateCustomConstraints({
    required FormulaDefinition formula,
    required String solveFor,
    required SymbolContext context,
  }) {
    // Equilibrium majority carrier (p/n-type, compensated): guard against division by zero
    // and obviously non-physical negative inputs when solving for dopants.
    if ((formula.id == 'doped_p_type_majority' || formula.id == 'doped_n_type_majority') &&
        (solveFor == 'N_A' || solveFor == 'N_D')) {
      final isPType = formula.id == 'doped_p_type_majority';
      final majorityKey = isPType ? 'p_0' : 'n_0';
      final carrier = context.getValue(majorityKey);
      final ni = context.getValue('n_i');
      final na = context.getValue('N_A');
      final nd = context.getValue('N_D');

      if (carrier == null || carrier <= 0) {
        return 'Invalid input: ${isPType ? 'p0' : 'n0'} must be > 0 to solve for $solveFor.';
      }
      if (ni != null && ni <= 0) {
        return 'Invalid input: n_i must be > 0.';
      }
      if (solveFor == 'N_A' && nd != null && nd < 0) {
        return 'Invalid input: N_D must be non-negative.';
      }
      if (solveFor == 'N_D' && na != null && na < 0) {
        return 'Invalid input: N_A must be non-negative.';
      }
    }
    return null;
  }

  _CustomSolveResult _tryMajorityCustomSolve({
    required FormulaDefinition formula,
    required String solveFor,
    required SymbolContext context,
  }) {
    const relEps = 1e-10;
    const absEps = 1.0;

    if (formula.id != 'doped_p_type_majority' && formula.id != 'doped_n_type_majority') {
      return const _CustomSolveResult();
    }

    final isPType = formula.id == 'doped_p_type_majority';
    final majorityKey = isPType ? 'p_0' : 'n_0';
    final majorityVal = context.getValue(majorityKey);
    final na = context.getValue('N_A');
    final nd = context.getValue('N_D');
    final ni = context.getValue('n_i');

    if (majorityVal != null && majorityVal < 0) {
      return const _CustomSolveResult(error: 'Non-physical input: carrier concentration must be ≥ 0.');
    }
    if (na != null && na < -absEps) {
      return const _CustomSolveResult(error: 'Non-physical input: N_A must be ≥ 0.');
    }
    if (nd != null && nd < -absEps) {
      return const _CustomSolveResult(error: 'Non-physical input: N_D must be ≥ 0.');
    }
    if (ni != null && ni < 0) {
      return const _CustomSolveResult(error: 'Non-physical input: n_i must be ≥ 0.');
    }

    String? notice;

    double solveNA() {
      if (majorityVal == null || majorityVal <= 0) {
        throw StateError('${isPType ? 'p0' : 'n0'} must be > 0 to solve for N_A.');
      }
      final niVal = ni ?? 0;
      final ndVal = nd ?? 0;
      final value = isPType
          ? ndVal + majorityVal - (niVal * niVal) / majorityVal
          : ndVal - majorityVal + (niVal * niVal) / majorityVal;
      if (isPType && value < ndVal) {
        notice = 'Computed N_A < N_D → material is n-type; consider the n-type compensated screen.';
      }
      return value;
    }

    double solveND() {
      if (majorityVal == null || majorityVal <= 0) {
        throw StateError('${isPType ? 'p0' : 'n0'} must be > 0 to solve for N_D.');
      }
      final niVal = ni ?? 0;
      final naVal = na ?? 0;
      final value = isPType
          ? naVal - majorityVal + (niVal * niVal) / majorityVal
          : naVal + majorityVal - (niVal * niVal) / majorityVal;
      if (!isPType && value < naVal) {
        notice = 'Computed N_D < N_A → material is p-type; consider the p-type compensated screen.';
      }
      return value;
    }

    double solveNi() {
      if (majorityVal == null) {
        throw StateError('${isPType ? 'p0' : 'n0'} is required to solve for n_i.');
      }
      final delta = isPType ? ((na ?? 0) - (nd ?? 0)) : ((nd ?? 0) - (na ?? 0));
      final d = majorityVal - delta;
      final scale = [majorityVal.abs(), delta.abs(), 1.0].reduce((a, b) => a > b ? a : b);
      final tol = math.max(absEps, relEps * scale);

      double dSafe = d;
      final absD = d.abs();
      final isIll = absD <= tol;
      if (d < -tol) {
        throw StateError('Inputs inconsistent: ${isPType ? 'p0 < (N_A - N_D)' : 'n0 < (N_D - N_A)'} would make n_i imaginary.');
      }
      if (isIll || d < 0) {
        dSafe = 0;
        notice =
            'Ill-conditioned reverse solve: cannot reliably recover n_i because ${isPType ? 'p0' : 'n0'} ≈ ${isPType ? '(N_A - N_D)' : '(N_D - N_A)'} (precision/rounding). Clamped d to 0, so n_i = 0.';
      }

      final inside = majorityVal * dSafe;
      return inside <= 0 ? 0 : math.sqrt(inside);
    }

    try {
      double? value;
      if (solveFor == 'N_A') {
        value = solveNA();
      } else if (solveFor == 'N_D') {
        value = solveND();
      } else if (solveFor == 'n_i') {
        value = solveNi();
      }
      if (value == null) return const _CustomSolveResult();
      return _CustomSolveResult(value: value, notice: notice);
    } catch (e) {
      var msg = e.toString();
      msg = msg.replaceFirst('Bad state: ', '');
      msg = msg.replaceFirst('StateError: ', '');
      return _CustomSolveResult(error: msg);
    }
  }
}

class _CustomSolveResult {
  final double? value;
  final String? error;
  final String? notice;

  const _CustomSolveResult({this.value, this.error, this.notice});
}
