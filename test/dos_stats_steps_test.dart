import 'package:flutter_test/flutter_test.dart';

import 'package:semiconductor_appv2/core/constants/constants_loader.dart';
import 'package:semiconductor_appv2/core/constants/constants_repository.dart';
import 'package:semiconductor_appv2/core/formulas/formula_repository.dart';
import 'package:semiconductor_appv2/core/models/workspace.dart';
import 'package:semiconductor_appv2/core/solver/formula_solver.dart';
import 'package:semiconductor_appv2/core/solver/step_latex_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DOS & Statistics steps', () {
    late ConstantsRepository constants;
    late FormulaRepository formulas;
    late FormulaSolver solver;
    late dynamic latexMap;

    setUpAll(() async {
      constants = ConstantsRepository();
      await constants.load();
      formulas = FormulaRepository();
      await formulas.preloadAll();
      solver = FormulaSolver(formulaRepo: formulas, constantsRepo: constants);
      latexMap = await ConstantsLoader.loadLatexSymbols();
    });

    test('Nc builder uses three sections and LaTeX density units', () {
      final result = solver.solve(
        formulaId: 'dos_Nc_effective_density_conduction',
        solveFor: 'N_c',
        workspaceGlobals: const {},
        panelOverrides: const {
          'm_n_star': SymbolValue(value: 9.11e-31, unit: 'kg', source: SymbolSource.user),
          'T': SymbolValue(value: 300.0, unit: 'K', source: SymbolSource.user),
          '__meta__density_unit': SymbolValue(value: 0, unit: 'cm^-3', source: SymbolSource.computed),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final items = result.stepsLatex!.workingItems;
      final titles = items.where((i) => i.type == StepItemType.text).map((i) => i.value).toList();
      expect(
        titles,
        containsAllInOrder([
          'Step 1 - Unit Conversion',
          'Step 3 - Substitute known values',
          'Step 4 - Computed Value',
          'Rounded off to 3 s.f.',
        ]),
      );
      final math = items.where((i) => i.type == StepItemType.math).map((i) => i.latex).join(' ');
      expect(math, contains(r'\textbf{Step 2 - Rearrange to solve for }N_{c}'));
      expect(math, contains(r'\mathrm{m^{-3}}'));
      expect(math, contains(r'\times 10^{'));
      expect(math.contains('m_n_star'), isFalse);
      expect(math.contains(r'\frac('), isFalse);
    });

    test('Nv builder renders without raw keys and uses braced fractions', () {
      final result = solver.solve(
        formulaId: 'dos_Nv_effective_density_valence',
        solveFor: 'N_v',
        workspaceGlobals: const {},
        panelOverrides: const {
          'm_p_star': SymbolValue(value: 5.0e-31, unit: 'kg', source: SymbolSource.user),
          'T': SymbolValue(value: 350.0, unit: 'K', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final titles = result.stepsLatex!.workingItems.where((i) => i.type == StepItemType.text).map((i) => i.value).toList();
      expect(
        titles,
        containsAllInOrder([
          'Step 1 - Unit Conversion',
          'Step 3 - Substitute known values',
          'Step 4 - Computed Value',
          'Rounded off to 3 s.f.',
        ]),
      );
      final math = result.stepsLatex!.workingItems.where((i) => i.type == StepItemType.math).map((i) => i.latex).join(' ');
      expect(math, contains(r'\textbf{Step 2 - Rearrange to solve for }N_{v}'));
      expect(math.contains('m_p_star'), isFalse);
      expect(math.contains(r'\frac('), isFalse);
      expect(math, contains(r'\mathrm{kg}'));
      expect(math, contains(r'\mathrm{K}'));
    });

    test('Fermi-Dirac builder converts eV to J in substitution', () {
      final result = solver.solve(
        formulaId: 'dos_fermi_dirac_probability',
        solveFor: 'E_F',
        workspaceGlobals: const {},
        panelOverrides: const {
          'f_E': SymbolValue(value: 0.5, unit: '1', source: SymbolSource.user),
          'E': SymbolValue(value: 0.1, unit: 'eV', source: SymbolSource.user),
          'T': SymbolValue(value: 300.0, unit: 'K', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final items = result.stepsLatex!.workingItems;
      final titles = items.where((i) => i.type == StepItemType.text).map((i) => i.value).toList();
      expect(
        titles,
        containsAllInOrder([
          'Step 1 - Unit Conversion',
          'Step 3 - Substitute known values',
          'Step 4 - Computed Value',
          'Rounded off to 3 s.f.',
        ]),
      );
      final math = items.where((i) => i.type == StepItemType.math).map((i) => i.latex).join(' ');
      expect(math, contains(r'\textbf{Step 2 - Rearrange to solve for }E_{F}'));
      expect(math, contains(r'\mathrm{eV}'));
      expect(math, contains(r'\mathrm{J}'));
    });

    test('Midgap energy shows primary and secondary energy units', () {
      final result = solver.solve(
        formulaId: 'dos_stats_midgap_energy',
        solveFor: 'E_mid',
        workspaceGlobals: const {},
        panelOverrides: const {
          'E_c': SymbolValue(value: 1.2, unit: 'eV', source: SymbolSource.user),
          'E_v': SymbolValue(value: 0.2, unit: 'eV', source: SymbolSource.user),
          '__meta__E_unit': SymbolValue(value: 0, unit: 'eV', source: SymbolSource.computed),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final items = result.stepsLatex!.workingItems;
      final titles = items.where((i) => i.type == StepItemType.text).map((i) => i.value).toList();
      expect(
        titles,
        containsAllInOrder([
          'Step 1 - Unit Conversion',
          'Step 3 - Substitute known values',
          'Step 4 - Computed Value',
          'Rounded off to 3 s.f.',
        ]),
      );
      final resultLine = items.lastWhere((i) => i.type == StepItemType.math).latex;
      final math = items.where((i) => i.type == StepItemType.math).map((i) => i.latex).join(' ');
      expect(math, contains(r'\textbf{Step 2 - Rearrange to solve for }E_{mid}'));
      expect(resultLine, contains(r'\mathrm{eV}'));
      expect(resultLine, contains(r'\mathrm{J}'));
    });

    test('Fermi-Dirac: solve for T shows full derivation and numeric substitution in eV', () {
      final result = solver.solve(
        formulaId: 'dos_fermi_dirac_probability',
        solveFor: 'T',
        workspaceGlobals: const {},
        panelOverrides: const {
          '__meta__E_unit': SymbolValue(value: 0, unit: 'eV', source: SymbolSource.computed),
          'f_E': SymbolValue(value: 0.1262991, unit: '1', source: SymbolSource.user),
          'E': SymbolValue(value: 0.250000, unit: 'eV', source: SymbolSource.user),
          'E_F': SymbolValue(value: 0.200000, unit: 'eV', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final items = result.stepsLatex!.workingItems;
      final math = items.where((i) => i.type == StepItemType.math).map((i) => i.latex).join(' ');

      // Step 1: no unit conversion message aligned with eV evaluation
      expect(math, contains(r'\text{No unit conversion required (using eV).}'));

      // Step 2: full rearrangement chain present
      expect(math, contains(r'\frac{1}{f(E)}=1+\exp'));
      expect(math, contains(r'\frac{1}{f(E)}-1=\exp'));
      expect(math, contains(r'\ln\left(\frac{1}{f(E)}-1\right)=\frac{E-E_F}{kT}'));
      expect(math, contains(r'T=\frac{E-E_F}{k\,\ln\left(\frac{1}{f(E)}-1\right)}'));

      // Step 3: numeric intermediates and final substitution
      expect(math, contains(r'f(E)=0.1262991'));
      expect(math, contains(r'E = 0.2500000'));
      expect(math, contains(r'E_F = 0.2000000'));
      expect(math, contains(r'(E-E_F)=0.0500000'));
      expect(math, contains(r'\frac{1}{f(E)}-1=6.9177128'));
      expect(math, contains(r'\ln\left(\frac{1}{f(E)}-1\right)=1.9340852'));
      expect(math, contains(r'T = \frac{0.0500000'));
      expect(math, contains(r')=300.000'));

      // Step 4: still rounded to 3 s.f.
      final roundedLine = items.lastWhere((i) => i.type == StepItemType.math).latex;
      expect(roundedLine, contains(r'T = 300'));
    });

    test('Intrinsic carrier: solve for N_v shows step-by-step algebraic rearrangement', () {
      final result = solver.solve(
        formulaId: 'intrinsic_concentration_from_dos',
        solveFor: 'N_v',
        workspaceGlobals: const {},
        panelOverrides: const {
          'n_i': SymbolValue(value: 1.0e16, unit: 'm^-3', source: SymbolSource.user),
          'N_c': SymbolValue(value: 2.8e25, unit: 'm^-3', source: SymbolSource.user),
          'E_g': SymbolValue(value: 1.12, unit: 'eV', source: SymbolSource.user),
          'T': SymbolValue(value: 300.0, unit: 'K', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final items = result.stepsLatex!.workingItems;
      final math = items.where((i) => i.type == StepItemType.math).map((i) => i.latex).join(' ');

      // Step 2: verify all intermediate rearrangement steps are present
      expect(math, contains(r'n_i^{2} = N_c N_v\, \exp\left(\frac{-E_g}{kT}\right)'));
      expect(math, contains(r'\frac{n_i^{2}}{N_c} = N_v\, \exp\left(\frac{-E_g}{kT}\right)'));
      expect(math, contains(r'\frac{n_i^{2}}{N_c\, \exp\left(\frac{-E_g}{kT}\right)} = N_v'));
      expect(math, contains(r'N_v = \frac{n_i^{2}}{N_c\, \exp\left(\frac{-E_g}{kT}\right)}'));

      // Step 3: verify intermediate calculations are shown
      expect(math, contains(r'kT = '));
      expect(math, contains(r'\frac{-E_g}{kT} = '));

      // Step 3: verify substitution uses bracketed values and \exp\left(...\right) format
      // Note: The LaTeX output uses subscripted symbols like N_{v} not N_v
      expect(math, contains(r'N_{v} = \frac{('));
      expect(math, contains(r')^{2}'));
      expect(math, contains(r')\exp\left(\frac{-'));
      
      // Verify proper LaTeX formatting with \exp\left ... \right
      expect(math, contains(r'\exp\left('));
      expect(math.contains(r'\exp'), isTrue);
      
      // Verify units are formatted with \mathrm
      expect(math, contains(r'\mathrm{m}^{-3}'));
      expect(math, contains(r'\mathrm{J}'));
    });

    test('Intrinsic carrier: solve for N_c shows step-by-step algebraic rearrangement', () {
      final result = solver.solve(
        formulaId: 'intrinsic_concentration_from_dos',
        solveFor: 'N_c',
        workspaceGlobals: const {},
        panelOverrides: const {
          'n_i': SymbolValue(value: 1.0e16, unit: 'm^-3', source: SymbolSource.user),
          'N_v': SymbolValue(value: 1.0e25, unit: 'm^-3', source: SymbolSource.user),
          'E_g': SymbolValue(value: 1.12, unit: 'eV', source: SymbolSource.user),
          'T': SymbolValue(value: 300.0, unit: 'K', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final items = result.stepsLatex!.workingItems;
      final math = items.where((i) => i.type == StepItemType.math).map((i) => i.latex).join(' ');

      // Step 2: verify all intermediate rearrangement steps are present
      expect(math, contains(r'n_i^{2} = N_c N_v\, \exp\left(\frac{-E_g}{kT}\right)'));
      expect(math, contains(r'\frac{n_i^{2}}{N_v} = N_c\, \exp\left(\frac{-E_g}{kT}\right)'));
      expect(math, contains(r'\frac{n_i^{2}}{N_v\, \exp\left(\frac{-E_g}{kT}\right)} = N_c'));
      expect(math, contains(r'N_c = \frac{n_i^{2}}{N_v\, \exp\left(\frac{-E_g}{kT}\right)}'));

      // Step 3: verify intermediate calculations and bracketed substitution
      expect(math, contains(r'kT = '));
      expect(math, contains(r'\frac{-E_g}{kT} = '));
      expect(math, contains(r'N_{c} = \frac{('));
      expect(math, contains(r')^{2}'));
      expect(math, contains(r')\exp\left(\frac{-'));
    });

    test('Intrinsic Fermi level: solve for E_mid shows step-by-step algebraic rearrangement', () {
      final result = solver.solve(
        formulaId: 'dos_stats_intrinsic_fermi_level',
        solveFor: 'E_mid',
        workspaceGlobals: const {},
        panelOverrides: const {
          'E_i': SymbolValue(value: 0.56, unit: 'eV', source: SymbolSource.user),
          'm_p_star': SymbolValue(value: 0.81e-30, unit: 'kg', source: SymbolSource.user),
          'm_n_star': SymbolValue(value: 0.26e-30, unit: 'kg', source: SymbolSource.user),
          'T': SymbolValue(value: 300.0, unit: 'K', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final items = result.stepsLatex!.workingItems;
      final math = items.where((i) => i.type == StepItemType.math).map((i) => i.latex).join(' ');

      // Step 2: verify all intermediate rearrangement steps are present
      expect(math, contains(r'E_i = E_{\mathrm{mid}} + \frac{3}{4} k T \ln\left(\frac{m_p^{*}}{m_n^{*}}\right)'));
      expect(math, contains(r'E_i - \frac{3}{4} k T \ln\left(\frac{m_p^{*}}{m_n^{*}}\right) = E_{\mathrm{mid}}'));
      expect(math, contains(r'E_{\mathrm{mid}} = E_i - \frac{3}{4} k T \ln\left(\frac{m_p^{*}}{m_n^{*}}\right)'));

      // Step 3: verify intermediate calculations
      expect(math, contains(r'\frac{3}{4}kT = '));
      expect(math, contains(r'\ln\left(\frac{m_p^{*}}{m_n^{*}}\right) = '));

      // Step 3: verify bracketed substitution
      expect(math, contains(r'E_{mid} = ('));
      expect(math, contains(r') - \frac{3}{4}'));
      expect(math, contains(r'\ln\left(\frac{'));
    });

    test('Intrinsic Fermi level: solve for T shows detailed rearrangement steps', () {
      final result = solver.solve(
        formulaId: 'dos_stats_intrinsic_fermi_level',
        solveFor: 'T',
        workspaceGlobals: const {},
        panelOverrides: const {
          'E_i': SymbolValue(value: 0.56, unit: 'eV', source: SymbolSource.user),
          'E_mid': SymbolValue(value: 0.55, unit: 'eV', source: SymbolSource.user),
          'm_p_star': SymbolValue(value: 0.81e-30, unit: 'kg', source: SymbolSource.user),
          'm_n_star': SymbolValue(value: 0.26e-30, unit: 'kg', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final items = result.stepsLatex!.workingItems;
      final math = items.where((i) => i.type == StepItemType.math).map((i) => i.latex).join(' ');

      // Step 2: verify all intermediate rearrangement steps are present
      expect(math, contains(r'E_i = E_{\mathrm{mid}} + \frac{3}{4} k T \ln\left(\frac{m_p^{*}}{m_n^{*}}\right)'));
      expect(math, contains(r'E_i - E_{\mathrm{mid}} = \frac{3}{4} k T \ln\left(\frac{m_p^{*}}{m_n^{*}}\right)'));
      expect(math, contains(r'\frac{E_i - E_{\mathrm{mid}}}{\frac{3}{4}k \ln\left(\frac{m_p^{*}}{m_n^{*}}\right)} = T'));
      expect(math, contains(r'T = \frac{E_i - E_{\mathrm{mid}}}{\frac{3}{4}k \ln\left(\frac{m_p^{*}}{m_n^{*}}\right)}'));
    });

    test('Intrinsic Fermi level: solve for m_p_star shows detailed rearrangement with exp steps', () {
      final result = solver.solve(
        formulaId: 'dos_stats_intrinsic_fermi_level',
        solveFor: 'm_p_star',
        workspaceGlobals: const {},
        panelOverrides: const {
          'E_i': SymbolValue(value: 0.56, unit: 'eV', source: SymbolSource.user),
          'E_mid': SymbolValue(value: 0.55, unit: 'eV', source: SymbolSource.user),
          'm_n_star': SymbolValue(value: 0.26e-30, unit: 'kg', source: SymbolSource.user),
          'T': SymbolValue(value: 300.0, unit: 'K', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final items = result.stepsLatex!.workingItems;
      final math = items.where((i) => i.type == StepItemType.math).map((i) => i.latex).join(' ');

      // Step 2: verify all intermediate rearrangement steps including exp transformation
      expect(math, contains(r'E_i = E_{\mathrm{mid}} + \frac{3}{4} k T \ln\left(\frac{m_p^{*}}{m_n^{*}}\right)'));
      expect(math, contains(r'E_i - E_{\mathrm{mid}} = \frac{3}{4} k T \ln\left(\frac{m_p^{*}}{m_n^{*}}\right)'));
      expect(math, contains(r'\frac{E_i - E_{\mathrm{mid}}}{\frac{3}{4} k T} = \ln\left(\frac{m_p^{*}}{m_n^{*}}\right)'));
      expect(math, contains(r'\exp\left(\frac{E_i - E_{\mathrm{mid}}}{\frac{3}{4} k T}\right) = \frac{m_p^{*}}{m_n^{*}}'));
      expect(math, contains(r'm_p^{*} = m_n^{*} \exp\left(\frac{4}{3}\frac{E_i - E_{\mathrm{mid}}}{kT}\right)'));
    });
  });
}
