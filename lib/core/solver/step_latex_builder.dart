import 'dart:math' as math;
import 'package:equatable/equatable.dart';

import '../constants/latex_symbols.dart';
import '../formulas/formula_definition.dart';
import '../models/workspace.dart';
import 'number_formatter.dart';
import 'step_items.dart';
import 'symbol_context.dart';
import 'unit_converter.dart';
import 'steps/energy_band/energy_band_steps.dart';
import 'steps/dos_stats/dos_stats_steps.dart';
import 'steps/carrier_eq_steps.dart';
import 'steps/universal_step_template.dart';
import 'substitution_equation_builder.dart';

export 'step_items.dart';

List<String> _splitAlignedWorkingLines(String alignedWorking) {
  var body = alignedWorking;

  if (body.contains(r'\begin{aligned}')) {
    body = body
        .replaceAll(r'\begin{aligned}', '')
        .replaceAll(r'\end{aligned}', '');
  }

  final newlineSplit = body.split('\n');
  final allLines = <String>[];

  for (final newlinePart in newlineSplit) {
    final latexSplit = newlinePart.split(r'\\');
    for (final line in latexSplit) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (RegExp(r'^\[[^\]]+em\]$').hasMatch(trimmed)) continue;
      allLines.add(trimmed);
    }
  }

  return allLines;
}

bool _looksLikeProse(String value) {
  final pattern = RegExp(
    r'\b(Given|Constants|Formula|Rounded|Step|Result|Convert|Working|Computed|Full[-–—]?precision)\b',
    caseSensitive: false,
  );
  return pattern.hasMatch(value);
}

String _normalizeMathLine(String line) {
  var normalized = line;
  normalized = normalized.replaceAll(r'\quad', ' ');
  normalized = normalized.replaceAll(RegExp(r'\[[^\]]+em\]'), ' ');
  normalized = normalized.replaceAll('&', '');
  normalized = normalized.replaceAll(RegExp(r'\\mathrm\(([^)]+)\)'), r'\\mathrm{$1}');
  normalized = normalized.replaceAll('J*s', r'J\cdot s');
  normalized = normalized.replaceAll('J\\cdot  s', r'J\cdot s');
  normalized = normalized.replaceAll('m^-3', r'm^{-3}');
  normalized = normalized.replaceAll('cm^-3', r'cm^{-3}');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized;
}

List<StepItem> _parseWorkingLine(String raw) {
  var line = raw.trim();
  if (line.isEmpty) return const [];

  final textSegments = <String>[];

  line = line.replaceAllMapped(
    RegExp(r'\\textbf\{([^}]*)\}'),
    (match) {
      final content = match.group(1)?.trim() ?? '';
      if (content.isNotEmpty) textSegments.add(content);
      return '';
    },
  );

  line = line.replaceAllMapped(
    RegExp(r'\\text\{([^}]*)\}'),
    (match) {
      final content = match.group(1)?.trim() ?? '';
      if (content.isNotEmpty) {
        textSegments.add(content);
      }
      return '';
    },
  );

  final labelMatch = RegExp(
    r'^(Step\s*\d+[^:]*:|Given:|Constants:|Formula:|Rounded to 3 s\.f\.?:|Rounded:?|Result:|Convert:)\s*(.*)$',
    caseSensitive: false,
  ).firstMatch(line);
  if (labelMatch != null) {
    final label = labelMatch.group(1)?.trim() ?? '';
    final rest = labelMatch.group(2)?.trim() ?? '';
    if (label.isNotEmpty) {
      textSegments.add(label);
    }
    line = rest;
  }

  line = _normalizeMathLine(line);

  final items = <StepItem>[];
  if (textSegments.isNotEmpty) {
    final combined = textSegments.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (combined.isNotEmpty) {
      items.add(StepItem.text(combined));
    }
  }

  if (line.isEmpty) {
    return items;
  }

  if (_looksLikeProse(line)) {
    items.add(StepItem.text(line));
    return items;
  }

  items.add(StepItem.math(line));
  return items;
}

List<StepItem> parseAlignedWorking(String alignedWorking) {
  final rawLines = _splitAlignedWorkingLines(alignedWorking);
  final items = <StepItem>[];
  for (final raw in rawLines) {
    items.addAll(_parseWorkingLine(raw));
  }
  return items;
}

/// LaTeX representation of a solving step.
class StepLatex extends Equatable {
  final String formulaLatex;
  final String substitutionLatex;
  final String resultLatex;
  final String? alignedWorking; // Full aligned LaTeX block for step-by-step (deprecated - use workingItems)
  final List<StepItem> _workingItems;

  /// Typed working items (text vs math) for Step 4.
  List<StepItem> get workingItems {
    if (_workingItems.isNotEmpty) {
      return _workingItems;
    }
    if (alignedWorking == null || alignedWorking!.isEmpty) {
      return const [];
    }
    return parseAlignedWorking(alignedWorking!);
  }

  List<String> get workingLines {
    return workingItems
        .where((item) => item.type == StepItemType.math)
        .map((item) => item.latex)
        .toList();
  }

  const StepLatex({
    required this.formulaLatex,
    required this.substitutionLatex,
    required this.resultLatex,
    this.alignedWorking,
    List<StepItem>? workingItems,
  }) : _workingItems = workingItems ?? const [];

  @override
  List<Object?> get props => [formulaLatex, substitutionLatex, resultLatex, alignedWorking, _workingItems];
}

/// Builder for generating LaTeX steps with substitutions.
class StepLaTeXBuilder {
  final LatexSymbolMap _latexMap;
  final NumberFormatter _formatter;

  const StepLaTeXBuilder({
    required LatexSymbolMap latexMap,
    NumberFormatter? formatter,
  })  : _latexMap = latexMap,
        _formatter = formatter ?? const NumberFormatter();

  /// Build step LaTeX for a formula solution.
  StepLatex build(
    FormulaDefinition formula,
    String solveFor,
    SymbolContext context,
    Map<String, SymbolValue> outputs, {
    bool showUnitsInSubstitution = false,
    UnitConversionLog? conversions,
  }) {
    final formulaLatex = formula.equationLatex;
    final substitutionLatex = _buildSubstitutionLatex(
      formula.equationLatex,
      context,
      showUnitsInSubstitution,
    );

    final resultValue = outputs[solveFor];
    final resultLatex = resultValue != null ? _buildResultLatex(solveFor, resultValue) : '';

    final conversionLines = _conversionLines(conversions);

    final universalSteps = _buildUniversalSteps(
      formula: formula,
      solveFor: solveFor,
      context: context,
      outputs: outputs,
      conversionLines: conversionLines,
    );

    return StepLatex(
      formulaLatex: formulaLatex,
      substitutionLatex: substitutionLatex,
      resultLatex: resultLatex,
      workingItems: universalSteps,
    );
  }

  /// Route category-specific step builders before falling back to legacy templates.
  List<StepItem>? tryBuildModuleSteps(
    FormulaDefinition formula,
    String solveFor,
    SymbolContext context,
    Map<String, SymbolValue> outputs,
    UnitConverter? unitConverter, {
    UnitConversionLog? conversions,
    String primaryEnergyUnit = 'J',
  }) {
    final conversionLines = _conversionLines(conversions);
    final pnSteps = _buildPnBuiltInPotentialSteps(
      formula: formula,
      solveFor: solveFor,
      context: context,
      outputs: outputs,
    );
    if (pnSteps != null) return _applyConversionLinesToWorkingItems(pnSteps, conversionLines);

    final ctFundamental = _buildCtFundamentalSteps(
      formula: formula,
      solveFor: solveFor,
      context: context,
      outputs: outputs,
      conversionLines: conversionLines,
    );
    if (ctFundamental != null) return ctFundamental;

    final energySteps = EnergyBandSteps.tryBuildSteps(
      formula: formula,
      solveFor: solveFor,
      context: context,
      outputs: outputs,
      latexMap: _latexMap,
      formatter: _formatter,
      unitConverter: unitConverter,
      conversions: conversions,
      primaryEnergyUnit: primaryEnergyUnit,
    );
    if (energySteps != null) return _applyConversionLinesToWorkingItems(energySteps, conversionLines);

    final dosSteps = DosStatsSteps.tryBuildSteps(
      formula: formula,
      solveFor: solveFor,
      context: context,
      outputs: outputs,
      latexMap: _latexMap,
      formatter: _formatter,
      unitConverter: unitConverter,
      conversions: conversions,
      primaryEnergyUnit: primaryEnergyUnit,
    );
    if (dosSteps != null) return _applyConversionLinesToWorkingItems(dosSteps, conversionLines);

    final carrierSteps = CarrierEqSteps.tryBuildSteps(
      formula: formula,
      solveFor: solveFor,
      context: context,
      outputs: outputs,
      latexMap: _latexMap,
      formatter: _formatter,
      unitConverter: unitConverter,
      conversions: conversions,
      primaryEnergyUnit: primaryEnergyUnit,
    );
    if (carrierSteps != null) return _applyConversionLinesToWorkingItems(carrierSteps, conversionLines);
    return null;
  }

  String _buildSubstitutionLatex(
    String equationLatex,
    SymbolContext context,
    bool showUnits,
  ) {
    final substitutionMap = <String, String>{};
    for (final entry in context.getAll().entries) {
      final key = entry.key;
      final value = entry.value;
      final useUnit = showUnits && value.unit.isNotEmpty;
      final formatted = useUnit
          ? _formatter.formatLatexWithUnit(value.value, value.unit)
          : _formatter.formatLatex(value.value);
      substitutionMap[key] = formatted;
    }

    return buildSubstitutionEquation(
      equationLatex: equationLatex,
      latexMap: _latexMap,
      substitutionMap: substitutionMap,
      wrapValuesWithParens: showUnits,
      debugLabel: 'global-substitution',
    );
  }
  
