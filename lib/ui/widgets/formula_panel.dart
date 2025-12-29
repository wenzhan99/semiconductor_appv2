import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/constants_repository.dart';
import '../../core/constants/formula_constants_resolver.dart';
import '../../core/constants/latex_symbols.dart';
import '../../core/formulas/formula_definition.dart';
import '../../core/formulas/formula_repository.dart';
import '../../core/formulas/formula_variable.dart';
import '../../core/formulas/formula_extensions.dart';
import '../../core/models/workspace.dart';
import '../../core/models/unit_preferences.dart';
import '../../core/solver/formula_solver.dart';
import '../../core/solver/input_number_parser.dart';
import '../../core/solver/number_formatter.dart';
import '../../core/solver/step_latex_builder.dart';
import '../../core/solver/step_items.dart';
import '../../core/solver/unit_converter.dart';
import '../../services/app_state.dart';
import 'formula_ui_theme.dart';
import 'latex_text.dart';

/// Rebuilt FormulaPanel widget for rendering and solving formulas.
class FormulaPanel extends StatefulWidget {
  final FormulaDefinition formula;
  final WorkspacePanel panel;

  const FormulaPanel({
    super.key,
    required this.formula,
    required this.panel,
  });

  @override
  State<FormulaPanel> createState() => _FormulaPanelState();
}

class _FormulaPanelState extends State<FormulaPanel> {
  final Map<String, TextEditingController> _controllers = {};
  final NumberFormatter _formatter = const NumberFormatter(significantFigures: 3, sciThresholdExp: 3);
  final Map<String, String> _unitSelections = {}; // key -> current unit (for dropdown-enabled fields)

  FormulaSolver? _solver;
  StepLatex? _lastSteps;
  Map<String, SymbolValue>? _lastOutputs;
  String? _lastError;
  String? _lastNotice;
  bool get _isEnergyBandCategory =>
      widget.formula.id == 'parabolic_band_dispersion' ||
      widget.formula.id == 'effective_mass_from_curvature';
  bool _isComputing = false;
  static const double _valueFieldWidth = 168;
  String? _densityDisplayUnitMeta; // Tracks current density unit preference (cm^-3 or m^-3)

  @override
  void initState() {
    super.initState();
    _initControllers();
    _initSolver();
  }

