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

  group('PN Junction - Peak Electric Field (Charge Form)', () {
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

    test('N-side: solve for E_max with numerator/denominator breakdown', () {
      final q = constants.getConstantValue('q')!;
      const nd = 1e22; // m^-3
      const xn = 1e-6; // m (1 μm)
      const eps = 1.04e-10; // F/m (Si permittivity)
      final expectedEmax = (q * nd * xn) / eps;

      final result = solver.solve(
        formulaId: 'pn_peak_field_charge_form_n_side',
        solveFor: 'E_max',
        workspaceGlobals: const {},
        panelOverrides: const {
          'N_D': SymbolValue(value: nd, unit: 'm^-3', source: SymbolSource.user),
          'x_n': SymbolValue(value: xn, unit: 'm', source: SymbolSource.user),
          'eps_s': SymbolValue(value: eps, unit: 'F/m', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['E_max']!.value, closeTo(expectedEmax, expectedEmax * 1e-6));

      final steps = result.stepsLatex;
      expect(steps, isNotNull);

      // Verify Step 3 contains a single substituted fraction (no numerator/denominator split)
      final mathItems = steps!.workingItems
          .where((i) => i.type == StepItemType.math)
          .map((i) => i.latex)
          .toList();

      final allMath = mathItems.join(' ');
      expect(allMath.contains(r'\dfrac'), isTrue,
        reason: 'Step 3 should show substituted fraction');
      expect(allMath.contains('Numerator'), isFalse,
        reason: 'Numerator breakdown should not appear');
      expect(allMath.contains('Denominator'), isFalse,
        reason: 'Denominator breakdown should not appear');

      // Should substitute all values (no leftover N_D, x_n, eps_s symbols in numeric lines)
      final numericLines = mathItems.where((m) => m.contains(r'\times 10^{')).toList();
      expect(numericLines.length, greaterThanOrEqualTo(2),
        reason: 'Should have numeric substitution lines');
    });

    test('P-side: solve for N_A with full substitution', () {
      final q = constants.getConstantValue('q')!;
      const emax = 1.54e6; // V/m
      const xp = 1e-6; // m
      const eps = 1.04e-10; // F/m
      final expectedNA = (emax * eps) / (q * xp);

      final result = solver.solve(
        formulaId: 'pn_peak_field_charge_form_p_side',
        solveFor: 'N_A',
        workspaceGlobals: const {},
        panelOverrides: const {
          'E_max': SymbolValue(value: emax, unit: 'V/m', source: SymbolSource.user),
          'x_p': SymbolValue(value: xp, unit: 'm', source: SymbolSource.user),
          'eps_s': SymbolValue(value: eps, unit: 'F/m', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['N_A']!.value, closeTo(expectedNA, expectedNA * 1e-6));

      final steps = result.stepsLatex;
      expect(steps, isNotNull);

      final mathItems = steps!.workingItems
          .where((i) => i.type == StepItemType.math)
          .map((i) => i.latex)
          .toList();
      final allMath = mathItems.join(' ');

      // Should show a single substituted fraction (no numerator/denominator labels)
      expect(allMath.contains(r'\dfrac'), isTrue);
      expect(allMath.contains('Numerator'), isFalse);
      expect(allMath.contains('Denominator'), isFalse);

      // Step 2 should show rearrangement
      final step2Math = _getStepMath(steps, 2);
      expect(step2Math.any((m) => m.contains(r'N_{A}') && m.contains(r'\dfrac')), isTrue,
        reason: 'Step 2 should show N_A = ... rearrangement');
    });

    test('N-side: solve for x_n with full substitution', () {
      final q = constants.getConstantValue('q')!;
      const emax = 1.54e6; // V/m
      const nd = 1e22; // m^-3
      const eps = 1.04e-10; // F/m
      final expectedXn = (emax * eps) / (q * nd);

      final result = solver.solve(
        formulaId: 'pn_peak_field_charge_form_n_side',
        solveFor: 'x_n',
        workspaceGlobals: const {},
        panelOverrides: const {
          'E_max': SymbolValue(value: emax, unit: 'V/m', source: SymbolSource.user),
          'N_D': SymbolValue(value: nd, unit: 'm^-3', source: SymbolSource.user),
          'eps_s': SymbolValue(value: eps, unit: 'F/m', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['x_n']!.value, closeTo(expectedXn, expectedXn * 1e-6));

      final steps = result.stepsLatex;
      expect(steps, isNotNull);

      // Verify numerator/denominator breakdown
      final mathItems = steps!.workingItems
          .where((i) => i.type == StepItemType.math)
          .map((i) => i.latex)
          .toList();
      final allMath = mathItems.join(' ');
      
      expect(allMath.contains(r'\dfrac'), isTrue);
      expect(allMath.contains('Numerator'), isFalse);
      expect(allMath.contains('Denominator'), isFalse);
    });

    test('P-side: solve for eps_s with full substitution', () {
      final q = constants.getConstantValue('q')!;
      const emax = 1.54e6; // V/m
      const na = 1e22; // m^-3
      const xp = 1e-6; // m
      final expectedEps = (q * na * xp) / emax;

      final result = solver.solve(
        formulaId: 'pn_peak_field_charge_form_p_side',
        solveFor: 'eps_s',
        workspaceGlobals: const {},
        panelOverrides: const {
          'E_max': SymbolValue(value: emax, unit: 'V/m', source: SymbolSource.user),
          'N_A': SymbolValue(value: na, unit: 'm^-3', source: SymbolSource.user),
          'x_p': SymbolValue(value: xp, unit: 'm', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['eps_s']!.value, closeTo(expectedEps, expectedEps * 1e-6));

      final steps = result.stepsLatex;
      expect(steps, isNotNull);

      // Verify numerator/denominator breakdown
      final mathItems = steps!.workingItems
          .where((i) => i.type == StepItemType.math)
          .map((i) => i.latex)
          .toList();
      final allMath = mathItems.join(' ');
      
      expect(allMath.contains(r'\dfrac'), isTrue);
      expect(allMath.contains('Numerator'), isFalse);
      expect(allMath.contains('Denominator'), isFalse);

      // Step 2 should show rearrangement
      final step2Math = _getStepMath(steps, 2);
      expect(step2Math.any((m) => m.contains(r'\varepsilon_{s}') && m.contains(r'\dfrac')), isTrue);
    });
  });
}

List<String> _getStepMath(StepLatex steps, int stepNumber) {
  final items = steps.workingItems;
  final stepHeading = 'Step $stepNumber';
  
  final start = items.indexWhere(
    (item) => (item.type == StepItemType.text && item.value.contains(stepHeading)) ||
              (item.type == StepItemType.math && item.latex.contains(stepHeading)),
  );
  
  if (start == -1) return const [];
  
  final nextStep = items.skip(start + 1).toList().indexWhere(
    (item) => (item.type == StepItemType.text && item.value.startsWith('Step ')) ||
              (item.type == StepItemType.math && item.latex.contains(r'\textbf{Step')),
  );
  
  final end = nextStep == -1 ? items.length : start + 1 + nextStep;
  
  return items
      .sublist(start + 1, end)
      .where((item) => item.type == StepItemType.math)
      .map((e) => e.latex)
      .toList();
}