  /// Build aligned LaTeX block for step-by-step working (formula-specific templates).
  String buildAlignedWorking(
    FormulaDefinition formula,
    String solveFor,
    SymbolContext context,
    Map<String, SymbolValue> outputs,
    UnitConverter? unitConverter, {
    String primaryEnergyUnit = 'J', // 'J' or 'eV'
  }) {
    // This builds a safe aligned LaTeX block without regex backreferences
    
    // Build formatted values with units
    // IMPORTANT: choose template by formulaId first.
    // Otherwise solveFor == 'm_star' would incorrectly pick the parabolic derivation even when
    // the active formula is "effective_mass_from_curvature".

    // Density of States & Statistics templates
    if (formula.id == 'dos_Nc_effective_density_conduction' && solveFor == 'N_c') {
      final kB = context.getValue('k');
      final h = context.getValue('h');
      final mn = context.getValue('m_n_star');
      final t = context.getValue('T');
      final ncSI = outputs['N_c']?.value;

      final densityUnit = context.getUnit('__meta__density_unit');
      final showCm = densityUnit == 'cm^-3';
      
      // Format given values
      final mnFmt = mn != null ? _formatter.formatLatexWithUnit(mn, 'kg') : r'm_n^*';
      final tFmt = t != null ? _formatter.formatLatexWithUnit(t, 'K') : 'T';
      final kBFmt = kB != null ? _formatter.formatLatexWithUnit(kB, 'J/K') : 'k';
      final hFmt = h != null ? _formatter.formatLatexWithUnit(h, 'J*s') : 'h';

      // Step 4: Compute intermediate A
      final a = (mn != null && kB != null && t != null && h != null)
          ? (2 * math.pi * mn * kB * t) / (h * h)
          : null;
      final aFullFmt = a != null ? _formatter.formatLatexFullPrecision(a) : r'\frac{2\pi m_n^* kT}{h^2}';
      
      final aPow = a != null ? math.pow(a, 1.5).toDouble() : null;
      final aPowFmt = aPow != null ? _formatter.formatLatexFullPrecision(aPow) : r'A^{3/2}';
      
      final ncComputed = aPow != null ? 2.0 * aPow : null;
      final ncComputedFmt = ncComputed != null ? _formatter.formatLatexFullPrecision(ncComputed) : r'2A^{3/2}';

      // Step 5 & 6: Full precision + 3 s.f.
      final ncFullSIFmt = ncSI != null ? _formatter.formatLatexWithUnitFullPrecision(ncSI, 'm^{-3}') : 'N_c';
      final ncRoundedSIFmt = ncSI != null ? _formatter.formatLatexWithUnit(ncSI, 'm^{-3}') : 'N_c';
      
      // Convert to cm^-3 if needed
      String ncConversionLine = '';
      String ncRoundedCmFmt = '';
      if (showCm && ncSI != null && unitConverter != null) {
        final ncCm = unitConverter.convertDensity(ncSI, 'm^-3', 'cm^-3');
        if (ncCm != null) {
          final ncSIVal = _formatter.formatLatex(ncSI);
          final ncCmVal = _formatter.formatLatex(ncCm);
          ncConversionLine = 'N_c &= \\frac{' + ncSIVal + r'\,\mathrm{m^{-3}}}{10^6} = ' + ncCmVal + r'\,\mathrm{cm^{-3}} \\';
          ncRoundedCmFmt = _formatter.formatLatexWithUnit(ncCm, 'cm^{-3}');
        }
      }

      final template = r'''
\begin{aligned}
\textbf{Step 1 — Given and formula:} \\
\textbf{Given:}\; m_n^* &= {{MN}},\; T = {{T}} \\
\textbf{Constants:}\; k &= {{K}},\; h = {{H}} \\
\textbf{Formula:}\; N_c &= 2\left(\frac{2\pi m_n^* k T}{h^2}\right)^{3/2} \\[0.5em]
\textbf{Step 2 — Rearrange to solve for } N_c: \\
N_c &= 2\left(\frac{2\pi m_n^* kT}{h^2}\right)^{3/2} \quad \text{(no rearrangement needed)} \\[0.5em]
\textbf{Step 3 — Substitute known values:} \\
N_c &= 2\left(\frac{2\pi ({{MN}})({{K}})({{T}})}{({{H}})^2}\right)^{3/2} \\[0.5em]
\textbf{Step 4 — Compute:} \\
A &= \frac{2\pi ({{MN}})({{K}})({{T}})}{({{H}})^2} = {{A_FULL}} \\
A^{3/2} &= ({{A_FULL}})^{3/2} = {{A_POW}} \\
N_c &= 2 \times {{A_POW}} = {{NC_COMPUTED}} \\[0.5em]
\textbf{Step 5 — Computed value:} \\
N_c &= {{NC_FULL_SI}} \\
{{NC_CONVERSION_LINE}}
\textbf{Rounded to 3 s.f.:} \\
N_c &\approx {{NC_ROUNDED}}
\end{aligned}
''';

      final finalResult = showCm && !ncRoundedCmFmt.isEmpty 
          ? ncRoundedCmFmt 
          : ncRoundedSIFmt;

      return template
          .replaceAll('{{MN}}', mnFmt)
          .replaceAll('{{T}}', tFmt)
          .replaceAll('{{K}}', kBFmt)
          .replaceAll('{{H}}', hFmt)
          .replaceAll('{{A_FULL}}', aFullFmt)
          .replaceAll('{{A_POW}}', aPowFmt)
          .replaceAll('{{NC_COMPUTED}}', ncComputedFmt)
          .replaceAll('{{NC_FULL_SI}}', ncFullSIFmt)
          .replaceAll('{{NC_CONVERSION_LINE}}', ncConversionLine)
          .replaceAll('{{NC_ROUNDED}}', finalResult);
    }

    if (formula.id == 'dos_Nc_effective_density_conduction' && solveFor == 'm_n_star') {
      final kB = context.getValue('k');
      final h = context.getValue('h');
      final t = context.getValue('T');
      final ncSI = context.getValue('N_c'); // Always in SI m^-3 internally
      final mn = outputs['m_n_star']?.value;

      final densityUnit = context.getUnit('__meta__density_unit');
      final showCm = densityUnit == 'cm^-3';
      
      // Format given values
      final tFmt = t != null ? _formatter.formatLatexWithUnit(t, 'K') : 'T';
      final kBFmt = kB != null ? _formatter.formatLatexWithUnit(kB, 'J/K') : 'k';
      final hFmt = h != null ? _formatter.formatLatexWithUnit(h, 'J*s') : 'h';
      
      // Step 1: Given values (show in user's input unit if cm^-3)
      String ncGivenFmt = '';
      if (showCm && ncSI != null && unitConverter != null) {
        final ncCm = unitConverter.convertDensity(ncSI, 'm^-3', 'cm^-3');
        if (ncCm != null) {
          ncGivenFmt = _formatter.formatLatexWithUnit(ncCm, 'cm^{-3}');
        }
      }
      if (ncGivenFmt.isEmpty && ncSI != null) {
        ncGivenFmt = _formatter.formatLatexWithUnit(ncSI, 'm^{-3}');
      }

      // Step 3: Unit conversion + substitution
      String ncConversionLine = '';
      String ncSIFmt = '';
      if (showCm && ncSI != null && unitConverter != null) {
        final ncCm = unitConverter.convertDensity(ncSI, 'm^-3', 'cm^-3');
        if (ncCm != null) {
          final ncCmFmt = _formatter.formatLatexWithUnit(ncCm, 'cm^{-3}');
          ncSIFmt = _formatter.formatLatexWithUnit(ncSI, 'm^{-3}');
          ncConversionLine = r'\textbf{Convert:}\; 1\,\mathrm{cm^{-3}} = 10^6\,\mathrm{m^{-3}} \\' + '\n' +
              'N_c &= ' + ncCmFmt + ' = ' + ncCmFmt.replaceAll(r'\,\mathrm{cm^{-3}}', r'\times 10^6\,\mathrm{m^{-3}}') + ' = ' + ncSIFmt + r' \\';
        }
      } else if (ncSI != null) {
        ncSIFmt = _formatter.formatLatexWithUnit(ncSI, 'm^{-3}');
      }

      // Step 4: Compute intermediate values (use numeric expressions only)
      final ncOver2 = ncSI != null ? ncSI / 2.0 : null;
      final ncOver2Fmt = ncOver2 != null ? _formatter.formatLatexFullPrecision(ncOver2) : r'\frac{N_c}{2}';
      
      final ncOver2Pow = ncOver2 != null ? math.pow(ncOver2, 2.0 / 3.0).toDouble() : null;
      final ncOver2PowFmt = ncOver2Pow != null ? _formatter.formatLatexFullPrecision(ncOver2Pow) : r'\left(\frac{N_c}{2}\right)^{2/3}';

      final prefactor = (h != null && kB != null && t != null)
          ? ((h * h) / (2 * math.pi * kB * t))
          : null;
      final prefactorFmt = prefactor != null
          ? _formatter.formatLatexFullPrecision(prefactor)
          : r'\frac{h^2}{2\pi kT}';

      // Step 5 & 6: Full precision + 3 s.f.
      final mnFullFmt = mn != null ? _formatter.formatLatexWithUnitFullPrecision(mn, 'kg') : r'm_n^*';
      final mnRoundedFmt = mn != null ? _formatter.formatLatexWithUnit(mn, 'kg') : r'm_n^*';

      final template = r'''
\begin{aligned}
\textbf{Step 1 — Given and formula:} \\
\textbf{Given:}\; N_c &= {{NC_GIVEN}},\; T = {{T}} \\
\textbf{Constants:}\; k &= {{K}},\; h = {{H}} \\
\textbf{Formula:}\; N_c &= 2\left(\frac{2\pi m_n^* k T}{h^2}\right)^{3/2} \\[0.5em]
\textbf{Step 2 — Rearrange to solve for } m_n^*: \\
\frac{N_c}{2} &= \left(\frac{2\pi m_n^* kT}{h^2}\right)^{3/2} \\
\left(\frac{N_c}{2}\right)^{2/3} &= \frac{2\pi m_n^* kT}{h^2} \\
m_n^* &= \frac{h^2}{2\pi kT}\left(\frac{N_c}{2}\right)^{2/3} \\[0.5em]
\textbf{Step 3 — Unit conversion and substitution:} \\
{{NC_CONVERSION_LINE}}
m_n^* &= \frac{({{H}})^2}{2\pi({{K}})({{T}})}\left(\frac{{{NC_SI}}}{2}\right)^{2/3} \\[0.5em]
\textbf{Step 4 — Compute:} \\
\frac{{{NC_SI}}}{2} &= {{NC_OVER_2}} \\
({{NC_OVER_2}})^{2/3} &= {{NC_POW}} \\
\frac{({{H}})^2}{2\pi({{K}})({{T}})} &= {{PREFACTOR}}\,\mathrm{kg} \\[0.5em]
\textbf{Step 5 — Full-precision answer:} \\
m_n^* &= ({{PREFACTOR}})({{NC_POW}}) = {{MN_FULL}} \\[0.5em]
\textbf{Step 6 — Rounded to 3 s.f.:} \\
m_n^* &\approx {{MN_ROUNDED}}
\end{aligned}
''';

      return template
          .replaceAll('{{NC_GIVEN}}', ncGivenFmt.isNotEmpty ? ncGivenFmt : (ncSIFmt.isNotEmpty ? ncSIFmt : 'N_c'))
          .replaceAll('{{T}}', tFmt)
          .replaceAll('{{K}}', kBFmt)
          .replaceAll('{{H}}', hFmt)
          .replaceAll('{{NC_CONVERSION_LINE}}', ncConversionLine)
          .replaceAll('{{NC_SI}}', ncSIFmt.isNotEmpty ? ncSIFmt : 'N_c')
          .replaceAll('{{NC_OVER_2}}', ncOver2Fmt)
          .replaceAll('{{NC_POW}}', ncOver2PowFmt)
          .replaceAll('{{PREFACTOR}}', prefactorFmt)
          .replaceAll('{{MN_FULL}}', mnFullFmt)
          .replaceAll('{{MN_ROUNDED}}', mnRoundedFmt);
    }

    if (formula.id == 'dos_Nc_effective_density_conduction' && solveFor == 'm_n_star') {
      final kB = context.getValue('k');
      final h = context.getValue('h');
      final t = context.getValue('T');
      final ncSI = context.getValue('N_c'); // Always in SI m^-3 internally
      final mn = outputs['m_n_star']?.value;

      final densityUnit = context.getUnit('__meta__density_unit');
      final showCm = densityUnit == 'cm^-3';
      
      // Format given values
      final tFmt = t != null ? _formatter.formatLatexWithUnit(t, 'K') : 'T';
      final kBFmt = kB != null ? _formatter.formatLatexWithUnit(kB, 'J/K') : 'k';
      final hFmt = h != null ? _formatter.formatLatexWithUnit(h, 'J*s') : 'h';
      
      // Step 1: Given values (show in user's input unit if cm^-3)
      String ncGivenFmt = '';
      if (showCm && ncSI != null && unitConverter != null) {
        final ncCm = unitConverter.convertDensity(ncSI, 'm^-3', 'cm^-3');
        if (ncCm != null) {
          ncGivenFmt = _formatter.formatLatexWithUnit(ncCm, 'cm^{-3}');
        }
      }
      if (ncGivenFmt.isEmpty && ncSI != null) {
        ncGivenFmt = _formatter.formatLatexWithUnit(ncSI, 'm^{-3}');
      }

      // Step 3: Unit conversion + substitution
      String ncConversionLine = '';
      String ncSIFmt = '';
      if (showCm && ncSI != null && unitConverter != null) {
        final ncCm = unitConverter.convertDensity(ncSI, 'm^-3', 'cm^-3');
        if (ncCm != null) {
          final ncCmVal = _formatter.formatLatex(ncCm);
          ncSIFmt = _formatter.formatLatex(ncSI);
          ncConversionLine = r'\textbf{Convert:}\; 1\,\mathrm{cm^{-3}} = 10^6\,\mathrm{m^{-3}} \\' + '\n' +
              'N_c &= ' + ncCmVal + r'\,\mathrm{cm^{-3}} = ' + ncCmVal + r' \times 10^6\,\mathrm{m^{-3}} = ' + ncSIFmt + r'\,\mathrm{m^{-3}} \\';
        }
      } else if (ncSI != null) {
        ncSIFmt = _formatter.formatLatex(ncSI);
      }

      // Step 4: Compute intermediate values (use numeric expressions only)
      final ncOver2 = ncSI != null ? ncSI / 2.0 : null;
      final ncOver2Fmt = ncOver2 != null ? _formatter.formatLatexFullPrecision(ncOver2) : r'\frac{N_c}{2}';
      
      final ncOver2Pow = ncOver2 != null ? math.pow(ncOver2, 2.0 / 3.0).toDouble() : null;
      final ncOver2PowFmt = ncOver2Pow != null ? _formatter.formatLatexFullPrecision(ncOver2Pow) : r'\left(\frac{N_c}{2}\right)^{2/3}';

      final prefactor = (h != null && kB != null && t != null)
          ? ((h * h) / (2 * math.pi * kB * t))
          : null;
      final prefactorFmt = prefactor != null
          ? _formatter.formatLatexFullPrecision(prefactor)
          : r'\frac{h^2}{2\pi kT}';

      // Step 5 & 6: Full precision + 3 s.f.
      final mnFullFmt = mn != null ? _formatter.formatLatexWithUnitFullPrecision(mn, 'kg') : r'm_n^*';
      final mnRoundedFmt = mn != null ? _formatter.formatLatexWithUnit(mn, 'kg') : r'm_n^*';

      final template = r'''
\begin{aligned}
\textbf{Step 1 — Given and formula:} \\
\textbf{Given:}\; N_c &= {{NC_GIVEN}},\; T = {{T}} \\
\textbf{Constants:}\; k &= {{K}},\; h = {{H}} \\
\textbf{Formula:}\; N_c &= 2\left(\frac{2\pi m_n^* k T}{h^2}\right)^{3/2} \\[0.5em]
\textbf{Step 2 — Rearrange to solve for } m_n^*: \\
\frac{N_c}{2} &= \left(\frac{2\pi m_n^* kT}{h^2}\right)^{3/2} \\
\left(\frac{N_c}{2}\right)^{2/3} &= \frac{2\pi m_n^* kT}{h^2} \\
m_n^* &= \frac{h^2}{2\pi kT}\left(\frac{N_c}{2}\right)^{2/3} \\[0.5em]
\textbf{Step 3 — Unit conversion and substitution:} \\
{{NC_CONVERSION_LINE}}
m_n^* &= \frac{({{H}})^2}{2\pi({{K}})({{T}})}\left(\frac{{{NC_SI}}}{2}\right)^{2/3} \\[0.5em]
\textbf{Step 4 — Compute:} \\
\frac{{{NC_SI}}}{2} &= {{NC_OVER_2}} \\
({{NC_OVER_2}})^{2/3} &= {{NC_POW}} \\
\frac{({{H}})^2}{2\pi({{K}})({{T}})} &= {{PREFACTOR}}\,\mathrm{kg} \\[0.5em]
\textbf{Step 5 — Full-precision answer:} \\
m_n^* &= ({{PREFACTOR}})({{NC_POW}}) = {{MN_FULL}} \\[0.5em]
\textbf{Step 6 — Rounded to 3 s.f.:} \\
m_n^* &\approx {{MN_ROUNDED}}
\end{aligned}
''';

      return template
          .replaceAll('{{NC_GIVEN}}', ncGivenFmt.isNotEmpty ? ncGivenFmt : (ncSIFmt.isNotEmpty ? ncSIFmt : 'N_c'))
          .replaceAll('{{T}}', tFmt)
          .replaceAll('{{K}}', kBFmt)
          .replaceAll('{{H}}', hFmt)
          .replaceAll('{{NC_CONVERSION_LINE}}', ncConversionLine)
          .replaceAll('{{NC_SI}}', ncSIFmt.isNotEmpty ? ncSIFmt : 'N_c')
          .replaceAll('{{NC_OVER_2}}', ncOver2Fmt)
          .replaceAll('{{NC_POW}}', ncOver2PowFmt)
          .replaceAll('{{PREFACTOR}}', prefactorFmt)
          .replaceAll('{{MN_FULL}}', mnFullFmt)
          .replaceAll('{{MN_ROUNDED}}', mnRoundedFmt);
    }

    if (formula.id == 'dos_Nv_effective_density_valence' && solveFor == 'm_p_star') {
      final kB = context.getValue('k');
      final h = context.getValue('h');
      final t = context.getValue('T');
      final nvSI = context.getValue('N_v'); // Always in SI m^-3 internally
      final mp = outputs['m_p_star']?.value;

      final densityUnit = context.getUnit('__meta__density_unit');
      final showCm = densityUnit == 'cm^-3';
      
      // Format given values
      final tFmt = t != null ? _formatter.formatLatexWithUnit(t, 'K') : 'T';
      final kBFmt = kB != null ? _formatter.formatLatexWithUnit(kB, 'J/K') : 'k';
      final hFmt = h != null ? _formatter.formatLatexWithUnit(h, 'J*s') : 'h';
      
      // Step 1: Given values (show in user's input unit if cm^-3)
      String nvGivenFmt = '';
      if (showCm && nvSI != null && unitConverter != null) {
        final nvCm = unitConverter.convertDensity(nvSI, 'm^-3', 'cm^-3');
        if (nvCm != null) {
          nvGivenFmt = _formatter.formatLatexWithUnit(nvCm, 'cm^{-3}');
        }
      }
      if (nvGivenFmt.isEmpty && nvSI != null) {
        nvGivenFmt = _formatter.formatLatexWithUnit(nvSI, 'm^{-3}');
      }

      // Step 3: Unit conversion + substitution
      String nvConversionLine = '';
      String nvSIFmt = '';
      if (showCm && nvSI != null && unitConverter != null) {
        final nvCm = unitConverter.convertDensity(nvSI, 'm^-3', 'cm^-3');
        if (nvCm != null) {
          final nvCmVal = _formatter.formatLatex(nvCm);
          nvSIFmt = _formatter.formatLatex(nvSI);
          nvConversionLine = r'\textbf{Convert:}\; 1\,\mathrm{cm^{-3}} = 10^6\,\mathrm{m^{-3}} \\' + '\n' +
              'N_v &= ' + nvCmVal + r'\,\mathrm{cm^{-3}} = ' + nvCmVal + r' \times 10^6\,\mathrm{m^{-3}} = ' + nvSIFmt + r'\,\mathrm{m^{-3}} \\';
        }
      } else if (nvSI != null) {
        nvSIFmt = _formatter.formatLatex(nvSI);
      }

      // Step 4: Compute intermediate values
      final nvOver2 = nvSI != null ? nvSI / 2.0 : null;
      final nvOver2Fmt = nvOver2 != null ? _formatter.formatLatexFullPrecision(nvOver2) : r'\frac{N_v}{2}';
      
      final nvOver2Pow = nvOver2 != null ? math.pow(nvOver2, 2.0 / 3.0).toDouble() : null;
      final nvOver2PowFmt = nvOver2Pow != null ? _formatter.formatLatexFullPrecision(nvOver2Pow) : r'\left(\frac{N_v}{2}\right)^{2/3}';

      final prefactor = (h != null && kB != null && t != null)
          ? ((h * h) / (2 * math.pi * kB * t))
          : null;
      final prefactorFmt = prefactor != null
          ? _formatter.formatLatexFullPrecision(prefactor)
          : r'\frac{h^2}{2\pi kT}';

      // Step 5 & 6: Full precision + 3 s.f.
      final mpFullFmt = mp != null ? _formatter.formatLatexWithUnitFullPrecision(mp, 'kg') : r'm_p^*';
      final mpRoundedFmt = mp != null ? _formatter.formatLatexWithUnit(mp, 'kg') : r'm_p^*';

      final template = r'''
\begin{aligned}
\textbf{Step 1 — Given and formula:} \\
\textbf{Given:}\; N_v &= {{NV_GIVEN}},\; T = {{T}} \\
\textbf{Constants:}\; k &= {{K}},\; h = {{H}} \\
\textbf{Formula:}\; N_v &= 2\left(\frac{2\pi m_p^* k T}{h^2}\right)^{3/2} \\[0.5em]
\textbf{Step 2 — Rearrange to solve for } m_p^*: \\
\frac{N_v}{2} &= \left(\frac{2\pi m_p^* kT}{h^2}\right)^{3/2} \\
\left(\frac{N_v}{2}\right)^{2/3} &= \frac{2\pi m_p^* kT}{h^2} \\
m_p^* &= \frac{h^2}{2\pi kT}\left(\frac{N_v}{2}\right)^{2/3} \\[0.5em]
\textbf{Step 3 — Unit conversion and substitution:} \\
{{NV_CONVERSION_LINE}}
m_p^* &= \frac{({{H}})^2}{2\pi({{K}})({{T}})}\left(\frac{{{NV_SI}}}{2}\right)^{2/3} \\[0.5em]
\textbf{Step 4 — Compute:} \\
\frac{{{NV_SI}}}{2} &= {{NV_OVER_2}} \\
({{NV_OVER_2}})^{2/3} &= {{NV_POW}} \\
\frac{({{H}})^2}{2\pi({{K}})({{T}})} &= {{PREFACTOR}}\,\mathrm{kg} \\[0.5em]
\textbf{Step 5 — Computed value:} \\
m_p^* &= ({{PREFACTOR}})({{NV_POW}}) = {{MP_FULL}} \\[0.5em]
\textbf{Rounded to 3 s.f.:} \\
m_p^* &\approx {{MP_ROUNDED}}
\end{aligned}
''';

      return template
          .replaceAll('{{NV_GIVEN}}', nvGivenFmt.isNotEmpty ? nvGivenFmt : (nvSIFmt.isNotEmpty ? nvSIFmt : 'N_v'))
          .replaceAll('{{T}}', tFmt)
          .replaceAll('{{K}}', kBFmt)
          .replaceAll('{{H}}', hFmt)
          .replaceAll('{{NV_CONVERSION_LINE}}', nvConversionLine)
          .replaceAll('{{NV_SI}}', nvSIFmt.isNotEmpty ? nvSIFmt : 'N_v')
          .replaceAll('{{NV_OVER_2}}', nvOver2Fmt)
          .replaceAll('{{NV_POW}}', nvOver2PowFmt)
          .replaceAll('{{PREFACTOR}}', prefactorFmt)
          .replaceAll('{{MP_FULL}}', mpFullFmt)
          .replaceAll('{{MP_ROUNDED}}', mpRoundedFmt);
    }

    if (formula.id == 'dos_Nv_effective_density_valence' && solveFor == 'N_v') {
      final kB = context.getValue('k');
      final h = context.getValue('h');
      final mp = context.getValue('m_p_star');
      final t = context.getValue('T');
      final nvSI = outputs['N_v']?.value;

      final densityUnit = context.getUnit('__meta__density_unit');
      final showCm = densityUnit == 'cm^-3';
      
      // Format given values
      final mpFmt = mp != null ? _formatter.formatLatexWithUnit(mp, 'kg') : r'm_p^*';
      final tFmt = t != null ? _formatter.formatLatexWithUnit(t, 'K') : 'T';
      final kBFmt = kB != null ? _formatter.formatLatexWithUnit(kB, 'J/K') : 'k';
      final hFmt = h != null ? _formatter.formatLatexWithUnit(h, 'J*s') : 'h';

      // Step 4: Compute intermediate A
      final a = (mp != null && kB != null && t != null && h != null)
          ? (2 * math.pi * mp * kB * t) / (h * h)
          : null;
      final aFullFmt = a != null ? _formatter.formatLatexFullPrecision(a) : r'\frac{2\pi m_p^* kT}{h^2}';
      
      final aPow = a != null ? math.pow(a, 1.5).toDouble() : null;
      final aPowFmt = aPow != null ? _formatter.formatLatexFullPrecision(aPow) : r'A^{3/2}';
      
      final nvComputed = aPow != null ? 2.0 * aPow : null;
      final nvComputedFmt = nvComputed != null ? _formatter.formatLatexFullPrecision(nvComputed) : r'2A^{3/2}';

      // Step 5 & 6: Full precision + 3 s.f.
      final nvFullSIFmt = nvSI != null ? _formatter.formatLatexWithUnitFullPrecision(nvSI, 'm^{-3}') : 'N_v';
      final nvRoundedSIFmt = nvSI != null ? _formatter.formatLatexWithUnit(nvSI, 'm^{-3}') : 'N_v';
      
      // Convert to cm^-3 if needed
      String nvConversionLine = '';
      String nvRoundedCmFmt = '';
      if (showCm && nvSI != null && unitConverter != null) {
        final nvCm = unitConverter.convertDensity(nvSI, 'm^-3', 'cm^-3');
        if (nvCm != null) {
          final nvSIVal = _formatter.formatLatex(nvSI);
          final nvCmVal = _formatter.formatLatex(nvCm);
          nvConversionLine = 'N_v &= \\frac{' + nvSIVal + r'\,\mathrm{m^{-3}}}{10^6} = ' + nvCmVal + r'\,\mathrm{cm^{-3}} \\';
          nvRoundedCmFmt = _formatter.formatLatexWithUnit(nvCm, 'cm^{-3}');
        }
      }

      final template = r'''
\begin{aligned}
\textbf{Step 1 — Given and formula:} \\
\textbf{Given:}\; m_p^* &= {{MP}},\; T = {{T}} \\
\textbf{Constants:}\; k &= {{K}},\; h = {{H}} \\
\textbf{Formula:}\; N_v &= 2\left(\frac{2\pi m_p^* k T}{h^2}\right)^{3/2} \\[0.5em]
\textbf{Step 2 — Rearrange to solve for } N_v: \\
N_v &= 2\left(\frac{2\pi m_p^* kT}{h^2}\right)^{3/2} \quad \text{(no rearrangement needed)} \\[0.5em]
\textbf{Step 3 — Substitute known values:} \\
N_v &= 2\left(\frac{2\pi ({{MP}})({{K}})({{T}})}{({{H}})^2}\right)^{3/2} \\[0.5em]
\textbf{Step 4 — Compute:} \\
A &= \frac{2\pi ({{MP}})({{K}})({{T}})}{({{H}})^2} = {{A_FULL}} \\
A^{3/2} &= ({{A_FULL}})^{3/2} = {{A_POW}} \\
N_v &= 2 \times {{A_POW}} = {{NV_COMPUTED}} \\[0.5em]
\textbf{Step 5 — Computed value:} \\
N_v &= {{NV_FULL_SI}} \\
{{NV_CONVERSION_LINE}}
\textbf{Rounded to 3 s.f.:} \\
N_v &\approx {{NV_ROUNDED}}
\end{aligned}
''';

      final finalResult = showCm && !nvRoundedCmFmt.isEmpty 
          ? nvRoundedCmFmt 
          : nvRoundedSIFmt;

      return template
          .replaceAll('{{MP}}', mpFmt)
          .replaceAll('{{T}}', tFmt)
          .replaceAll('{{K}}', kBFmt)
          .replaceAll('{{H}}', hFmt)
          .replaceAll('{{A_FULL}}', aFullFmt)
          .replaceAll('{{A_POW}}', aPowFmt)
          .replaceAll('{{NV_COMPUTED}}', nvComputedFmt)
          .replaceAll('{{NV_FULL_SI}}', nvFullSIFmt)
          .replaceAll('{{NV_CONVERSION_LINE}}', nvConversionLine)
          .replaceAll('{{NV_ROUNDED}}', finalResult);
    }

    // Solve for T (temperature) in conduction band DOS formula (Nc)
    if (formula.id == 'dos_Nc_effective_density_conduction' && solveFor == 'T') {
      final kB = context.getValue('k');
      final h = context.getValue('h');
      final mn = context.getValue('m_n_star');
      final ncSI = context.getValue('N_c'); // SI m^-3
      final t = outputs['T']?.value;

      final densityUnit = context.getUnit('__meta__density_unit');
      final showCm = densityUnit == 'cm^-3';

      String ncGivenFmt = '';
      if (showCm && ncSI != null && unitConverter != null) {
        final ncCm = unitConverter.convertDensity(ncSI, 'm^-3', 'cm^-3');
        if (ncCm != null) {
          ncGivenFmt = _formatter.formatLatexWithUnit(ncCm, 'cm^{-3}');
        }
      }
      if (ncGivenFmt.isEmpty && ncSI != null) {
        ncGivenFmt = _formatter.formatLatexWithUnit(ncSI, 'm^{-3}');
      }

      String ncConversionLine = '';
      String ncSIFmt = '';
      if (showCm && ncSI != null) {
        final ncCm = unitConverter?.convertDensity(ncSI, 'm^-3', 'cm^-3');
        if (ncCm != null) {
          ncSIFmt = _formatter.formatLatexFullPrecision(ncSI);
          ncConversionLine = r'N_{c,\mathrm{SI}} = N_c\cdot 10^{6} = ' + ncSIFmt;
        }
      } else if (ncSI != null) {
        ncSIFmt = _formatter.formatLatexFullPrecision(ncSI);
      }

      String tLine = '';
      String tRoundedLine = '';
      if (t != null && mn != null && kB != null && h != null && ncSI != null) {
        final factor = (h * h) / (2 * math.pi * mn * kB);
        final inner = math.pow((ncSI / 2), (2.0 / 3.0));
        final tComputed = factor * inner;
        final tFmt = _formatter.formatLatexFullPrecision(tComputed);
        final tRounded = _formatter.formatLatexWithUnit(t, 'K');
        tLine = r'T = ' + tFmt + r'\,\mathrm{K}';
        tRoundedLine = r'T \approx ' + tRounded;
      }

      final buffer = StringBuffer();
      buffer.writeln(r'N_c = 2\left(\frac{2\pi m_n^* kT}{h^2}\right)^{3/2}');
      buffer.writeln(r'T = \frac{h^2}{2\pi m_n^* k}\left(\frac{N_c}{2}\right)^{2/3}');
      if (ncConversionLine.isNotEmpty) buffer.writeln(ncConversionLine);
      if (ncSIFmt.isNotEmpty) buffer.writeln(r'N_c = ' + ncSIFmt + r'\,\mathrm{m^{-3}}');
      if (ncSI != null) {
        final ncHalf = _formatter.formatLatexFullPrecision(ncSI / 2.0);
        buffer.writeln(r'\frac{N_c}{2} = ' + ncHalf);
        final powVal = math.pow(ncSI / 2.0, 2.0 / 3.0).toDouble();
        buffer.writeln(
          r'\left(\frac{N_c}{2}\right)^{2/3} = ' + _formatter.formatLatexFullPrecision(powVal),
        );
      }
      if (mn != null && kB != null && h != null) {
        final pref = (h * h) / (2 * math.pi * mn * kB);
        buffer.writeln(r'\frac{h^2}{2\pi m_n^* k} = ' + _formatter.formatLatexFullPrecision(pref));
      }
      if (tLine.isNotEmpty) buffer.writeln(tLine);
      if (tRoundedLine.isNotEmpty) buffer.writeln(tRoundedLine);

      return buffer.toString();
    }

    // Solve for T (temperature) in valence band DOS formula (Nv)
    if (formula.id == 'dos_Nv_effective_density_valence' && solveFor == 'T') {
      final kB = context.getValue('k');
      final h = context.getValue('h');
      final mp = context.getValue('m_p_star');
      final nvSI = context.getValue('N_v'); // SI m^-3
      final t = outputs['T']?.value;

      final densityUnit = context.getUnit('__meta__density_unit');
      final showCm = densityUnit == 'cm^-3';
      
      String nvGivenFmt = '';
      if (showCm && nvSI != null && unitConverter != null) {
        final nvCm = unitConverter.convertDensity(nvSI, 'm^-3', 'cm^-3');
        if (nvCm != null) {
          nvGivenFmt = _formatter.formatLatexWithUnit(nvCm, 'cm^{-3}');
        }
      }
      if (nvGivenFmt.isEmpty && nvSI != null) {
        nvGivenFmt = _formatter.formatLatexWithUnit(nvSI, 'm^{-3}');
      }

      String nvConversionLine = '';
      String nvSIFmt = '';
      if (showCm && nvSI != null) {
        final nvCm = unitConverter?.convertDensity(nvSI, 'm^-3', 'cm^-3');
        if (nvCm != null) {
          nvSIFmt = _formatter.formatLatexFullPrecision(nvSI);
          nvConversionLine = r'N_{v,\mathrm{SI}} = N_v\cdot 10^{6} = ' + nvSIFmt;
        }
      } else if (nvSI != null) {
        nvSIFmt = _formatter.formatLatexFullPrecision(nvSI);
      }

      final prefactor = (h != null && mp != null && kB != null)
          ? (h * h) / (2 * math.pi * mp * kB)
          : null;
      final prefactorFmt = prefactor != null ? _formatter.formatLatexFullPrecision(prefactor) : r'\frac{h^2}{2\pi m_p^* k}';
      
      final tFullFmt = t != null ? _formatter.formatLatexWithUnitFullPrecision(t, 'K') : 'T';
      final tRoundedFmt = t != null ? _formatter.formatLatexWithUnit(t, 'K') : 'T';

      final buffer = StringBuffer();
      buffer.writeln(r'N_v = 2\left(\frac{2\pi m_p^* kT}{h^2}\right)^{3/2}');
      buffer.writeln(r'T = \frac{h^2}{2\pi m_p^* k}\left(\frac{N_v}{2}\right)^{2/3}');
      if (nvConversionLine.isNotEmpty) buffer.writeln(nvConversionLine);
      if (nvSIFmt.isNotEmpty) buffer.writeln(r'N_v = ' + nvSIFmt + r'\,\mathrm{m^{-3}}');
      if (nvSI != null) {
        final nvHalf = _formatter.formatLatexFullPrecision(nvSI / 2.0);
        buffer.writeln(r'\frac{N_v}{2} = ' + nvHalf);
        final powVal = math.pow(nvSI / 2.0, 2.0 / 3.0).toDouble();
        buffer.writeln(
          r'\left(\frac{N_v}{2}\right)^{2/3} = ' + _formatter.formatLatexFullPrecision(powVal),
        );
      }
      if (prefactorFmt.isNotEmpty) {
        buffer.writeln(r'\frac{h^2}{2\pi m_p^* k} = ' + prefactorFmt);
      }
      buffer.writeln(r'T = ' + tFullFmt);
      if (tRoundedFmt.isNotEmpty) buffer.writeln(r'T \approx ' + tRoundedFmt);

      return buffer.toString();
    }

    if (formula.id == 'dos_fermi_dirac_probability' && solveFor == 'f_E') {
      final kB = context.getValue('k');
      final t = context.getValue('T');
      final eJLocal = context.getValue('E');
      final efJLocal = context.getValue('E_F');
      final qLocal = context.getValue('q');
      final f = outputs['f_E']?.value;

      final eUnit = context.getUnit('__meta__unit_E') ?? primaryEnergyUnit;
      final efUnit = context.getUnit('__meta__unit_E_F') ?? primaryEnergyUnit;

      final eShown = (eJLocal != null && qLocal != null && eUnit == 'eV' && unitConverter != null)
          ? unitConverter.convertEnergy(eJLocal, 'J', 'eV')
          : null;
      final efShown = (efJLocal != null && qLocal != null && efUnit == 'eV' && unitConverter != null)
          ? unitConverter.convertEnergy(efJLocal, 'J', 'eV')
          : null;

      final eInUnitFmt = (eUnit == 'eV' && eShown != null)
          ? _formatter.formatLatexWithUnit(eShown, 'eV')
          : (eJLocal != null ? _formatter.formatLatexWithUnit(eJLocal, 'J') : 'E');
      final efInUnitFmt = (efUnit == 'eV' && efShown != null)
          ? _formatter.formatLatexWithUnit(efShown, 'eV')
          : (efJLocal != null ? _formatter.formatLatexWithUnit(efJLocal, 'J') : 'E_F');

      final eJFmt = eJLocal != null ? _formatter.formatLatexWithUnit(eJLocal, 'J') : 'E';
      final efJFmt = efJLocal != null ? _formatter.formatLatexWithUnit(efJLocal, 'J') : 'E_F';
      final kTFmt = (kB != null && t != null)
          ? _formatter.formatLatexWithUnit(kB * t, 'J')
          : r'kT';
      final delta = (eJLocal != null && efJLocal != null) ? (eJLocal - efJLocal) : null;
      final deltaFmt = delta != null ? _formatter.formatLatexWithUnitFullPrecision(delta, 'J') : r'(E-E_F)';
      final x = (delta != null && kB != null && t != null) ? delta / (kB * t) : null;
      final xFmt = x != null ? _formatter.formatLatexFullPrecision(x) : r'\frac{E-E_F}{kT}';
      final expx = x != null ? math.exp(x) : null;
      final expFmt = expx != null ? _formatter.formatLatexFullPrecision(expx) : r'\exp\left(\frac{E-E_F}{kT}\right)';
      final fFmt = f != null ? _formatter.formatLatexFullPrecision(f) : 'f(E)';

      final qFmt = qLocal != null ? _formatter.formatLatexWithUnit(qLocal, 'C') : 'q';
      final eConvLine = eUnit == 'eV'
          ? r'E_J &= (E_{\mathrm{eV}})\,q = ({{EUNIT}})\,({{Q}}) = {{EJ}} \\'
          : r'\;';
      final efConvLine = efUnit == 'eV'
          ? r'E_{F,J} &= (E_{F,\mathrm{eV}})\,q = ({{EFUNIT}})\,({{Q}}) = {{EFJ}} \\'
          : r'\;';

      final template = r'''
\begin{aligned}
f(E) &= \frac{1}{1+\exp\left(\frac{E-E_F}{kT}\right)} \\
{{E_CONV}}
{{EF_CONV}}
\Delta E &= E_J - E_{F,J} = {{DELTA}} \\
kT &= {{KT}} \\
x &= \frac{\Delta E}{kT} = {{X}} \\
\exp(x) &= {{EXPX}} \\
f(E) &= \frac{1}{1+\exp(x)} = {{F}} \\
\textbf{Result:}\; f(E) &= {{F}}
\end{aligned}
''';

      return template
          .replaceAll('{{E_CONV}}', eConvLine
              .replaceAll('{{EUNIT}}', eInUnitFmt)
              .replaceAll('{{Q}}', qFmt)
              .replaceAll('{{EJ}}', eJFmt))
          .replaceAll('{{EF_CONV}}', efConvLine
              .replaceAll('{{EFUNIT}}', efInUnitFmt)
              .replaceAll('{{Q}}', qFmt)
              .replaceAll('{{EFJ}}', efJFmt))
          .replaceAll('{{DELTA}}', deltaFmt)
          .replaceAll('{{KT}}', kTFmt)
          .replaceAll('{{X}}', xFmt)
          .replaceAll('{{EXPX}}', expFmt)
          .replaceAll('{{F}}', fFmt);
    }

    if (formula.id == 'dos_fermi_dirac_probability' && solveFor == 'E_F') {
      final kB = context.getValue('k');
      final t = context.getValue('T');
      final eJLocal = context.getValue('E');
      final f = context.getValue('f_E');
      final qLocal = context.getValue('q');
      final ef = outputs['E_F']?.value;

      final energyUnit = context.getUnit('__meta__E_unit') ?? primaryEnergyUnit; // 'eV' or 'J'

      final eShown = (eJLocal != null && qLocal != null && energyUnit == 'eV' && unitConverter != null)
          ? unitConverter.convertEnergy(eJLocal, 'J', 'eV')
          : null;
      final eInUnitFmt = (energyUnit == 'eV' && eShown != null)
          ? _formatter.formatLatexWithUnit(eShown, 'eV')
          : (eJLocal != null ? _formatter.formatLatexWithUnit(eJLocal, 'J') : 'E');
      final eJFmt = eJLocal != null ? _formatter.formatLatexWithUnit(eJLocal, 'J') : 'E';

      final qFmt = qLocal != null ? _formatter.formatLatexWithUnit(qLocal, 'C') : 'q';
      final a = (f != null) ? (1.0 / f) - 1.0 : null;
      final aFmt = a != null ? _formatter.formatLatexFullPrecision(a) : r'\left(\frac{1}{f}-1\right)';
      final lnA = a != null ? math.log(a) : null;
      final lnAFmt = lnA != null ? _formatter.formatLatexFullPrecision(lnA) : r'\ln\left(\frac{1}{f}-1\right)';

      final delta = (kB != null && t != null && lnA != null) ? (kB * t * lnA) : null;
      final deltaFmt = delta != null ? _formatter.formatLatexWithUnitFullPrecision(delta, 'J') : r'kT\ln\left(\frac{1}{f}-1\right)';

      final efJFmt = ef != null ? _formatter.formatLatexWithUnit(ef, 'J') : r'E_F';
      final efEV = (ef != null && unitConverter != null && qLocal != null)
          ? unitConverter.convertEnergy(ef, 'J', 'eV')
          : null;
      final efInUnitFmt = (energyUnit == 'eV' && efEV != null)
          ? _formatter.formatLatexWithUnit(efEV, 'eV')
          : efJFmt;
      final efOtherFmt = (energyUnit == 'eV' && efJFmt.isNotEmpty)
          ? efJFmt
          : (efEV != null ? _formatter.formatLatexWithUnit(efEV, 'eV') : efJFmt);

      final eConvLine = energyUnit == 'eV'
          ? r'E_J &= (E_{\mathrm{eV}})\,q = ({{EUNIT}})\,({{Q}}) = {{EJ}} \\'
          : r'\;';
      final efConvLine = energyUnit == 'eV' && efEV != null
          ? r'E_{F,\mathrm{eV}} &= \frac{E_{F,J}}{q} = \frac{{{EFJ}}}{{{Q}}} = {{EFEV}} \\'
          : r'\;';

      final template = r'''
\begin{aligned}
f(E) &= \frac{1}{1+\exp\left(\frac{E-E_F}{kT}\right)} \\
1+\exp\left(\frac{E-E_F}{kT}\right) &= \frac{1}{f} \\
\exp\left(\frac{E-E_F}{kT}\right) &= \frac{1}{f}-1 \\
\frac{E-E_F}{kT} &= \ln\left(\frac{1}{f}-1\right) \\
E_F &= E - kT\ln\left(\frac{1}{f}-1\right) \\
{{E_CONV}}
\left(\frac{1}{f}-1\right) &= {{A}} \\
\ln\left(\frac{1}{f}-1\right) &= {{LNA}} \\
kT\ln\left(\frac{1}{f}-1\right) &= {{DELTA}} \\
E_{F,J} &= {{EJ}} - {{DELTA}} = {{EFJ}} \\
{{EF_CONV}}
\textbf{Result:}\; E_F &= {{EF_PRIMARY}}\;\;({{EF_SECONDARY}})
\end{aligned}
''';

      return template
          .replaceAll('{{E_CONV}}', eConvLine
              .replaceAll('{{EUNIT}}', eInUnitFmt)
              .replaceAll('{{Q}}', qFmt)
              .replaceAll('{{EJ}}', eJFmt))
          .replaceAll('{{A}}', aFmt)
          .replaceAll('{{LNA}}', lnAFmt)
          .replaceAll('{{DELTA}}', deltaFmt)
          .replaceAll('{{EJ}}', eJFmt)
          .replaceAll('{{EFJ}}', efJFmt)
          .replaceAll('{{EF_CONV}}', efConvLine
              .replaceAll('{{EFJ}}', efJFmt)
              .replaceAll('{{Q}}', qFmt)
              .replaceAll('{{EFEV}}', efEV != null ? _formatter.formatLatexWithUnit(efEV, 'eV') : ''))
          .replaceAll('{{EF_PRIMARY}}', efInUnitFmt)
          .replaceAll('{{EF_SECONDARY}}', efOtherFmt);
    }

    // Carrier statistics (non-degenerate) templates
    if (formula.id == 'carrier_electron_concentration_n0' && solveFor == 'n_0') {
      final niSI = context.getValue('n_i');
      final efJ = context.getValue('E_F');
      final eiJ = context.getValue('E_i');
      final kB = context.getValue('k');
      final t = context.getValue('T');
      final qLocal = context.getValue('q');
      final n0SI = outputs['n_0']?.value;

      final unitMode = context.getUnit('__meta__unit_system'); // 'si' or 'cm'
      final showCm = unitMode == 'cm';
      final densityUnit = showCm ? 'cm^-3' : 'm^-3';

      double? toDisplayDensity(double? vSI) {
        if (vSI == null) return null;
        if (!showCm || unitConverter == null) return vSI;
        return unitConverter.convertDensity(vSI, 'm^-3', 'cm^-3');
      }

      final ni = toDisplayDensity(niSI);
      final n0 = toDisplayDensity(n0SI);

      final energyUnit = context.getUnit('__meta__E_unit') ?? primaryEnergyUnit; // 'eV' or 'J'
      final qFmt = qLocal != null ? _formatter.formatLatexWithUnit(qLocal, 'C') : 'q';
      final efEV = (efJ != null && energyUnit == 'eV' && unitConverter != null)
          ? unitConverter.convertEnergy(efJ, 'J', 'eV')
          : null;
      final eiEV = (eiJ != null && energyUnit == 'eV' && unitConverter != null)
          ? unitConverter.convertEnergy(eiJ, 'J', 'eV')
          : null;

      final efShown = (energyUnit == 'eV' && efEV != null)
          ? _formatter.formatLatexWithUnit(efEV, 'eV')
          : (efJ != null ? _formatter.formatLatexWithUnit(efJ, 'J') : 'E_F');
      final eiShown = (energyUnit == 'eV' && eiEV != null)
          ? _formatter.formatLatexWithUnit(eiEV, 'eV')
          : (eiJ != null ? _formatter.formatLatexWithUnit(eiJ, 'J') : 'E_i');

      final delta = (efJ != null && eiJ != null) ? (efJ - eiJ) : null;
      final deltaFmt = delta != null ? _formatter.formatLatexWithUnitFullPrecision(delta, 'J') : r'(E_F-E_i)';
      final kT = (kB != null && t != null) ? (kB * t) : null;
      final kTFmt = kT != null ? _formatter.formatLatexWithUnitFullPrecision(kT, 'J') : r'kT';
      final x = (delta != null && kT != null) ? (delta / kT) : null;

      String xFmt;
      if (x == null) {
        xFmt = r'\frac{\Delta E}{kT}';
      } else {
        final ax = x.abs();
        if (ax > 1e-5 && ax < 1e6) {
          xFmt = x.toStringAsFixed(5);
        } else {
          xFmt = _formatter.formatLatexFullPrecision(x);
        }
      }

      final expx = x != null ? math.exp(x) : null;
      final expxFmt = expx != null ? _formatter.formatLatexFullPrecision(expx) : r'\exp(x)';

      final niFmt = ni != null ? _formatter.formatLatexWithUnitFullPrecision(ni, densityUnit) : 'n_i';
      final n0Fmt = n0 != null ? _formatter.formatLatexWithUnit(n0, densityUnit) : 'n_0';

      final energyConvLine = energyUnit == 'eV'
          ? r'E_{F,J} &= (E_{F,\mathrm{eV}})\,q,\;\;E_{i,J} = (E_{i,\mathrm{eV}})\,q \\'
          : r'\;';

      final template = r'''
\begin{aligned}
n_0 &= n_i\,\exp\left(\frac{E_F - E_i}{kT}\right) \\
{{ENERGY_CONV}}
\Delta E &= E_F - E_i = ({{EF}}) - ({{EI}}) = {{DELTA}} \\
kT &= {{KT}} \\
x &= \frac{\Delta E}{kT} = {{X}} \\
\exp(x) &= {{EXPX}} \\
n_0 &= ({{NI}})\cdot \exp(x) = {{N0}} \\
\textbf{Result:}\; n_0 &= {{N0}}
\end{aligned}
''';

      return template
          .replaceAll('{{ENERGY_CONV}}', energyConvLine.replaceAll('{{Q}}', qFmt))
          .replaceAll('{{EF}}', efShown)
          .replaceAll('{{EI}}', eiShown)
          .replaceAll('{{DELTA}}', deltaFmt)
          .replaceAll('{{KT}}', kTFmt)
          .replaceAll('{{X}}', xFmt)
          .replaceAll('{{EXPX}}', expxFmt)
          .replaceAll('{{NI}}', niFmt)
          .replaceAll('{{N0}}', n0Fmt);
    }

    if (formula.id == 'carrier_electron_concentration_n0' && solveFor == 'n_i') {
      final n0SI = context.getValue('n_0');
      final efJ = context.getValue('E_F');
      final eiJ = context.getValue('E_i');
      final kB = context.getValue('k');
      final t = context.getValue('T');
      final qLocal = context.getValue('q');
      final niSI = outputs['n_i']?.value;

      final unitMode = context.getUnit('__meta__unit_system'); // 'si' or 'cm'
      final showCm = unitMode == 'cm';
      final densityUnit = showCm ? 'cm^-3' : 'm^-3';

      double? toDisplayDensity(double? vSI) {
        if (vSI == null) return null;
        if (!showCm || unitConverter == null) return vSI;
        return unitConverter.convertDensity(vSI, 'm^-3', 'cm^-3');
      }

      final n0 = toDisplayDensity(n0SI);
      final ni = toDisplayDensity(niSI);

      final energyUnit = context.getUnit('__meta__E_unit') ?? primaryEnergyUnit; // 'eV' or 'J'
      final qFmt = qLocal != null ? _formatter.formatLatexWithUnit(qLocal, 'C') : 'q';
      final efEV = (efJ != null && energyUnit == 'eV' && unitConverter != null)
          ? unitConverter.convertEnergy(efJ, 'J', 'eV')
          : null;
      final eiEV = (eiJ != null && energyUnit == 'eV' && unitConverter != null)
          ? unitConverter.convertEnergy(eiJ, 'J', 'eV')
          : null;
      final efShown = (energyUnit == 'eV' && efEV != null)
          ? _formatter.formatLatexWithUnit(efEV, 'eV')
          : (efJ != null ? _formatter.formatLatexWithUnit(efJ, 'J') : 'E_F');
      final eiShown = (energyUnit == 'eV' && eiEV != null)
          ? _formatter.formatLatexWithUnit(eiEV, 'eV')
          : (eiJ != null ? _formatter.formatLatexWithUnit(eiJ, 'J') : 'E_i');

      final delta = (efJ != null && eiJ != null) ? (efJ - eiJ) : null;
      final deltaFmt = delta != null ? _formatter.formatLatexWithUnitFullPrecision(delta, 'J') : r'(E_F-E_i)';
      final kT = (kB != null && t != null) ? (kB * t) : null;
      final kTFmt = kT != null ? _formatter.formatLatexWithUnitFullPrecision(kT, 'J') : r'kT';
      final x = (delta != null && kT != null) ? (delta / kT) : null;

      String xFmt;
      if (x == null) {
        xFmt = r'\frac{\Delta E}{kT}';
      } else {
        final ax = x.abs();
        if (ax > 1e-5 && ax < 1e6) {
          xFmt = x.toStringAsFixed(5);
        } else {
          xFmt = _formatter.formatLatexFullPrecision(x);
        }
      }

      final expx = x != null ? math.exp(x) : null;
      final expxFmt = expx != null ? _formatter.formatLatexFullPrecision(expx) : r'\exp(x)';

      final n0Fmt = n0 != null ? _formatter.formatLatexWithUnitFullPrecision(n0, densityUnit) : 'n_0';
      final niFmt = ni != null ? _formatter.formatLatexWithUnit(ni, densityUnit) : 'n_i';

      final energyConvLine = energyUnit == 'eV'
          ? r'E_{F,J} &= (E_{F,\mathrm{eV}})\,q,\;\;E_{i,J} = (E_{i,\mathrm{eV}})\,q \\'
          : r'\;';

      final template = r'''
\begin{aligned}
n_0 &= n_i\,\exp\left(\frac{E_F - E_i}{kT}\right) \\
n_i &= \frac{n_0}{\exp\left(\frac{E_F - E_i}{kT}\right)} = n_0\,\exp\left(-\frac{E_F - E_i}{kT}\right) \\
{{ENERGY_CONV}}
\Delta E &= E_F - E_i = ({{EF}}) - ({{EI}}) = {{DELTA}} \\
kT &= {{KT}} \\
x &= \frac{\Delta E}{kT} = {{X}} \\
\exp(x) &= {{EXPX}} \\
n_i &= \frac{({{N0}})}{\exp(x)} = {{NI}} \\
\textbf{Result:}\; n_i &= {{NI}}
\end{aligned}
''';

      return template
          .replaceAll('{{ENERGY_CONV}}', energyConvLine.replaceAll('{{Q}}', qFmt))
          .replaceAll('{{EF}}', efShown)
          .replaceAll('{{EI}}', eiShown)
          .replaceAll('{{DELTA}}', deltaFmt)
          .replaceAll('{{KT}}', kTFmt)
          .replaceAll('{{X}}', xFmt)
          .replaceAll('{{EXPX}}', expxFmt)
          .replaceAll('{{N0}}', n0Fmt)
          .replaceAll('{{NI}}', niFmt);
    }

    if (formula.id == 'carrier_electron_concentration_n0' && (solveFor == 'E_F' || solveFor == 'E_i')) {
      final n0SI = context.getValue('n_0');
      final niSI = context.getValue('n_i');
      final efJ = outputs['E_F']?.value ?? context.getValue('E_F');
      final eiJ = outputs['E_i']?.value ?? context.getValue('E_i');
      final kB = context.getValue('k');
      final t = context.getValue('T');
      final qLocal = context.getValue('q');

      final unitMode = context.getUnit('__meta__unit_system'); // 'si' or 'cm'
      final showCm = unitMode == 'cm';
      final densityUnit = showCm ? 'cm^-3' : 'm^-3';

      double? toDisplayDensity(double? vSI) {
        if (vSI == null) return null;
        if (!showCm || unitConverter == null) return vSI;
        return unitConverter.convertDensity(vSI, 'm^-3', 'cm^-3');
      }

      final n0 = toDisplayDensity(n0SI);
      final ni = toDisplayDensity(niSI);

      final ratio = (n0 != null && ni != null) ? (n0 / ni) : null;
      final lnRatio = (ratio != null && ratio > 0) ? math.log(ratio) : null;

      final kT = (kB != null && t != null) ? (kB * t) : null;
      final kTFmt = kT != null ? _formatter.formatLatexWithUnitFullPrecision(kT, 'J') : r'kT';
      final lnFmt = lnRatio != null ? lnRatio.toStringAsFixed(5) : r'\ln\left(\frac{n_0}{n_i}\right)';

      final n0Fmt = n0 != null ? _formatter.formatLatexWithUnitFullPrecision(n0, densityUnit) : 'n_0';
      final niFmt = ni != null ? _formatter.formatLatexWithUnitFullPrecision(ni, densityUnit) : 'n_i';

      final energyUnit = context.getUnit('__meta__E_unit') ?? primaryEnergyUnit; // 'eV' or 'J'
      final qFmt = qLocal != null ? _formatter.formatLatexWithUnit(qLocal, 'C') : 'q';
      final energyConvLine = energyUnit == 'eV'
          ? r'(\text{energies are computed in J; displayed in eV using } q) \\'
          : r'\;';

      String resultLine;
      if (solveFor == 'E_F') {
        final efShow = (energyUnit == 'eV' && efJ != null && unitConverter != null && qLocal != null)
            ? _formatter.formatLatexWithUnit(unitConverter.convertEnergy(efJ, 'J', 'eV') ?? efJ, 'eV')
            : (efJ != null ? _formatter.formatLatexWithUnit(efJ, 'J') : 'E_F');
        final eiShow = (energyUnit == 'eV' && eiJ != null && unitConverter != null && qLocal != null)
            ? _formatter.formatLatexWithUnit(unitConverter.convertEnergy(eiJ, 'J', 'eV') ?? eiJ, 'eV')
            : (eiJ != null ? _formatter.formatLatexWithUnit(eiJ, 'J') : 'E_i');
        resultLine = r'\textbf{Result:}\; E_F &= ' + efShow + r'\;\;(\text{with } E_i = ' + eiShow + r')';
      } else {
        final eiShow = (energyUnit == 'eV' && eiJ != null && unitConverter != null && qLocal != null)
            ? _formatter.formatLatexWithUnit(unitConverter.convertEnergy(eiJ, 'J', 'eV') ?? eiJ, 'eV')
            : (eiJ != null ? _formatter.formatLatexWithUnit(eiJ, 'J') : 'E_i');
        final efShow = (energyUnit == 'eV' && efJ != null && unitConverter != null && qLocal != null)
            ? _formatter.formatLatexWithUnit(unitConverter.convertEnergy(efJ, 'J', 'eV') ?? efJ, 'eV')
            : (efJ != null ? _formatter.formatLatexWithUnit(efJ, 'J') : 'E_F');
        resultLine = r'\textbf{Result:}\; E_i &= ' + eiShow + r'\;\;(\text{with } E_F = ' + efShow + r')';
      }

      final template = r'''
\begin{aligned}
n_0 &= n_i\,\exp\left(\frac{E_F - E_i}{kT}\right) \\
\ln\left(\frac{n_0}{n_i}\right) &= \frac{E_F - E_i}{kT} \\
\Delta &= \ln\left(\frac{n_0}{n_i}\right) = \ln\left(\frac{{{N0}}}{{{NI}}}\right) = {{LN}} \\
kT &= {{KT}} \\
{{ENERGY_CONV}}
{{RESULT_LINE}}
\end{aligned}
''';

      return template
          .replaceAll('{{N0}}', n0Fmt)
          .replaceAll('{{NI}}', niFmt)
          .replaceAll('{{LN}}', lnFmt)
          .replaceAll('{{KT}}', kTFmt)
          .replaceAll('{{ENERGY_CONV}}', energyConvLine.replaceAll('{{Q}}', qFmt))
          .replaceAll('{{RESULT_LINE}}', resultLine);
    }

    if (formula.id == 'carrier_hole_concentration_p0' && solveFor == 'p_0') {
      final niSI = context.getValue('n_i');
      final efJ = context.getValue('E_F');
      final eiJ = context.getValue('E_i');
      final kB = context.getValue('k');
      final t = context.getValue('T');
      final qLocal = context.getValue('q');
      final p0SI = outputs['p_0']?.value;

      final unitMode = context.getUnit('__meta__unit_system'); // 'si' or 'cm'
      final showCm = unitMode == 'cm';
      final densityUnit = showCm ? 'cm^-3' : 'm^-3';

      double? toDisplayDensity(double? vSI) {
        if (vSI == null) return null;
        if (!showCm || unitConverter == null) return vSI;
        return unitConverter.convertDensity(vSI, 'm^-3', 'cm^-3');
      }

      final ni = toDisplayDensity(niSI);
      final p0 = toDisplayDensity(p0SI);

      final energyUnit = context.getUnit('__meta__E_unit') ?? primaryEnergyUnit; // 'eV' or 'J'
      final qFmt = qLocal != null ? _formatter.formatLatexWithUnit(qLocal, 'C') : 'q';
      final efEV = (efJ != null && energyUnit == 'eV' && unitConverter != null)
          ? unitConverter.convertEnergy(efJ, 'J', 'eV')
          : null;
      final eiEV = (eiJ != null && energyUnit == 'eV' && unitConverter != null)
          ? unitConverter.convertEnergy(eiJ, 'J', 'eV')
          : null;
      final efShown = (energyUnit == 'eV' && efEV != null)
          ? _formatter.formatLatexWithUnit(efEV, 'eV')
          : (efJ != null ? _formatter.formatLatexWithUnit(efJ, 'J') : 'E_F');
      final eiShown = (energyUnit == 'eV' && eiEV != null)
          ? _formatter.formatLatexWithUnit(eiEV, 'eV')
          : (eiJ != null ? _formatter.formatLatexWithUnit(eiJ, 'J') : 'E_i');

      final delta = (eiJ != null && efJ != null) ? (eiJ - efJ) : null;
      final deltaFmt = delta != null ? _formatter.formatLatexWithUnitFullPrecision(delta, 'J') : r'(E_i-E_F)';
      final kT = (kB != null && t != null) ? (kB * t) : null;
      final kTFmt = kT != null ? _formatter.formatLatexWithUnitFullPrecision(kT, 'J') : r'kT';
      final x = (delta != null && kT != null) ? (delta / kT) : null;

      String xFmt;
      if (x == null) {
        xFmt = r'\frac{\Delta E}{kT}';
      } else {
        final ax = x.abs();
        if (ax > 1e-5 && ax < 1e6) {
          xFmt = x.toStringAsFixed(5);
        } else {
          xFmt = _formatter.formatLatexFullPrecision(x);
        }
      }

      final expx = x != null ? math.exp(x) : null;
      final expxFmt = expx != null ? _formatter.formatLatexFullPrecision(expx) : r'\exp(x)';

      final niFmt = ni != null ? _formatter.formatLatexWithUnitFullPrecision(ni, densityUnit) : 'n_i';
      final p0Fmt = p0 != null ? _formatter.formatLatexWithUnit(p0, densityUnit) : 'p_0';

      final energyConvLine = energyUnit == 'eV'
          ? r'E_{F,J} &= (E_{F,\mathrm{eV}})\,q,\;\;E_{i,J} = (E_{i,\mathrm{eV}})\,q \\'
          : r'\;';

      final template = r'''
\begin{aligned}
p_0 &= n_i\,\exp\left(\frac{E_i - E_F}{kT}\right) \\
{{ENERGY_CONV}}
\Delta E &= E_i - E_F = ({{EI}}) - ({{EF}}) = {{DELTA}} \\
kT &= {{KT}} \\
x &= \frac{\Delta E}{kT} = {{X}} \\
\exp(x) &= {{EXPX}} \\
p_0 &= ({{NI}})\cdot \exp(x) = {{P0}} \\
\textbf{Result:}\; p_0 &= {{P0}}
\end{aligned}
''';

      return template
          .replaceAll('{{ENERGY_CONV}}', energyConvLine.replaceAll('{{Q}}', qFmt))
          .replaceAll('{{EI}}', eiShown)
          .replaceAll('{{EF}}', efShown)
          .replaceAll('{{DELTA}}', deltaFmt)
          .replaceAll('{{KT}}', kTFmt)
          .replaceAll('{{X}}', xFmt)
          .replaceAll('{{EXPX}}', expxFmt)
          .replaceAll('{{NI}}', niFmt)
          .replaceAll('{{P0}}', p0Fmt);
    }

    if (formula.id == 'carrier_hole_concentration_p0' && solveFor == 'n_i') {
      final p0SI = context.getValue('p_0');
      final efJ = context.getValue('E_F');
      final eiJ = context.getValue('E_i');
      final kB = context.getValue('k');
      final t = context.getValue('T');
      final qLocal = context.getValue('q');
      final niSI = outputs['n_i']?.value;

      final unitMode = context.getUnit('__meta__unit_system'); // 'si' or 'cm'
      final showCm = unitMode == 'cm';
      final densityUnit = showCm ? 'cm^-3' : 'm^-3';

      double? toDisplayDensity(double? vSI) {
        if (vSI == null) return null;
        if (!showCm || unitConverter == null) return vSI;
        return unitConverter.convertDensity(vSI, 'm^-3', 'cm^-3');
      }

      final p0 = toDisplayDensity(p0SI);
      final ni = toDisplayDensity(niSI);

      final energyUnit = context.getUnit('__meta__E_unit') ?? primaryEnergyUnit; // 'eV' or 'J'
      final qFmt = qLocal != null ? _formatter.formatLatexWithUnit(qLocal, 'C') : 'q';
      final efEV = (efJ != null && energyUnit == 'eV' && unitConverter != null)
          ? unitConverter.convertEnergy(efJ, 'J', 'eV')
          : null;
      final eiEV = (eiJ != null && energyUnit == 'eV' && unitConverter != null)
          ? unitConverter.convertEnergy(eiJ, 'J', 'eV')
          : null;
      final efShown = (energyUnit == 'eV' && efEV != null)
          ? _formatter.formatLatexWithUnit(efEV, 'eV')
          : (efJ != null ? _formatter.formatLatexWithUnit(efJ, 'J') : 'E_F');
      final eiShown = (energyUnit == 'eV' && eiEV != null)
          ? _formatter.formatLatexWithUnit(eiEV, 'eV')
          : (eiJ != null ? _formatter.formatLatexWithUnit(eiJ, 'J') : 'E_i');

      final delta = (eiJ != null && efJ != null) ? (eiJ - efJ) : null;
      final deltaFmt = delta != null ? _formatter.formatLatexWithUnitFullPrecision(delta, 'J') : r'(E_i-E_F)';
      final kT = (kB != null && t != null) ? (kB * t) : null;
      final kTFmt = kT != null ? _formatter.formatLatexWithUnitFullPrecision(kT, 'J') : r'kT';
      final x = (delta != null && kT != null) ? (delta / kT) : null;

      String xFmt;
      if (x == null) {
        xFmt = r'\frac{\Delta E}{kT}';
      } else {
        final ax = x.abs();
        if (ax > 1e-5 && ax < 1e6) {
          xFmt = x.toStringAsFixed(5);
        } else {
          xFmt = _formatter.formatLatexFullPrecision(x);
        }
      }

      final expx = x != null ? math.exp(x) : null;
      final expxFmt = expx != null ? _formatter.formatLatexFullPrecision(expx) : r'\exp(x)';

      final p0Fmt = p0 != null ? _formatter.formatLatexWithUnitFullPrecision(p0, densityUnit) : 'p_0';
      final niFmt = ni != null ? _formatter.formatLatexWithUnit(ni, densityUnit) : 'n_i';

      final energyConvLine = energyUnit == 'eV'
          ? r'E_{F,J} &= (E_{F,\mathrm{eV}})\,q,\;\;E_{i,J} = (E_{i,\mathrm{eV}})\,q \\'
          : r'\;';

      final template = r'''
\begin{aligned}
p_0 &= n_i\,\exp\left(\frac{E_i - E_F}{kT}\right) \\
n_i &= \frac{p_0}{\exp\left(\frac{E_i - E_F}{kT}\right)} = p_0\,\exp\left(-\frac{E_i - E_F}{kT}\right) \\
{{ENERGY_CONV}}
\Delta E &= E_i - E_F = ({{EI}}) - ({{EF}}) = {{DELTA}} \\
kT &= {{KT}} \\
x &= \frac{\Delta E}{kT} = {{X}} \\
\exp(x) &= {{EXPX}} \\
n_i &= \frac{({{P0}})}{\exp(x)} = {{NI}} \\
\textbf{Result:}\; n_i &= {{NI}}
\end{aligned}
''';

      return template
          .replaceAll('{{ENERGY_CONV}}', energyConvLine.replaceAll('{{Q}}', qFmt))
          .replaceAll('{{EI}}', eiShown)
          .replaceAll('{{EF}}', efShown)
          .replaceAll('{{DELTA}}', deltaFmt)
          .replaceAll('{{KT}}', kTFmt)
          .replaceAll('{{X}}', xFmt)
          .replaceAll('{{EXPX}}', expxFmt)
          .replaceAll('{{P0}}', p0Fmt)
          .replaceAll('{{NI}}', niFmt);
    }

    if (formula.id == 'carrier_hole_concentration_p0' && (solveFor == 'E_F' || solveFor == 'E_i')) {
      final p0SI = context.getValue('p_0');
      final niSI = context.getValue('n_i');
      final efJ = outputs['E_F']?.value ?? context.getValue('E_F');
      final eiJ = outputs['E_i']?.value ?? context.getValue('E_i');
      final kB = context.getValue('k');
      final t = context.getValue('T');
      final qLocal = context.getValue('q');

      final unitMode = context.getUnit('__meta__unit_system'); // 'si' or 'cm'
      final showCm = unitMode == 'cm';
      final densityUnit = showCm ? 'cm^-3' : 'm^-3';

      double? toDisplayDensity(double? vSI) {
        if (vSI == null) return null;
        if (!showCm || unitConverter == null) return vSI;
        return unitConverter.convertDensity(vSI, 'm^-3', 'cm^-3');
      }

      final p0 = toDisplayDensity(p0SI);
      final ni = toDisplayDensity(niSI);
      final ratio = (p0 != null && ni != null) ? (p0 / ni) : null;
      final lnRatio = (ratio != null && ratio > 0) ? math.log(ratio) : null;

      final kT = (kB != null && t != null) ? (kB * t) : null;
      final kTFmt = kT != null ? _formatter.formatLatexWithUnitFullPrecision(kT, 'J') : r'kT';
      final lnFmt = lnRatio != null ? lnRatio.toStringAsFixed(5) : r'\ln\left(\frac{p_0}{n_i}\right)';

      final p0Fmt = p0 != null ? _formatter.formatLatexWithUnitFullPrecision(p0, densityUnit) : 'p_0';
      final niFmt = ni != null ? _formatter.formatLatexWithUnitFullPrecision(ni, densityUnit) : 'n_i';

      final energyUnit = context.getUnit('__meta__E_unit') ?? primaryEnergyUnit; // 'eV' or 'J'
      final qFmt = qLocal != null ? _formatter.formatLatexWithUnit(qLocal, 'C') : 'q';
      final energyConvLine = energyUnit == 'eV'
          ? r'(\text{energies are computed in J; displayed in eV using } q) \\'
          : r'\;';

      String resultLine;
      if (solveFor == 'E_F') {
        final efShow = (energyUnit == 'eV' && efJ != null && unitConverter != null && qLocal != null)
            ? _formatter.formatLatexWithUnit(unitConverter.convertEnergy(efJ, 'J', 'eV') ?? efJ, 'eV')
            : (efJ != null ? _formatter.formatLatexWithUnit(efJ, 'J') : 'E_F');
        final eiShow = (energyUnit == 'eV' && eiJ != null && unitConverter != null && qLocal != null)
            ? _formatter.formatLatexWithUnit(unitConverter.convertEnergy(eiJ, 'J', 'eV') ?? eiJ, 'eV')
            : (eiJ != null ? _formatter.formatLatexWithUnit(eiJ, 'J') : 'E_i');
        resultLine = r'\textbf{Result:}\; E_F &= ' + efShow + r'\;\;(\text{with } E_i = ' + eiShow + r')';
      } else {
        final eiShow = (energyUnit == 'eV' && eiJ != null && unitConverter != null && qLocal != null)
            ? _formatter.formatLatexWithUnit(unitConverter.convertEnergy(eiJ, 'J', 'eV') ?? eiJ, 'eV')
            : (eiJ != null ? _formatter.formatLatexWithUnit(eiJ, 'J') : 'E_i');
        final efShow = (energyUnit == 'eV' && efJ != null && unitConverter != null && qLocal != null)
            ? _formatter.formatLatexWithUnit(unitConverter.convertEnergy(efJ, 'J', 'eV') ?? efJ, 'eV')
            : (efJ != null ? _formatter.formatLatexWithUnit(efJ, 'J') : 'E_F');
        resultLine = r'\textbf{Result:}\; E_i &= ' + eiShow + r'\;\;(\text{with } E_F = ' + efShow + r')';
      }

      final template = r'''
\begin{aligned}
p_0 &= n_i\,\exp\left(\frac{E_i - E_F}{kT}\right) \\
\ln\left(\frac{p_0}{n_i}\right) &= \frac{E_i - E_F}{kT} \\
\Delta &= \ln\left(\frac{p_0}{n_i}\right) = \ln\left(\frac{{{P0}}}{{{NI}}}\right) = {{LN}} \\
kT &= {{KT}} \\
{{ENERGY_CONV}}
{{RESULT_LINE}}
\end{aligned}
''';

      return template
          .replaceAll('{{P0}}', p0Fmt)
          .replaceAll('{{NI}}', niFmt)
          .replaceAll('{{LN}}', lnFmt)
          .replaceAll('{{KT}}', kTFmt)
          .replaceAll('{{ENERGY_CONV}}', energyConvLine.replaceAll('{{Q}}', qFmt))
          .replaceAll('{{RESULT_LINE}}', resultLine);
    }

    if (formula.id == 'mass_action_law' && (solveFor == 'n_0' || solveFor == 'p_0' || solveFor == 'n_i')) {
      final n0SI = context.getValue('n_0');
      final p0SI = context.getValue('p_0');
      final niSI = context.getValue('n_i');
      final outSI = outputs[solveFor]?.value;

      final unitMode = context.getUnit('__meta__unit_system'); // 'si' or 'cm'
      final showCm = unitMode == 'cm';
      final baseUnit = showCm ? 'cm^-3' : 'm^-3';
      final squaredUnit = showCm ? 'cm^-6' : 'm^-6';

      double? toDisplay(double? vSI) {
        if (vSI == null) return null;
        if (!showCm || unitConverter == null) return vSI;
        return unitConverter.convertDensity(vSI, 'm^-3', 'cm^-3');
      }

      final n0 = toDisplay(n0SI);
      final p0 = toDisplay(p0SI);
      final ni = toDisplay(niSI);
      final out = toDisplay(outSI);

      // Format inputs with full precision for intermediate steps
      final n0Term = n0 != null ? _formatter.formatLatexWithUnitFullPrecision(n0, baseUnit) : 'n_0';
      final p0Term = p0 != null ? _formatter.formatLatexWithUnitFullPrecision(p0, baseUnit) : 'p_0';
      final niTerm = ni != null ? _formatter.formatLatexWithUnitFullPrecision(ni, baseUnit) : 'n_i';

      // For solving n_i: show n_i^2 and sqrt steps
      if (solveFor == 'n_i') {
        final ni2 = (n0 != null && p0 != null) ? (n0 * p0) : null;
        final ni2WithUnit = ni2 != null
            ? _formatter.formatLatexWithUnitFullPrecision(ni2, squaredUnit)
            : r'n_i^2';
        final ni2Num = ni2 != null ? _formatter.formatLatexFullPrecision(ni2) : r'n_i^2';
        final niFull = ni2 != null ? math.sqrt(ni2) : null;
        final niFullWithUnit = niFull != null
            ? _formatter.formatLatexWithUnitFullPrecision(niFull, baseUnit)
            : r'n_i';
        final niResult = out != null
            ? _formatter.formatLatexWithUnit(out, baseUnit)
            : (niFull != null ? _formatter.formatLatexWithUnit(niFull, baseUnit) : r'n_i');

        final template = r'''
\begin{aligned}
n_i^2 &= n_0 p_0 \\
&= \left({{N0}}\right)\cdot\left({{P0}}\right) \\
&= {{NI2}} \\
n_i &= \sqrt{n_i^2} \\
&= \sqrt{{{NI2NUM}}}\,\mathrm{''' + _formatter.formatLatexUnit(baseUnit) + r'''} \\
&= {{NIFULL}} \\
\textbf{Result:}\; n_i &= {{NIRES}}
\end{aligned}
''';

        return template
            .replaceAll('{{N0}}', n0Term)
            .replaceAll('{{P0}}', p0Term)
            .replaceAll('{{NI2}}', ni2WithUnit)
            .replaceAll('{{NI2NUM}}', ni2Num)
            .replaceAll('{{NIFULL}}', niFullWithUnit)
            .replaceAll('{{NIRES}}', niResult);
      }

      // For solving n_0: n_0 = n_i^2 / p_0
      if (solveFor == 'n_0') {
        final ni2 = (ni != null) ? (ni * ni) : null;
        final ni2Num = ni2 != null ? _formatter.formatLatexFullPrecision(ni2) : r'n_i^2';
        final n0Full = (ni2 != null && p0 != null) ? (ni2 / p0) : null;
        final n0FullWithUnit = n0Full != null
            ? _formatter.formatLatexWithUnitFullPrecision(n0Full, baseUnit)
            : r'n_0';
        final n0Result = out != null
            ? _formatter.formatLatexWithUnit(out, baseUnit)
            : (n0Full != null ? _formatter.formatLatexWithUnit(n0Full, baseUnit) : r'n_0');

        final template = r'''
\begin{aligned}
n_i^2 &= n_0 p_0 \\
n_0 &= \frac{n_i^2}{p_0} \\
&= \frac{\left({{NI}}\right)^2}{\left({{P0}}\right)} \\
&= \frac{{{NI2NUM}}}{\left({{P0}}\right)} \\
&= {{N0FULL}} \\
\textbf{Result:}\; n_0 &= {{N0RES}}
\end{aligned}
''';

        return template
            .replaceAll('{{NI}}', niTerm)
            .replaceAll('{{P0}}', p0Term)
            .replaceAll('{{NI2NUM}}', ni2Num)
            .replaceAll('{{N0FULL}}', n0FullWithUnit)
            .replaceAll('{{N0RES}}', n0Result);
      }

      // For solving p_0: p_0 = n_i^2 / n_0
      if (solveFor == 'p_0') {
        final ni2 = (ni != null) ? (ni * ni) : null;
        final ni2Num = ni2 != null ? _formatter.formatLatexFullPrecision(ni2) : r'n_i^2';
        final p0Full = (ni2 != null && n0 != null) ? (ni2 / n0) : null;
        final p0FullWithUnit = p0Full != null
            ? _formatter.formatLatexWithUnitFullPrecision(p0Full, baseUnit)
            : r'p_0';
        final p0Result = out != null
            ? _formatter.formatLatexWithUnit(out, baseUnit)
            : (p0Full != null ? _formatter.formatLatexWithUnit(p0Full, baseUnit) : r'p_0');

        final template = r'''
\begin{aligned}
n_i^2 &= n_0 p_0 \\
p_0 &= \frac{n_i^2}{n_0} \\
&= \frac{\left({{NI}}\right)^2}{\left({{N0}}\right)} \\
&= \frac{{{NI2NUM}}}{\left({{N0}}\right)} \\
&= {{P0FULL}} \\
\textbf{Result:}\; p_0 &= {{P0RES}}
\end{aligned}
''';

        return template
            .replaceAll('{{NI}}', niTerm)
            .replaceAll('{{N0}}', n0Term)
            .replaceAll('{{NI2NUM}}', ni2Num)
            .replaceAll('{{P0FULL}}', p0FullWithUnit)
            .replaceAll('{{P0RES}}', p0Result);
      }
    }

    if (formula.id == 'intrinsic_concentration_from_dos' && solveFor == 'n_i') {
      final nc = context.getValue('N_c');
      final nv = context.getValue('N_v');
      final eg = context.getValue('E_g');
      final kB = context.getValue('k');
      final t = context.getValue('T');
      final ni = outputs['n_i']?.value;

      final unitMode = context.getUnit('__meta__unit_system'); // 'si' or 'cm'
      final showCm = unitMode == 'cm';
      final niCm = (ni != null && unitConverter != null) ? unitConverter.convertDensity(ni, 'm^-3', 'cm^-3') : null;

      final ncFmt = nc != null ? _formatter.formatLatexWithUnit(nc, 'm^-3') : 'N_c';
      final nvFmt = nv != null ? _formatter.formatLatexWithUnit(nv, 'm^-3') : 'N_v';
      final egFmt = eg != null ? _formatter.formatLatexWithUnit(eg, 'J') : 'E_g';
      final denom = (kB != null && t != null) ? (kB * t) : null;
      final x = (eg != null && denom != null) ? (-eg / denom) : null;
      final expx = x != null ? math.exp(x) : null;
      final expFmt = expx != null ? _formatter.formatLatexFullPrecision(expx) : r'\exp\left(\frac{-E_g}{kT}\right)';
      final niFmt = ni != null ? _formatter.formatLatexWithUnit(ni, 'm^-3') : 'n_i';
      final niResult = showCm && niCm != null ? _formatter.formatLatexWithUnit(niCm, 'cm^-3') : niFmt;

      final cmLine = showCm && niCm != null
          ? r'n_{i,\mathrm{cm^{-3}}} &= \frac{n_{i,\mathrm{m^{-3}}}}{10^{6}} = {{NICM}} \\'
          : r'\;';

      final template = r'''
\begin{aligned}
n_i^2 &= N_c N_v \exp\left(\frac{-E_g}{kT}\right) \\
\exp\left(\frac{-E_g}{kT}\right) &= {{EXPX}} \\
n_i &= \sqrt{({{NC}})({{NV}})\,{{EXPX}}} = {{NI_M}} \\
{{CM_LINE}}
\textbf{Result:}\; n_i &= {{NI_RESULT}}
\end{aligned}
''';

      return template
          .replaceAll('{{NC}}', ncFmt)
          .replaceAll('{{NV}}', nvFmt)
          .replaceAll('{{EXPX}}', expFmt)
          .replaceAll('{{NI_M}}', niFmt)
          .replaceAll('{{CM_LINE}}', cmLine.replaceAll('{{NICM}}', niCm != null ? _formatter.formatLatexWithUnit(niCm, 'cm^-3') : ''))
          .replaceAll('{{NI_RESULT}}', niResult)
          .replaceAll('E_g', egFmt);
    }

    if (formula.id == 'effective_mass_from_curvature' || formula.id == 'parabolic_band_dispersion') {
      return r'\text{Step-by-step working moved to EnergyBandSteps.}';
    }

    // Fallback for unknown solveFor
    return r'\text{Step-by-step working not available for this variable.}';
  }

