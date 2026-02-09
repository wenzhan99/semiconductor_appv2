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

  group('PN Junction - Depletion width (abrupt)', () {
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

    test('Solving for N_A shows rearrangement and full substitutions', () {
      const w = 3.31629e-7; // m
      const eps = 1.03534e-10; // F/m
      const vdep = 0.774; // V
      const nd = 1e22; // m^-3
      final q = constants.getConstantValue('q')!;
      final expectedNa = 1 / (((w * w * q) / (2 * eps * vdep)) - (1 / nd));

      final result = solver.solve(
        formulaId: 'pn_depletion_width',
        solveFor: 'N_A',
        workspaceGlobals: const {},
        panelOverrides: const {
          'W': SymbolValue(value: w, unit: 'm', source: SymbolSource.user),
          'eps_s': SymbolValue(value: eps, unit: 'F/m', source: SymbolSource.user),
          'V_dep': SymbolValue(value: vdep, unit: 'V', source: SymbolSource.user),
          'N_D': SymbolValue(value: nd, unit: 'm^-3', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['N_A']!.value, closeTo(expectedNa, expectedNa * 1e-6));

      final steps = result.stepsLatex;
      expect(steps, isNotNull);

      final step2Math = _getStepMath(steps!, 2);
      expect(step2Math, isNotEmpty, reason: 'Step 2 should show rearrangement for N_A');
      expect(
        step2Math.any((m) => m.contains(r'N_{A}') && m.contains(r'\dfrac')),
        isTrue,
        reason: 'Step 2 should display isolated N_A expression',
      );

      final step3Math = _getStepMath(steps, 3);
      final joinedStep3 = step3Math.join(' ');
      expect(joinedStep3.contains('1.03534'), isTrue,
          reason: 'Step 3 should substitute eps_s numeric value');
      expect(joinedStep3.contains(r'\mathrm{m}^{-3}'), isTrue,
          reason: 'Step 3 should include numeric N_D with units');
      expect(joinedStep3.contains('3.31629'), isTrue,
          reason: 'Step 3 should use the unrounded W value');
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
