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
          'Step 2 - Rearrange to solve for N_c',
          'Step 3 - Substitute known values',
          'Step 4 - Computed value',
          'Computed Value',
        ]),
      );

      final math = items.where((i) => i.type == StepItemType.math).map((i) => i.latex).join(' ');
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
          'Step 2 - Rearrange to solve for N_v',
          'Step 3 - Substitute known values',
          'Step 4 - Computed value',
          'Computed Value',
        ]),
      );
      final math = result.stepsLatex!.workingItems.where((i) => i.type == StepItemType.math).map((i) => i.latex).join(' ');
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
      final expectedTitles = [
        'Step 1 - Unit Conversion',
        'Step 2 - Rearrange to solve for E_F',
        'Step 3 - Substitute known values',
        'Step 4 - Computed value',
        'Computed Value',
      ];
      expect(titles, containsAllInOrder(expectedTitles));
      final math = items.where((i) => i.type == StepItemType.math).map((i) => i.latex).join(' ');
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
          'Step 2 - Rearrange to solve for E_mid',
          'Step 3 - Substitute known values',
          'Step 4 - Computed value',
          'Computed Value',
        ]),
      );
      final resultLine = items.lastWhere((i) => i.type == StepItemType.math).latex;
      expect(resultLine, contains(r'\mathrm{eV}'));
      expect(resultLine, contains(r'\mathrm{J}'));
    });
  });
}