  List<StepItem> buildParabolicBandSteps(
    FormulaDefinition formula,
    String solveFor,
    SymbolContext context,
    Map<String, SymbolValue> outputs,
    UnitConverter? unitConverter, {
    String primaryEnergyUnit = 'J',
  }) {
    final steps = EnergyBandSteps.tryBuildSteps(
      formula: formula,
      solveFor: solveFor,
      context: context,
      outputs: outputs,
      latexMap: _latexMap,
      formatter: _formatter,
      unitConverter: unitConverter,
      primaryEnergyUnit: primaryEnergyUnit,
    );

    if (steps != null) {
      return steps;
    }

    return const [];
  }

  List<StepItem> buildEffectiveMassCurvatureSteps(
    FormulaDefinition formula,
    String solveFor,
    SymbolContext context,
    Map<String, SymbolValue> outputs,
    UnitConverter? unitConverter, {
    String primaryEnergyUnit = 'J',
  }) {
    final steps = EnergyBandSteps.tryBuildSteps(
      formula: formula,
      solveFor: solveFor,
      context: context,
      outputs: outputs,
      latexMap: _latexMap,
      formatter: _formatter,
      unitConverter: unitConverter,
      primaryEnergyUnit: primaryEnergyUnit,
    );

    if (steps != null) {
      return steps;
    }

    return const [];
  }

