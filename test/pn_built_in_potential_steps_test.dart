import 'dart:math' as math;

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

  group('PN Junction - Built-in potential (solve for T)', () {
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

    test('Step 2 shows full rearrangement and Step 3 uses isolated substitution', () {
      const vbi = 0.799638; // V
      const na = 5.0e22; // m^-3
      const nd = 2.0e22; // m^-3
      const ni = 1.0e16; // m^-3

      final q = constants.getConstantValue('q')!;
      final k = constants.getConstantValue('k')!;
      final expectedT = (vbi * q) / (k * math.log((na * nd) / (ni * ni)));

      final result = solver.solve(
        formulaId: 'pn_built_in_potential',
        solveFor: 'T',
        workspaceGlobals: const {},
        panelOverrides: const {
          'V_bi': SymbolValue(value: vbi, unit: 'V', source: SymbolSource.user),
          'N_A': SymbolValue(value: na, unit: 'm^-3', source: SymbolSource.user),
          'N_D': SymbolValue(value: nd, unit: 'm^-3', source: SymbolSource.user),
          'n_i': SymbolValue(value: ni, unit: 'm^-3', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['T']!.value, closeTo(expectedT, expectedT * 1e-6));

      final steps = result.stepsLatex;
      expect(steps, isNotNull);

      final step2Math = _getStepMath(steps!, 2);
      expect(step2Math.length, greaterThanOrEqualTo(4),
          reason: 'Step 2 should show multiply, divide-by-k, and divide-by-ln operations.');
      expect(step2Math[0], contains(r'V_{bi} = \frac{k T}{q}'),
          reason: 'Step 2 should start from the base equation.');
      expect(step2Math[1], contains(r'q V_{bi} = k T \ln'),
          reason: 'Step 2 should multiply both sides by q.');
      expect(step2Math[2], contains(r'\frac{q V_{bi}}{k} = T \ln'),
          reason: 'Step 2 should divide by k.');
      expect(step2Math[3], contains(r'T = \frac{q V_{bi}}{k \ln'),
          reason: 'Step 2 should isolate T with ln term in the denominator.');

      final step3Math = _getStepMath(steps, 3);
      expect(step3Math.isNotEmpty, isTrue, reason: 'Step 3 should exist.');
      expect(step3Math.first, contains(r'T = \frac{q V_{bi}}{k \ln'),
          reason: 'Step 3 must begin with the isolated form for T.');
      expect(step3Math.any((m) => m.contains(r'\times 10^{-19}') && m.contains(r'\mathrm{C}')), isTrue,
          reason: 'Substitution should include q with units.');
      expect(step3Math.any((m) => m.contains(r'\times 10^{') && m.contains(r'\mathrm{m}^{-3}')), isTrue,
          reason: 'Substitution should include dopant concentrations with units.');
      expect(step3Math.every((m) => !m.startsWith(r'V_{bi} = \frac{k T}{q}')), isTrue,
          reason: 'Step 3 should not repeat the original equation.');

      final step4Math = _getStepMath(steps, 4);
      expect(step4Math.isNotEmpty, isTrue);
      expect(step4Math.first, contains(r'\mathrm{K}'),
          reason: 'Step 4 should report temperature in Kelvin.');
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