  Widget _buildConstantsSection(LatexSymbolMap latexMap) {
    final constantsRepo = context.read<ConstantsRepository>();
    final constantsResolver = FormulaConstantsResolver(constantsRepo);
    final requiredKeys = <String>[];
    final seen = <String>{};

    // Preserve declared order, then add any additional constants discovered from expressions.
    for (final c in widget.formula.constantsUsedResolved) {
      final normalized = constantsRepo.normalizeConstantKey(c.key);
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      requiredKeys.add(normalized);
    }
    for (final k in constantsResolver.requiredKeys(widget.formula)) {
      final normalized = constantsRepo.normalizeConstantKey(k);
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      requiredKeys.add(normalized);
    }

    if (requiredKeys.isEmpty) return const SizedBox.shrink();

    final resolved = constantsRepo.resolveConstants(requiredKeys);
    final noteByKey = {
      for (final c in widget.formula.constantsUsedResolved)
        constantsRepo.normalizeConstantKey(c.key): c.note
    };
    final constantsFormatter = const NumberFormatter(significantFigures: 6, sciThresholdExp: 3);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: FormulaUiTheme.fieldRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Constants used:',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...requiredKeys.map((key) {
            final latex = latexMap.latexOf(key);
            final symbolValue = resolved[key];
            final unit = symbolValue?.unit ?? '';
            final valueLatex = symbolValue != null
                ? constantsFormatter.formatLatexWithUnit(symbolValue.value, unit)
                : r'\text{Missing constant}';
            final note = noteByKey[key];
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxNoteWidth = constraints.maxWidth * 0.35;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 48,
                        child: LatexText(
                          latex,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: LatexText('= $valueLatex', style: Theme.of(context).textTheme.bodyMedium),
                        ),
                      ),
                      if (note != null && note.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxNoteWidth),
                          child: Text(
                            '($note)',
                            overflow: TextOverflow.visible,
                            softWrap: true,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllers() {
    for (final v in widget.formula.variablesResolved) {
      final existing = widget.panel.overrides[v.key];
      final text = existing != null ? _formatInput(existing.value) : '';
      _controllers[v.key] = TextEditingController(text: text);
      // Track unit selection for dropdown-enabled fields
      if (v.preferredUnits.contains('eV') && v.preferredUnits.contains('J')) {
        _unitSelections[v.key] = existing?.unit.isNotEmpty == true ? existing!.unit : v.preferredUnits.first;
      } else if (v.preferredUnits.contains('cm^-3') && v.preferredUnits.contains('m^-3')) {
        final existingUnit = existing?.unit.isNotEmpty == true ? existing!.unit : v.preferredUnits.first;
        _unitSelections[v.key] = existingUnit;
        _densityDisplayUnitMeta ??= existingUnit;
      }
    }
  }

  Future<void> _initSolver() async {
    final repo = FormulaRepository();
    await repo.preloadAll();
    setState(() {
      _solver = FormulaSolver(formulaRepo: repo, constantsRepo: context.read<ConstantsRepository>());
    });
  }

  String _formatInput(double value) {
    // Use 6 s.f. for back-filling inputs.
    final fmt = NumberFormatter(significantFigures: 6, sciThresholdExp: 6);
    return fmt.formatPlainText(value);
  }

  @override
  Widget build(BuildContext context) {
    final latexMap = context.read<LatexSymbolMap>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(latexMap),
        const SizedBox(height: 12),
        _buildConstantsSection(latexMap),
        const SizedBox(height: 12),
        _buildInputs(latexMap),
        const SizedBox(height: 12),
        _buildActions(),
        const SizedBox(height: 12),
        if (_lastError != null) _buildError(),
        if (_lastNotice != null) _buildNotice(),
        if (_lastOutputs != null && _lastOutputs!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildResults(latexMap),
        ],
        if (_lastSteps != null) ...[
          const SizedBox(height: 12),
          _buildSteps(latexMap),
        ],
      ],
    );
  }

  Widget _buildHeader(LatexSymbolMap latexMap) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            widget.formula.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: LatexText(
              latexMap.sanitizeEquationLatexForRender(widget.formula.equationLatex),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              displayMode: true,
              scale: 1.15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputs(LatexSymbolMap latexMap) {
    final variables = widget.formula.variablesResolved;
    final unitConverter = UnitConverter(context.read<ConstantsRepository>());
    final unitSystem = context.read<AppState>().currentWorkspace?.unitSystem ?? UnitSystem.cm;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: variables.map((v) {
        final labelLatex = latexMap.latexOf(v.key);
        final wantsLatex = labelLatex != v.key || labelLatex.contains(RegExp(r'[\\_^]'));
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220),
          child: _buildVariableInput(v, wantsLatex ? LatexText(labelLatex) : null, latexMap, unitConverter, unitSystem),
        );
      }).toList(),
    );
  }

  Widget _inputRow({required Widget inputField, required Widget unitWidget}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: _valueFieldWidth, height: FormulaUiTheme.fieldHeight, child: inputField),
        const SizedBox(width: 8),
        unitWidget,
      ],
    );
  }

  Widget _buildVariableInput(
    FormulaVariable v,
    Widget? labelWidget,
    LatexSymbolMap latexMap,
    UnitConverter unitConverter,
    UnitSystem unitSystem,
  ) {
    // Energy dropdown (eV/J)
    final supportsEnergy = v.preferredUnits.contains('eV') && v.preferredUnits.contains('J');
    // Density dropdown (cm^-3 / m^-3)
    final supportsDensity = v.preferredUnits.contains('cm^-3') && v.preferredUnits.contains('m^-3');

    if (supportsEnergy) {
      final selectedUnit = _unitSelections[v.key] ?? v.preferredUnits.first;
      final inputField = TextField(
        controller: _controllers[v.key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: FormulaUiTheme.inputTextStyle(context),
        decoration: FormulaUiTheme.inputDecoration(
          context,
          label: labelWidget,
          labelText: labelWidget == null ? v.name : null,
          hintText: 'Enter value',
        ),
      );
      final unitWidget = UnitDropdown<String>(
        value: selectedUnit,
        width: FormulaUiTheme.unitMinWidth,
        items: [
          DropdownMenuItem(
            value: 'J',
            child: LatexText(r'\mathrm{J}', style: FormulaUiTheme.unitTextStyle(context)),
          ),
          DropdownMenuItem(
            value: 'eV',
            child: LatexText(r'\mathrm{eV}', style: FormulaUiTheme.unitTextStyle(context)),
          ),
        ],
        onChanged: (u) {
          if (u == null || u == selectedUnit) return;
          final controller = _controllers[v.key];
          final currentText = controller?.text.trim() ?? '';
          final parsed = InputNumberParser.parseFlexibleDouble(currentText);
          if (parsed != null) {
            final converted = unitConverter.convertEnergy(parsed, selectedUnit, u);
            if (converted != null) {
              final fmt6 = NumberFormatter(significantFigures: 6, sciThresholdExp: 6);
              controller?.text = fmt6.formatPlainText(converted);
            }
          }
          setState(() {
            _unitSelections[v.key] = u;
            _densityDisplayUnitMeta = u;
          });
        },
      );
      return _inputRow(inputField: inputField, unitWidget: unitWidget);
    }

    if (supportsDensity) {
      final selectedUnit = _unitSelections[v.key] ?? (unitSystem == UnitSystem.cm ? 'cm^-3' : v.preferredUnits.first);
      final inputField = TextField(
        controller: _controllers[v.key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: FormulaUiTheme.inputTextStyle(context),
        decoration: FormulaUiTheme.inputDecoration(
          context,
          label: labelWidget,
          labelText: labelWidget == null ? v.name : null,
          hintText: 'Enter value',
        ),
      );
      final unitWidget = UnitDropdown<String>(
        value: selectedUnit,
        width: FormulaUiTheme.unitMinWidth,
        items: [
          DropdownMenuItem(
            value: 'cm^-3',
            child: LatexText(r'\mathrm{cm^{-3}}', style: FormulaUiTheme.unitTextStyle(context)),
          ),
          DropdownMenuItem(
            value: 'm^-3',
            child: LatexText(r'\mathrm{m^{-3}}', style: FormulaUiTheme.unitTextStyle(context)),
          ),
        ],
        onChanged: (u) {
          if (u == null || u == selectedUnit) return;
          final controller = _controllers[v.key];
          final currentText = controller?.text.trim() ?? '';
          final parsed = InputNumberParser.parseFlexibleDouble(currentText);
          if (parsed != null) {
            final converted = unitConverter.convertDensity(parsed, selectedUnit, u);
            if (converted != null) {
              final fmt6 = NumberFormatter(significantFigures: 6, sciThresholdExp: 6);
              controller?.text = fmt6.formatPlainText(converted);
            }
          }
          setState(() {
            _unitSelections[v.key] = u;
          });
        },
      );
      return _inputRow(inputField: inputField, unitWidget: unitWidget);
    }

    final inputField = TextField(
      controller: _controllers[v.key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: FormulaUiTheme.inputTextStyle(context),
      decoration: FormulaUiTheme.inputDecoration(
        context,
        label: labelWidget,
        labelText: labelWidget == null ? v.name : null,
        hintText: 'Enter value',
      ),
    );
    final unitWidget = UnitCell(
      latex: _unitLatexFor(v, latexMap, unitConverter, unitSystem),
    );
    return _inputRow(inputField: inputField, unitWidget: unitWidget);
  }

  String _unitLatexFor(
    FormulaVariable v,
    LatexSymbolMap latexMap,
    UnitConverter converter,
    UnitSystem unitSystem,
  ) {
    final formatter = const NumberFormatter();
    var unit = v.siUnit.isNotEmpty ? v.siUnit : '';
    if (unitSystem == UnitSystem.cm && unit == 'm^-3' && v.preferredUnits.contains('cm^-3')) {
      unit = 'cm^-3';
    }
    // Respect dropdown overrides
    final overrideUnit = _unitSelections[v.key];
    if (overrideUnit != null && overrideUnit.isNotEmpty) {
      unit = overrideUnit;
    }
    return r'\mathrm{' + formatter.formatLatexUnit(unit) + r'}';
  }

  Widget _buildActions() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _isComputing ? null : _compute,
          icon: const Icon(Icons.calculate),
          label: Text(_isComputing ? 'Computing...' : 'Compute'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: _isComputing ? null : _clear,
          child: const Text('Clear'),
        ),
      ],
    );
  }

  Future<void> _compute() async {
    if (_solver == null) return;
    setState(() {
      _isComputing = true;
      _lastError = null;
      _lastNotice = null;
      _lastSteps = null;
      _lastOutputs = null;
    });

    final appState = context.read<AppState>();
    final constantsRepo = context.read<ConstantsRepository>();
    final latexMap = context.read<LatexSymbolMap>();
    final workspace = appState.currentWorkspace;
    final unitConverter = UnitConverter(constantsRepo);
    if (workspace == null) {
      setState(() {
        _isComputing = false;
        _lastError = 'No workspace selected.';
      });
      return;
    }

    final overrides = <String, SymbolValue>{};
    String? densityUnitMeta;
    String? energyUnitMeta;
    final missing = <String>[];
    final unitSystem = workspace.unitSystem;
    final sanityHints = <String>{};
    for (final v in widget.formula.variablesResolved) {
      final raw = _controllers[v.key]?.text.trim() ?? '';
      if (raw.isEmpty) {
        missing.add(v.key);
        continue;
      }
      final parsed = InputNumberParser.parseFlexibleDouble(raw);
      if (parsed == null) {
        setState(() {
          _isComputing = false;
          _lastError = 'Invalid input for ${v.name}';
        });
        return;
      }

      final supportsEnergy = v.preferredUnits.contains('eV') && v.preferredUnits.contains('J');
      final supportsDensity = v.preferredUnits.contains('cm^-3') && v.preferredUnits.contains('m^-3');

      double value = parsed;
      String unit = v.siUnit;

      if (supportsEnergy) {
        final selectedUnit = _unitSelections[v.key] ?? v.preferredUnits.first;
        energyUnitMeta ??= selectedUnit;
        if (selectedUnit == 'eV') {
          final converted = unitConverter.convertEnergy(value, 'eV', 'J');
          if (converted == null) {
            setState(() {
              _isComputing = false;
              _lastError = 'Unable to convert energy to J for ${v.name}.';
            });
            return;
          }
          value = converted;
        }
        unit = 'J';
      } else if (supportsDensity) {
        final selectedUnit = _unitSelections[v.key] ?? (unitSystem == UnitSystem.cm ? 'cm^-3' : v.preferredUnits.first);
        densityUnitMeta ??= selectedUnit;
        if (selectedUnit == 'cm^-3') {
          final converted = unitConverter.convertDensity(value, 'cm^-3', 'm^-3');
          if (converted == null) {
            setState(() {
              _isComputing = false;
              _lastError = 'Unable to convert density to m^-3 for ${v.name}.';
            });
            return;
          }
          value = converted;
        }
        if (selectedUnit == 'm^-3' && value >= 1e12 && value <= 1e19) {
          final cmGuess = unitConverter.convertDensity(value, 'm^-3', 'cm^-3');
          final fmt6 = NumberFormatter(significantFigures: 6, sciThresholdExp: 6);
          final guessed = cmGuess != null ? fmt6.formatPlainText(cmGuess) : null;
          final hint = guessed != null
              ? 'Value for ${v.name} is $value m^-3 (≈ $guessed cm^-3); typical doping is often entered in cm^-3.'
              : 'Value for ${v.name} is $value m^-3; typical doping is often entered in cm^-3.';
          sanityHints.add(hint);
        }
        unit = 'm^-3';
      }

      overrides[v.key] = SymbolValue(value: value, unit: unit, source: SymbolSource.user);
    }

    // Propagate meta unit preferences for step rendering.
    overrides['__meta__unit_system'] = SymbolValue(
      value: 0,
      unit: unitSystem == UnitSystem.cm ? 'cm' : 'si',
      source: SymbolSource.computed,
    );
    if (densityUnitMeta != null) {
      overrides['__meta__density_unit'] = SymbolValue(value: 0, unit: densityUnitMeta!, source: SymbolSource.computed);
      _densityDisplayUnitMeta = densityUnitMeta;
    }
    if (energyUnitMeta != null) {
      overrides['__meta__E_unit'] = SymbolValue(value: 0, unit: energyUnitMeta!, source: SymbolSource.computed);
    }

    // Determine target variable via autosolve: single missing -> solve for it; none missing -> consistency solve.
    String solveFor;
    if (missing.length == 1) {
      solveFor = missing.first;
    } else if (missing.isEmpty) {
      solveFor = widget.formula.solvableFor?.first ?? (widget.formula.variablesResolved.isNotEmpty ? widget.formula.variablesResolved.first.key : '');
    } else {
      setState(() {
        _isComputing = false;
        _lastError = 'Missing required inputs: ${missing.join(", ")}';
      });
      return;
    }

    if (solveFor.isEmpty || !(widget.formula.solvableFor?.contains(solveFor) ?? false)) {
      setState(() {
        _isComputing = false;
        _lastError = 'Formula cannot be solved for: ${solveFor.isEmpty ? 'unknown target' : solveFor}';
      });
      return;
    }

    // Build solver context maps
    final solver = _solver!;
    final result = solver.solve(
      formulaId: widget.formula.id,
      solveFor: solveFor,
      workspaceGlobals: workspace.globals,
      panelOverrides: overrides,
      latexMap: latexMap,
    );

    if (result.status != PanelStatus.solved) {
      setState(() {
        _isComputing = false;
        _lastError = result.errorMessage ?? 'Unable to solve.';
      });
      return;
    }

    final outputs = result.outputs;
    final solvedValue = outputs[solveFor];
    // Update controller for solved variable with 6 s.f. (skip backfill for consistency runs with no missing vars)
    final shouldBackfill = missing.length == 1;
    if (solvedValue != null && shouldBackfill) {
      final fmt6 = NumberFormatter(significantFigures: 6, sciThresholdExp: 6);
      _controllers[solveFor]?.text = fmt6.formatPlainText(solvedValue.value);
    }

    // Update workspace panel overrides/outputs
    final updatedOverrides = Map<String, SymbolValue>.from(widget.panel.overrides)..addAll(overrides);
    final updatedOutputs = Map<String, SymbolValue>.from(outputs);
    final updatedPanels = workspace.panels.map((p) {
      if (p.id != widget.panel.id) return p;
      return p.copyWith(
        overrides: updatedOverrides,
        outputs: updatedOutputs,
        status: PanelStatus.solved,
      );
    }).toList();
    await appState.updateCurrentWorkspace(workspace.copyWith(panels: updatedPanels));

    setState(() {
      _isComputing = false;
      _lastOutputs = outputs;
      _lastSteps = result.stepsLatex;
      if (result.notice != null && result.notice!.isNotEmpty) {
        _lastNotice = result.notice;
      } else if (sanityHints.isNotEmpty) {
        _lastNotice = sanityHints.join(' ');
      } else {
        _lastNotice = null;
      }
    });
  }

  void _clear() {
    for (final c in _controllers.values) {
      c.clear();
    }
    setState(() {
      _lastOutputs = null;
      _lastSteps = null;
      _lastError = null;
      _lastNotice = null;
    });
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: FormulaUiTheme.fieldRadius,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lastError ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: FormulaUiTheme.fieldRadius,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lastNotice ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(LatexSymbolMap latexMap) {
    final formatter = const NumberFormatter(significantFigures: 3, sciThresholdExp: 3);
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Result',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._lastOutputs!.entries.map((entry) {
              final key = entry.key;
              final value = entry.value;
              final latexLabel = latexMap.latexOf(key);
              final displayValue = _convertResultForDisplay(key, value);
              final latexVal = displayValue.unit.isNotEmpty
                  ? formatter.formatLatexWithUnit(displayValue.value, displayValue.unit)
                  : formatter.formatLatex(displayValue.value);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      LatexText(
                        latexLabel,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      LatexText(
                        r'\;=\;' + latexVal,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  SymbolValue _convertResultForDisplay(String key, SymbolValue value) {
    final constantsRepo = context.read<ConstantsRepository>();
    final unitConverter = UnitConverter(constantsRepo);
    final densityPreference = _densityDisplayUnitMeta;
    final isDensityVar = widget.formula.variablesResolved.any(
      (v) => v.key == key && v.preferredUnits.contains('cm^-3') && v.preferredUnits.contains('m^-3'),
    );
    if (isDensityVar && densityPreference != null && value.unit == 'm^-3' && densityPreference != 'm^-3') {
      final converted = unitConverter.convertDensity(value.value, 'm^-3', densityPreference);
      if (converted != null) {
        return SymbolValue(value: converted, unit: densityPreference, source: value.source);
      }
    }
    return value;
  }

  Widget _buildSteps(LatexSymbolMap latexMap) {
    final steps = _lastSteps!;
    final items = steps.workingItems;
    if (items.isEmpty) return const SizedBox.shrink();
    final headerStyle = FormulaUiTheme.stepHeaderTextStyle(context);
    final bodyStyle = FormulaUiTheme.stepBodyTextStyle(context);
    final mathStyle = FormulaUiTheme.stepMathTextStyle(context);
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step-by-step working', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...items.map((item) {
              if (item.type == StepItemType.text) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(item.value, style: headerStyle),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: LatexText(
                    item.latex,
                    style: mathStyle,
                    displayMode: true,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