  List<StepItem> buildEffectiveDensitySteps(
    FormulaDefinition formula,
    String solveFor,
    SymbolContext context,
    Map<String, SymbolValue> outputs,
    UnitConverter? unitConverter,
  ) {
    final steps = DosStatsSteps.tryBuildSteps(
      formula: formula,
      solveFor: solveFor,
      context: context,
      outputs: outputs,
      latexMap: _latexMap,
      formatter: _formatter,
      unitConverter: unitConverter,
    );
    return steps ?? const [];
  }

  String _buildResultLatex(String targetVar, SymbolValue result) {
    final latexSymbol = _latexLabel(targetVar);

    // Always use formatLatexWithUnit for consistent LaTeX rendering
    final formattedValueWithUnit = result.unit.isNotEmpty
        ? _formatter.formatLatexWithUnit(result.value, result.unit)
        : _formatter.formatLatex(result.value);

    return '$latexSymbol = $formattedValueWithUnit';
  }

  String _latexLabel(String key) {
    return _latexMap.renderSymbol(key, warnOnFallback: true);
  }

  List<StepItem> _buildUniversalSteps({
    required FormulaDefinition formula,
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required List<String> conversionLines,
  }) {
    final targetLatex = _latexLabel(solveFor);
    final fmt6 = _formatter.withSigFigs(6);
    final fmt3 = _formatter;
    final result = outputs[solveFor];

    final baseLine = formula.equationLatex;
    final substitutionLine = _buildSubstitutionLatex(
      baseLine,
      context,
      true,
    );

    final evaluatedLine = result != null
        ? '$targetLatex = ${(result.unit.isNotEmpty ? fmt6.formatLatexWithUnit(result.value, result.unit) : fmt6.formatLatex(result.value))}'
        : targetLatex;

    final computedLine = result != null
        ? '$targetLatex = ${(result.unit.isNotEmpty ? fmt6.formatLatexWithUnit(result.value, result.unit) : fmt6.formatLatex(result.value))}'
        : targetLatex;
    final roundedLine = result != null
        ? '$targetLatex = ${(result.unit.isNotEmpty ? fmt3.formatLatexWithUnit(result.value, result.unit) : fmt3.formatLatex(result.value))}'
        : targetLatex;

    final substitutionLines = <String>[
      baseLine,
      substitutionLine,
    ];
    final rearrangeLines = _rearrangeLines(formula, solveFor);

    return UniversalStepTemplate.build(
      targetLabelLatex: targetLatex,
      unitConversionLines: conversionLines,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: evaluatedLine,
      computedValueLine: computedLine,
      roundedValueLine: roundedLine,
    );
  }

