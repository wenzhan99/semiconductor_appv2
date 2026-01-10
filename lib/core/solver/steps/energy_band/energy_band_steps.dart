import 'package:semiconductor_appv2/core/constants/latex_symbols.dart';
import 'package:semiconductor_appv2/core/formulas/formula_definition.dart';
import 'package:semiconductor_appv2/core/models/workspace.dart';
import 'package:semiconductor_appv2/core/solver/number_formatter.dart';
import 'package:semiconductor_appv2/core/solver/step_items.dart';
import 'package:semiconductor_appv2/core/solver/steps/universal_step_template.dart';
import 'package:semiconductor_appv2/core/solver/symbol_context.dart';
import 'package:semiconductor_appv2/core/solver/unit_converter.dart';

class EnergyBandSteps {
  static const _parabolicId = 'parabolic_band_dispersion';
  static const _curvatureId = 'effective_mass_from_curvature';

  static List<StepItem> _assemble({
    required String targetLatex,
    required List<String> unitConversions,
    required List<String> rearrangeLines,
    required List<String> substitutionLines,
    required String substitutionEvaluation,
    required String computedValueLine,
    required String roundedLine,
  }) {
    return UniversalStepTemplate.build(
      targetLabelLatex: targetLatex,
      unitConversionLines: unitConversions,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: substitutionEvaluation,
      computedValueLine: computedValueLine,
      roundedValueLine: roundedLine,
    );
  }

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
    if (formula.id == _parabolicId) {
      return _buildParabolic(
        solveFor: solveFor,
        context: context,
        outputs: outputs,
        latexMap: latexMap,
        formatter: formatter,
        unitConverter: unitConverter,
        primaryEnergyUnit: primaryEnergyUnit,
      );
    }

    if (formula.id == _curvatureId) {
      return _buildCurvature(
        solveFor: solveFor,
        context: context,
        outputs: outputs,
        latexMap: latexMap,
        formatter: formatter,
      );
    }

