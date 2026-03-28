import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/constants_repository.dart';
import '../../core/constants/latex_symbols.dart';
import '../../core/formulas/formula_definition.dart';
import '../../core/formulas/formula_extensions.dart';
import '../../core/formulas/formula_repository.dart';
import '../../core/formulas/formula_variable.dart';
import '../../core/models/unit_preferences.dart';
import '../../core/models/workspace.dart';
import '../../core/solver/formula_solver.dart';
import '../../core/solver/input_number_parser.dart';
import '../../core/solver/number_formatter.dart';
import '../../core/solver/step_latex_builder.dart';
import '../../core/solver/unit_converter.dart';
import '../../services/app_state.dart';

/// Controller that owns formula panel state and orchestrates computation.
class FormulaPanelController extends ChangeNotifier {
  FormulaPanelController({
    required this.formula,
    required this.panel,
  });

  final FormulaDefinition formula;
  final WorkspacePanel panel;

  final Map<String, TextEditingController> controllers = {};
  final Map<String, String> unitSelections = {};

  FormulaSolver? _solver;
  StepLatex? lastSteps;
  Map<String, SymbolValue>? lastOutputs;
  String? lastError;
  String? lastErrorLatex;
  bool isComputing = false;
  String? densityDisplayUnitMeta;
  String? energyDisplayUnitMeta;

  static const double valueFieldWidth = 168;

  Future<void> initSolver(BuildContext context) async {
    final repo = FormulaRepository();
    await repo.preloadAll();
    _solver = FormulaSolver(formulaRepo: repo, constantsRepo: context.read<ConstantsRepository>());
    notifyListeners();
  }