  List<String> _conversionLines(UnitConversionLog? log) {
    if (log == null || log.isEmpty) return const [];
    final fmt = _formatter.withSigFigs(6);
    return log.steps.map((step) {
      final sym = _latexLabel(step.symbol);
      final fromStr = step.fromUnit.isNotEmpty
          ? fmt.formatLatexWithUnit(step.fromValue, step.fromUnit)
          : fmt.formatLatex(step.fromValue);
      final toStr = step.toUnit.isNotEmpty
          ? fmt.formatLatexWithUnit(step.toValue, step.toUnit)
          : fmt.formatLatex(step.toValue);
      return '$sym = $fromStr = $toStr';
    }).toList();
  }

  List<StepItem> _applyConversionLinesToWorkingItems(List<StepItem> items, List<String> conversionLines) {
    final result = List<StepItem>.from(items);
    final noConversion = conversionLines.isEmpty;
    final headingIndex = result.indexWhere((item) => item.type == StepItemType.text && item.value.startsWith('Step 1'));
    final replacementMathItems = noConversion
        ? [const StepItem.math(r'\text{No unit conversion required.}')]
        : conversionLines.map((line) => StepItem.math(line)).toList();

    if (headingIndex == -1) {
      // Prepend a full Step 1 section.
      result.insertAll(0, [
        const StepItem.text('Step 1 - Unit Conversion'),
        ...replacementMathItems,
      ]);
      return result;
    }

    // Find where Step 1 math lines end (next text heading or list end).
    int nextHeading = result.length;
    for (var i = headingIndex + 1; i < result.length; i++) {
      final item = result[i];
      final isTextHeading = item.type == StepItemType.text;
      final isMathHeading = item.type == StepItemType.math && item.latex.trim().startsWith(r'\textbf{Step');
      if (isTextHeading || isMathHeading) {
        nextHeading = i;
        break;
      }
    }

    // Remove existing math items in Step 1 block.
    result.removeRange(headingIndex + 1, nextHeading);
    result.insertAll(headingIndex + 1, replacementMathItems);

    assert(() {
      if (!noConversion) {
        final hasNoConversionLine = replacementMathItems.any((i) => i.type == StepItemType.math && i.latex.contains('No unit conversion required'));
        assert(!hasNoConversionLine, 'Unit conversion log is non-empty but Step 1 rendered as no conversion.');
      }
      return true;
    }());

    return result;
  }

