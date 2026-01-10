import 'dart:math' as math;

import 'package:semiconductor_appv2/core/constants/latex_symbols.dart';
import 'package:semiconductor_appv2/core/formulas/formula_definition.dart';
import 'package:semiconductor_appv2/core/models/workspace.dart';
import 'package:semiconductor_appv2/core/solver/number_formatter.dart';
import 'package:semiconductor_appv2/core/solver/step_items.dart';
import 'package:semiconductor_appv2/core/solver/steps/universal_step_template.dart';
import 'package:semiconductor_appv2/core/solver/symbol_context.dart';
import 'package:semiconductor_appv2/core/solver/unit_converter.dart';

class DosStatsSteps {
  static const _ncId = 'dos_Nc_effective_density_conduction';
  static const _nvId = 'dos_Nv_effective_density_valence';
  static const _fermiId = 'dos_fermi_dirac_probability';
  static const _niId = 'intrinsic_concentration_from_dos';
  static const _midgapId = 'dos_stats_midgap_energy';
  static const _eiId = 'dos_stats_intrinsic_fermi_level';

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
    switch (formula.id) {
      case _ncId:
        return _buildNcNv(
          solveFor: solveFor,
          context: context,
          outputs: outputs,
          latexMap: latexMap,
          formatter: formatter,
          unitConverter: unitConverter,
          isValence: false,
        );
      case _nvId:
        return _buildNcNv(
          solveFor: solveFor,
          context: context,
          outputs: outputs,
          latexMap: latexMap,
          formatter: formatter,
          unitConverter: unitConverter,
          isValence: true,
        );
      case _fermiId:
        return _buildFermi(
          solveFor: solveFor,
          context: context,
          outputs: outputs,
          latexMap: latexMap,
          formatter: formatter,
          unitConverter: unitConverter,
          primaryEnergyUnit: primaryEnergyUnit,
        );
      case _niId:
        return _buildIntrinsic(
          solveFor: solveFor,
          context: context,
          outputs: outputs,
          latexMap: latexMap,
          formatter: formatter,
          unitConverter: unitConverter,
          primaryEnergyUnit: primaryEnergyUnit,
        );
      case _midgapId:
        return _buildMidgap(
          solveFor: solveFor,
          context: context,
          outputs: outputs,
          latexMap: latexMap,
          formatter: formatter,
          unitConverter: unitConverter,
          primaryEnergyUnit: primaryEnergyUnit,
        );
      case _eiId:
        return _buildEi(
          solveFor: solveFor,
          context: context,
          outputs: outputs,
          latexMap: latexMap,
          formatter: formatter,
          unitConverter: unitConverter,
          primaryEnergyUnit: primaryEnergyUnit,
        );
    }
    return null;
  }

  static List<StepItem> _buildWithTemplate({
    required String targetLatex,
    required List<String> unitConversionLines,
    required List<String> rearrangeLines,
    required List<String> substitutionLines,
    required String substitutionEvaluationLine,
    required SymbolValue? result,
    required NumberFormatter formatter,
    required SymbolContext context,
    UnitConverter? unitConverter,
    String primaryEnergyUnit = 'J',
  }) {
    final computed6 = result != null
        ? _formatResultValue(
            formatter,
            result,
            sigFigs: 6,
            context: context,
            unitConverter: unitConverter,
            primaryEnergyUnit: primaryEnergyUnit,
          )
        : targetLatex;
    final rounded3 = result != null
        ? _formatResultValue(
            formatter,
            result,
            sigFigs: 3,
            context: context,
            unitConverter: unitConverter,
            primaryEnergyUnit: primaryEnergyUnit,
          )
        : targetLatex;

    return UniversalStepTemplate.build(
      targetLabelLatex: targetLatex,
      unitConversionLines: unitConversionLines,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: substitutionEvaluationLine,
      computedValueLine: '$targetLatex = $computed6',
      roundedValueLine: '$targetLatex = $rounded3',
    );
  }

  static List<StepItem>? _buildNcNv({
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
    required UnitConverter? unitConverter,
    required bool isValence,
  }) {
    final fmt6 = formatter.withSigFigs(6);
    final densityDisplayUnit = context.getUnit('__meta__density_unit') ?? 'm^-3';
    final densityKey = isValence ? 'N_v' : 'N_c';
    final massKey = isValence ? 'm_p_star' : 'm_n_star';
    final densitySym = _safeSymbol(densityKey, latexMap);
    final massSym = _safeSymbol(massKey, latexMap);
    final kSym = _safeSymbol('k', latexMap);
    final tSym = _safeSymbol('T', latexMap);
    final hSym = _safeSymbol('h', latexMap);

    if (solveFor != densityKey && solveFor != massKey && solveFor != 'T') return null;

    final density = context.getSymbolValue(densityKey);
    final mass = context.getSymbolValue(massKey);
    final k = context.getSymbolValue('k');
    final h = context.getSymbolValue('h');
    final t = context.getSymbolValue('T');

    final unitConversionLines = <String>[];
    final densityConversionLine = _densityConversionLine(
      key: densityKey,
      value: density,
      displayUnit: densityDisplayUnit,
      latexMap: latexMap,
      formatter: formatter,
      converter: unitConverter,
    );
    if (densityConversionLine != null) unitConversionLines.add(densityConversionLine);

    final densityConversion = _maybeConvertDensity(
      density,
      unitConverter,
      targetUnit: 'm^-3',
      formatter: formatter,
      symbolKey: densityKey,
    );

    final rearrangeLines = <String>[];
    if (solveFor == densityKey) {
      rearrangeLines.add('$densitySym = 2\\left(\\frac{2\\pi $massSym $kSym $tSym}{{$hSym}^{2}}\\right)^{3/2}');
    } else if (solveFor == massKey) {
      rearrangeLines.add('$densitySym = 2\\left(\\frac{2\\pi $massSym $kSym $tSym}{{$hSym}^{2}}\\right)^{3/2}');
      rearrangeLines.add('\\frac{$densitySym}{2} = \\left(\\frac{2\\pi $massSym $kSym $tSym}{{$hSym}^{2}}\\right)^{3/2}');
      rearrangeLines.add('\\left(\\frac{$densitySym}{2}\\right)^{2/3} = \\frac{2\\pi $massSym $kSym $tSym}{{$hSym}^{2}}');
      rearrangeLines.add('$massSym = \\frac{{$hSym}^{2}}{2\\pi $kSym $tSym}\\left(\\frac{$densitySym}{2}\\right)^{2/3}');
    } else {
      rearrangeLines.add('$densitySym = 2\\left(\\frac{2\\pi $massSym $kSym $tSym}{{$hSym}^{2}}\\right)^{3/2}');
      rearrangeLines.add('\\frac{$densitySym}{2} = \\left(\\frac{2\\pi $massSym $kSym $tSym}{{$hSym}^{2}}\\right)^{3/2}');
      rearrangeLines.add('\\left(\\frac{$densitySym}{2}\\right)^{2/3} = \\frac{2\\pi $massSym $kSym $tSym}{{$hSym}^{2}}');
      rearrangeLines.add('$tSym = \\frac{{$hSym}^{2}}{2\\pi $massSym $kSym}\\left(\\frac{$densitySym}{2}\\right)^{2/3}');
    }

    final substitutionLines = <String>[];
    String? formatKnown(String key, SymbolValue? val, {String? defaultUnit}) {
      if (val == null) return null;
      return _formatSymbol(fmt6, latexMap, key, val, defaultUnit: defaultUnit);
    }

    final densityBase = densityConversion?.converted ?? density;
    final densityBaseVal = densityConversion?.baseValue ?? density?.value;
    final densityKnown = densityBaseVal != null
        ? fmt6.valueLatex(densityBaseVal, unit: (densityBase?.unit.isNotEmpty == true ? densityBase!.unit : 'm^-3'), sigFigs: 6)
        : null;
    if (densityKnown != null) substitutionLines.add('$densitySym = $densityKnown');
    final massKnown = formatKnown(massKey, mass, defaultUnit: 'kg');
    if (massKnown != null) substitutionLines.add('$massSym = $massKnown');
    final kKnown = formatKnown('k', k, defaultUnit: 'J/K');
    if (kKnown != null) substitutionLines.add('$kSym = $kKnown');
    final hKnown = formatKnown('h', h, defaultUnit: 'J*s');
    if (hKnown != null) substitutionLines.add('$hSym = $hKnown');
    final tKnown = formatKnown('T', t, defaultUnit: 'K');
    if (tKnown != null) substitutionLines.add('$tSym = $tKnown');

    final result = outputs[solveFor];
    final result6 = result != null
        ? _formatResultValue(
            formatter,
            result,
            sigFigs: 6,
            context: context,
            unitConverter: unitConverter,
          )
        : null;

    String substitutionEvaluation;
    if (solveFor == densityKey) {
      final hSub = hKnown ?? hSym;
      final mSub = massKnown ?? massSym;
      final kSub = kKnown ?? kSym;
      final tSub = tKnown ?? tSym;
      final expr = '$densitySym = 2\\left(\\frac{2\\pi ($mSub)($kSub)($tSub)}{(${hSub})^{2}}\\right)^{3/2}';
      substitutionEvaluation = result6 != null ? '$expr = $result6' : expr;
    } else if (solveFor == massKey) {
      final hSub = hKnown ?? hSym;
      final kSub = kKnown ?? kSym;
      final tSub = tKnown ?? tSym;
      final densSub = densityKnown ?? densitySym;
      final expr =
          '$massSym = \\frac{(${hSub})^{2}}{2\\pi(${kSub})(${tSub})}\\left(\\frac{$densSub}{2}\\right)^{2/3}';
      substitutionEvaluation = result6 != null ? '$expr = $result6' : expr;
    } else {
      final hSub = hKnown ?? hSym;
      final mSub = massKnown ?? massSym;
      final kSub = kKnown ?? kSym;
      final densSub = densityKnown ?? densitySym;
      final expr = '$tSym = \\frac{(${hSub})^{2}}{2\\pi(${mSub})(${kSub})}\\left(\\frac{$densSub}{2}\\right)^{2/3}';
      substitutionEvaluation = result6 != null ? '$expr = $result6' : expr;
    }

    return _buildWithTemplate(
      targetLatex: _latexLabel(solveFor, latexMap),
      unitConversionLines: unitConversionLines,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: substitutionEvaluation,
      result: result,
      formatter: formatter,
      context: context,
      unitConverter: unitConverter,
    );
  }

  static List<StepItem>? _buildFermi({
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
    UnitConverter? unitConverter,
    required String primaryEnergyUnit,
  }) {
    if (solveFor != 'f_E' && solveFor != 'E_F' && solveFor != 'E' && solveFor != 'T') return null;

    final fmt6 = formatter.withSigFigs(6);
    final energyUnit = primaryEnergyUnit.isNotEmpty ? primaryEnergyUnit : 'J';
    final f = context.getSymbolValue('f_E');
    final e = context.getSymbolValue('E');
    final ef = context.getSymbolValue('E_F');
    final k = context.getSymbolValue('k');
    final t = context.getSymbolValue('T');

    final eConv = _maybeEnergyConversion(
      e,
      unitConverter,
      label: latexMap.latexOf('E'),
      formatter: formatter,
      symbolKey: 'E',
      preferredUnit: energyUnit,
    );
    final efConv = _maybeEnergyConversion(
      ef,
      unitConverter,
      label: latexMap.latexOf('E_F'),
      formatter: formatter,
      symbolKey: 'E_F',
      preferredUnit: energyUnit,
    );
    final kConv = _maybeBoltzmannConversion(
      kSymbol: k,
      converter: unitConverter,
      formatter: formatter,
      energyUnit: energyUnit,
    );

    final unitConversions = <String>[];
    if (eConv?.line != null) unitConversions.add(eConv!.line!);
    if (efConv?.line != null) unitConversions.add(efConv!.line!);
    if (kConv?.line != null) unitConversions.add(kConv!.line!);

    final rearrangeLines = <String>[];
    switch (solveFor) {
      case 'f_E':
        rearrangeLines.add(r'f(E)=\frac{1}{1+\exp\left(\frac{E-E_F}{kT}\right)}');
        break;
      case 'E_F':
        rearrangeLines.addAll([
          r'f(E)=\frac{1}{1+\exp\left(\frac{E-E_F}{kT}\right)}',
          r'\frac{1}{f}=1+\exp\left(\frac{E-E_F}{kT}\right)',
          r'\frac{1}{f}-1=\exp\left(\frac{E-E_F}{kT}\right)',
          r'\ln\left(\frac{1}{f}-1\right)=\frac{E-E_F}{kT}',
          r'E_F=E-kT\ln\left(\frac{1}{f}-1\right)',
        ]);
        break;
      case 'E':
        rearrangeLines.addAll([
          r'f(E)=\frac{1}{1+\exp\left(\frac{E-E_F}{kT}\right)}',
          r'\frac{1}{f}=1+\exp\left(\frac{E-E_F}{kT}\right)',
          r'\frac{1}{f}-1=\exp\left(\frac{E-E_F}{kT}\right)',
          r'\ln\left(\frac{1}{f}-1\right)=\frac{E-E_F}{kT}',
          r'E=E_F+kT\ln\left(\frac{1}{f}-1\right)',
        ]);
        break;
      case 'T':
        rearrangeLines.add(r'T = \frac{E-E_F}{k\,\ln\left(\frac{1}{f(E)}-1\right)}');
        break;
    }

    final substitutionLines = <String>[];
    void addKnown(String key, SymbolValue? val, {String? defaultUnit}) {
      if (val == null) return;
      final latexVal = _formatSymbol(fmt6, latexMap, key, val, defaultUnit: defaultUnit);
      substitutionLines.add('${_safeSymbol(key, latexMap)} = $latexVal');
    }

    addKnown('f_E', f);
    final eBase = eConv?.converted ?? e;
    final efBase = efConv?.converted ?? ef;

    String? _energyWithUnit(SymbolValue? val, _EnergyConversion? conv) {
      if (val == null) return null;
      final unit = (conv?.baseUnit ?? val.unit).isNotEmpty ? (conv?.baseUnit ?? val.unit) : 'J';
      final baseVal = conv?.baseValue ?? val.value;
      return fmt6.valueLatex(baseVal, unit: unit, sigFigs: 6);
    }

    if (eBase != null) {
      substitutionLines.add('${_safeSymbol('E', latexMap)} = ${_energyWithUnit(eBase, eConv)}');
    }
    if (efBase != null) {
      substitutionLines.add('${_safeSymbol('E_F', latexMap)} = ${_energyWithUnit(efBase, efConv)}');
    }
    final kBase = kConv?.converted ?? k;
    addKnown('k', kBase, defaultUnit: kBase?.unit.isNotEmpty == true ? kBase!.unit : '$energyUnit/K');
    addKnown('T', t, defaultUnit: 'K');

    final eVal = eConv?.baseValue ?? e?.value;
    final efVal = efConv?.baseValue ?? ef?.value;
    final kVal = kConv?.baseValue ?? k?.value;
    final tVal = t?.value;
    final fVal = f?.value;

    String lnTermRaw() {
      if (fVal == null) return r'\ln\left(\frac{1}{f(E)}-1\right)';
      final fStr = fmt6.formatLatex(fVal);
      return r'\ln\left(\frac{1}{' + fStr + r'}-1\right)';
    }

    String lnTermEval() {
      if (fVal == null) return r'\ln\left(\frac{1}{f(E)}-1\right)';
      final val = math.log((1 / fVal) - 1);
      return fmt6.formatLatex(val);
    }

    final result = outputs[solveFor];
    final result6 = result != null
        ? _formatResultValue(
            formatter,
            result,
            sigFigs: 6,
            context: context,
            unitConverter: unitConverter,
            primaryEnergyUnit: primaryEnergyUnit,
          )
        : null;

    String substitutionEvaluation;
    switch (solveFor) {
      case 'f_E': {
        final numStr = (eVal != null && efVal != null && kVal != null && tVal != null)
            ? fmt6.formatLatex((eVal - efVal) / (kVal * tVal))
            : r'\frac{E-E_F}{kT}';
        final expr = 'f(E) = \\frac{1}{1+\\exp\\left(' + numStr + r'\right)}';
        substitutionLines.add(expr);
        substitutionEvaluation = result6 != null ? '$expr = $result6' : expr;
        break;
      }
      case 'E_F': {
        final kTVal = (kVal != null && tVal != null) ? kVal * tVal : null;
        final kT = kTVal != null ? fmt6.formatLatexWithUnit(kTVal, energyUnit) : r'kT';
        final eLeft = eVal != null ? fmt6.formatLatexWithUnit(eVal, energyUnit) : _safeSymbol('E', latexMap);
        final lnTerm = lnTermRaw();
        final lnTermEvaluated = lnTermEval();
        final substituted = '${_safeSymbol('E_F', latexMap)} = $eLeft - ($kT)\\,$lnTerm';
        final computed = (eVal != null && kTVal != null && fVal != null)
            ? fmt6.valueLatex(eVal - kTVal * math.log((1 / fVal) - 1), unit: 'J', sigFigs: 6)
            : null;
        substitutionLines.add(substituted);
        final evaluated = '${_safeSymbol('E_F', latexMap)} = $eLeft - ($kT)\\,$lnTermEvaluated';
        substitutionEvaluation = computed != null ? '$evaluated = $computed' : evaluated;
        break;
      }
      case 'E': {
        final kTVal = (kVal != null && tVal != null) ? kVal * tVal : null;
        final kT = kTVal != null ? fmt6.formatLatexWithUnit(kTVal, energyUnit) : r'kT';
        final efLeft = efVal != null ? fmt6.formatLatexWithUnit(efVal, energyUnit) : _safeSymbol('E_F', latexMap);
        final lnTerm = lnTermRaw();
        final lnTermEvaluated = lnTermEval();
        final computedJ = (efVal != null && kTVal != null && fVal != null)
            ? fmt6.valueLatex(efVal + kTVal * math.log((1 / fVal) - 1), unit: energyUnit, sigFigs: 6)
            : null;
        final resultEnergyUnit = result?.unit ?? 'J';
        String conversionSuffix = '';
        if (result != null &&
            unitConverter != null &&
            (resultEnergyUnit == 'eV' || primaryEnergyUnit == 'eV') &&
            resultEnergyUnit != 'J') {
          final toEv = unitConverter.convertEnergy(result.value, resultEnergyUnit, 'eV');
          if (toEv != null && resultEnergyUnit != 'eV') {
            conversionSuffix = ' = ${fmt6.formatLatexWithUnit(toEv, 'eV')}';
          }
        }
        final expr = '${_safeSymbol('E', latexMap)} = $efLeft + ($kT)\\,$lnTerm';
        substitutionLines.add(expr);
        final evaluatedExpr = '${_safeSymbol('E', latexMap)} = $efLeft + ($kT)\\,$lnTermEvaluated';
        final evaluated = computedJ != null ? '$evaluatedExpr = $computedJ$conversionSuffix' : evaluatedExpr;
        substitutionEvaluation = result6 != null ? '$evaluated = $result6' : evaluated;
        break;
      }
      case 'T':
      default: {
        final num = (eVal != null && efVal != null) ? fmt6.formatLatexWithUnit(eVal - efVal, energyUnit) : r'(E-E_F)';
        final denom = lnTermRaw();
        final denomEval = lnTermEval();
        final expr = r'T = \frac{' + num + r'}{k\, ' + denom + '}';
        substitutionLines.add(expr);
        final evaluated = r'T = \frac{' + num + r'}{k\, ' + denomEval + '}';
        substitutionEvaluation = result6 != null ? '$evaluated = $result6' : evaluated;
        break;
      }
    }

    return _buildWithTemplate(
      targetLatex: _latexLabel(solveFor, latexMap),
      unitConversionLines: unitConversions,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: substitutionEvaluation,
      result: result,
      formatter: formatter,
      context: context,
      unitConverter: unitConverter,
      primaryEnergyUnit: primaryEnergyUnit,
    );
  }

  static List<StepItem>? _buildIntrinsic({
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
    UnitConverter? unitConverter,
    required String primaryEnergyUnit,
  }) {
    if (solveFor != 'n_i' && solveFor != 'E_g' && solveFor != 'T' && solveFor != 'N_c' && solveFor != 'N_v') {
      return null;
    }

    final fmt6 = formatter.withSigFigs(6);
    final densityDisplayUnit = context.getUnit('__meta__density_unit') ?? 'm^-3';
    final energyUnit = primaryEnergyUnit.isNotEmpty ? primaryEnergyUnit : 'J';
    final nc = context.getSymbolValue('N_c');
    final nv = context.getSymbolValue('N_v');
    final ni = context.getSymbolValue('n_i');
    final eg = context.getSymbolValue('E_g');
    final k = context.getSymbolValue('k');
    final t = context.getSymbolValue('T');

    final ncConv = _maybeConvertDensity(nc, unitConverter, targetUnit: 'm^-3', formatter: formatter, symbolKey: 'N_c');
    final nvConv = _maybeConvertDensity(nv, unitConverter, targetUnit: 'm^-3', formatter: formatter, symbolKey: 'N_v');
    final egConv = _maybeEnergyConversion(eg, unitConverter, label: latexMap.latexOf('E_g'), formatter: formatter, symbolKey: 'E_g', preferredUnit: energyUnit);
    final kConv = _maybeBoltzmannConversion(
      kSymbol: k,
      converter: unitConverter,
      formatter: formatter,
      energyUnit: energyUnit,
    );

    final unitConversions = <String>[];
    final ncDisplayLine = _densityConversionLine(
      key: 'N_c',
      value: nc,
      displayUnit: densityDisplayUnit,
      latexMap: latexMap,
      formatter: formatter,
      converter: unitConverter,
    );
    final nvDisplayLine = _densityConversionLine(
      key: 'N_v',
      value: nv,
      displayUnit: densityDisplayUnit,
      latexMap: latexMap,
      formatter: formatter,
      converter: unitConverter,
    );
    final niDisplayLine = _densityConversionLine(
      key: 'n_i',
      value: ni,
      displayUnit: densityDisplayUnit,
      latexMap: latexMap,
      formatter: formatter,
      converter: unitConverter,
    );
    if (ncDisplayLine != null) unitConversions.add(ncDisplayLine);
    if (nvDisplayLine != null) unitConversions.add(nvDisplayLine);
    if (niDisplayLine != null) unitConversions.add(niDisplayLine);
    if (ncConv?.line != null) unitConversions.add(ncConv!.line!);
    if (nvConv?.line != null) unitConversions.add(nvConv!.line!);
    if (egConv?.line != null) unitConversions.add(egConv!.line!);
    if (kConv?.line != null) unitConversions.add(kConv!.line!);

    final targetLatex = _latexLabel(solveFor, latexMap);
    final rearrangeLines = <String>[];
    switch (solveFor) {
      case 'n_i':
        rearrangeLines.add(r'n_i = \sqrt{N_c N_v\, \exp\left(\frac{-E_g}{kT}\right)}');
        break;
      case 'E_g':
        rearrangeLines.add(r'E_g = -kT \ln\left(\frac{n_i^{2}}{N_c N_v}\right)');
        break;
      case 'T':
        rearrangeLines.add(r'T = -\frac{E_g}{k\,\ln\left(\frac{n_i^{2}}{N_c N_v}\right)}');
        break;
      case 'N_c':
        rearrangeLines.add(r'N_c = \frac{n_i^{2}}{N_v\,\exp\left(\frac{-E_g}{kT}\right)}');
        break;
      case 'N_v':
        rearrangeLines.add(r'N_v = \frac{n_i^{2}}{N_c\,\exp\left(\frac{-E_g}{kT}\right)}');
        break;
    }

    final substitutionLines = <String>[];
    void addKnown(String key, SymbolValue? val, {String? defaultUnit}) {
      if (val == null) return;
      final latexVal = _formatSymbol(fmt6, latexMap, key, val, defaultUnit: defaultUnit);
      substitutionLines.add('${_safeSymbol(key, latexMap)} = $latexVal');
    }

    final ncBase = ncConv?.converted ?? nc;
    final nvBase = nvConv?.converted ?? nv;
    final egBase = egConv?.converted ?? eg;

    if (ncBase != null) {
      substitutionLines.add('${_safeSymbol('N_c', latexMap)} = ${fmt6.valueLatex(ncConv?.baseValue ?? ncBase.value, unit: ncBase.unit.isNotEmpty ? ncBase.unit : 'm^-3', sigFigs: 6)}');
    }
    if (nvBase != null) {
      substitutionLines.add('${_safeSymbol('N_v', latexMap)} = ${fmt6.valueLatex(nvConv?.baseValue ?? nvBase.value, unit: nvBase.unit.isNotEmpty ? nvBase.unit : 'm^-3', sigFigs: 6)}');
    }
    addKnown('n_i', ni, defaultUnit: 'm^-3');
    if (egBase != null) {
      substitutionLines.add('${_safeSymbol('E_g', latexMap)} = ${fmt6.valueLatex(egConv?.baseValue ?? egBase.value, unit: egBase.unit.isNotEmpty ? egBase.unit : energyUnit, sigFigs: 6)}');
    }
    final kBase = kConv?.converted ?? k;
    addKnown('k', kBase, defaultUnit: kBase?.unit.isNotEmpty == true ? kBase!.unit : '$energyUnit/K');
    addKnown('T', t, defaultUnit: 'K');

    final ncVal = ncConv?.baseValue ?? nc?.value;
    final nvVal = nvConv?.baseValue ?? nv?.value;
    final niVal = ni?.value;
    final egVal = egConv?.baseValue ?? eg?.value;
    final kVal = kConv?.baseValue ?? k?.value;
    final tVal = t?.value;
    final result = outputs[solveFor];
    final result6 = result != null
        ? _formatResultValue(
            formatter,
            result,
            sigFigs: 6,
            context: context,
            unitConverter: unitConverter,
            primaryEnergyUnit: primaryEnergyUnit,
      )
        : null;

    String substitutionEvaluation;
    switch (solveFor) {
      case 'n_i':
        final kTVal = (kVal != null && tVal != null) ? kVal * tVal : null;
        final exponentVal = (egVal != null && kVal != null && tVal != null)
            ? (-egVal) / (kVal * tVal)
            : null;
        if (kTVal != null) {
          substitutionLines.add(r'kT = ' + fmt6.formatLatexWithUnit(kTVal, energyUnit));
        }
        if (exponentVal != null) {
          substitutionLines.add(r'\frac{-E_g}{kT} = ' + fmt6.formatLatex(exponentVal));
        }
        final egTerm = exponentVal != null
            ? fmt6.formatLatex(exponentVal)
            : r'\frac{-E_g}{kT}';
        final ncSub = ncVal != null ? fmt6.formatLatexWithUnit(ncVal, 'm^{-3}') : latexMap.latexOf('N_c');
        final nvSub = nvVal != null ? fmt6.formatLatexWithUnit(nvVal, 'm^{-3}') : latexMap.latexOf('N_v');
        final expr = '${_safeSymbol('n_i', latexMap)} = \\sqrt{(' + ncSub + ')(' + nvSub + ') \\exp(' + egTerm + ')}';
        substitutionEvaluation = result6 != null ? '$expr = $result6' : expr;
        break;
      case 'E_g':
        final logArg = (niVal != null && ncVal != null && nvVal != null)
            ? fmt6.formatLatex((niVal * niVal) / (ncVal * nvVal))
            : r'\frac{n_i^{2}}{N_c N_v}';
        final expr = '${_safeSymbol('E_g', latexMap)} = -kT \\ln(' + logArg + ')';
        substitutionEvaluation = result6 != null ? '$expr = $result6' : expr;
        break;
      case 'T':
        final numStr = egVal != null ? fmt6.formatLatexWithUnit(egVal, energyUnit) : r'E_g';
        final denom = (niVal != null && ncVal != null && nvVal != null)
            ? fmt6.formatLatex(math.log((niVal * niVal) / (ncVal * nvVal)))
            : r'\ln\left(\frac{n_i^{2}}{N_c N_v}\right)';
        final expr = '${_safeSymbol('T', latexMap)} = -\\frac{$numStr}{k\\, ' + denom + '}';
        substitutionEvaluation = result6 != null ? '$expr = $result6' : expr;
        break;
      case 'N_c':
        final numStr = niVal != null ? fmt6.formatLatexWithUnit(niVal * niVal, 'm^{-6}') : r'n_i^{2}';
        final kTVal = (kVal != null && tVal != null) ? kVal * tVal : null;
        final exponentVal = (egVal != null && kVal != null && tVal != null)
            ? (-egVal) / (kVal * tVal)
            : null;
        if (kTVal != null) {
          substitutionLines.add(r'kT = ' + fmt6.formatLatexWithUnit(kTVal, energyUnit));
        }
        if (exponentVal != null) {
          substitutionLines.add(r'\frac{-E_g}{kT} = ' + fmt6.formatLatex(exponentVal));
        }
        final egTerm = exponentVal != null
            ? fmt6.formatLatex(exponentVal)
            : r'\frac{-E_g}{kT}';
        final denomNv = nvVal != null ? fmt6.formatLatexWithUnit(nvVal, 'm^{-3}') : latexMap.latexOf('N_v');
        final expr = '${_safeSymbol('N_c', latexMap)} = \\frac{$numStr}{' + denomNv + r'\exp(' + egTerm + ')}';
        substitutionEvaluation = result6 != null ? '$expr = $result6' : expr;
        break;
      case 'N_v':
      default:
        final numStr = niVal != null ? fmt6.formatLatexWithUnit(niVal * niVal, 'm^{-6}') : r'n_i^{2}';
        final kTVal = (kVal != null && tVal != null) ? kVal * tVal : null;
        final exponentVal = (egVal != null && kVal != null && tVal != null)
            ? (-egVal) / (kVal * tVal)
            : null;
        if (kTVal != null) {
          substitutionLines.add(r'kT = ' + fmt6.formatLatexWithUnit(kTVal, energyUnit));
        }
        if (exponentVal != null) {
          substitutionLines.add(r'\frac{-E_g}{kT} = ' + fmt6.formatLatex(exponentVal));
        }
        final egTerm = exponentVal != null
            ? fmt6.formatLatex(exponentVal)
            : r'\frac{-E_g}{kT}';
        final denomNc = ncVal != null ? fmt6.formatLatexWithUnit(ncVal, 'm^{-3}') : latexMap.latexOf('N_c');
        final expr = '${_safeSymbol('N_v', latexMap)} = \\frac{$numStr}{' + denomNc + r'\exp(' + egTerm + ')}';
        substitutionEvaluation = result6 != null ? '$expr = $result6' : expr;
        break;
    }

    return _buildWithTemplate(
      targetLatex: targetLatex,
      unitConversionLines: unitConversions,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: substitutionEvaluation,
      result: result,
      formatter: formatter,
      context: context,
      unitConverter: unitConverter,
      primaryEnergyUnit: primaryEnergyUnit,
    );
  }

  static List<StepItem>? _buildMidgap({
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
    UnitConverter? unitConverter,
    required String primaryEnergyUnit,
  }) {
    if (solveFor != 'E_mid' && solveFor != 'E_c' && solveFor != 'E_v') return null;

    final fmt6 = formatter.withSigFigs(6);
    final energyUnit = primaryEnergyUnit.isNotEmpty ? primaryEnergyUnit : 'J';
    final targetLatex = _latexLabel(solveFor, latexMap);

    final eMid = context.getSymbolValue('E_mid');
    final eC = context.getSymbolValue('E_c');
    final eV = context.getSymbolValue('E_v');

    final midConv = _maybeEnergyConversion(eMid, unitConverter, label: latexMap.latexOf('E_mid'), formatter: formatter, symbolKey: 'E_mid', preferredUnit: energyUnit);
    final cConv = _maybeEnergyConversion(eC, unitConverter, label: latexMap.latexOf('E_c'), formatter: formatter, symbolKey: 'E_c', preferredUnit: energyUnit);
    final vConv = _maybeEnergyConversion(eV, unitConverter, label: latexMap.latexOf('E_v'), formatter: formatter, symbolKey: 'E_v', preferredUnit: energyUnit);

    final unitConversions = <String>[];
    if (midConv?.line != null) unitConversions.add(midConv!.line!);
    if (cConv?.line != null) unitConversions.add(cConv!.line!);
    if (vConv?.line != null) unitConversions.add(vConv!.line!);

    final rearrangeLines = <String>[];
    if (solveFor == 'E_mid') {
      rearrangeLines.add(r'E_{\mathrm{mid}} = \frac{E_c + E_v}{2}');
    } else if (solveFor == 'E_c') {
      rearrangeLines.add(r'E_c = 2E_{\mathrm{mid}} - E_v');
    } else {
      rearrangeLines.add(r'E_v = 2E_{\mathrm{mid}} - E_c');
    }

    final substitutionLines = <String>[];
    String? energyVal(SymbolValue? symbol, _EnergyConversion? conv) {
      final base = conv?.baseValue ?? symbol?.value;
      final unit = conv?.baseUnit ?? symbol?.unit ?? 'J';
      if (base == null) return null;
      return fmt6.valueLatex(base, unit: unit, sigFigs: 6);
    }

    final ecStr6 = energyVal(eC, cConv);
    final evStr6 = energyVal(eV, vConv);
    final emidStr6 = energyVal(eMid, midConv);

    // List known values, but skip the target variable to avoid identity lines.
    if (solveFor != 'E_c' && ecStr6 != null) substitutionLines.add('${_safeSymbol('E_c', latexMap)} = $ecStr6');
    if (solveFor != 'E_v' && evStr6 != null) substitutionLines.add('${_safeSymbol('E_v', latexMap)} = $evStr6');
    if (solveFor != 'E_mid' && emidStr6 != null) substitutionLines.add('${_safeSymbol('E_mid', latexMap)} = $emidStr6');

    final result = outputs[solveFor];
    final result6 = result != null
        ? _formatResultValue(
            formatter,
            result,
            sigFigs: 6,
            context: context,
            unitConverter: unitConverter,
            primaryEnergyUnit: primaryEnergyUnit,
          )
        : null;

    String substitutionEvaluation;
    if (solveFor == 'E_mid') {
      final expr =
          '${_safeSymbol('E_mid', latexMap)} = \\frac{${ecStr6 ?? _safeSymbol('E_c', latexMap)} + ${evStr6 ?? _safeSymbol('E_v', latexMap)}}{2}';
      substitutionEvaluation = result6 != null ? '$expr = $result6' : expr;
    } else if (solveFor == 'E_c') {
      final expr =
          '${_safeSymbol('E_c', latexMap)} = 2(${emidStr6 ?? _safeSymbol('E_mid', latexMap)}) - ${evStr6 ?? _safeSymbol('E_v', latexMap)}';
      substitutionEvaluation = result6 != null ? '$expr = $result6' : expr;
    } else {
      final expr =
          '${_safeSymbol('E_v', latexMap)} = 2(${emidStr6 ?? _safeSymbol('E_mid', latexMap)}) - ${ecStr6 ?? _safeSymbol('E_c', latexMap)}';
      substitutionEvaluation = result6 != null ? '$expr = $result6' : expr;
    }

    return _buildWithTemplate(
      targetLatex: targetLatex,
      unitConversionLines: unitConversions,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: substitutionEvaluation,
      result: result,
      formatter: formatter,
      context: context,
      unitConverter: unitConverter,
      primaryEnergyUnit: primaryEnergyUnit,
    );
  }

  static List<StepItem>? _buildEi({
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required LatexSymbolMap latexMap,
    required NumberFormatter formatter,
    UnitConverter? unitConverter,
    required String primaryEnergyUnit,
  }) {
    if (solveFor != 'E_i' && solveFor != 'E_mid' && solveFor != 'T' && solveFor != 'm_p_star' && solveFor != 'm_n_star') {
      return null;
    }

    final fmt6 = formatter.withSigFigs(6);
    final energyUnit = primaryEnergyUnit.isNotEmpty ? primaryEnergyUnit : 'J';
    final ei = context.getSymbolValue('E_i');
    final emid = context.getSymbolValue('E_mid');
    final mp = context.getSymbolValue('m_p_star');
    final mn = context.getSymbolValue('m_n_star');
    final k = context.getSymbolValue('k');
    final t = context.getSymbolValue('T');

    final eiConv = _maybeEnergyConversion(ei, unitConverter, label: latexMap.latexOf('E_i'), formatter: formatter, symbolKey: 'E_i', preferredUnit: energyUnit);
    final emidConv = _maybeEnergyConversion(emid, unitConverter, label: latexMap.latexOf('E_mid'), formatter: formatter, symbolKey: 'E_mid', preferredUnit: energyUnit);
    final kConv = _maybeBoltzmannConversion(
      kSymbol: k,
      converter: unitConverter,
      formatter: formatter,
      energyUnit: energyUnit,
    );

    final unitConversions = <String>[];
    if (eiConv?.line != null) unitConversions.add(eiConv!.line!);
    if (emidConv?.line != null) unitConversions.add(emidConv!.line!);
    if (kConv?.line != null) unitConversions.add(kConv!.line!);

    final targetLatex = _latexLabel(solveFor, latexMap);
    final rearrangeLines = <String>[];
    switch (solveFor) {
      case 'E_i':
        rearrangeLines.add(r'E_i = E_{\mathrm{mid}} + \frac{3}{4} k T \ln\left(\frac{m_p^{*}}{m_n^{*}}\right)');
        break;
      case 'E_mid':
        rearrangeLines.add(r'E_{\mathrm{mid}} = E_i - \frac{3}{4} k T \ln\left(\frac{m_p^{*}}{m_n^{*}}\right)');
        break;
      case 'T':
        rearrangeLines.add(r'T = \frac{E_i - E_{\mathrm{mid}}}{\frac{3}{4}k \ln\left(\frac{m_p^{*}}{m_n^{*}}\right)}');
        break;
      case 'm_p_star':
        rearrangeLines.add(r'm_p^{*} = m_n^{*} \exp\left(\frac{4}{3}\frac{E_i - E_{\mathrm{mid}}}{kT}\right)');
        break;
      case 'm_n_star':
        rearrangeLines.add(r'm_n^{*} = m_p^{*} \exp\left(-\frac{4}{3}\frac{E_i - E_{\mathrm{mid}}}{kT}\right)');
        break;
    }

    final substitutionLines = <String>[];
    String? energyVal(SymbolValue? symbol, _EnergyConversion? conv) {
      final base = conv?.baseValue ?? symbol?.value;
      final unit = conv?.baseUnit ?? symbol?.unit ?? 'J';
      if (base == null) return null;
      return fmt6.valueLatex(base, unit: unit, sigFigs: 6);
    }

    final eiStr6 = energyVal(ei, eiConv);
    final emidStr6 = energyVal(emid, emidConv);
    if (eiStr6 != null) substitutionLines.add('${_safeSymbol('E_i', latexMap)} = $eiStr6');
    if (emidStr6 != null) substitutionLines.add('${_safeSymbol('E_mid', latexMap)} = $emidStr6');
    if (mp != null) substitutionLines.add('${_safeSymbol('m_p_star', latexMap)} = ${_formatSymbol(fmt6, latexMap, 'm_p_star', mp, defaultUnit: 'kg')}');
    if (mn != null) substitutionLines.add('${_safeSymbol('m_n_star', latexMap)} = ${_formatSymbol(fmt6, latexMap, 'm_n_star', mn, defaultUnit: 'kg')}');
    final kBase = kConv?.converted ?? k;
    if (kBase != null) {
      substitutionLines.add('${_safeSymbol('k', latexMap)} = ${_formatSymbol(fmt6, latexMap, 'k', kBase, defaultUnit: kBase.unit.isNotEmpty ? kBase.unit : '$energyUnit/K')}');
    }
    if (t != null) substitutionLines.add('${_safeSymbol('T', latexMap)} = ${_formatSymbol(fmt6, latexMap, 'T', t, defaultUnit: 'K')}');

    final eiVal = eiConv?.baseValue ?? ei?.value;
    final emidVal = emidConv?.baseValue ?? emid?.value;
    final mpVal = mp?.value;
    final mnVal = mn?.value;
    final kVal = kConv?.baseValue ?? k?.value;
    final tVal = t?.value;

    String logTermRaw() {
      if (mpVal != null && mnVal != null) {
        final mpStr = fmt6.formatLatex(mpVal);
        final mnStr = fmt6.formatLatex(mnVal);
        return r'\ln\left(\frac{' + mpStr + '}{' + mnStr + r'}\right)';
      }
      return r'\ln\left(\frac{m_p^{*}}{m_n^{*}}\right)';
    }

    String logTermEval() {
      if (mpVal != null && mnVal != null) {
        final val = math.log(mpVal / mnVal);
        return fmt6.formatLatex(val);
      }
      return r'\ln\left(\frac{m_p^{*}}{m_n^{*}}\right)';
    }

    final result = outputs[solveFor];
    final result6 = result != null
        ? _formatResultValue(
            formatter,
            result,
            sigFigs: 6,
            context: context,
            unitConverter: unitConverter,
            primaryEnergyUnit: primaryEnergyUnit,
          )
        : null;

    String substitutionEvaluation;
    switch (solveFor) {
      case 'E_i':
        final kTerm = (kVal != null && tVal != null) ? fmt6.formatLatexWithUnit((3 / 4) * kVal * tVal, energyUnit) : r'\frac{3}{4}kT';
        final exprRaw = '${_safeSymbol('E_i', latexMap)} = ' +
            (emidStr6 ?? _safeSymbol('E_mid', latexMap)) +
            ' + (' +
            kTerm +
            ') ' +
            logTermRaw();
        final exprEval = '${_safeSymbol('E_i', latexMap)} = ' +
            (emidStr6 ?? _safeSymbol('E_mid', latexMap)) +
            ' + (' +
            kTerm +
            ') ' +
            logTermEval();
        substitutionLines.add(exprRaw);
        substitutionEvaluation = result6 != null ? '$exprEval = $result6' : exprEval;
        break;
      case 'E_mid':
        final kTerm = (kVal != null && tVal != null) ? fmt6.formatLatexWithUnit((3 / 4) * kVal * tVal, energyUnit) : r'\frac{3}{4}kT';
        final exprRaw = '${_safeSymbol('E_mid', latexMap)} = ' +
            (eiStr6 ?? _safeSymbol('E_i', latexMap)) +
            ' - (' +
            kTerm +
            ') ' +
            logTermRaw();
        final exprEval = '${_safeSymbol('E_mid', latexMap)} = ' +
            (eiStr6 ?? _safeSymbol('E_i', latexMap)) +
            ' - (' +
            kTerm +
            ') ' +
            logTermEval();
        substitutionLines.add(exprRaw);
        substitutionEvaluation = result6 != null ? '$exprEval = $result6' : exprEval;
        break;
      case 'T':
        final num = (eiVal != null && emidVal != null) ? fmt6.formatLatexWithUnit(eiVal - emidVal, 'J') : r'(E_i - E_{\mathrm{mid}})';
        final expr = '${_safeSymbol('T', latexMap)} = \\frac{$num}{\\frac{3}{4}k ' + logTermRaw() + '}';
        final evaluated = '${_safeSymbol('T', latexMap)} = \\frac{$num}{\\frac{3}{4}k ' + logTermEval() + '}';
        substitutionLines.add(expr);
        substitutionEvaluation = result6 != null ? '$evaluated = $result6' : evaluated;
        break;
      case 'm_p_star':
        final num = (eiVal != null && emidVal != null && kVal != null && tVal != null)
            ? fmt6.formatLatex((4 / 3) * (eiVal - emidVal) / (kVal * tVal))
            : r'\frac{4}{3}\frac{E_i - E_{\mathrm{mid}}}{kT}';
        final mnStr = mnVal != null ? fmt6.formatLatexWithUnit(mnVal, 'kg') : latexMap.latexOf('m_n_star');
        final expr = '${_safeSymbol('m_p_star', latexMap)} = ' + mnStr + r'\,\exp(' + num + ')';
        substitutionEvaluation = result6 != null ? '$expr = $result6' : expr;
        break;
      case 'm_n_star':
      default:
        final num = (eiVal != null && emidVal != null && kVal != null && tVal != null)
            ? fmt6.formatLatex(-(4 / 3) * (eiVal - emidVal) / (kVal * tVal))
            : r'-\frac{4}{3}\frac{E_i - E_{\mathrm{mid}}}{kT}';
        final mpStr = mpVal != null ? fmt6.formatLatexWithUnit(mpVal, 'kg') : latexMap.latexOf('m_p_star');
        final expr = '${_safeSymbol('m_n_star', latexMap)} = ' + mpStr + r'\,\exp(' + num + ')';
        substitutionEvaluation = result6 != null ? '$expr = $result6' : expr;
        break;
    }

    return _buildWithTemplate(
      targetLatex: targetLatex,
      unitConversionLines: unitConversions,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: substitutionEvaluation,
      result: result,
      formatter: formatter,
      context: context,
      unitConverter: unitConverter,
      primaryEnergyUnit: primaryEnergyUnit,
    );
  }

  static String _formatSymbol(
    NumberFormatter formatter,
    LatexSymbolMap latexMap,
    String key,
    SymbolValue? value, {
    String? defaultUnit,
  }) {
    if (value == null) return _safeSymbol(key, latexMap);
    final unit = value.unit.isNotEmpty ? value.unit : (defaultUnit ?? '');
    if (unit.isEmpty) return formatter.formatLatex(value.value);
    return formatter.formatLatexWithUnit(value.value, unit);
  }

  static String _formatResultValue(
    NumberFormatter formatter,
    SymbolValue result, {
    required int sigFigs,
    SymbolContext? context,
    UnitConverter? unitConverter,
    String primaryEnergyUnit = 'J',
  }) {
    final fmt = formatter.withSigFigs(sigFigs);
    var value = result.value;
    var unit = result.unit;

    // Density preference handling
    if (context != null && unit == 'm^-3') {
      final densityUnitPref = context.getUnit('__meta__density_unit');
      if (densityUnitPref == 'cm^-3' && unitConverter != null) {
        final cm = unitConverter.convertDensity(value, 'm^-3', 'cm^-3');
        if (cm != null) {
          value = cm;
          unit = 'cm^-3';
        }
      }
    }

    // Energy preference handling
    if ((unit == 'J' || unit == 'eV') && unitConverter != null && primaryEnergyUnit.isNotEmpty) {
      if (primaryEnergyUnit != unit) {
        final converted = unitConverter.convertEnergy(value, unit, primaryEnergyUnit);
        if (converted != null) {
          value = converted;
          unit = primaryEnergyUnit;
        }
      }
    }

    return fmt.valueLatex(value, unit: unit, sigFigs: sigFigs);
  }

  static String _safeSymbol(String key, LatexSymbolMap latexMap) {
    final latex = _latexLabel(key, latexMap);
    if (latex.isNotEmpty && latex != key) return latex;
    final escaped = key.replaceAll('_', r'\_');
    return r'\mathrm{' + escaped + '}';
  }

  static String _latexLabel(String key, LatexSymbolMap latexMap) {
    final fromMap = latexMap.renderSymbol(key, warnOnFallback: true);
    if (fromMap.isNotEmpty && fromMap != key) return fromMap;
    final escaped = key.replaceAll('_', r'\_');
    return r'\mathrm{' + escaped + '}';
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
    final converted = converter.convertDensity(
      value.value,
      baseUnit,
      displayUnit,
      symbol: key,
      reason: 'preferred density unit',
    );
    if (converted == null) return null;
    final convertedFmt = formatter.formatLatexWithUnit(converted, displayUnit);
    final baseFmt = formatter.formatLatexWithUnit(value.value, baseUnit);
    return '${_safeSymbol(key, latexMap)} = $convertedFmt = $baseFmt';
  }

  static _EnergyConversion? _maybeEnergyConversion(
    SymbolValue? symbol,
    UnitConverter? converter, {
    required String label,
    required NumberFormatter formatter,
    required String symbolKey,
    String? preferredUnit,
  }) {
    if (symbol == null) return null;

    String baseUnit = preferredUnit?.isNotEmpty == true ? preferredUnit! : (symbol.unit.isNotEmpty ? symbol.unit : '');
    double baseValue = symbol.value;
    String? line;

    // If preferredUnit is provided and differs, attempt conversion.
    if (preferredUnit != null &&
        preferredUnit.isNotEmpty &&
        symbol.unit.isNotEmpty &&
        symbol.unit != preferredUnit &&
        converter != null) {
      final converted = converter.convertEnergy(
        symbol.value,
        symbol.unit,
        preferredUnit,
        symbol: symbolKey,
        reason: 'preferred energy unit',
      );
      if (converted != null) {
        baseValue = converted;
        baseUnit = preferredUnit;
        final fromStr = formatter.formatLatexWithUnit(symbol.value, symbol.unit);
        final toStr = formatter.formatLatexWithUnit(converted, preferredUnit);
        line = '$label = $fromStr = $toStr';
      }
    } else if (symbol.unit == 'eV' && converter != null) {
      // Legacy path: always provide J equivalent.
      final j = converter.convertEnergy(
        symbol.value,
        'eV',
        'J',
        symbol: symbolKey,
        reason: 'canonical energy unit',
      );
      if (j != null) {
        baseValue = preferredUnit == 'eV' ? symbol.value : j;
        baseUnit = preferredUnit == 'eV' ? 'eV' : 'J';
        final jStr = formatter.formatLatexWithUnit(j, 'J');
        final evStr = formatter.formatLatexWithUnit(symbol.value, 'eV');
        line = '$label = $evStr = $jStr';
      }
    }

    final baseStr = baseUnit.isNotEmpty
        ? formatter.formatLatexWithUnit(baseValue, baseUnit)
        : formatter.formatLatex(baseValue);

    return _EnergyConversion(
      baseValue: baseValue,
      baseUnit: baseUnit,
      baseStr: baseStr,
      line: line,
      converted: SymbolValue(value: baseValue, unit: baseUnit, source: symbol.source),
    );
  }

  static _EnergyConversion? _maybeBoltzmannConversion({
    required SymbolValue? kSymbol,
    required UnitConverter? converter,
    required NumberFormatter formatter,
    required String energyUnit,
  }) {
    if (kSymbol == null) return null;
    final targetUnit = '$energyUnit/K';

    // If already in target, no conversion line.
    if (kSymbol.unit == targetUnit || energyUnit.isEmpty) {
      return _EnergyConversion(
        baseValue: kSymbol.value,
        baseUnit: kSymbol.unit,
        baseStr: formatter.formatLatexWithUnit(kSymbol.value, kSymbol.unit.isNotEmpty ? kSymbol.unit : targetUnit),
        converted: kSymbol,
      );
    }

    if (converter == null) {
      return _EnergyConversion(
        baseValue: kSymbol.value,
        baseUnit: kSymbol.unit,
        baseStr: formatter.formatLatexWithUnit(kSymbol.value, kSymbol.unit.isNotEmpty ? kSymbol.unit : targetUnit),
        converted: kSymbol,
      );
    }

    // Convert energy part of k using energy conversion.
    final fromEnergyUnit = kSymbol.unit.replaceAll('/K', '').replaceAll('K^-1', '').replaceAll(' per K', '').replaceAll(' ', '');
    final converted = converter.convertEnergy(
      kSymbol.value,
      fromEnergyUnit.isNotEmpty ? fromEnergyUnit : 'J',
      energyUnit,
      symbol: 'k',
      reason: 'preferred energy unit for k',
    );
    if (converted == null) {
      return _EnergyConversion(
        baseValue: kSymbol.value,
        baseUnit: kSymbol.unit,
        baseStr: formatter.formatLatexWithUnit(kSymbol.value, kSymbol.unit.isNotEmpty ? kSymbol.unit : targetUnit),
        converted: kSymbol,
      );
    }

    final fromStr = formatter.formatLatexWithUnit(kSymbol.value, kSymbol.unit.isNotEmpty ? kSymbol.unit : 'J/K');
    final toStr = formatter.formatLatexWithUnit(converted, targetUnit);
    return _EnergyConversion(
      baseValue: converted,
      baseUnit: targetUnit,
      baseStr: toStr,
      line: 'k = $fromStr = $toStr',
      converted: SymbolValue(value: converted, unit: targetUnit, source: kSymbol.source),
    );
  }

  static _DensityConversion? _maybeConvertDensity(
    SymbolValue? symbol,
    UnitConverter? converter, {
    required String targetUnit,
    required NumberFormatter formatter,
    String symbolKey = '__unspecified__',
  }) {
    if (symbol == null || converter == null) return null;
    if (symbol.unit == targetUnit) return null;
    final converted = converter.convertDensity(
      symbol.value,
      symbol.unit,
      targetUnit,
      symbol: symbolKey,
      reason: 'canonical density unit',
    );
    if (converted == null) return null;
    final fromStr = formatter.formatLatexWithUnit(symbol.value, symbol.unit);
    final toStr = formatter.formatLatexWithUnit(converted, targetUnit);
    return _DensityConversion(
      baseValue: converted,
      baseUnit: targetUnit,
      line: '$fromStr = $toStr',
      converted: SymbolValue(value: converted, unit: targetUnit, source: symbol.source),
    );
  }
}

class _EnergyConversion {
  final double baseValue;
  final String baseUnit;
  final String baseStr;
  final String? line;
  final SymbolValue converted;

  _EnergyConversion({
    required this.baseValue,
    required this.baseUnit,
    required this.baseStr,
    required this.converted,
    this.line,
  });
}

class _DensityConversion {
  final double baseValue;
  final String baseUnit;
  final String? line;
  final SymbolValue converted;

  _DensityConversion({
    required this.baseValue,
    required this.baseUnit,
    required this.converted,
    this.line,
  });
}
