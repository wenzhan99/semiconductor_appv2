import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

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
  final UnitConversionLog conversions;

  const SolveResult({
    required this.status,
    required this.outputs,
    required this.conversions,
    this.errorMessage,
    this.stepsLatex,
  });

  @override
  List<Object?> get props => [status, outputs, errorMessage, stepsLatex, conversions];
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
    final conversionLog = UnitConversionLog();
    final unitConverter = UnitConverter(_constantsRepo, log: conversionLog);

    // Get formula definition
    final formula = _formulaRepo.getFormulaById(formulaId);
    if (formula == null) {
      _logSolveFailure(
        formulaId: formulaId,
        solveFor: solveFor,
        reason: 'formula_not_found',
      );
      return SolveResult(
        status: PanelStatus.error,
        outputs: const {},
        conversions: conversionLog,
        errorMessage: 'Formula not found: $formulaId',
      );
    }

    // Check if formula can be solved for the target
    if (formula.solvableFor == null || !formula.solvableFor!.contains(solveFor)) {
      _logSolveFailure(
        formulaId: formulaId,
        solveFor: solveFor,
        reason: 'solveFor_not_supported',
        contextKeys: panelOverrides.keys,
      );
      return SolveResult(
        status: PanelStatus.error,
        outputs: const {},
        conversions: conversionLog,
        errorMessage: 'Formula cannot be solved for: $solveFor',
      );
    }

    // Get compute expression
    final computeExpr = formula.compute?[solveFor];
    if (computeExpr == null) {
      _logSolveFailure(
        formulaId: formulaId,
        solveFor: solveFor,
        reason: 'compute_expr_missing',
        contextKeys: panelOverrides.keys,
      );
      return SolveResult(
        status: PanelStatus.error,
        outputs: const {},
        conversions: conversionLog,
        errorMessage: 'No compute expression for: $solveFor',
      );
    }

    // Build symbol context (merge constants -> globals -> overrides)
    final constantsResolver = FormulaConstantsResolver(_constantsRepo);
    final resolvedConstants = constantsResolver.resolveConstants(formula);
    final rawContext = SymbolContext(_constantsRepo);
    rawContext.mergeIn(
      constants: resolvedConstants,
      globals: workspaceGlobals,
      overrides: panelOverrides,
    );
    final context = _normalizeContext(
      formula: formula,
      rawContext: rawContext,
      unitConverter: unitConverter,
      log: conversionLog,
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
      _logSolveFailure(
        formulaId: formula.id,
        solveFor: solveFor,
        reason: 'missing_inputs',
        requiredVars: requiredVars,
        contextKeys: context.getAll().keys,
        computeExpr: computeExpr,
      );
      return SolveResult(
        status: PanelStatus.needsInputs,
        outputs: const {},
        conversions: conversionLog,
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
      _logSolveFailure(
        formulaId: formula.id,
        solveFor: solveFor,
        reason: 'constraint_violation',
        requiredVars: requiredVars,
        contextKeys: context.getAll().keys,
        computeExpr: computeExpr,
      );
      return SolveResult(
        status: PanelStatus.error,
        outputs: const {},
        conversions: conversionLog,
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
      _logSolveFailure(
        formulaId: formula.id,
        solveFor: solveFor,
        reason: 'custom_constraint_violation',
        requiredVars: requiredVars,
        contextKeys: context.getAll().keys,
        computeExpr: computeExpr,
      );
      return SolveResult(
        status: PanelStatus.error,
        outputs: const {},
        conversions: conversionLog,
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
        conversions: conversionLog,
        errorMessage: custom.error,
      );
    }

    double computedValue;
    if (custom.value != null) {
      computedValue = custom.value!;
    } else {
      final evaluationResult = _evaluator.evaluate(computeExpr, context);
      if (evaluationResult.error != null) {
        _logSolveFailure(
          formulaId: formula.id,
          solveFor: solveFor,
          reason: 'evaluation_error:${_cleanEvalError(evaluationResult.error!)}',
          requiredVars: requiredVars,
          contextKeys: context.getAll().keys,
          computeExpr: computeExpr,
        );
        return SolveResult(
          status: PanelStatus.error,
          outputs: const {},
          conversions: conversionLog,
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
      _logSolveFailure(
        formulaId: formula.id,
        solveFor: solveFor,
        reason: 'output_constraint_violation',
        requiredVars: requiredVars,
        contextKeys: context.getAll().keys,
        computeExpr: computeExpr,
      );
      return SolveResult(
        status: PanelStatus.error,
        outputs: const {},
        conversions: conversionLog,
        errorMessage: outputConstraintError,
      );
    }

    // Get output unit - prefer user's selected unit from metadata over SI default
    final outputVar = formula.variables?.firstWhere(
      (v) => v.key == solveFor,
      orElse: () => throw StateError('Variable not found in formula'),
    );
    final siUnit = outputVar?.siUnit ?? '';
    
    // Check for user's unit preference in metadata
    String outputUnit = siUnit;
    final userUnitMeta = context.getValue('__meta__unit_$solveFor');
    if (userUnitMeta != null) {
      // User has explicit unit preference for this symbol
      final preferredUnit = context.getUnit('__meta__unit_$solveFor') ?? '';
      if (preferredUnit.isNotEmpty) {
        outputUnit = preferredUnit;
        
        // Convert computed value to user's preferred unit
        if (siUnit != outputUnit) {
          if (siUnit.contains('^-') && outputUnit.contains('^-')) {
            final converted = unitConverter.convertDensity(computedValue, siUnit, outputUnit);
            if (converted != null) computedValue = converted;
          } else if ((siUnit == 'J' || siUnit == 'eV') && (outputUnit == 'J' || outputUnit == 'eV')) {
            final converted = unitConverter.convertEnergy(computedValue, siUnit, outputUnit);
            if (converted != null) computedValue = converted;
          }
        }
      }
    } else if (siUnit.contains('^-')) {
      // Fallback: check global density unit metadata
      final densityUnitPref = context.getUnit('__meta__density_unit') ?? '';
      if (densityUnitPref.isNotEmpty && densityUnitPref != siUnit) {
        outputUnit = densityUnitPref;
        final converted = unitConverter.convertDensity(computedValue, siUnit, outputUnit);
        if (converted != null) computedValue = converted;
      }
    }

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
      stepsLatex = builder.build(
        formula,
        solveFor,
        context,
        outputs,
        showUnitsInSubstitution: true,
        conversions: conversionLog,
      );

      final targetEnergyUnit = panelOverrides['__meta__unit_$solveFor']?.unit;
      final primaryEnergyUnit = targetEnergyUnit ?? panelOverrides['__meta__E_unit']?.unit ?? 'J';

      final canonicalWorking = builder.tryBuildModuleSteps(
        formula,
        solveFor,
        context,
        outputs,
        unitConverter,
        conversions: conversionLog,
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
      conversions: conversionLog,
    );
  }

  SymbolContext _normalizeContext({
    required FormulaDefinition formula,
    required SymbolContext rawContext,
    required UnitConverter unitConverter,
    required UnitConversionLog log,
  }) {
    final normalized = SymbolContext(_constantsRepo);
    final merged = rawContext.getAll();
    final vars = formula.variables ?? const [];
    SymbolValue convertSymbol(String key, SymbolValue value) {
      final varDef = vars.firstWhere(
        (v) => v.key == key,
        orElse: () => FormulaVariable(key: key, name: key, siUnit: value.unit, preferredUnits: const []),
      );
      final targetUnit = varDef.siUnit.isNotEmpty ? varDef.siUnit : value.unit;
      if (targetUnit.isEmpty || value.unit == targetUnit) return value;

      double? convertedValue;
      if (targetUnit.contains('^-')) {
        convertedValue = unitConverter.convertDensity(value.value, value.unit, targetUnit, symbol: key, reason: 'canonical density unit');
      } else if (targetUnit == 'J' || targetUnit == 'eV' || value.unit == 'J' || value.unit == 'eV') {
        convertedValue = unitConverter.convertEnergy(value.value, value.unit, targetUnit, symbol: key, reason: 'canonical energy unit');
      } else if (RegExp(r'^(m|cm|nm|um|Aćm)$').hasMatch(targetUnit)) {
        convertedValue = unitConverter.convertLength(value.value, value.unit, targetUnit, symbol: key, reason: 'canonical length unit');
      } else {
        convertedValue = null;
      }

      if (convertedValue == null) return value;
      return SymbolValue(value: convertedValue, unit: targetUnit, source: value.source);
    }

    final normalizedMap = <String, SymbolValue>{};
    merged.forEach((key, val) {
      if (key.startsWith('__meta__')) {
        normalizedMap[key] = val;
      } else {
        normalizedMap[key] = convertSymbol(key, val);
      }
    });

    normalized.mergeIn(overrides: normalizedMap);
    return normalized;
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
    // PN depletion partition (x_n/x_p) domain: require 0 < x < W when solving for dopants
    final isDepletionPartition =
        formula.id == 'pn_depletion_width_xn' || formula.id == 'pn_depletion_width_xp';
    if (isDepletionPartition && (solveFor == 'N_A' || solveFor == 'N_D')) {
      final xKey = formula.id == 'pn_depletion_width_xn' ? 'x_n' : 'x_p';
      final x = context.getValue(xKey);
      final w = context.getValue('W');
      if (x != null && w != null) {
        final scale = [w.abs(), x.abs(), 1.0].reduce((a, b) => a > b ? a : b);
        final tol = 1e-15 * scale;
        if ((w - x).abs() <= tol) {
          return 'Cannot solve: W - $xKey = 0 (division by zero). Choose W != $xKey.';
        }
        if (x <= 0 || x >= w) {
          return 'No physical solution: require 0 < $xKey < W to keep N_A, N_D positive.';
        }
      }
    }

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
      return const _CustomSolveResult(error: 'Non-physical input: carrier concentration must be >= 0.');
    }
    if (na != null && na < -absEps) {
      return const _CustomSolveResult(error: 'Non-physical input: N_A must be >= 0.');
    }
    if (nd != null && nd < -absEps) {
      return const _CustomSolveResult(error: 'Non-physical input: N_D must be >= 0.');
    }
    if (ni != null && ni < 0) {
      return const _CustomSolveResult(error: 'Non-physical input: n_i must be >= 0.');
    }

    double solveNA() {
      if (majorityVal == null || majorityVal <= 0) {
        throw StateError('${isPType ? 'p0' : 'n0'} must be > 0 to solve for N_A.');
      }
      final niVal = ni ?? 0;
      final ndVal = nd ?? 0;
      return isPType
          ? ndVal + majorityVal - (niVal * niVal) / majorityVal
          : ndVal - majorityVal + (niVal * niVal) / majorityVal;
    }

    double solveND() {
      if (majorityVal == null || majorityVal <= 0) {
        throw StateError('${isPType ? 'p0' : 'n0'} must be > 0 to solve for N_D.');
      }
      final niVal = ni ?? 0;
      final naVal = na ?? 0;
      return isPType
          ? naVal - majorityVal + (niVal * niVal) / majorityVal
          : naVal + majorityVal - (niVal * niVal) / majorityVal;
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
      return _CustomSolveResult(value: value);
    } catch (e) {
      var msg = e.toString();
      msg = msg.replaceFirst('Bad state: ', '');
      msg = msg.replaceFirst('StateError: ', '');
      return _CustomSolveResult(error: msg);
    }
  }

  void _logSolveFailure({
    required String formulaId,
    required String solveFor,
    required String reason,
    Iterable<String>? requiredVars,
    Iterable<String>? contextKeys,
    String? computeExpr,
  }) {
    debugPrint('[solver] formula=$formulaId target=$solveFor reason=$reason '
        'required=[${requiredVars?.join(", ") ?? ''}] '
        'context=[${contextKeys?.join(", ") ?? ''}] '
        'compute="$computeExpr"');
  }
}

class _CustomSolveResult {
  final double? value;
  final String? error;

  const _CustomSolveResult({this.value, this.error});
}