  List<StepItem>? _buildCtFundamentalSteps({
    required FormulaDefinition formula,
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required List<String> conversionLines,
  }) {
    // Handle Einstein relation (ct_f7, ct_f8)
    final isEinsteinElectron = formula.id == 'ct_f7_einstein_relation_electrons';
    final isEinsteinHole = formula.id == 'ct_f8_einstein_relation_holes';
    if (isEinsteinElectron || isEinsteinHole) {
      return _buildEinsteinRelationSteps(
        isElectron: isEinsteinElectron,
        solveFor: solveFor,
        context: context,
        outputs: outputs,
        conversionLines: conversionLines,
      );
    }

    // Handle drift velocity (ct_f1, ct_f2)
    final isDriftElectron = formula.id == 'ct_f1_electron_drift_velocity';
    final isDriftHole = formula.id == 'ct_f2_hole_drift_velocity';
    
    // Handle diffusion current density (ct_f5, ct_f6)
    final isDiffElectron = formula.id == 'ct_f5_electron_diffusion_current_density';
    final isDiffHole = formula.id == 'ct_f6_hole_diffusion_current_density';
    
    if (isDiffElectron || isDiffHole) {
      return _buildDiffusionCurrentSteps(
        formula: formula,
        solveFor: solveFor,
        context: context,
        outputs: outputs,
        isElectron: isDiffElectron,
        conversionLines: conversionLines,
      );
    }
    
    if (!isDriftElectron && !isDriftHole) {
      // Fallback: if this is an unhandled carrier transport fundamental, default to universal steps
      // so canonical IDs don't surface missing-template warnings.
      if (formula.id.startsWith('ct_f')) {
        return _buildUniversalSteps(
          formula: formula,
          solveFor: solveFor,
          context: context,
          outputs: outputs,
          conversionLines: conversionLines,
        );
      }
      return null;
    }
    
    final isElectron = isDriftElectron;
    final isHole = isDriftHole;

    final vKey = isElectron ? 'v_dn' : 'v_dp';
    final muKey = isElectron ? 'mu_n' : 'mu_p';
    const eKey = 'E_field';
    final sign = isElectron ? '-' : '';

    final vSym = _latexLabel(vKey);
    final muSym = _latexLabel(muKey);
    final eSym = _latexLabel(eKey);

    final baseEq = '$vSym = ${sign.isEmpty ? '' : sign}$muSym $eSym';

    final fmt6 = _formatter.withSigFigs(6);
    final fmt3 = _formatter;

    final vVal = context.getSymbolValue(vKey);
    final muVal = context.getSymbolValue(muKey);
    final eVal = context.getSymbolValue(eKey);

    final substitutionMap = <String, String>{};
    if (vVal != null) substitutionMap[vKey] = fmt6.formatLatexWithUnit(vVal.value, vVal.unit.isNotEmpty ? vVal.unit : 'm/s');
    if (muVal != null) substitutionMap[muKey] = fmt6.formatLatexWithUnit(muVal.value, muVal.unit.isNotEmpty ? muVal.unit : 'm^2/(V*s)');
    if (eVal != null) substitutionMap[eKey] = fmt6.formatLatexWithUnit(eVal.value, eVal.unit.isNotEmpty ? eVal.unit : 'V/m');

    final substitutionEq = buildSubstitutionEquation(
      equationLatex: baseEq,
      latexMap: _latexMap,
      substitutionMap: substitutionMap,
      wrapValuesWithParens: true,
    );

    final result = outputs[solveFor];
    final targetLatex = _latexLabel(solveFor);
    final computedLine = result != null
        ? '$targetLatex = ${fmt6.formatLatexWithUnit(result.value, result.unit)}'
        : targetLatex;
    final roundedLine = result != null
        ? '$targetLatex = ${fmt3.formatLatexWithUnit(result.value, result.unit)}'
        : targetLatex;

    final rearrangeLines = <String>[];
    if (solveFor == muKey) {
      rearrangeLines.add('$muSym = ${sign.isEmpty ? '' : sign}\\dfrac{${vSym}}{${eSym}}');
    } else if (solveFor == eKey) {
      final ratio = sign.isEmpty ? '\\dfrac{${vSym}}{${muSym}}' : '${sign}\\dfrac{${vSym}}{${muSym}}';
      rearrangeLines.add('$eSym = $ratio');
    }

    final substitutionLines = <String>[
      baseEq,
      substitutionEq,
      if (computedLine.isNotEmpty) computedLine,
    ];

    return UniversalStepTemplate.build(
      targetLabelLatex: targetLatex,
      unitConversionLines: conversionLines,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: computedLine,
      computedValueLine: computedLine,
      roundedValueLine: roundedLine,
    );
  }