  void initControllers(BuildContext context) {
    final unitConverter = UnitConverter(context.read<ConstantsRepository>());
    for (final v in formula.variablesResolved) {
      final existing = panel.overrides[v.key];
      final existingUnit = existing?.unit ?? '';
      String? selectedUnit;
      double? displayValue = existing?.value;

      if (v.preferredUnits.contains('eV') && v.preferredUnits.contains('J')) {
        selectedUnit = existingUnit.isNotEmpty ? existingUnit : v.preferredUnits.first;
        energyDisplayUnitMeta ??= selectedUnit;
        if (displayValue != null && existingUnit.isNotEmpty && selectedUnit != existingUnit) {
          final converted = unitConverter.convertEnergy(displayValue, existingUnit, selectedUnit);
          displayValue = converted ?? displayValue;
        }
      } else if (v.preferredUnits.contains('cm^-3') && v.preferredUnits.contains('m^-3')) {
        selectedUnit = existingUnit.isNotEmpty ? existingUnit : v.preferredUnits.first;
        densityDisplayUnitMeta ??= selectedUnit;
        if (displayValue != null && existingUnit.isNotEmpty && selectedUnit != existingUnit) {
          final converted = unitConverter.convertDensity(displayValue, existingUnit, selectedUnit);
          displayValue = converted ?? displayValue;
        }
      }

      if (selectedUnit != null) {
        unitSelections[v.key] = selectedUnit;
      }

      final text = displayValue != null ? _formatInput(displayValue) : '';
      controllers[v.key] = TextEditingController(text: text);
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> compute(BuildContext context) async {
    if (_solver == null) return;
    _startComputing();

    final appState = context.read<AppState>();
    final constantsRepo = context.read<ConstantsRepository>();
    final latexMap = context.read<LatexSymbolMap>();
    final workspace = appState.currentWorkspace;
    final unitConverter = UnitConverter(constantsRepo);

    if (workspace == null) {
      _finishWithError('No workspace selected.');
      return;
    }

    final overrides = <String, SymbolValue>{};
    String? densityUnitMeta;
    String? energyUnitMeta;
    final missing = <String>[];
    final unitSystem = workspace.unitSystem;
    FormulaVariable? firstEnergyVar;

    for (final v in formula.variablesResolved) {
      if (firstEnergyVar == null && v.preferredUnits.contains('eV') && v.preferredUnits.contains('J')) {
        firstEnergyVar = v;
      }
      final raw = controllers[v.key]?.text.trim() ?? '';
      if (raw.isEmpty) {
        missing.add(v.key);
        continue;
      }
      final parsed = InputNumberParser.parseFlexibleDouble(raw);
      if (parsed == null) {
        _finishWithError('Invalid input for ${v.name}');
        return;
      }

      final supportsEnergy = v.preferredUnits.contains('eV') && v.preferredUnits.contains('J');
      final supportsDensity = v.preferredUnits.contains('cm^-3') && v.preferredUnits.contains('m^-3');

      final rawValue = parsed;
      double value = parsed;
      String unit = v.siUnit;

      if (supportsEnergy) {
        final selectedUnit = unitSelections[v.key] ?? v.preferredUnits.first;
        energyUnitMeta ??= selectedUnit;
        overrides['__meta__unit_${v.key}'] = SymbolValue(value: 0, unit: selectedUnit, source: SymbolSource.computed);
        overrides['__meta__input_${v.key}'] = SymbolValue(value: rawValue, unit: selectedUnit, source: SymbolSource.user);
        // Keep value/unit as entered; solver will normalize to canonical units with logging.
        unit = selectedUnit;
      } else if (supportsDensity) {
        final selectedUnit = unitSelections[v.key] ?? (unitSystem == UnitSystem.cm ? 'cm^-3' : v.preferredUnits.first);
        densityUnitMeta ??= selectedUnit;
        overrides['__meta__unit_${v.key}'] = SymbolValue(value: 0, unit: selectedUnit, source: SymbolSource.computed);
        // Keep value/unit as entered; solver will normalize to canonical units with logging.
        unit = selectedUnit;
      }

      overrides[v.key] = SymbolValue(value: value, unit: unit, source: SymbolSource.user);
    }

    overrides['__meta__unit_system'] = SymbolValue(
      value: 0,
      unit: unitSystem == UnitSystem.cm ? 'cm' : 'si',
      source: SymbolSource.computed,
    );

    // Determine solveFor BEFORE setting unit metadata, so we can use target variable's unit
    String solveFor;
    if (missing.length == 1) {
      solveFor = missing.first;
    } else if (missing.isEmpty) {
      solveFor = formula.solvableFor?.first ?? (formula.variablesResolved.isNotEmpty ? formula.variablesResolved.first.key : '');
    } else {
      final plainMissing = missing.join(', ');
      final latexMissing = missing
          .map((key) {
            final mapped = latexMap.latexOf(key);
            if (mapped.isNotEmpty) return mapped;
            return _fallbackSymbolLatex(key);
          })
          .join(r',\;');
      _finishWithError(
        'Missing required inputs: $plainMissing',
        latexMessage: r'\text{Missing required inputs: } ' + latexMissing,
      );
      return;
    }

    if (solveFor.isEmpty || !(formula.solvableFor?.contains(solveFor) ?? false)) {
      _finishWithError('Formula cannot be solved for: ${solveFor.isEmpty ? 'unknown target' : solveFor}');
      return;
    }

    // Now set metadata based on target variable's unit preference
    if (energyUnitMeta == null && firstEnergyVar != null) {
      energyUnitMeta = unitSelections[firstEnergyVar.key] ?? firstEnergyVar.preferredUnits.first;
    }
    
    // Priority: use target variable's selected unit > fallback to collected densityUnitMeta
    final targetVar = formula.variablesResolved.firstWhere((v) => v.key == solveFor, orElse: () => formula.variablesResolved.first);
    final isDensityTarget = targetVar.preferredUnits.contains('cm^-3') && targetVar.preferredUnits.contains('m^-3');
    if (isDensityTarget) {
      final targetDensityUnit = unitSelections[solveFor] ?? densityUnitMeta ?? (unitSystem == UnitSystem.cm ? 'cm^-3' : 'm^-3');
      overrides['__meta__density_unit'] = SymbolValue(value: 0, unit: targetDensityUnit, source: SymbolSource.computed);
      densityDisplayUnitMeta = targetDensityUnit;
    } else if (densityUnitMeta != null) {
      overrides['__meta__density_unit'] = SymbolValue(value: 0, unit: densityUnitMeta, source: SymbolSource.computed);
      densityDisplayUnitMeta = densityUnitMeta;
    }
    
    if (energyUnitMeta != null) {
      overrides['__meta__E_unit'] = SymbolValue(value: 0, unit: energyUnitMeta, source: SymbolSource.computed);
      energyDisplayUnitMeta = energyUnitMeta;
    }

    final solver = _solver!;
    final result = solver.solve(
      formulaId: formula.id,
      solveFor: solveFor,
      workspaceGlobals: workspace.globals,
      panelOverrides: overrides,
      latexMap: latexMap,
    );

    if (result.status != PanelStatus.solved) {
      _finishWithError(result.errorMessage ?? 'Unable to solve.');
      return;
    }

    final outputs = result.outputs;
    final solvedValue = outputs[solveFor];
    final shouldBackfill = missing.length == 1;
    if (solvedValue != null && shouldBackfill) {
      final fmt6 = NumberFormatter(significantFigures: 6, sciThresholdExp: 6);
      var displayValue = solvedValue.value;
      var currentUnit = solvedValue.unit.isNotEmpty ? solvedValue.unit : 'm^-3';
      
      FormulaVariable? solvedVar;
      for (final v in formula.variablesResolved) {
        if (v.key == solveFor) {
          solvedVar = v;
          break;
        }
      }
      if (solvedVar != null) {
        final selection = unitSelections[solveFor];
        if (solvedVar.preferredUnits.contains('eV') && solvedVar.preferredUnits.contains('J')) {
          final targetUnit = selection ?? energyDisplayUnitMeta ?? solvedVar.preferredUnits.first;
          // Only convert if solver output unit differs from target unit
          if (currentUnit != targetUnit) {
            final converted = unitConverter.convertEnergy(displayValue, currentUnit, targetUnit);
            if (converted != null) displayValue = converted;
          }
        } else if (solvedVar.preferredUnits.contains('cm^-3') && solvedVar.preferredUnits.contains('m^-3')) {
          final targetUnit = selection ?? (workspace.unitSystem == UnitSystem.cm ? 'cm^-3' : 'm^-3');
          // Only convert if solver output unit differs from target unit
          if (currentUnit != targetUnit) {
            final converted = unitConverter.convertDensity(displayValue, currentUnit, targetUnit);
            if (converted != null) displayValue = converted;
          }
        }
      }
      controllers[solveFor]?.text = fmt6.formatPlainText(displayValue);
    }

    final updatedOverrides = Map<String, SymbolValue>.from(panel.overrides)..addAll(overrides);
    final updatedOutputs = Map<String, SymbolValue>.from(outputs);
    final updatedPanels = workspace.panels.map((p) {
      if (p.id != panel.id) return p;
      return p.copyWith(
        overrides: updatedOverrides,
        outputs: updatedOutputs,
        status: PanelStatus.solved,
        lastSolvedFor: solveFor,
        lastStepLatex: result.stepsLatex?.workingLines ?? const [],
        lastSolvedAt: DateTime.now(),
      );
    }).toList();
    await appState.updateCurrentWorkspace(workspace.copyWith(panels: updatedPanels));

    isComputing = false;
    lastOutputs = outputs;
    lastSteps = result.stepsLatex;
    notifyListeners();
  }

  void clear() {
    for (final c in controllers.values) {
      c.clear();
    }
    lastOutputs = null;
    lastSteps = null;
    lastError = null;
    lastErrorLatex = null;
    notifyListeners();
  }

  String? selectedUnit(String key) => unitSelections[key];

  void setUnitSelection(String key, String unit, {bool updateDensityMeta = false, bool updateEnergyMeta = false}) {
    unitSelections[key] = unit;
    if (updateDensityMeta) {
      densityDisplayUnitMeta = unit;
    }
    if (updateEnergyMeta) {
      energyDisplayUnitMeta = unit;
    }
    notifyListeners();
  }

  bool isEnergyVariable(String key) =>
      formula.variablesResolved.any((v) => v.key == key && v.preferredUnits.contains('eV') && v.preferredUnits.contains('J'));

  String primaryEnergyUnitFor(String key) => unitSelections[key] ?? energyDisplayUnitMeta ?? 'J';

  SymbolValue _convertEnergyValue(SymbolValue value, ConstantsRepository constantsRepo, String targetUnit) {
    if (value.unit.isEmpty && targetUnit == 'J') {
      return SymbolValue(value: value.value, unit: 'J', source: value.source);
    }
    if (value.unit == targetUnit) return value;
    final sourceUnit = value.unit.isNotEmpty ? value.unit : 'J';
    final unitConverter = UnitConverter(constantsRepo);
    if (sourceUnit == 'J' && targetUnit == 'eV') {
      final converted = unitConverter.convertEnergy(value.value, 'J', 'eV');
      if (converted != null) return SymbolValue(value: converted, unit: 'eV', source: value.source);
    }
    if (sourceUnit == 'eV' && targetUnit == 'J') {
      final converted = unitConverter.convertEnergy(value.value, 'eV', 'J');
      if (converted != null) return SymbolValue(value: converted, unit: 'J', source: value.source);
    }
    return value.unit.isNotEmpty ? value : SymbolValue(value: value.value, unit: sourceUnit, source: value.source);
  }

  String unitLatexFor(
    FormulaVariable v,
    UnitSystem unitSystem,
  ) {
    final formatter = const NumberFormatter();
    var unit = v.siUnit.isNotEmpty ? v.siUnit : '';
    if (unitSystem == UnitSystem.cm && unit == 'm^-3' && v.preferredUnits.contains('cm^-3')) {
      unit = 'cm^-3';
    }
    final overrideUnit = unitSelections[v.key];
    if (overrideUnit != null && overrideUnit.isNotEmpty) {
      unit = overrideUnit;
    }
    return r'\mathrm{' + formatter.formatLatexUnit(unit) + r'}';
  }

  SymbolValue convertResultForDisplay(
    String key,
    SymbolValue value,
    ConstantsRepository constantsRepo,
  ) {
    final unitConverter = UnitConverter(constantsRepo);
    if (isEnergyVariable(key)) {
      final targetUnit = primaryEnergyUnitFor(key);
      return _convertEnergyValue(value, constantsRepo, targetUnit);
    }
    final isDensityVar = formula.variablesResolved.any(
      (v) => v.key == key && v.preferredUnits.contains('cm^-3') && v.preferredUnits.contains('m^-3'),
    );
    if (isDensityVar) {
      // Get user's selected unit for THIS specific symbol (not global density meta)
      final targetUnit = unitSelections[key] ?? densityDisplayUnitMeta ?? 'm^-3';
      final sourceUnit = value.unit.isNotEmpty ? value.unit : 'm^-3';
      
      // Convert if source and target differ
      if (sourceUnit != targetUnit) {
        final converted = unitConverter.convertDensity(value.value, sourceUnit, targetUnit);
        if (converted != null) {
          return SymbolValue(value: converted, unit: targetUnit, source: value.source);
        }
      }
      // If no conversion needed, ensure unit label matches target
      return SymbolValue(value: value.value, unit: targetUnit, source: value.source);
    }
    return value;
  }

  String _formatInput(double value) {
    final fmt = NumberFormatter(significantFigures: 6, sciThresholdExp: 6);
    return fmt.formatPlainText(value);
  }

  void _startComputing() {
    isComputing = true;
    lastError = null;
    lastErrorLatex = null;
    lastSteps = null;
    lastOutputs = null;
    notifyListeners();
  }

  void _finishWithError(String message, {String? latexMessage}) {
    isComputing = false;
    lastError = message;
    lastErrorLatex = latexMessage;
    notifyListeners();
  }

  String _fallbackSymbolLatex(String key) {
    final match = RegExp(r'^([A-Za-z]+)_(.+)$').firstMatch(key);
    if (match == null) return key;
    final base = match.group(1)!;
    final sub = match.group(2)!;
    return '${base}_{${sub}}';
  }
}
