import 'package:flutter_test/flutter_test.dart';
import 'package:semiconductor_appv2/core/constants/constants_loader.dart';
import 'package:semiconductor_appv2/core/constants/constants_repository.dart';
import 'package:semiconductor_appv2/core/constants/latex_symbols.dart';
import 'package:semiconductor_appv2/core/formulas/formula_repository.dart';
import 'package:semiconductor_appv2/core/models/workspace.dart';
import 'package:semiconductor_appv2/core/solver/formula_solver.dart';
import 'package:semiconductor_appv2/core/solver/step_latex_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PN Junction - Depletion partition (x_n / x_p)', () {
    late FormulaRepository formulas;
    late ConstantsRepository constants;
    late FormulaSolver solver;
    late LatexSymbolMap latexMap;

    setUpAll(() async {
      formulas = FormulaRepository();
      await formulas.preloadAll();

      constants = ConstantsRepository();
      await constants.load();

      solver = FormulaSolver(formulaRepo: formulas, constantsRepo: constants);
      latexMap = await ConstantsLoader.loadLatexSymbols();
    });

    test('n-side: solve for N_A with valid domain', () {
      const xn = 1.2e-7; // m
      const nd = 1e22; // m^-3
      const w = 6e-7; // m
      final expectedNa = (xn * nd) / (w - xn);

      final result = solver.solve(
        formulaId: 'pn_depletion_width_xn',
        solveFor: 'N_A',
        workspaceGlobals: const {},
        panelOverrides: const {
          'x_n': SymbolValue(value: xn, unit: 'm', source: SymbolSource.user),
          'N_D': SymbolValue(value: nd, unit: 'm^-3', source: SymbolSource.user),
          'W': SymbolValue(value: w, unit: 'm', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['N_A']!.value, closeTo(expectedNa, expectedNa * 1e-6));

      final steps = result.stepsLatex!;
      final step2Math = _getStepMath(steps, 2);
      expect(step2Math.length, greaterThanOrEqualTo(5),
          reason: 'Step 2 should show multi-line rearrangement trace.');
      expect(step2Math.last, contains(r'N_{A} = \frac{x_{n} N_{D}}{W - x_{n}}'));
    });

    test('p-side: solve for N_A with valid domain', () {
      const xp = 1.2e-7; // m
      const nd = 1e22; // m^-3
      const w = 6e-7; // m
      final expectedNa = ((w - xp) * nd) / xp;

      final result = solver.solve(
        formulaId: 'pn_depletion_width_xp',
        solveFor: 'N_A',
        workspaceGlobals: const {},
        panelOverrides: const {
          'x_p': SymbolValue(value: xp, unit: 'm', source: SymbolSource.user),
          'N_D': SymbolValue(value: nd, unit: 'm^-3', source: SymbolSource.user),
          'W': SymbolValue(value: w, unit: 'm', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['N_A']!.value, closeTo(expectedNa, expectedNa * 1e-6));

      final steps = result.stepsLatex!;
      final step2Math = _getStepMath(steps, 2);
      expect(step2Math.last, contains(r'N_{A} = \frac{(W - x_{p})N_{D}}{x_{p}}'));
    });

    test('division-by-zero when x_n = W surfaces clear error', () {
      const w = 6e-7;
      const xn = 6e-7;

      final result = solver.solve(
        formulaId: 'pn_depletion_width_xn',
        solveFor: 'N_A',
        workspaceGlobals: const {},
        panelOverrides: const {
          'x_n': SymbolValue(value: xn, unit: 'm', source: SymbolSource.user),
          'W': SymbolValue(value: w, unit: 'm', source: SymbolSource.user),
          'N_D': SymbolValue(value: 1e22, unit: 'm^-3', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.error);
      expect(result.errorMessage, contains('division by zero'));
      expect(result.errorMessage, contains('W - x_n'));
    });

    test('non-physical x_p > W surfaces physical-domain error', () {
      const w = 6e-7;
      const xp = 7e-7;

      final result = solver.solve(
        formulaId: 'pn_depletion_width_xp',
        solveFor: 'N_D',
        workspaceGlobals: const {},
        panelOverrides: const {
          'x_p': SymbolValue(value: xp, unit: 'm', source: SymbolSource.user),
          'W': SymbolValue(value: w, unit: 'm', source: SymbolSource.user),
          'N_A': SymbolValue(value: 1e22, unit: 'm^-3', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.error);
      expect(result.errorMessage, contains('No physical solution'));
      expect(result.errorMessage, contains('0 < x_p < W'));
    });

    test('solve for W still works (p-side)', () {
      const xp = 1.5e-7;
      const na = 2e22;
      const nd = 1e22;
      final expectedW = xp * (1 + na / nd);

      final result = solver.solve(
        formulaId: 'pn_depletion_width_xp',
        solveFor: 'W',
        workspaceGlobals: const {},
        panelOverrides: const {
          'x_p': SymbolValue(value: xp, unit: 'm', source: SymbolSource.user),
          'N_A': SymbolValue(value: na, unit: 'm^-3', source: SymbolSource.user),
          'N_D': SymbolValue(value: nd, unit: 'm^-3', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['W']!.value, closeTo(expectedW, expectedW * 1e-6));
    });
  });
}

List<String> _getStepMath(StepLatex steps, int stepNumber) {
  final items = steps.workingItems;
  final stepHeading = 'Step $stepNumber';

  final start = items.indexWhere(
    (item) =>
        (item.type == StepItemType.text && item.value.contains(stepHeading)) ||
        (item.type == StepItemType.math && item.latex.contains(stepHeading)),
  );

  if (start == -1) return const [];

  final nextStep = items.skip(start + 1).toList().indexWhere(
    (item) =>
        (item.type == StepItemType.text && item.value.startsWith('Step ')) ||
        (item.type == StepItemType.math && item.latex.contains(r'\textbf{Step')),
  );

  final end = nextStep == -1 ? items.length : start + 1 + nextStep;

  return items
      .sublist(start + 1, end)
      .where((item) => item.type == StepItemType.math)
      .map((e) => e.latex)
      .toList();
}