  List<StepItem>? _buildEinsteinRelationSteps({
    required bool isElectron,
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required List<String> conversionLines,
  }) {
    final dKey = isElectron ? 'D_n' : 'D_p';
    final muKey = isElectron ? 'mu_n' : 'mu_p';
    const tKey = 'T';

    // Only handle Einstein relation targets
    if (solveFor != dKey && solveFor != muKey && solveFor != tKey) {
      return null;
    }

    final fmt6 = _formatter.withSigFigs(6);
    final fmt3 = _formatter;

    final dSym = _latexLabel(dKey);
    final muSym = _latexLabel(muKey);
    final tSym = _latexLabel(tKey);
    final kSym = _latexLabel('k');
    final qSym = _latexLabel('q');

    final baseEq = '$dSym = $muSym \\frac{$kSym $tSym}{$qSym}';

    String rearranged;
    if (solveFor == dKey) {
      rearranged = baseEq;
    } else if (solveFor == muKey) {
      rearranged = '$muSym = \\dfrac{$dSym $qSym}{$kSym $tSym}';
    } else {
      rearranged = '$tSym = \\dfrac{$dSym $qSym}{$kSym $muSym}';
    }

    String _fmt(SymbolValue? v, String key, String defaultUnit) {
      if (v == null) return '';
      final unit = v.unit.isNotEmpty ? v.unit : defaultUnit;
      return fmt6.formatLatexWithUnit(v.value, unit);
    }

    final substitutionMap = <String, String>{};
    void addIfKnown(String key, String defaultUnit) {
      if (key == solveFor) return; // keep target symbolic
      final val = context.getSymbolValue(key);
      if (val == null) return;
      substitutionMap[key] = _fmt(val, key, defaultUnit);
    }

    addIfKnown(dKey, 'm^2/s');
    addIfKnown(muKey, 'm^2/(V*s)');
    addIfKnown(tKey, 'K');
    addIfKnown('k', 'J/K');
    addIfKnown('q', 'C');

    final substituted = buildSubstitutionEquation(
      equationLatex: rearranged,
      latexMap: _latexMap,
      substitutionMap: substitutionMap,
      wrapValuesWithParens: true,
      debugLabel: 'einstein:${isElectron ? 'electron' : 'hole'}:$solveFor',
    );

    final substitutionLines = <String>[
      rearranged,
      substituted,
    ];

    final result = outputs[solveFor];
    final targetLatex = _latexLabel(solveFor);
    final computedLine = result != null
        ? (result.unit.isNotEmpty
            ? '$targetLatex = ${fmt6.formatLatexWithUnit(result.value, result.unit)}'
            : '$targetLatex = ${fmt6.formatLatex(result.value)}')
        : targetLatex;
    final roundedLine = result != null
        ? (result.unit.isNotEmpty
            ? '$targetLatex = ${fmt3.formatLatexWithUnit(result.value, result.unit)}'
            : '$targetLatex = ${fmt3.formatLatex(result.value)}')
        : targetLatex;

    return UniversalStepTemplate.build(
      targetLabelLatex: targetLatex,
      unitConversionLines: conversionLines,
      rearrangeLines: [rearranged],
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: computedLine,
      computedValueLine: computedLine,
      roundedValueLine: roundedLine,
    );
  }

