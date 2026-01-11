import 'package:flutter/material.dart';

import '../../../core/constants/constants_repository.dart';
import '../../../core/constants/latex_symbols.dart';
import '../../../core/formulas/formula_variable.dart';
import '../../../core/models/unit_preferences.dart';
import '../../../core/solver/input_number_parser.dart';
import '../../../core/solver/number_formatter.dart';
import '../../../core/solver/unit_converter.dart';
import '../../controllers/formula_panel_controller.dart';
import '../formula_ui_theme.dart';
import '../latex_text.dart';

class VariableInputs extends StatelessWidget {
  const VariableInputs({
    super.key,
    required this.controller,
    required this.variables,
    required this.latexMap,
    required this.constantsRepo,
    required this.unitSystem,
  });

  final FormulaPanelController controller;
  final List<FormulaVariable> variables;
  final LatexSymbolMap latexMap;
  final ConstantsRepository constantsRepo;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final unitConverter = UnitConverter(constantsRepo);
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = constraints.maxWidth > 600 ? 220.0 : 180.0;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: variables.map((v) {
            final symbolLatex = latexMap.latexOf(v.key).isNotEmpty ? latexMap.latexOf(v.key) : v.key;
            final labelWidget = ConstrainedBox(
              constraints: BoxConstraints(maxWidth: minWidth),
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: LatexText(
                  symbolLatex,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            );
            return ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth),
              child: _VariableInputField(
                variable: v,
                labelWidget: labelWidget,
                controller: controller,
                latexMap: latexMap,
                unitConverter: unitConverter,
                unitSystem: unitSystem,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _VariableInputField extends StatelessWidget {
  const _VariableInputField({
    required this.variable,
    required this.labelWidget,
    required this.controller,
    required this.latexMap,
    required this.unitConverter,
    required this.unitSystem,
  });

  final FormulaVariable variable;
  final Widget? labelWidget;
  final FormulaPanelController controller;
  final LatexSymbolMap latexMap;
  final UnitConverter unitConverter;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final supportsEnergy = variable.preferredUnits.contains('eV') && variable.preferredUnits.contains('J');
    final supportsDensity = variable.preferredUnits.contains('cm^-3') && variable.preferredUnits.contains('m^-3');

    if (supportsEnergy) return _energyField(context);
    if (supportsDensity) return _densityField(context);
    return _defaultField(context);
  }

  Widget _energyField(BuildContext context) {
    final selectedUnit = controller.selectedUnit(variable.key) ?? variable.preferredUnits.first;
    final inputField = TextField(
      controller: controller.controllers[variable.key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: FormulaUiTheme.inputTextStyle(context),
      decoration: FormulaUiTheme.inputDecoration(
        context,
        label: labelWidget,
        labelText: null,
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
        final controllerForField = controller.controllers[variable.key];
        final currentText = controllerForField?.text.trim() ?? '';
        final parsed = InputNumberParser.parseFlexibleDouble(currentText);
        if (parsed != null) {
          final converted = unitConverter.convertEnergy(parsed, selectedUnit, u);
          if (converted != null) {
            final fmt6 = NumberFormatter(significantFigures: 6, sciThresholdExp: 6);
            controllerForField?.text = fmt6.formatPlainText(converted);
          }
        }
        controller.setUnitSelection(variable.key, u, updateEnergyMeta: true);
      },
    );
    return _inputRow(inputField: inputField, unitWidget: unitWidget);
  }

  Widget _densityField(BuildContext context) {
    final selectedUnit =
        controller.selectedUnit(variable.key) ?? (unitSystem == UnitSystem.cm ? 'cm^-3' : variable.preferredUnits.first);
    final inputField = TextField(
      controller: controller.controllers[variable.key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: FormulaUiTheme.inputTextStyle(context),
      decoration: FormulaUiTheme.inputDecoration(
        context,
        label: labelWidget,
        labelText: null,
        hintText: 'Enter value',
      ),
    );
    final unitWidget = UnitDropdown<String>(
      value: selectedUnit,
      width: FormulaUiTheme.unitMinWidth,
      items: [
        DropdownMenuItem(
          value: 'cm^-3',
          child: LatexText(r'\mathrm{cm}^{-3}', style: FormulaUiTheme.unitTextStyle(context)),
        ),
        DropdownMenuItem(
          value: 'm^-3',
          child: LatexText(r'\mathrm{m}^{-3}', style: FormulaUiTheme.unitTextStyle(context)),
        ),
      ],
      onChanged: (u) {
        if (u == null || u == selectedUnit) return;
        final controllerForField = controller.controllers[variable.key];
        final currentText = controllerForField?.text.trim() ?? '';
        final parsed = InputNumberParser.parseFlexibleDouble(currentText);
        if (parsed != null) {
          final converted = unitConverter.convertDensity(parsed, selectedUnit, u);
          if (converted != null) {
            final fmt6 = NumberFormatter(significantFigures: 6, sciThresholdExp: 6);
            controllerForField?.text = fmt6.formatPlainText(converted);
          }
        }
        controller.setUnitSelection(variable.key, u, updateDensityMeta: true);
      },
    );
    return _inputRow(inputField: inputField, unitWidget: unitWidget);
  }

  Widget _defaultField(BuildContext context) {
    final inputField = TextField(
      controller: controller.controllers[variable.key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: FormulaUiTheme.inputTextStyle(context),
      decoration: FormulaUiTheme.inputDecoration(
        context,
        label: labelWidget,
        labelText: null,
        hintText: 'Enter value',
      ),
    );
    final unitWidget = UnitCell(
      latex: controller.unitLatexFor(variable, unitSystem),
    );
    return _inputRow(inputField: inputField, unitWidget: unitWidget);
  }

  Widget _inputRow({required Widget inputField, required Widget unitWidget}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: FormulaPanelController.valueFieldWidth, height: FormulaUiTheme.fieldHeight, child: inputField),
        const SizedBox(width: 8),
        unitWidget,
      ],
    );
  }
}
