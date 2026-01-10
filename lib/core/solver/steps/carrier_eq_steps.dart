import 'dart:math' as math;

import 'package:semiconductor_appv2/core/constants/latex_symbols.dart';
import 'package:semiconductor_appv2/core/formulas/formula_definition.dart';
import 'package:semiconductor_appv2/core/models/workspace.dart';
import 'package:semiconductor_appv2/core/solver/number_formatter.dart';
import 'package:semiconductor_appv2/core/solver/step_items.dart';
import 'package:semiconductor_appv2/core/solver/steps/universal_step_template.dart';
import 'package:semiconductor_appv2/core/solver/symbol_context.dart';
import 'package:semiconductor_appv2/core/solver/unit_converter.dart';
import 'package:semiconductor_appv2/core/solver/substitution_equation_builder.dart';

class CarrierEqSteps {
  static const double _relEps = 1e-10;
  static const double _absEps = 1.0;
  static const _electronId = 'carrier_electron_concentration_n0';
  static const _holeId = 'carrier_hole_concentration_p0';
  static const _massActionId = 'mass_action_law';
  static const _majorityNId = 'doped_n_type_majority';
  static const _majorityPId = 'doped_p_type_majority';
  static const _chargeId = 'charge_neutrality_equilibrium';

  static List<StepItem>? tryBuildSteps({
    required FormulaDefinition formula,
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
    UnitConverter? unitConverter,
    UnitConversionLog? conversions,
    String primaryEnergyUnit = 'J',
  }) {
    if (formula.id == _electronId) {
      return _buildElectron(
        solveFor: solveFor,
        context: context,
        outputs: outputs,
        latexMap: latexMap,
        formatter: formatter,
        unitConverter: unitConverter,
        primaryEnergyUnit: primaryEnergyUnit,
      );
    }

    if (formula.id == _holeId) {
      return _buildHole(
        solveFor: solveFor,
        context: context,
        outputs: outputs,
        latexMap: latexMap,
        formatter: formatter,
        unitConverter: unitConverter,
        primaryEnergyUnit: primaryEnergyUnit,
      );
    }

    if (formula.id == _massActionId) {
      return _buildMassAction(
        solveFor: solveFor,
        context: context,
        outputs: outputs,
        latexMap: latexMap,
        formatter: formatter,
        unitConverter: unitConverter,
      );
    }

    if (formula.id == _majorityNId || formula.id == _majorityPId) {
      final isPType = formula.id == _majorityPId;
      return _buildMajority(
        solveFor: solveFor,
        context: context,
        outputs: outputs,
        latexMap: latexMap,
        formatter: formatter,
        unitConverter: unitConverter,
        isPType: isPType,
      );
    }

    if (formula.id == _chargeId) {
      return _buildChargeNeutrality(
        solveFor: solveFor,
        context: context,
        outputs: outputs,
        latexMap: latexMap,
        formatter: formatter,
        unitConverter: unitConverter,
      );
    }

    return null;
  }

