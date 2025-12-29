import 'package:flutter_test/flutter_test.dart';

import 'package:semiconductor_appv2/core/constants/constants_loader.dart';
import 'package:semiconductor_appv2/core/constants/constants_repository.dart';
import 'package:semiconductor_appv2/core/formulas/formula_repository.dart';
import 'package:semiconductor_appv2/core/models/workspace.dart';
import 'package:semiconductor_appv2/core/solver/formula_solver.dart';
import 'package:semiconductor_appv2/core/solver/step_latex_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Energy & Band Structure steps', () {
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

    test('Parabolic band dispersion solves for E with eV rendering', () {
      const k = 1.0e9; // m^-1
      const mStar = 9.11e-31; // kg

      final result = solver.solve(
        formulaId: 'parabolic_band_dispersion',
        solveFor: 'E',
        workspaceGlobals: const {},
        panelOverrides: const {
          'k': SymbolValue(value: k, unit: 'm^-1', source: SymbolSource.user),
          'm_star': SymbolValue(value: mStar, unit: 'kg', source: SymbolSource.user),
          '__meta__E_unit': SymbolValue(value: 0, unit: 'eV', source: SymbolSource.computed),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final working = result.stepsLatex?.workingItems ?? [];
      final titles = working.where((w) => w.type == StepItemType.text).map((w) => w.value).toList();
      expect(
        titles,
        containsAllInOrder([
          'Step 1 - Unit Conversion',
          'Step 2 - Rearrange to solve for E',
          'Step 3 - Substitute known values',
          'Step 4 - Computed value',
          'Computed Value',
        ]),
      );

      final mathLines = working.where((w) => w.type == StepItemType.math).map((w) => w.latex).join(' ');
      expect(mathLines, contains(r'\times 10^{'));
      expect(mathLines, contains(r'\mathrm{J}'));
      expect(mathLines, contains(r'\mathrm{eV}'));
    });

    test('Effective mass from curvature solves for d2E/dk2 with latex units', () {
      const mStar = 0.5 * 9.11e-31; // kg

      final result = solver.solve(
        formulaId: 'effective_mass_from_curvature',
        solveFor: 'd2E_dk2',
        workspaceGlobals: const {},
        panelOverrides: const {
          'm_star': SymbolValue(value: mStar, unit: 'kg', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final hbar = constants.getHbar();
      expect(hbar, isNotNull);

      final expected = (hbar! * hbar) / mStar;
      expect(result.outputs['d2E_dk2']!.value, closeTo(expected, expected * 1e-9));

      final mathLines = result.stepsLatex?.workingItems
              .where((w) => w.type == StepItemType.math)
              .map((w) => w.latex)
              .join(' ') ??
          '';
      final titles = result.stepsLatex?.workingItems.where((w) => w.type == StepItemType.text).map((w) => w.value).toList() ?? [];
      expect(
        titles,
        containsAllInOrder([
          'Step 1 - Unit Conversion',
          'Step 2 - Rearrange to solve for d2E_dk2',
          'Step 3 - Substitute known values',
          'Step 4 - Computed value',
          'Computed Value',
        ]),
      );
      expect(mathLines, contains(r'\mathrm{J\cdot m^{2}}'));
      expect(mathLines, contains(r'\times 10^{'));
    });
  });
}
