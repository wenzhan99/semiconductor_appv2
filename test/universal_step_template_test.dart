import 'package:flutter_test/flutter_test.dart';
import 'package:semiconductor_appv2/core/constants/constants_loader.dart';
import 'package:semiconductor_appv2/core/constants/constants_repository.dart';
import 'package:semiconductor_appv2/core/constants/latex_symbols.dart';
import 'package:semiconductor_appv2/core/formulas/formula_repository.dart';
import 'package:semiconductor_appv2/core/solver/formula_solver.dart';
import 'package:semiconductor_appv2/core/solver/step_latex_builder.dart';
import 'package:semiconductor_appv2/core/models/workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Universal step template regression', () {
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

    test('Mass action law shows substitution in Step 3', () {
      final result = solver.solve(
        formulaId: 'mass_action_law',
        solveFor: 'n_i',
        workspaceGlobals: const {},
        panelOverrides: const {
          'n_0': SymbolValue(value: 1.8e21, unit: 'm^-3', source: SymbolSource.user),
          'p_0': SymbolValue(value: 5.6e10, unit: 'm^-3', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final step3 = _step3Math(result.stepsLatex);
      expect(step3.length, greaterThanOrEqualTo(2));
      expect(step3.any((line) => line.contains(r'\sqrt')), isTrue);
      expect(step3.any((line) => line.contains(r'\times 10^{')), isTrue);
    });

    test('Conductivity uses single substituted line in Step 3', () {
      final q = constants.getConstantValue('q')!;
      final result = solver.solve(
        formulaId: 'ct_f9_conductivity',
        solveFor: 'sigma',
        workspaceGlobals: const {},
        panelOverrides: const {
          'n': SymbolValue(value: 1e21, unit: 'm^-3', source: SymbolSource.user),
          'p': SymbolValue(value: 2e20, unit: 'm^-3', source: SymbolSource.user),
          'mu_n': SymbolValue(value: 0.12, unit: 'm^2/(V*s)', source: SymbolSource.user),
          'mu_p': SymbolValue(value: 0.04, unit: 'm^2/(V*s)', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final step3 = _step3Math(result.stepsLatex);
      expect(step3.length, 3);
      expect(step3[1], contains(r'\sigma'));
      expect(step3[1], contains(r'\sigma'));
      expect(step3[1], contains(r'\times 10^{'));
      expect(step3[1], contains(r'\mathrm{m^{-3}}'));

      // Evaluated line should match computed sigma value (within tolerance).
      final expectedSigma = q * ((1e21 * 0.12) + (2e20 * 0.04));
      expect(result.outputs['sigma']!.value, closeTo(expectedSigma, expectedSigma * 1e-6));
    });

    test('Einstein relation substitution contains kT/q term', () {
      final result = solver.solve(
        formulaId: 'ct_f7_einstein_relation_electrons',
        solveFor: 'D_n',
        workspaceGlobals: const {},
        panelOverrides: const {
          'mu_n': SymbolValue(value: 0.15, unit: 'm^2/(V*s)', source: SymbolSource.user),
          'T': SymbolValue(value: 300.0, unit: 'K', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final step3 = _step3Math(result.stepsLatex);
      expect(step3.length, 3);
      expect(step3[1], contains(r'\times 10^{'));
      expect(step3[1], contains(r'\mathrm{K}'));
    });
  });
}

List<String> _step3Math(StepLatex? steps) {
  if (steps == null) return const [];
  final items = steps.workingItems;
  final start = items.indexWhere(
    (item) => item.type == StepItemType.text && item.value.contains('Step 3'),
  );
  final end = items.indexWhere(
    (item) => item.type == StepItemType.text && item.value.contains('Step 4'),
  );
  if (start == -1 || end == -1 || end <= start) {
    return items.where((item) => item.type == StepItemType.math).map((e) => e.latex).toList();
  }
  return items
      .sublist(start + 1, end)
      .where((item) => item.type == StepItemType.math)
      .map((e) => e.latex)
      .toList();
}