  List<StepItem>? _buildDiffusionCurrentSteps({
    required FormulaDefinition formula,
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
    required bool isElectron,
    required List<String> conversionLines,
  }) {
    // Formula: J = q D (dn/dx) for electrons, J = -q D (dp/dx) for holes
    final jKey = isElectron ? 'J_n_diff' : 'J_p_diff';
    final dKey = isElectron ? 'D_n' : 'D_p';
    final gradKey = isElectron ? 'dn_dx' : 'dp_dx';
    final sign = isElectron ? '' : '-';
    
    // Get LaTeX symbols
    final jSym = _latexLabel(jKey);
    final dSym = _latexLabel(dKey);
    final gradSym = _latexLabel(gradKey);
    final qSym = _latexLabel('q');
    
    final fmt6 = _formatter.withSigFigs(6);
    final fmt3 = _formatter;
    
    // Get values (including constants with full precision)
    final jVal = context.getSymbolValue(jKey);
    final dVal = context.getSymbolValue(dKey);
    final gradVal = context.getSymbolValue(gradKey);
    final qVal = context.getSymbolValue('q'); // Use full-precision constant from context
    
    // Build base equation
    final baseEq = '$jSym = ${sign}$qSym $dSym $gradSym';
    
    // Build rearrangement based on target
    final rearrangeLines = <String>[];
    if (solveFor == dKey) {
      // Solving for D: D = J / (q * gradient)
      rearrangeLines.add(baseEq);
      rearrangeLines.add('$dSym = \\dfrac{$jSym}{${sign}$qSym $gradSym}');
    } else if (solveFor == gradKey) {
      // Solving for gradient: dn/dx = J / (q * D)
      rearrangeLines.add(baseEq);
      rearrangeLines.add('$gradSym = \\dfrac{$jSym}{${sign}$qSym $dSym}');
    } else {
      // Solving for J (already isolated)
      rearrangeLines.add(baseEq);
    }
    
    // Build substitution lines with FULL numeric values
    final substitutionLines = <String>[];
    
    // Format helper with full precision
    String _fmt(SymbolValue? val, String key, String defaultUnit) {
      if (val == null) return _latexLabel(key);
      final unit = val.unit.isNotEmpty ? val.unit : defaultUnit;
      return '(' + fmt6.formatLatexWithUnit(val.value, unit) + ')';
    }
    
    final jFmt = _fmt(jVal, jKey, 'A/m^2');
    final dFmt = _fmt(dVal, dKey, 'm^2/s');
    final gradFmt = _fmt(gradVal, gradKey, 'm^-4');
    final qFmt = _fmt(qVal, 'q', 'C'); // Full-precision q
    
    // Build substituted equation based on target
    if (solveFor == jKey) {
      // J = q D (dn/dx)
      substitutionLines.add('$jSym = ${sign}$qSym $dSym $gradSym');
      substitutionLines.add('$jSym = ${sign}$qFmt $dFmt $gradFmt');
    } else if (solveFor == dKey) {
      // D = J / (q * gradient)
      substitutionLines.add('$dSym = \\dfrac{$jSym}{${sign}$qSym $gradSym}');
      substitutionLines.add('$dSym = \\dfrac{$jFmt}{${sign}$qFmt $gradFmt}');
    } else {
      // gradient = J / (q * D)
      substitutionLines.add('$gradSym = \\dfrac{$jSym}{${sign}$qSym $dSym}');
      substitutionLines.add('$gradSym = \\dfrac{$jFmt}{${sign}$qFmt $dFmt}');
    }
    
    // Compute evaluation line
    final result = outputs[solveFor];
    final targetLatex = _latexLabel(solveFor);
    final computedLine = result != null
        ? '$targetLatex = ${fmt6.formatLatexWithUnit(result.value, result.unit)}'
        : targetLatex;
    final roundedLine = result != null
        ? '$targetLatex = ${fmt3.formatLatexWithUnit(result.value, result.unit)}'
        : targetLatex;
    
    return UniversalStepTemplate.build(
      targetLabelLatex: targetLatex,
      unitConversionLines: conversionLines,
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: computedLine,
      computedValueLine: computedLine,
      roundedValueLine: roundedLine,
    );
  }

  List<StepItem>? _buildPnBuiltInPotentialSteps({
    required FormulaDefinition formula,
    required String solveFor,
    required SymbolContext context,
    required Map<String, SymbolValue> outputs,
  }) {
    if (formula.id != 'pn_built_in_potential') return null;

    final vb = _latexLabel('V_bi');
    final kSym = _latexLabel('k');
    final tSym = _latexLabel('T');
    final qSym = _latexLabel('q');
    final naSym = _latexLabel('N_A');
    final ndSym = _latexLabel('N_D');
    final niSym = _latexLabel('n_i');
    final targetLatex = _latexLabel(solveFor);

    final baseEq = '$vb = \\frac{$kSym $tSym}{$qSym} \\ln\\left(\\frac{$naSym $ndSym}{${niSym}^{2}}\\right)';

    String rearranged;
    if (solveFor == 'V_bi') {
      rearranged = baseEq;
    } else if (solveFor == 'N_A') {
      rearranged = '$naSym = \\frac{{${niSym}}^{2}}{$ndSym}\\exp\\left(\\frac{$qSym $vb}{$kSym $tSym}\\right)';
    } else if (solveFor == 'N_D') {
      rearranged = '$ndSym = \\frac{{${niSym}}^{2}}{$naSym}\\exp\\left(\\frac{$qSym $vb}{$kSym $tSym}\\right)';
    } else if (solveFor == 'n_i') {
      rearranged = '$niSym = \\sqrt{$naSym $ndSym}\\,\\exp\\left(-\\frac{$qSym $vb}{2 $kSym $tSym}\\right)';
    } else if (solveFor == 'T') {
      rearranged = '$tSym = \\frac{$vb $qSym}{$kSym \\ln\\left(\\frac{$naSym $ndSym}{{${niSym}}^{2}}\\right)}';
    } else {
      // For any unexpected target, fall back to base equation.
      rearranged = baseEq;
    }

    String _formatFull(SymbolValue? v, {String? defaultUnit}) {
      if (v == null) return '';
      final unit = v.unit.isNotEmpty ? v.unit : (defaultUnit ?? '');
      return unit.isNotEmpty
          ? _formatter.formatLatexWithUnitFullPrecision(v.value, unit)
          : _formatter.formatLatexFullPrecision(v.value);
    }

    final substitutionMap = <String, String>{};
    context.getAll().forEach((key, val) {
      substitutionMap[key] = _formatFull(val);
    });
    // Include outputs (if already computed) so they can appear in substitution when solving inverses.
    outputs.forEach((key, val) {
      substitutionMap[key] = _formatFull(val);
    });

    final substitutionEq = buildSubstitutionEquation(
      equationLatex: rearranged,
      latexMap: _latexMap,
      substitutionMap: substitutionMap,
      wrapValuesWithParens: true,
      debugLabel: 'pn_built_in_potential:$solveFor',
    );

    final fmt6 = _formatter.withSigFigs(6);
    final fmt3 = _formatter;
    final result = outputs[solveFor];
    final computedLine = result != null
        ? '$targetLatex = ${(result.unit.isNotEmpty ? _formatter.formatLatexWithUnitFullPrecision(result.value, result.unit) : _formatter.formatLatexFullPrecision(result.value))}'
        : targetLatex;
    final roundedLine = result != null
        ? '$targetLatex = ${(result.unit.isNotEmpty ? fmt3.formatLatexWithUnit(result.value, result.unit) : fmt3.formatLatex(result.value))}'
        : targetLatex;

    final rearrangeLines = <String>[];
    if (solveFor != 'V_bi') {
      rearrangeLines.add(rearranged);
    }

    final substitutionLines = <String>[
      baseEq,
      rearranged,
      substitutionEq,
    ];

    return UniversalStepTemplate.build(
      targetLabelLatex: targetLatex,
      unitConversionLines: const [],
      rearrangeLines: rearrangeLines,
      substitutionLines: substitutionLines,
      substitutionEvaluationLine: computedLine,
      computedValueLine: computedLine,
      roundedValueLine: roundedLine,
    );
  }

  List<String> _rearrangeLines(FormulaDefinition formula, String solveFor) {
    final id = formula.id;
    if (id == 'ct_f1_electron_drift_velocity') {
      final v = _latexLabel('v_dn');
      final mu = _latexLabel('mu_n');
      final e = _latexLabel('E_field');
      if (solveFor == 'mu_n') return ['$mu = -\\dfrac{$v}{$e}'];
      if (solveFor == 'E_field') return ['$e = -\\dfrac{$v}{$mu}'];
    } else if (id == 'ct_f2_hole_drift_velocity') {
      final v = _latexLabel('v_dp');
      final mu = _latexLabel('mu_p');
      final e = _latexLabel('E_field');
      if (solveFor == 'mu_p') return ['$mu = \\dfrac{$v}{$e}'];
      if (solveFor == 'E_field') return ['$e = \\dfrac{$v}{$mu}'];
    }
    return const [];
  }
}