  static List<StepItem>? _buildElectron({
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
    UnitConverter? unitConverter,
    required String primaryEnergyUnit,
    UnitConversionLog? conversions,
  }) {
    if (solveFor != 'n_0' && solveFor != 'n_i' && solveFor != 'E_F' && solveFor != 'E_i' && solveFor != 'T') {
      return null;
    }

    final fmt6 = formatter.withSigFigs(6);
    final densityUnit = context.getUnit('__meta__density_unit') ?? 'm^-3';

    final n0 = context.getSymbolValue('n_0');
    final ni = context.getSymbolValue('n_i');
    final ef = context.getSymbolValue('E_F');
    final ei = context.getSymbolValue('E_i');
    final k = context.getSymbolValue('k');
    final t = context.getSymbolValue('T');
    final n0Val = n0?.value;
    final niVal = ni?.value;
    final result = outputs[solveFor];
    final baseUnit = (result != null && result.unit.isNotEmpty)
        ? result.unit
        : (solveFor.startsWith('E_') ? 'J' : solveFor == 'T' ? 'K' : 'm^-3');
    final computedBase = result?.value;

    final unitConversions = <String>[];

    final rearrangeLines = <String>[];
    if (solveFor == 'n_0') {
      rearrangeLines.add('${_sym('n_0', latexMap)} = ${_sym('n_i', latexMap)}\\exp\\!\\left(\\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
    } else if (solveFor == 'n_i') {
      rearrangeLines.add('${_sym('n_0', latexMap)} = ${_sym('n_i', latexMap)}\\exp\\!\\left(\\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('\\dfrac{${_sym('n_0', latexMap)}}{${_sym('n_i', latexMap)}} = \\exp\\!\\left(\\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('${_sym('n_i', latexMap)} = \\dfrac{${_sym('n_0', latexMap)}}{\\exp\\!\\left(\\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)}');
    } else if (solveFor == 'E_F') {
      rearrangeLines.add('${_sym('n_0', latexMap)} = ${_sym('n_i', latexMap)}\\exp\\!\\left(\\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('\\dfrac{${_sym('n_0', latexMap)}}{${_sym('n_i', latexMap)}} = \\exp\\!\\left(\\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('\\ln\\!\\left(\\dfrac{${_sym('n_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right) = \\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}');
      rearrangeLines.add('${_sym('E_F', latexMap)} = ${_sym('E_i', latexMap)} + {${_sym('k', latexMap)}}{${_sym('T', latexMap)}}\\,\\ln\\!\\left(\\dfrac{${_sym('n_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right)');
    } else if (solveFor == 'E_i') {
      rearrangeLines.add('${_sym('n_0', latexMap)} = ${_sym('n_i', latexMap)}\\exp\\!\\left(\\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('\\dfrac{${_sym('n_0', latexMap)}}{${_sym('n_i', latexMap)}} = \\exp\\!\\left(\\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('\\ln\\!\\left(\\dfrac{${_sym('n_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right) = \\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}');
      rearrangeLines.add('${_sym('E_i', latexMap)} = ${_sym('E_F', latexMap)} - {${_sym('k', latexMap)}}{${_sym('T', latexMap)}}\\,\\ln\\!\\left(\\dfrac{${_sym('n_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right)');
    } else {
      rearrangeLines.add('${_sym('n_0', latexMap)} = ${_sym('n_i', latexMap)}\\exp\\!\\left(\\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('\\dfrac{${_sym('n_0', latexMap)}}{${_sym('n_i', latexMap)}} = \\exp\\!\\left(\\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('\\ln\\!\\left(\\dfrac{${_sym('n_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right) = \\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}');
      rearrangeLines.add('${_sym('T', latexMap)} = \\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}\\,\\ln\\!\\left(\\dfrac{${_sym('n_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right)}');
    }

    final substitutionLines = <String>[];
    void addSubstitution(String equation, Map<String, SymbolValue?> values) {
      substitutionLines.add(equation);
      substitutionLines.add(_buildSubstitutionLine(
        equation: equation,
        values: values,
        latexMap: latexMap,
        formatter: fmt6,
      ));
    }

    if (solveFor == 'n_0') {
      final equation = '${_sym('n_0', latexMap)} = ${_sym('n_i', latexMap)}\\exp\\!\\left(\\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)';
      addSubstitution(equation, {
        'n_i': ni,
        'E_F': ef,
        'E_i': ei,
        'k': k,
        'T': t,
      });
    } else if (solveFor == 'n_i') {
      final equation = '${_sym('n_i', latexMap)} = \\dfrac{${_sym('n_0', latexMap)}}{\\exp\\!\\left(\\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)}';
      final efSub = _formatVal(ef, 'E_F', 'J', fmt6, latexMap);
      final eiSub = _formatVal(ei, 'E_i', 'J', fmt6, latexMap);
      final kSub = _formatVal(k, 'k', 'J/K', fmt6, latexMap);
      final tSub = _formatVal(t, 'T', 'K', fmt6, latexMap);
      final n0Sub = _formatVal(n0, 'n_0', 'm^-3', fmt6, latexMap);
      substitutionLines.add(equation);
      substitutionLines.add(
          '${_sym('n_i', latexMap)} = \\dfrac{$n0Sub}{\\exp\\!\\left(\\dfrac{$efSub - $eiSub}{($kSub)($tSub)}\\right)}');
    } else if (solveFor == 'E_F') {
      final equation = '${_sym('E_F', latexMap)} = ${_sym('E_i', latexMap)} + {${_sym('k', latexMap)}}{${_sym('T', latexMap)}}\\,\\ln\\!\\left(\\dfrac{${_sym('n_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right)';
      final ratio = (n0Val != null && niVal != null && niVal != 0)
          ? fmt6.formatLatex(n0Val / niVal)
          : r'\dfrac{' + _sym('n_0', latexMap) + '}{' + _sym('n_i', latexMap) + '}';
      final eiSub = _formatVal(ei, 'E_i', 'J', fmt6, latexMap);
      final kSub = _formatVal(k, 'k', 'J/K', fmt6, latexMap);
      final tSub = _formatVal(t, 'T', 'K', fmt6, latexMap);
      substitutionLines.add(equation);
      substitutionLines.add('${_sym('E_F', latexMap)} = $eiSub + ($kSub)($tSub)\\,\\ln\\!\\left($ratio\\right)');
    } else if (solveFor == 'E_i') {
      final equation = '${_sym('E_i', latexMap)} = ${_sym('E_F', latexMap)} - {${_sym('k', latexMap)}}{${_sym('T', latexMap)}}\\,\\ln\\!\\left(\\dfrac{${_sym('n_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right)';
      final ratio = (n0Val != null && niVal != null && niVal != 0)
          ? fmt6.formatLatex(n0Val / niVal)
          : r'\dfrac{' + _sym('n_0', latexMap) + '}{' + _sym('n_i', latexMap) + '}';
      final efSub = _formatVal(ef, 'E_F', 'J', fmt6, latexMap);
      final kSub = _formatVal(k, 'k', 'J/K', fmt6, latexMap);
      final tSub = _formatVal(t, 'T', 'K', fmt6, latexMap);
      substitutionLines.add(equation);
      substitutionLines.add('${_sym('E_i', latexMap)} = $efSub - ($kSub)($tSub)\\,\\ln\\!\\left($ratio\\right)');
    } else {
      final equation = '${_sym('T', latexMap)} = \\dfrac{${_sym('E_F', latexMap)} - ${_sym('E_i', latexMap)}}{{${_sym('k', latexMap)}}\\,\\ln\\!\\left(\\dfrac{${_sym('n_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right)}';
      final ratio = (n0Val != null && niVal != null && niVal != 0)
          ? fmt6.formatLatex(n0Val / niVal)
          : r'\dfrac{' + _sym('n_0', latexMap) + '}{' + _sym('n_i', latexMap) + '}';
      final efSub = _formatVal(ef, 'E_F', 'J', fmt6, latexMap);
      final eiSub = _formatVal(ei, 'E_i', 'J', fmt6, latexMap);
      final kSub = _formatVal(k, 'k', 'J/K', fmt6, latexMap);
      substitutionLines.add(equation);
      substitutionLines.add('${_sym('T', latexMap)} = \\dfrac{$efSub - $eiSub}{($kSub)\\,\\ln\\!\\left($ratio\\right)}');
    }

    final targetLatex = _sym(solveFor, latexMap);
    String computedValueLine;
    String roundedValueLine;
    if (solveFor.startsWith('E_')) {
      final valueFmt6 = computedBase != null
          ? _formatEnergyValue(computedBase, primaryEnergyUnit, fmt6, unitConverter)
          : targetLatex;
      final valueFmt3 = computedBase != null
          ? _formatEnergyValue(computedBase, primaryEnergyUnit, formatter, unitConverter)
          : targetLatex;
      computedValueLine = '$targetLatex = $valueFmt6';
      roundedValueLine = '$targetLatex = $valueFmt3';
    } else if (solveFor == 'T') {
      final valueFmt6 = computedBase != null ? fmt6.formatLatexWithUnit(computedBase, baseUnit) : targetLatex;
      final valueFmt3 = computedBase != null ? formatter.formatLatexWithUnit(computedBase, baseUnit) : targetLatex;
      computedValueLine = '$targetLatex = $valueFmt6';
      roundedValueLine = '$targetLatex = $valueFmt3';
    } else {
      final displayValue6 = _convertDensity(computedBase, baseUnit, densityUnit, unitConverter) ?? computedBase;
      final displayValue3 = _convertDensity(computedBase, baseUnit, densityUnit, unitConverter) ?? computedBase;
      computedValueLine = computedBase != null
          ? '$targetLatex = ${fmt6.formatLatexWithUnit(displayValue6 ?? computedBase, densityUnit)}'
          : targetLatex;
      roundedValueLine = computedBase != null
          ? '$targetLatex = ${formatter.formatLatexWithUnit(displayValue3 ?? computedBase, densityUnit)}'
          : targetLatex;
    }

    final substitutionEvaluationLine = computedBase != null ? computedValueLine : '';

    return UniversalStepTemplate.build(
      targetLabelLatex: targetLatex,
      unitConversionLines: unitConversions,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: substitutionEvaluationLine,
      computedValueLine: computedValueLine,
      roundedValueLine: roundedValueLine,
    );
  }

  static List<StepItem>? _buildHole({
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
    UnitConverter? unitConverter,
    required String primaryEnergyUnit,
    UnitConversionLog? conversions,
  }) {
    if (solveFor != 'p_0' && solveFor != 'n_i' && solveFor != 'E_F' && solveFor != 'E_i' && solveFor != 'T') {
      return null;
    }

    final fmt6 = formatter.withSigFigs(6);
    final densityUnit = context.getUnit('__meta__density_unit') ?? 'm^-3';

    final p0 = context.getSymbolValue('p_0');
    final ni = context.getSymbolValue('n_i');
    final ef = context.getSymbolValue('E_F');
    final ei = context.getSymbolValue('E_i');
    final k = context.getSymbolValue('k');
    final t = context.getSymbolValue('T');
    final p0Val = p0?.value;
    final niVal = ni?.value;
    final result = outputs[solveFor];
    final baseUnit = (result != null && result.unit.isNotEmpty)
        ? result.unit
        : (solveFor.startsWith('E_') ? 'J' : solveFor == 'T' ? 'K' : 'm^-3');
    final computedBase = result?.value;

    final unitConversions = <String>[];

    final rearrangeLines = <String>[];
    if (solveFor == 'p_0') {
      rearrangeLines.add('${_sym('p_0', latexMap)} = ${_sym('n_i', latexMap)}\\exp\\!\\left(\\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
    } else if (solveFor == 'n_i') {
      rearrangeLines.add('${_sym('p_0', latexMap)} = ${_sym('n_i', latexMap)}\\exp\\!\\left(\\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('\\dfrac{${_sym('p_0', latexMap)}}{${_sym('n_i', latexMap)}} = \\exp\\!\\left(\\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('${_sym('n_i', latexMap)} = \\dfrac{${_sym('p_0', latexMap)}}{\\exp\\!\\left(\\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)}');
    } else if (solveFor == 'E_F') {
      rearrangeLines.add('${_sym('p_0', latexMap)} = ${_sym('n_i', latexMap)}\\exp\\!\\left(\\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('\\dfrac{${_sym('p_0', latexMap)}}{${_sym('n_i', latexMap)}} = \\exp\\!\\left(\\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('\\ln\\!\\left(\\dfrac{${_sym('p_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right) = \\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}');
      rearrangeLines.add('${_sym('E_F', latexMap)} = ${_sym('E_i', latexMap)} - {${_sym('k', latexMap)}}{${_sym('T', latexMap)}}\\,\\ln\\!\\left(\\dfrac{${_sym('p_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right)');
    } else if (solveFor == 'E_i') {
      rearrangeLines.add('${_sym('p_0', latexMap)} = ${_sym('n_i', latexMap)}\\exp\\!\\left(\\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('\\dfrac{${_sym('p_0', latexMap)}}{${_sym('n_i', latexMap)}} = \\exp\\!\\left(\\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('\\ln\\!\\left(\\dfrac{${_sym('p_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right) = \\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}');
      rearrangeLines.add('${_sym('E_i', latexMap)} = ${_sym('E_F', latexMap)} + {${_sym('k', latexMap)}}{${_sym('T', latexMap)}}\\,\\ln\\!\\left(\\dfrac{${_sym('p_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right)');
    } else {
      rearrangeLines.add('${_sym('p_0', latexMap)} = ${_sym('n_i', latexMap)}\\exp\\!\\left(\\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('\\dfrac{${_sym('p_0', latexMap)}}{${_sym('n_i', latexMap)}} = \\exp\\!\\left(\\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)');
      rearrangeLines.add('\\ln\\!\\left(\\dfrac{${_sym('p_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right) = \\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}');
      rearrangeLines.add('${_sym('T', latexMap)} = \\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}\\,\\ln\\!\\left(\\dfrac{${_sym('p_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right)}');
    }

    final substitutionLines = <String>[];
    void addSubstitution(String equation, Map<String, SymbolValue?> values) {
      substitutionLines.add(equation);
      substitutionLines.add(_buildSubstitutionLine(
        equation: equation,
        values: values,
        latexMap: latexMap,
        formatter: fmt6,
      ));
    }

    if (solveFor == 'p_0') {
      final equation = '${_sym('p_0', latexMap)} = ${_sym('n_i', latexMap)}\\exp\\!\\left(\\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)';
      addSubstitution(equation, {
        'n_i': ni,
        'E_i': ei,
        'E_F': ef,
        'k': k,
        'T': t,
      });
    } else if (solveFor == 'n_i') {
      final equation = '${_sym('n_i', latexMap)} = \\dfrac{${_sym('p_0', latexMap)}}{\\exp\\!\\left(\\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}{${_sym('T', latexMap)}}}\\right)}';
      final eiSub = _formatVal(ei, 'E_i', 'J', fmt6, latexMap);
      final efSub = _formatVal(ef, 'E_F', 'J', fmt6, latexMap);
      final kSub = _formatVal(k, 'k', 'J/K', fmt6, latexMap);
      final tSub = _formatVal(t, 'T', 'K', fmt6, latexMap);
      final p0Sub = _formatVal(p0, 'p_0', 'm^-3', fmt6, latexMap);
      substitutionLines.add(equation);
      substitutionLines.add(
          '${_sym('n_i', latexMap)} = \\dfrac{$p0Sub}{\\exp\\!\\left(\\dfrac{$eiSub - $efSub}{($kSub)($tSub)}\\right)}');
    } else if (solveFor == 'E_F') {
      final equation = '${_sym('E_F', latexMap)} = ${_sym('E_i', latexMap)} - {${_sym('k', latexMap)}}{${_sym('T', latexMap)}}\\,\\ln\\!\\left(\\dfrac{${_sym('p_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right)';
      final ratio = (p0Val != null && niVal != null && niVal != 0)
          ? fmt6.formatLatex(p0Val / niVal)
          : r'\dfrac{' + _sym('p_0', latexMap) + '}{' + _sym('n_i', latexMap) + '}';
      final eiSub = _formatVal(ei, 'E_i', 'J', fmt6, latexMap);
      final kSub = _formatVal(k, 'k', 'J/K', fmt6, latexMap);
      final tSub = _formatVal(t, 'T', 'K', fmt6, latexMap);
      substitutionLines.add(equation);
      substitutionLines.add('${_sym('E_F', latexMap)} = $eiSub - ($kSub)($tSub)\\,\\ln\\!\\left($ratio\\right)');
    } else if (solveFor == 'E_i') {
      final equation = '${_sym('E_i', latexMap)} = ${_sym('E_F', latexMap)} + {${_sym('k', latexMap)}}{${_sym('T', latexMap)}}\\,\\ln\\!\\left(\\dfrac{${_sym('p_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right)';
      final ratio = (p0Val != null && niVal != null && niVal != 0)
          ? fmt6.formatLatex(p0Val / niVal)
          : r'\dfrac{' + _sym('p_0', latexMap) + '}{' + _sym('n_i', latexMap) + '}';
      final efSub = _formatVal(ef, 'E_F', 'J', fmt6, latexMap);
      final kSub = _formatVal(k, 'k', 'J/K', fmt6, latexMap);
      final tSub = _formatVal(t, 'T', 'K', fmt6, latexMap);
      substitutionLines.add(equation);
      substitutionLines.add('${_sym('E_i', latexMap)} = $efSub + ($kSub)($tSub)\\,\\ln\\!\\left($ratio\\right)');
    } else {
      final equation = '${_sym('T', latexMap)} = \\dfrac{${_sym('E_i', latexMap)} - ${_sym('E_F', latexMap)}}{{${_sym('k', latexMap)}}\\,\\ln\\!\\left(\\dfrac{${_sym('p_0', latexMap)}}{${_sym('n_i', latexMap)}}\\right)}';
      final ratio = (p0Val != null && niVal != null && niVal != 0)
          ? fmt6.formatLatex(p0Val / niVal)
          : r'\dfrac{' + _sym('p_0', latexMap) + '}{' + _sym('n_i', latexMap) + '}';
      final eiSub = _formatVal(ei, 'E_i', 'J', fmt6, latexMap);
      final efSub = _formatVal(ef, 'E_F', 'J', fmt6, latexMap);
      final kSub = _formatVal(k, 'k', 'J/K', fmt6, latexMap);
      substitutionLines.add(equation);
      substitutionLines.add('${_sym('T', latexMap)} = \\dfrac{$eiSub - $efSub}{($kSub)\\,\\ln\\!\\left($ratio\\right)}');
    }

    final targetLatex = _sym(solveFor, latexMap);
    String computedValueLine;
    String roundedValueLine;
    if (solveFor.startsWith('E_')) {
      final valueFmt6 = computedBase != null
          ? _formatEnergyValue(computedBase, primaryEnergyUnit, fmt6, unitConverter)
          : targetLatex;
      final valueFmt3 = computedBase != null
          ? _formatEnergyValue(computedBase, primaryEnergyUnit, formatter, unitConverter)
          : targetLatex;
      computedValueLine = '$targetLatex = $valueFmt6';
      roundedValueLine = '$targetLatex = $valueFmt3';
    } else if (solveFor == 'T') {
      final valueFmt6 = computedBase != null ? fmt6.formatLatexWithUnit(computedBase, baseUnit) : targetLatex;
      final valueFmt3 = computedBase != null ? formatter.formatLatexWithUnit(computedBase, baseUnit) : targetLatex;
      computedValueLine = '$targetLatex = $valueFmt6';
      roundedValueLine = '$targetLatex = $valueFmt3';
    } else {
      final displayValue6 = _convertDensity(computedBase, baseUnit, densityUnit, unitConverter) ?? computedBase;
      final displayValue3 = _convertDensity(computedBase, baseUnit, densityUnit, unitConverter) ?? computedBase;
      computedValueLine = computedBase != null
          ? '$targetLatex = ${fmt6.formatLatexWithUnit(displayValue6 ?? computedBase, densityUnit)}'
          : targetLatex;
      roundedValueLine = computedBase != null
          ? '$targetLatex = ${formatter.formatLatexWithUnit(displayValue3 ?? computedBase, densityUnit)}'
          : targetLatex;
    }

    final substitutionEvaluationLine = computedBase != null ? computedValueLine : '';

    return UniversalStepTemplate.build(
      targetLabelLatex: targetLatex,
      unitConversionLines: unitConversions,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: substitutionEvaluationLine,
      computedValueLine: computedValueLine,
      roundedValueLine: roundedValueLine,
    );
  }

  static List<StepItem>? _buildMassAction({
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
    UnitConverter? unitConverter,
    UnitConversionLog? conversions,
  }) {
    if (solveFor != 'n_0' && solveFor != 'p_0' && solveFor != 'n_i') {
      return null;
    }

    final fmt6 = formatter.withSigFigs(6);
    final densityUnit = context.getUnit('__meta__density_unit') ?? 'm^-3';

    final n0 = context.getSymbolValue('n_0');
    final p0 = context.getSymbolValue('p_0');
    final ni = context.getSymbolValue('n_i');
    final result = outputs[solveFor];

    // Determine the target unit for computation (output unit takes precedence)
    final targetUnit = result?.unit.isNotEmpty == true ? result!.unit : densityUnit;
    
    // Build explicit unit conversion lines
    final unitConversionLines = <String>[];
    final needsConversion = targetUnit != 'cm^-3' && 
                           (n0?.unit == 'cm^-3' || p0?.unit == 'cm^-3' || ni?.unit == 'cm^-3');
    
    if (needsConversion) {
      final targetSymbol = _sym(solveFor, latexMap);
      unitConversionLines.add(r'\text{Since } ' + targetSymbol + r' \text{ is in } \mathrm{' + 
                             targetUnit.replaceAll('^', r'^{').replaceAll('-', r'-') + r'}\text{, we convert all inputs:}');
      unitConversionLines.add('');
    }

    // Convert inputs to target unit with explicit logging
    double? _toTargetDensity(SymbolValue? v, String key) {
      if (v == null) return null;
      final fromUnit = v.unit.isNotEmpty ? v.unit : 'm^-3';
      if (fromUnit == targetUnit) return v.value;
      
      final converted = unitConverter?.convertDensity(v.value, fromUnit, targetUnit);
      if (converted != null && fromUnit != targetUnit) {
        final symLatex = _sym(key, latexMap);
        final fromStr = fmt6.formatLatexWithUnit(v.value, fromUnit);
        final toStr = fmt6.formatLatexWithUnit(converted, targetUnit);
        unitConversionLines.add('$symLatex = $fromStr = $toStr');
      }
      return converted ?? v.value;
    }

    final n0Base = _toTargetDensity(n0, 'n_0');
    final p0Base = _toTargetDensity(p0, 'p_0');
    final niBase = _toTargetDensity(ni, 'n_i');

    final rearrangeLines = <String>[
      '${_sym('n_i', latexMap)}^{2} = ${_sym('n_0', latexMap)}${_sym('p_0', latexMap)}',
    ];
    if (solveFor == 'n_i') {
      rearrangeLines.add('${_sym('n_i', latexMap)} = \\sqrt{${_sym('n_0', latexMap)}${_sym('p_0', latexMap)}}');
    } else if (solveFor == 'n_0') {
      rearrangeLines.add('${_sym('n_0', latexMap)} = \\frac{{${_sym('n_i', latexMap)}}^{2}}{${_sym('p_0', latexMap)}}');
    } else {
      rearrangeLines.add('${_sym('p_0', latexMap)} = \\frac{{${_sym('n_i', latexMap)}}^{2}}{${_sym('n_0', latexMap)}}');
    }

    String _val(SymbolValue? v, String key, double? baseVal) =>
        v != null ? fmt6.formatLatexWithUnit(baseVal ?? v.value, targetUnit) : _sym(key, latexMap);
    final n0Fmt = _val(n0, 'n_0', n0Base);
    final p0Fmt = _val(p0, 'p_0', p0Base);
    final niFmt = _val(ni, 'n_i', niBase);

    final substitutionLines = <String>[];
    final n0Val = n0Base;
    final p0Val = p0Base;
    final niVal = niBase;
    final product = (n0Val != null && p0Val != null) ? n0Val * p0Val : null;
    final niSquared = niVal != null ? niVal * niVal : null;
    
    // Use target unit for squared density (adjust power: -3 -> -6)
    final squaredUnit = targetUnit.replaceAll('^-3', '^{-6}').replaceAll('^{-3}', '^{-6}');
    
    double? computedBase;
    String substitutionEvaluation;
    if (solveFor == 'n_i') {
      substitutionLines.add('${_sym('n_i', latexMap)} = \\sqrt{${_sym('n_0', latexMap)}${_sym('p_0', latexMap)}}');
      substitutionLines.add('${_sym('n_i', latexMap)} = \\sqrt{($n0Fmt)($p0Fmt)}');
      if (product != null) {
        substitutionLines.add('${_sym('n_i', latexMap)} = \\sqrt{${fmt6.formatLatexWithUnit(product, squaredUnit)}}');
      }
      computedBase = result?.value ?? (product != null ? math.sqrt(product) : null);
      final resultFmt = computedBase != null ? fmt6.formatLatexWithUnit(computedBase, targetUnit) : null;
      substitutionEvaluation = resultFmt != null ? '${_sym('n_i', latexMap)} = $resultFmt' : '';
    } else if (solveFor == 'n_0') {
      substitutionLines.add('${_sym('n_0', latexMap)} = \\frac{{${_sym('n_i', latexMap)}}^{2}}{${_sym('p_0', latexMap)}}');
      substitutionLines.add('${_sym('n_0', latexMap)} = \\frac{($niFmt)^{2}}{$p0Fmt}');
      if (niSquared != null) {
        substitutionLines.add('${_sym('n_0', latexMap)} = \\frac{${fmt6.formatLatexWithUnit(niSquared, squaredUnit)}}{$p0Fmt}');
      }
      computedBase = result?.value ?? (niSquared != null && p0Val != null && p0Val != 0 ? niSquared / p0Val : null);
      final resultFmt = computedBase != null ? fmt6.formatLatexWithUnit(computedBase, targetUnit) : null;
      substitutionEvaluation = resultFmt != null ? '${_sym('n_0', latexMap)} = $resultFmt' : '';
    } else {
      substitutionLines.add('${_sym('p_0', latexMap)} = \\frac{{${_sym('n_i', latexMap)}}^{2}}{${_sym('n_0', latexMap)}}');
      substitutionLines.add('${_sym('p_0', latexMap)} = \\frac{($niFmt)^{2}}{$n0Fmt}');
      if (niSquared != null) {
        substitutionLines.add('${_sym('p_0', latexMap)} = \\frac{${fmt6.formatLatexWithUnit(niSquared, squaredUnit)}}{$n0Fmt}');
      }
      computedBase = result?.value ?? (niSquared != null && n0Val != null && n0Val != 0 ? niSquared / n0Val : null);
      final resultFmt = computedBase != null ? fmt6.formatLatexWithUnit(computedBase, targetUnit) : null;
      substitutionEvaluation = resultFmt != null ? '${_sym('p_0', latexMap)} = $resultFmt' : '';
    }

    final targetLatex = _sym(solveFor, latexMap);
    // computedBase is in targetUnit, convert to user's display preference if needed
    final baseUnit = targetUnit;
    final displayValue6 = _convertDensity(computedBase, baseUnit, densityUnit, unitConverter) ?? computedBase;
    final displayValue3 = _convertDensity(computedBase, baseUnit, densityUnit, unitConverter) ?? computedBase;
    final computedValueLine = computedBase != null
        ? '$targetLatex = ${fmt6.formatLatexWithUnit(displayValue6 ?? computedBase, densityUnit)}'
        : targetLatex;
    final roundedValueLine = computedBase != null
        ? '$targetLatex = ${formatter.formatLatexWithUnit(displayValue3 ?? computedBase, densityUnit)}'
        : targetLatex;

    return UniversalStepTemplate.build(
      targetLabelLatex: targetLatex,
      unitConversionLines: unitConversionLines,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: substitutionEvaluation,
      computedValueLine: computedValueLine,
      roundedValueLine: roundedValueLine,
    );
  }

  static List<StepItem>? _buildMajority({
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
    UnitConverter? unitConverter,
    required bool isPType,
  }) {
    final targetKey = isPType ? 'p_0' : 'n_0';
    final allowedExtras = isPType ? <String>{'N_D', 'N_A'} : <String>{'N_A', 'N_D'};
    if (solveFor != targetKey && solveFor != 'n_i' && !allowedExtras.contains(solveFor)) {
      return null;
    }

    final fmt6 = formatter.withSigFigs(6);
    final densityUnit = context.getUnit('__meta__density_unit') ?? 'm^-3';

    final nd = context.getSymbolValue('N_D');
    final na = context.getSymbolValue('N_A');
    final ni = context.getSymbolValue('n_i');
    final result = outputs[solveFor];

    // Determine the target unit for computation (output unit takes precedence)
    final targetUnit = result?.unit.isNotEmpty == true ? result!.unit : densityUnit;
    
    // Build explicit unit conversion narrative
    final unitConversions = <String>[];
    final needsConversion = targetUnit != 'cm^-3' && 
                           (nd?.unit == 'cm^-3' || na?.unit == 'cm^-3' || ni?.unit == 'cm^-3');
    
    if (needsConversion) {
      // Add explanatory header
      final targetSymbol = _sym(solveFor, latexMap);
      unitConversions.add(r'\text{Since } ' + targetSymbol + r' \text{ is in } \mathrm{' + 
                         targetUnit.replaceAll('^', r'^{').replaceAll('-', r'-') + r'}\text{, we convert all inputs:}');
      unitConversions.add(''); // Blank line for readability
    }

    // Convert inputs to target unit and log conversions
    double? _convertToTarget(SymbolValue? v, String key) {
      if (v == null) return null;
      final fromUnit = v.unit.isNotEmpty ? v.unit : 'm^-3';
      if (fromUnit == targetUnit) return v.value;
      
      final converted = unitConverter?.convertDensity(v.value, fromUnit, targetUnit);
      if (converted != null && fromUnit != targetUnit) {
        // Build explicit conversion line
        final symLatex = _sym(key, latexMap);
        final fromStr = fmt6.formatLatexWithUnit(v.value, fromUnit);
        final toStr = fmt6.formatLatexWithUnit(converted, targetUnit);
        unitConversions.add('$symLatex = $fromStr = $toStr');
      }
      return converted ?? v.value;
    }

    final ndVal = _convertToTarget(nd, 'N_D') ?? 0;
    final naVal = _convertToTarget(na, 'N_A') ?? 0;
    final niVal = _convertToTarget(ni, 'n_i') ?? 0;

    final rearrangeLines = <String>[];
    if (solveFor == targetKey) {
      if (!isPType) {
        rearrangeLines.add('${_sym('n_0', latexMap)} = \\frac{(${_sym('N_D', latexMap)} - ${_sym('N_A', latexMap)}) + \\sqrt{(${_sym('N_D', latexMap)} - ${_sym('N_A', latexMap)})^{2} + 4 {${_sym('n_i', latexMap)}}^{2}}}{2}');
      } else {
        rearrangeLines.add('${_sym('p_0', latexMap)} = \\frac{(${_sym('N_A', latexMap)} - ${_sym('N_D', latexMap)}) + \\sqrt{(${_sym('N_A', latexMap)} - ${_sym('N_D', latexMap)})^{2} + 4 {${_sym('n_i', latexMap)}}^{2}}}{2}');
      }
    } else if (solveFor == 'n_i') {
      final targetSym = _sym(targetKey, latexMap);
      final deltaSym = isPType ? '(${_sym('N_A', latexMap)} - ${_sym('N_D', latexMap)})' : '(${_sym('N_D', latexMap)} - ${_sym('N_A', latexMap)})';
      rearrangeLines.add('$targetSym = \\frac{$deltaSym + \\sqrt{$deltaSym^{2} + 4{${_sym('n_i', latexMap)}}^{2}}}{2}');
      rearrangeLines.add('2$targetSym - $deltaSym = \\sqrt{$deltaSym^{2} + 4{${_sym('n_i', latexMap)}}^{2}}');
      rearrangeLines.add('{(2$targetSym - $deltaSym)}^{2} = $deltaSym^{2} + 4{${_sym('n_i', latexMap)}}^{2}');
      rearrangeLines.add('4{${targetSym}}^{2} - 4$targetSym $deltaSym = 4{${_sym('n_i', latexMap)}}^{2}');
      rearrangeLines.add('${_sym('n_i', latexMap)} = \\sqrt{$targetSym\\left($targetSym - $deltaSym\\right)}');
    } else {
      // Solve for compensating dopant: N_A (n-type) or N_D (p-type)
      if (isPType && solveFor == 'N_A') {
        rearrangeLines.addAll(_pTypeDerivationLines(
          latexMap: latexMap,
          solveFor: 'N_A',
        ));
      } else if (isPType && solveFor == 'N_D') {
        rearrangeLines.addAll(_pTypeDerivationLines(
          latexMap: latexMap,
          solveFor: 'N_D',
        ));
      } else if (!isPType && solveFor == 'N_D') {
        rearrangeLines.addAll(_nTypeDerivationLines(
          latexMap: latexMap,
          solveFor: 'N_D',
        ));
      } else if (!isPType && solveFor == 'N_A') {
        rearrangeLines.addAll(_nTypeDerivationLines(
          latexMap: latexMap,
          solveFor: 'N_A',
        ));
      }
    }

    // Format values using the target unit (already converted)
    String _fmtConverted(double val, String key) =>
        fmt6.formatLatexWithUnit(val, targetUnit);
    
    final ndFmt = _fmtConverted(ndVal, 'N_D');
    final naFmt = _fmtConverted(naVal, 'N_A');
    final niFmt = _fmtConverted(niVal, 'n_i');
    
    // Handle target variable (might be input when solving for dopant)
    final targetVal = context.getSymbolValue(targetKey);
    final double targetValNum = targetVal != null ? _convertToTarget(targetVal, targetKey) ?? 0.0 : 0.0;
    final targetFmt = targetValNum != 0 ? _fmtConverted(targetValNum, targetKey) : _sym(targetKey, latexMap);

    final delta = isPType ? (naVal - ndVal) : (ndVal - naVal);
    final deltaExpr = isPType ? '($naFmt - $ndFmt)' : '($ndFmt - $naFmt)';
    final deltaFmt = fmt6.formatLatexWithUnit(delta, targetUnit);
    final deltaSq = delta * delta;
    final niTerm = 4 * niVal * niVal;
    final discr = deltaSq + niTerm;
    final sqrtDiscr = math.sqrt(discr);

    final substitutionLines = <String>[];
    
    // Helper to create SymbolValue with converted value in targetUnit
    SymbolValue? _toSymbolValue(double? val, String key) {
      return val != null ? SymbolValue(value: val, unit: targetUnit, source: SymbolSource.computed) : null;
    }

    void addSubstitution(String equation, Map<String, SymbolValue?> values) {
      substitutionLines.add(equation);
      substitutionLines.add(_buildSubstitutionLine(
        equation: equation,
        values: values,
        latexMap: latexMap,
        formatter: fmt6,
      ));
    }

    if (solveFor == targetKey) {
      final equation =
          '${_sym(targetKey, latexMap)} = \\frac{$deltaExpr + \\sqrt{$deltaExpr^{2} + 4({$niFmt})^{2}}}{2}';
      addSubstitution(equation, {
        'N_A': _toSymbolValue(naVal, 'N_A'),
        'N_D': _toSymbolValue(ndVal, 'N_D'),
        'n_i': _toSymbolValue(niVal, 'n_i'),
      });
      final deltaDef = isPType
          ? r'\Delta N \equiv ' + '${_sym('N_A', latexMap)} - ${_sym('N_D', latexMap)}'
          : r'\Delta N \equiv ' + '${_sym('N_D', latexMap)} - ${_sym('N_A', latexMap)}';
      final deltaNumeric = isPType
          ? r'\Delta N = ' + '$naFmt - $ndFmt = $deltaFmt'
          : r'\Delta N = ' + '$ndFmt - $naFmt = $deltaFmt';
      substitutionLines.add(deltaDef);
      substitutionLines.add(deltaNumeric);
      
      // Use target unit for squared density (adjust power: -3 -> -6)
      final deltaSqUnit = targetUnit.replaceAll('^-3', '^{-6}').replaceAll('^{-3}', '^{-6}');
      final niTermUnit = deltaSqUnit;
      substitutionLines.add(r'\Delta N^{2} = ' + fmt6.formatLatexWithUnit(deltaSq, deltaSqUnit));
      substitutionLines.add(r'4n_i^{2} = ' + fmt6.formatLatexWithUnit(niTerm, niTermUnit));
      substitutionLines.add(r'\sqrt{\Delta N^{2} + 4n_i^{2}} = ' + fmt6.formatLatexWithUnit(sqrtDiscr, targetUnit));
    } else if (solveFor == 'n_i') {
      final equation = '${_sym('n_i', latexMap)} = \\sqrt{$targetFmt\\left($targetFmt - $deltaExpr\\right)}';
      addSubstitution(equation, {
        targetKey: _toSymbolValue(targetValNum, targetKey),
        'N_A': _toSymbolValue(naVal, 'N_A'),
        'N_D': _toSymbolValue(ndVal, 'N_D'),
      });
      // Explicit Δ definition and numeric evaluation for clarity
      final deltaDef = isPType
          ? r'\Delta N \equiv ' + '${_sym('N_A', latexMap)} - ${_sym('N_D', latexMap)}'
          : r'\Delta N \equiv ' + '${_sym('N_D', latexMap)} - ${_sym('N_A', latexMap)}';
      final deltaNumeric = isPType
          ? r'\Delta N = ' + '$naFmt - $ndFmt = $deltaFmt'
          : r'\Delta N = ' + '$ndFmt - $naFmt = $deltaFmt';
      substitutionLines.add(deltaDef);
      substitutionLines.add(deltaNumeric);

      if (targetVal != null) {
        final deltaVal = isPType ? (naVal - ndVal) : (ndVal - naVal);
        final dVal = targetValNum - deltaVal;
        final scale = [targetValNum.abs(), deltaVal.abs(), 1.0].reduce((a, b) => a > b ? a : b);
        final ill = dVal.abs() <= _relEps * scale;
        final negBeyond = dVal < -_absEps;
        final smallNeg = dVal < 0 && !negBeyond;
        final dFmt = fmt6.formatLatexWithUnit(dVal, targetUnit);
        substitutionLines.add('d = ${targetFmt} - ($deltaExpr) = $dFmt');
        if (negBeyond) {
          substitutionLines.add(r'\text{Inputs inconsistent: }d < 0 \text{ would make } n_i \text{ imaginary.}');
        } else if (ill || smallNeg) {
          substitutionLines.add(r'\text{Ill-conditioned: }d \approx 0 \text{, clamped to }0.');
        }
      }
    } else if (isPType && solveFor == 'N_A') {
      final equation =
          '${_sym('N_A', latexMap)} = ${_sym('N_D', latexMap)} + ${_sym('p_0', latexMap)} - \\frac{{${_sym('n_i', latexMap)}}^{2}}{{${_sym('p_0', latexMap)}}}';
      addSubstitution(equation, {
        'N_D': _toSymbolValue(ndVal, 'N_D'),
        'p_0': _toSymbolValue(targetValNum, 'p_0'),
        'n_i': _toSymbolValue(niVal, 'n_i'),
      });
    } else if (isPType && solveFor == 'N_D') {
      final equation =
          '${_sym('N_D', latexMap)} = ${_sym('N_A', latexMap)} - ${_sym('p_0', latexMap)} + \\frac{{${_sym('n_i', latexMap)}}^{2}}{{${_sym('p_0', latexMap)}}}';
      addSubstitution(equation, {
        'N_A': _toSymbolValue(naVal, 'N_A'),
        'p_0': _toSymbolValue(targetValNum, 'p_0'),
        'n_i': _toSymbolValue(niVal, 'n_i'),
      });
    } else if (!isPType && solveFor == 'N_D') {
      final equation =
          '${_sym('N_D', latexMap)} = ${_sym('N_A', latexMap)} + ${_sym('n_0', latexMap)} - \\frac{{${_sym('n_i', latexMap)}}^{2}}{{${_sym('n_0', latexMap)}}}';
      addSubstitution(equation, {
        'N_A': _toSymbolValue(naVal, 'N_A'),
        'n_0': _toSymbolValue(targetValNum, 'n_0'),
        'n_i': _toSymbolValue(niVal, 'n_i'),
      });
    } else {
      final equation =
          '${_sym('N_A', latexMap)} = ${_sym('N_D', latexMap)} - ${_sym('n_0', latexMap)} + \\frac{{${_sym('n_i', latexMap)}}^{2}}{{${_sym('n_0', latexMap)}}}';
      addSubstitution(equation, {
        'N_D': _toSymbolValue(ndVal, 'N_D'),
        'n_0': _toSymbolValue(targetValNum, 'n_0'),
        'n_i': _toSymbolValue(niVal, 'n_i'),
      });
    }

    String substitutionEvaluation = '';
    double? computedBase;
    if (solveFor == targetKey) {
      computedBase = result?.value ?? (delta + sqrtDiscr) / 2;
      final expr = '${_sym(targetKey, latexMap)} = \\frac{($deltaFmt) + (${fmt6.formatLatexWithUnit(sqrtDiscr, targetUnit)})}{2}';
      substitutionEvaluation = '$expr = ${fmt6.formatLatexWithUnit(computedBase, targetUnit)}';
    } else if (solveFor == 'n_i') {
      final inside = targetValNum * (targetValNum - delta);
      computedBase = result?.value ?? (inside > 0 ? math.sqrt(inside) : null);
      final expr = '${_sym('n_i', latexMap)} = \\sqrt{${_sym(targetKey, latexMap)}\\left(${_sym(targetKey, latexMap)} - ${_sym('N_D', latexMap)} + ${_sym('N_A', latexMap)}\\right)}';
      substitutionEvaluation = computedBase != null ? '$expr = ${fmt6.formatLatexWithUnit(computedBase, targetUnit)}' : expr;
    } else if (isPType && solveFor == 'N_A') {
      final denom = targetValNum;
      computedBase = result?.value ?? (denom != 0 ? ndVal + targetValNum - (niVal * niVal) / denom : null);
      final expr = '${_sym('N_A', latexMap)} = ${_sym('N_D', latexMap)} + ${_sym('p_0', latexMap)} - \\frac{{${_sym('n_i', latexMap)}}^{2}}{{${_sym('p_0', latexMap)}}}';
      substitutionEvaluation = computedBase != null ? '$expr = ${fmt6.formatLatexWithUnit(computedBase, targetUnit)}' : expr;
    } else if (isPType && solveFor == 'N_D') {
      final denom = targetValNum;
      computedBase = result?.value ?? (denom != 0 ? naVal - targetValNum + (niVal * niVal) / denom : null);
      final expr = '${_sym('N_D', latexMap)} = ${_sym('N_A', latexMap)} - ${_sym('p_0', latexMap)} + \\frac{({$niFmt})^{2}}{$targetFmt}';
      substitutionEvaluation = computedBase != null ? '$expr = ${fmt6.formatLatexWithUnit(computedBase, targetUnit)}' : expr;
    } else if (!isPType && solveFor == 'N_D') {
      final denom = targetValNum;
      computedBase = result?.value ?? (denom != 0 ? naVal + targetValNum - (niVal * niVal) / denom : null);
      final expr = '${_sym('N_D', latexMap)} = ${_sym('N_A', latexMap)} + ${_sym('n_0', latexMap)} - \\frac{({$niFmt})^{2}}{$targetFmt}';
      substitutionEvaluation = computedBase != null ? '$expr = ${fmt6.formatLatexWithUnit(computedBase, targetUnit)}' : expr;
    } else if (!isPType) {
      final denom = targetValNum;
      computedBase = result?.value ??
          (denom != 0 ? ndVal - targetValNum + (niVal * niVal) / denom : null);
      final expr = '${_sym('N_A', latexMap)} = $ndFmt - $targetFmt + \\frac{({$niFmt})^{2}}{$targetFmt}';
      substitutionEvaluation = computedBase != null ? '$expr = ${fmt6.formatLatexWithUnit(computedBase, targetUnit)}' : expr;
    }

    final targetLatex = _sym(solveFor, latexMap);
    // computedBase is in targetUnit, convert to user's display preference if needed
    final baseUnit = targetUnit;
    final displayValue6 = _convertDensity(computedBase, baseUnit, densityUnit, unitConverter) ?? computedBase;
    final displayValue3 = _convertDensity(computedBase, baseUnit, densityUnit, unitConverter) ?? computedBase;
    final computedValueLine = computedBase != null
        ? '$targetLatex = ${fmt6.formatLatexWithUnit(displayValue6 ?? computedBase, densityUnit)}'
        : targetLatex;
    final roundedValueLine = computedBase != null
        ? '$targetLatex = ${formatter.formatLatexWithUnit(displayValue3 ?? computedBase, densityUnit)}'
        : targetLatex;

    return UniversalStepTemplate.build(
      targetLabelLatex: targetLatex,
      unitConversionLines: unitConversions,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: substitutionEvaluation,
      computedValueLine: computedValueLine,
      roundedValueLine: roundedValueLine,
    );
  }

  static List<StepItem>? _buildChargeNeutrality({
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
    UnitConverter? unitConverter,
  }) {
    if (solveFor != 'n_0' && solveFor != 'p_0' && solveFor != 'N_A_minus' && solveFor != 'N_D_plus') {
      return null;
    }

    final fmt6 = formatter.withSigFigs(6);
    final densityUnit = context.getUnit('__meta__density_unit') ?? 'm^-3';

    final n0 = context.getSymbolValue('n_0');
    final p0 = context.getSymbolValue('p_0');
    final naMinus = context.getSymbolValue('N_A_minus');
    final ndPlus = context.getSymbolValue('N_D_plus');
    final result = outputs[solveFor];

    // Determine the target unit for computation
    final targetUnit = result?.unit.isNotEmpty == true ? result!.unit : densityUnit;
    
    // Build explicit unit conversion lines
    final unitConversions = <String>[];
    final needsConversion = targetUnit != 'cm^-3' && 
                           (n0?.unit == 'cm^-3' || p0?.unit == 'cm^-3' || 
                            naMinus?.unit == 'cm^-3' || ndPlus?.unit == 'cm^-3');
    
    if (needsConversion) {
      final targetSymbol = _sym(solveFor, latexMap);
      unitConversions.add(r'\text{Since } ' + targetSymbol + r' \text{ is in } \mathrm{' + 
                         targetUnit.replaceAll('^', r'^{').replaceAll('-', r'-') + r'}\text{, we convert all inputs:}');
      unitConversions.add('');
    }

    // Convert inputs to target unit
    double? _toTarget(SymbolValue? v, String key) {
      if (v == null) return null;
      final fromUnit = v.unit.isNotEmpty ? v.unit : 'm^-3';
      if (fromUnit == targetUnit) return v.value;
      
      final converted = unitConverter?.convertDensity(v.value, fromUnit, targetUnit);
      if (converted != null && fromUnit != targetUnit) {
        final symLatex = _sym(key, latexMap);
        final fromStr = fmt6.formatLatexWithUnit(v.value, fromUnit);
        final toStr = fmt6.formatLatexWithUnit(converted, targetUnit);
        unitConversions.add('$symLatex = $fromStr = $toStr');
      }
      return converted ?? v.value;
    }

    final rearrangeLines = <String>[];
    if (solveFor == 'n_0') {
      rearrangeLines.add('${_sym('n_0', latexMap)} + ${_sym('N_A_minus', latexMap)} = ${_sym('p_0', latexMap)} + ${_sym('N_D_plus', latexMap)}');
      rearrangeLines.add('${_sym('n_0', latexMap)} = ${_sym('p_0', latexMap)} + ${_sym('N_D_plus', latexMap)} - ${_sym('N_A_minus', latexMap)}');
    } else if (solveFor == 'p_0') {
      rearrangeLines.add('${_sym('n_0', latexMap)} + ${_sym('N_A_minus', latexMap)} = ${_sym('p_0', latexMap)} + ${_sym('N_D_plus', latexMap)}');
      rearrangeLines.add('${_sym('p_0', latexMap)} = ${_sym('n_0', latexMap)} + ${_sym('N_A_minus', latexMap)} - ${_sym('N_D_plus', latexMap)}');
    } else if (solveFor == 'N_A_minus') {
      rearrangeLines.add('${_sym('n_0', latexMap)} + ${_sym('N_A_minus', latexMap)} = ${_sym('p_0', latexMap)} + ${_sym('N_D_plus', latexMap)}');
      rearrangeLines.add('${_sym('N_A_minus', latexMap)} = ${_sym('p_0', latexMap)} + ${_sym('N_D_plus', latexMap)} - ${_sym('n_0', latexMap)}');
    } else {
      rearrangeLines.add('${_sym('n_0', latexMap)} + ${_sym('N_A_minus', latexMap)} = ${_sym('p_0', latexMap)} + ${_sym('N_D_plus', latexMap)}');
      rearrangeLines.add('${_sym('N_D_plus', latexMap)} = ${_sym('n_0', latexMap)} + ${_sym('N_A_minus', latexMap)} - ${_sym('p_0', latexMap)}');
    }

    // Convert and format values in target unit
    final n0Val = _toTarget(n0, 'n_0');
    final p0Val = _toTarget(p0, 'p_0');
    final naMinusVal = _toTarget(naMinus, 'N_A_minus');
    final ndPlusVal = _toTarget(ndPlus, 'N_D_plus');

    // Format values with units for substitution
    String _fmtVal(double? val, String key) =>
        val != null ? '(' + fmt6.formatLatexWithUnit(val, targetUnit) + ')' : _sym(key, latexMap);
    
    final n0Fmt = _fmtVal(n0Val, 'n_0');
    final p0Fmt = _fmtVal(p0Val, 'p_0');
    final naMinusFmt = _fmtVal(naMinusVal, 'N_A_minus');
    final ndPlusFmt = _fmtVal(ndPlusVal, 'N_D_plus');

    // Build substitution lines by substituting into the rearranged equation
    final substitutionLines = <String>[];
    if (solveFor == 'n_0') {
      // Repeat Step 2 equation
      substitutionLines.add('${_sym('n_0', latexMap)} = ${_sym('p_0', latexMap)} + ${_sym('N_D_plus', latexMap)} - ${_sym('N_A_minus', latexMap)}');
      // Substitute numeric values
      substitutionLines.add('${_sym('n_0', latexMap)} = $p0Fmt + $ndPlusFmt - $naMinusFmt');
    } else if (solveFor == 'p_0') {
      substitutionLines.add('${_sym('p_0', latexMap)} = ${_sym('n_0', latexMap)} + ${_sym('N_A_minus', latexMap)} - ${_sym('N_D_plus', latexMap)}');
      substitutionLines.add('${_sym('p_0', latexMap)} = $n0Fmt + $naMinusFmt - $ndPlusFmt');
    } else if (solveFor == 'N_A_minus') {
      substitutionLines.add('${_sym('N_A_minus', latexMap)} = ${_sym('p_0', latexMap)} + ${_sym('N_D_plus', latexMap)} - ${_sym('n_0', latexMap)}');
      substitutionLines.add('${_sym('N_A_minus', latexMap)} = $p0Fmt + $ndPlusFmt - $n0Fmt');
    } else {
      substitutionLines.add('${_sym('N_D_plus', latexMap)} = ${_sym('n_0', latexMap)} + ${_sym('N_A_minus', latexMap)} - ${_sym('p_0', latexMap)}');
      substitutionLines.add('${_sym('N_D_plus', latexMap)} = $n0Fmt + $naMinusFmt - $p0Fmt');
    }

    double? computed;
    final targetSym = _sym(solveFor, latexMap);
    if (solveFor == 'n_0') {
      if (p0Val != null && ndPlusVal != null && naMinusVal != null) {
        computed = p0Val + ndPlusVal - naMinusVal;
      }
    } else if (solveFor == 'p_0') {
      if (n0Val != null && naMinusVal != null && ndPlusVal != null) {
        computed = n0Val + naMinusVal - ndPlusVal;
      }
    } else if (solveFor == 'N_A_minus') {
      if (p0Val != null && ndPlusVal != null && n0Val != null) {
        computed = p0Val + ndPlusVal - n0Val;
      }
    } else {
      if (n0Val != null && naMinusVal != null && p0Val != null) {
        computed = n0Val + naMinusVal - p0Val;
      }
    }

    // Single source of truth: use solver's result if available, else local computation
    // This ensures Step 3 evaluation and Step 4 use IDENTICAL values
    final computedBase = result?.value ?? computed;
    final baseUnit = targetUnit;
    
    // Step 3 evaluation uses the same computedBase as Step 4
    final substitutionEvaluation = computedBase != null
        ? '$targetSym = ${fmt6.formatLatexWithUnit(computedBase, targetUnit)}'
        : targetSym;

    // Convert to user's display preference if needed
    final displayValue6 = _convertDensity(computedBase, baseUnit, densityUnit, unitConverter) ?? computedBase;
    final displayValue3 = _convertDensity(computedBase, baseUnit, densityUnit, unitConverter) ?? computedBase;

    final computedValueLine = computedBase != null
        ? '$targetSym = ${fmt6.formatLatexWithUnit(displayValue6 ?? computedBase, densityUnit)}'
        : targetSym;
    final roundedValueLine = computedBase != null
        ? '$targetSym = ${formatter.formatLatexWithUnit(displayValue3 ?? computedBase, densityUnit)}'
        : targetSym;

    return UniversalStepTemplate.build(
      targetLabelLatex: targetSym,
      unitConversionLines: unitConversions,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: substitutionEvaluation,
      computedValueLine: computedValueLine,
      roundedValueLine: roundedValueLine,
    );
  }

  static String _buildSubstitutionLine({
    required String equation,
    required Map<String, SymbolValue?> values,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
  }) {
    final substitutionMap = <String, String>{};
    for (final entry in values.entries) {
      final formatted = _formatValueWithUnit(entry.key, entry.value, formatter);
      if (formatted.isEmpty) continue;
      substitutionMap[entry.key] = formatted;
    }

    return buildSubstitutionEquation(
      equationLatex: equation,
      latexMap: latexMap,
      substitutionMap: substitutionMap,
      wrapValuesWithParens: true,
    );
  }

  static String _formatValueWithUnit(String key, SymbolValue? value, NumberFormatter formatter) {
    if (value == null) return '';
    final unit = value.unit.isNotEmpty ? value.unit : _defaultUnitFor(key);
    if (unit.isNotEmpty) {
      return formatter.formatLatexWithUnit(value.value, unit);
    }
    return formatter.formatLatex(value.value);
  }

  static String _defaultUnitFor(String key) {
    if (key == 'k') return 'J/K';
    if (key == 'T') return 'K';
    if (key.startsWith('E_') || key == 'E') return 'J';
    return 'm^-3';
  }

  static String _sym(String key, LatexSymbolMap latexMap) {
    return latexMap.latexOf(key);
  }

  static String? _densityConversionLine({
    required String key,
    required SymbolValue? value,
    required String displayUnit,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
    UnitConverter? converter,
  }) {
    if (value == null) return null;
    final baseUnit = value.unit.isNotEmpty ? value.unit : 'm^-3';
    if (displayUnit == baseUnit) return null;
    if (converter == null) return null;
    final converted = converter.convertDensity(value.value, baseUnit, displayUnit);
    if (converted == null) return null;
    final convertedFmt = formatter.formatLatexWithUnit(converted, displayUnit);
    final baseFmt = formatter.formatLatexWithUnit(value.value, baseUnit);
    return '${_sym(key, latexMap)} = $convertedFmt = $baseFmt';
  }

  static List<String>? _energyConversionLines({
    required String key,
    required double? valueJ,
    required SymbolContext context,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
    UnitConverter? converter,
    required String primaryEnergyUnit,
  }) {
    if (valueJ == null) return null;
    if (primaryEnergyUnit != 'eV') return null;
    if (converter == null) return null;
    final converted = converter.convertEnergy(valueJ, 'J', 'eV', symbol: 'q', reason: 'carrier eq display');
    if (converted == null) return null;

    final sym = _sym(key, latexMap);
    final evFmt = formatter.formatLatexWithUnit(converted, 'eV');
    final jFmt = formatter.formatLatexWithUnit(valueJ, 'J');

    // q for 1 eV = q J (fallback to context if converter unavailable)
    final qValue = converter.convertEnergy(1.0, 'eV', 'J') ?? context.getValue('q');
    final qNum = qValue != null ? formatter.formatLatex(qValue) : _sym('q', latexMap);
    final qSymbol = _sym('q', latexMap);

    final lines = <String>[];
    lines.add('$sym = $evFmt');
    lines.add(r'1\,\mathrm{eV} = ' + qSymbol + r'\,\mathrm{J} = (' + qNum + r')\,\mathrm{J}');
    lines.add('$sym = ($evFmt) \\times (${qNum}\\,\\mathrm{J/eV}) = $jFmt');
    return lines;
  }

  static double? _convertDensity(double? value, String fromUnit, String toUnit, UnitConverter? converter) {
    if (value == null) return null;
    if (fromUnit == toUnit) return value;
    return converter?.convertDensity(value, fromUnit, toUnit);
  }

  static String _formatEnergyValue(
    double? valueJ,
    String preferredUnit,
    NumberFormatter formatter,
    UnitConverter? converter,
  ) {
    if (valueJ == null) return '';
    if (preferredUnit == 'eV' && converter != null) {
    final converted = converter.convertEnergy(valueJ, 'J', 'eV', symbol: 'q', reason: 'carrier eq display');
      if (converted != null) {
        return formatter.formatLatexWithUnit(converted, 'eV');
      }
    }
    return formatter.formatLatexWithUnit(valueJ, 'J');
  }

  static String _formatVal(
    SymbolValue? value,
    String key,
    String fallbackUnit,
    NumberFormatter formatter,
    LatexSymbolMap latexMap,
  ) {
    if (value == null) return _sym(key, latexMap);
    final unit = value.unit.isNotEmpty ? value.unit : fallbackUnit;
    return formatter.formatLatexWithUnit(value.value, unit);
  }

  static List<String> _pTypeDerivationLines({
    required LatexSymbolMap latexMap,
    required String solveFor, // 'N_A' or 'N_D'
  }) {
    final p = _sym('p_0', latexMap);
    final na = _sym('N_A', latexMap);
    final nd = _sym('N_D', latexMap);
    final ni = _sym('n_i', latexMap);
    final delta = r'\Delta';

    final lines = <String>[
      '$p = \\frac{($na - $nd) + \\sqrt{($na - $nd)^{2} + 4{${ni}}^{2}}}{2}',
      '2$p = ($na - $nd) + \\sqrt{($na - $nd)^{2} + 4{${ni}}^{2}}',
      r'\text{Let }' + delta + '= ' + '$na - $nd',
      '2$p = $delta + \\sqrt{$delta^{2} + 4{${ni}}^{2}}',
      '2$p - $delta = \\sqrt{$delta^{2} + 4{${ni}}^{2}}',
      '(2$p - $delta)^{2} = $delta^{2} + 4{${ni}}^{2}',
      '4{${p}}^{2} - 4$p $delta + $delta^{2} = $delta^{2} + 4{${ni}}^{2}',
      '4{${p}}^{2} - 4$p $delta = 4{${ni}}^{2}',
      '{${p}}^{2} - $p $delta = {${ni}}^{2}',
      '$delta = $p - \\frac{{${ni}}^{2}}{$p}',
    ];

    if (solveFor == 'N_D') {
      lines.add('$nd = $na - $delta = $na - $p + \\frac{{${ni}}^{2}}{$p}');
    } else {
      lines.add('$na = $nd + $delta = $nd + $p - \\frac{{${ni}}^{2}}{$p}');
    }

    return lines;
  }

  static List<String> _nTypeDerivationLines({
    required LatexSymbolMap latexMap,
    required String solveFor, // 'N_A' or 'N_D'
  }) {
    final n0 = _sym('n_0', latexMap);
    final na = _sym('N_A', latexMap);
    final nd = _sym('N_D', latexMap);
    final ni = _sym('n_i', latexMap);
    final delta = r'\Delta';

    final lines = <String>[
      '$n0 = \\frac{($nd - $na) + \\sqrt{($nd - $na)^{2} + 4{${ni}}^{2}}}{2}',
      '2$n0 = ($nd - $na) + \\sqrt{($nd - $na)^{2} + 4{${ni}}^{2}}',
      r'\text{Let }' + delta + '= ' + '$nd - $na',
      '2$n0 = $delta + \\sqrt{$delta^{2} + 4{${ni}}^{2}}',
      '2$n0 - $delta = \\sqrt{$delta^{2} + 4{${ni}}^{2}}',
      '(2$n0 - $delta)^{2} = $delta^{2} + 4{${ni}}^{2}',
      '4{${n0}}^{2} - 4$n0 $delta + $delta^{2} = $delta^{2} + 4{${ni}}^{2}',
      '4{${n0}}^{2} - 4$n0 $delta = 4{${ni}}^{2}',
      '{${n0}}^{2} - $n0 $delta = {${ni}}^{2}',
      '$delta = $n0 - \\frac{{${ni}}^{2}}{$n0}',
    ];

    if (solveFor == 'N_A') {
      lines.add('$na = $nd - $delta = $nd - $n0 + \\frac{{${ni}}^{2}}{$n0}');
    } else {
      lines.add('$nd = $na + $delta = $na + $n0 - \\frac{{${ni}}^{2}}{$n0}');
    }

    return lines;
  }
}