    return null;
  }

  static List<StepItem>? _buildParabolic({
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
    UnitConverter? unitConverter,
    required String primaryEnergyUnit,
  }) {
    if (solveFor != 'E' && solveFor != 'm_star' && solveFor != 'k') {
      return null;
    }

    final fmt6 = formatter.withSigFigs(6);

    final hbar = context.getSymbolValue('hbar');
    final kVal = context.getSymbolValue('k');
    final mStar = context.getSymbolValue('m_star');
    final energy = context.getSymbolValue('E');
    final energyInput = context.getSymbolValue('__meta__input_E');

    final hbarStr6 = _formatSymbolValue(fmt6, latexMap, 'hbar', hbar, defaultUnit: 'J*s');
    final kStr6 = _formatSymbolValue(fmt6, latexMap, 'k', kVal, defaultUnit: 'm^-1');
    final mStr6 = _formatSymbolValue(fmt6, latexMap, 'm_star', mStar, defaultUnit: 'kg');

    final energyInputUnit = energyInput?.unit ?? energy?.unit;
    final energyInputValue = energyInput?.value ?? energy?.value;

    double? energyJ = energy?.value;
    var convertedEnergy = false;
    if (energyInputValue != null && energyInputUnit != null) {
      if (energyInputUnit == 'eV') {
        final converted = _convertEnergy(unitConverter, energyInputValue, 'eV', 'J');
        if (converted != null) {
          energyJ = converted;
          convertedEnergy = true;
        }
      } else {
        energyJ = energyInputValue;
      }
    }
    energyJ ??= energy?.value;

    final energyEvLatex = energyInputValue != null && energyInputUnit != null
        ? formatter.formatLatexWithUnit(energyInputValue, energyInputUnit)
        : (energy != null && energy.unit.isNotEmpty ? formatter.formatLatexWithUnit(energy.value, energy.unit) : latexMap.latexOf('E'));
    final energyJLatex6 = energyJ != null ? fmt6.formatLatexWithUnit(energyJ, 'J') : latexMap.latexOf('E');

    final unitConversions = <String>[];
    if (energyInputUnit != null && energyInputUnit != 'J' && convertedEnergy) {
      final energyJValue = energyJ ?? energy?.value;
      if (energyJValue != null) {
        final energyJLatex3 = formatter.formatLatexWithUnit(energyJValue, 'J');
        unitConversions.add('${_safeSymbol('E', latexMap)} = $energyEvLatex = $energyJLatex3');
      }
    }

    final rearrangeLines = <String>[];
    if (solveFor == 'E') {
      rearrangeLines.add(r'E = \frac{\hbar^{2} k^{2}}{2 m^{*}}');
    } else if (solveFor == 'm_star') {
      rearrangeLines.add(r'E = \frac{\hbar^{2} k^{2}}{2 m^{*}}');
      rearrangeLines.add(r'2 E m^{*} = \hbar^{2} k^{2}');
      rearrangeLines.add(r'm^{*} = \frac{\hbar^{2} k^{2}}{2 E}');
    } else {
      rearrangeLines.add(r'E = \frac{\hbar^{2} k^{2}}{2 m^{*}}');
      rearrangeLines.add(r'2 E m^{*} = \hbar^{2} k^{2}');
      rearrangeLines.add(r'k^{2} = \frac{2 E m^{*}}{\hbar^{2}}');
      rearrangeLines.add(r'k = \sqrt{\frac{2 E m^{*}}{\hbar^{2}}}');
    }

    final substitutionLines = <String>[];
    if (hbar != null) substitutionLines.add('${_safeSymbol('hbar', latexMap)} = $hbarStr6');
    if (kVal != null) substitutionLines.add('${_safeSymbol('k', latexMap)} = $kStr6');
    if (mStar != null) substitutionLines.add('${_safeSymbol('m_star', latexMap)} = $mStr6');
    if (solveFor != 'E' && energy != null) {
      substitutionLines.add('${_safeSymbol('E', latexMap)} = $energyJLatex6');
    }

    final hbarSub = hbar != null ? fmt6.formatLatexWithUnit(hbar.value, hbar.unit.isNotEmpty ? hbar.unit : 'J*s') : hbarStr6;
    final kSub = kVal != null ? fmt6.formatLatexWithUnit(kVal.value, kVal.unit.isNotEmpty ? kVal.unit : 'm^-1') : kStr6;
    final mSub = mStar != null ? fmt6.formatLatexWithUnit(mStar.value, mStar.unit.isNotEmpty ? mStar.unit : 'kg') : mStr6;
    final eSub = energyJLatex6;

    final result = outputs[solveFor];
    String? resultLatex6;
    String? resultLatex3;
    String? resultAlt6;
    String? resultAlt3;
    if (result != null) {
      if (solveFor == 'E') {
        resultLatex6 = _formatResultEnergy(fmt6, unitConverter, result, primaryEnergyUnit);
        resultLatex3 = _formatResultEnergy(formatter, unitConverter, result, primaryEnergyUnit);
        final altUnit = primaryEnergyUnit == 'eV' ? 'J' : 'eV';
        resultAlt6 = _formatResultEnergy(fmt6, unitConverter, result, altUnit);
        resultAlt3 = _formatResultEnergy(formatter, unitConverter, result, altUnit);
      } else {
        resultLatex6 = result.unit.isNotEmpty ? fmt6.formatLatexWithUnit(result.value, result.unit) : fmt6.formatLatex(result.value);
        resultLatex3 = result.unit.isNotEmpty ? formatter.formatLatexWithUnit(result.value, result.unit) : formatter.formatLatex(result.value);
      }
    }

    String substitutionEvaluation;
    if (solveFor == 'E') {
      final substitution = '${_safeSymbol('E', latexMap)} = \\frac{(${hbarSub})^{2} (${kSub})^{2}}{2(${mSub})}';
      substitutionEvaluation = resultLatex6 != null ? '$substitution = $resultLatex6' : substitution;
    } else if (solveFor == 'm_star') {
      final substitution = '${_safeSymbol('m_star', latexMap)} = \\frac{(${hbarSub})^{2} (${kSub})^{2}}{2(${eSub})}';
      substitutionEvaluation = resultLatex6 != null ? '$substitution = $resultLatex6' : substitution;
    } else {
      final substitution = '${_safeSymbol('k', latexMap)} = \\sqrt{\\frac{2(${mSub})(${eSub})}{(${hbarSub})^{2}}}';
      substitutionEvaluation = resultLatex6 != null ? '$substitution = $resultLatex6' : substitution;
    }

    final targetLatex = _safeSymbol(solveFor, latexMap);
    String _withAlt(String base, String? alt) {
      if (alt == null || alt.isEmpty || alt == base) return base;
      return '$base\\; ( $alt )';
    }

    final computedLine =
        resultLatex6 != null ? _withAlt('$targetLatex = $resultLatex6', resultAlt6) : targetLatex;
    final roundedLine = resultLatex3 != null ? _withAlt('$targetLatex = $resultLatex3', resultAlt3) : targetLatex;

    return _assemble(
      targetLatex: targetLatex,
      unitConversions: unitConversions,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluation: substitutionEvaluation,
      computedValueLine: computedLine,
      roundedLine: roundedLine,
    );
  }

  static List<StepItem>? _buildCurvature({
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
  }) {
    if (solveFor != 'm_star' && solveFor != 'd2E_dk2') {
      return null;
    }

    final fmt6 = formatter.withSigFigs(6);

    final hbar = context.getSymbolValue('hbar');
    final mStar = context.getSymbolValue('m_star');
    final curvature = context.getSymbolValue('d2E_dk2');

    final hbarStr6 = _formatSymbolValue(fmt6, latexMap, 'hbar', hbar, defaultUnit: 'J*s');
    final mStr6 = _formatSymbolValue(fmt6, latexMap, 'm_star', mStar, defaultUnit: 'kg');
    final curvStr6 = _formatSymbolValue(fmt6, latexMap, 'd2E_dk2', curvature, defaultUnit: 'J*m^2');

    final rearrangeLines = <String>[];
    if (solveFor == 'm_star') {
      rearrangeLines.add(r'\frac{d^{2}E}{dk^{2}} = \frac{\hbar^{2}}{m^{*}}');
      rearrangeLines.add(r'm^{*}\left(\frac{d^{2}E}{dk^{2}}\right) = \hbar^{2}');
      rearrangeLines.add(r'm^{*} = \frac{\hbar^{2}}{\frac{d^{2}E}{dk^{2}}}');
    } else {
      rearrangeLines.add(r'm^{*} = \hbar^{2}\left(\frac{d^{2}E}{dk^{2}}\right)^{-1}');
      rearrangeLines.add(r'\frac{1}{m^{*}} = \frac{1}{\hbar^{2}}\left(\frac{d^{2}E}{dk^{2}}\right)');
      rearrangeLines.add(r'\frac{d^{2}E}{dk^{2}} = \frac{\hbar^{2}}{m^{*}}');
    }

    final substitutionLines = <String>[];
    if (hbar != null) substitutionLines.add('${_safeSymbol('hbar', latexMap)} = $hbarStr6');
    if (solveFor == 'm_star') {
      if (curvature != null) substitutionLines.add('${_safeSymbol('d2E_dk2', latexMap)} = $curvStr6');
    } else {
      if (mStar != null) substitutionLines.add('${_safeSymbol('m_star', latexMap)} = $mStr6');
    }

    final hbarSub = hbar != null ? fmt6.formatLatexWithUnit(hbar.value, hbar.unit.isNotEmpty ? hbar.unit : 'J*s') : hbarStr6;
    final result = outputs[solveFor];
    final resultLatex6 = result != null
        ? (result.unit.isNotEmpty ? fmt6.formatLatexWithUnit(result.value, result.unit) : fmt6.formatLatex(result.value))
        : null;
    final resultLatex3 = result != null
        ? (result.unit.isNotEmpty ? formatter.formatLatexWithUnit(result.value, result.unit) : formatter.formatLatex(result.value))
        : null;

    String substitutionEvaluation;
    if (solveFor == 'm_star') {
      final d2eSub = curvature != null
          ? fmt6.formatLatexWithUnit(curvature.value, curvature.unit.isNotEmpty ? curvature.unit : 'J*m^2')
          : curvStr6;
      final substitution = '${_safeSymbol('m_star', latexMap)} = \\frac{(${hbarSub})^{2}}{(${d2eSub})}';
      substitutionEvaluation = resultLatex6 != null ? '$substitution = $resultLatex6' : substitution;
    } else {
      final mSub = mStar != null ? fmt6.formatLatexWithUnit(mStar.value, mStar.unit.isNotEmpty ? mStar.unit : 'kg') : mStr6;
      final substitution = '${_safeSymbol('d2E_dk2', latexMap)} = \\frac{(${hbarSub})^{2}}{(${mSub})}';
      substitutionEvaluation = resultLatex6 != null ? '$substitution = $resultLatex6' : substitution;
    }

    final targetLatex = _safeSymbol(solveFor, latexMap);
    final computedLine = resultLatex6 != null ? '$targetLatex = $resultLatex6' : targetLatex;
    final roundedLine = resultLatex3 != null ? '$targetLatex = $resultLatex3' : targetLatex;

    return _assemble(
      targetLatex: targetLatex,
      unitConversions: const [],
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluation: substitutionEvaluation,
      computedValueLine: computedLine,
      roundedLine: roundedLine,
    );
  }

  static String _formatSymbolValue(
    NumberFormatter formatter,
    LatexSymbolMap latexMap,
    String key,
    SymbolValue? value, {
    String? defaultUnit,
    bool asValueOnly = false,
  }) {
    if (value == null) return latexMap.latexOf(key);
    final unit = value.unit.isNotEmpty ? value.unit : (defaultUnit ?? '');
    if (unit.isEmpty) {
      return formatter.formatLatex(value.value);
    }
    final formatted = formatter.formatLatexWithUnit(value.value, unit);
    if (asValueOnly) {
      // strip latex symbol part since formatter already embeds unit
      return formatted;
    }
    return formatted;
  }

  static String _formatResultEnergy(
    NumberFormatter formatter,
    UnitConverter? converter,
    SymbolValue result,
    String targetUnit,
  ) {
    if (result.unit == targetUnit || targetUnit.isEmpty) {
      return result.unit.isNotEmpty ? formatter.formatLatexWithUnit(result.value, result.unit) : formatter.formatLatex(result.value);
    }
    final converted = _convertEnergy(converter, result.value, result.unit, targetUnit);
    if (converted == null) {
      return result.unit.isNotEmpty ? formatter.formatLatexWithUnit(result.value, result.unit) : formatter.formatLatex(result.value);
    }
    return formatter.formatLatexWithUnit(converted, targetUnit);
  }

  static double? _convertEnergy(UnitConverter? converter, double? value, String fromUnit, String toUnit) {
    if (converter == null || value == null) return null;
    return converter.convertEnergy(value, fromUnit, toUnit, symbol: '__energy__', reason: 'energy band step');
  }

  static String _safeSymbol(String key, LatexSymbolMap latexMap) {
    final latex = latexMap.latexOf(key);
    if (latex.isNotEmpty && latex != key) return latex;
    final escaped = key.replaceAll('_', r'\_');
    return r'\mathrm{' + escaped + '}';
  }
}
