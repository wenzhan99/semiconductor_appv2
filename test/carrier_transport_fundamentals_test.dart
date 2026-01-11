import 'package:flutter_test/flutter_test.dart';
import 'package:semiconductor_appv2/core/constants/constants_loader.dart';
import 'package:semiconductor_appv2/core/constants/constants_repository.dart';
import 'package:semiconductor_appv2/core/constants/latex_symbols.dart';
import 'package:semiconductor_appv2/core/formulas/formula_registry.dart';
import 'package:semiconductor_appv2/core/formulas/formula_repository.dart';
import 'package:semiconductor_appv2/core/solver/formula_solver.dart';
import 'package:semiconductor_appv2/core/solver/step_latex_builder.dart';
import 'package:semiconductor_appv2/core/models/workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Carrier Transport (Fundamentals)', () {
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

    test('Category registers all 10 formulas and appears after equilibrium concentration', () {
      final category = formulas.getCategoryById('carrier_transport_fundamentals');
      expect(category, isNotNull);
      expect(category!.formulaIds.length, greaterThanOrEqualTo(10));
      expect(
        Set.from(category.formulaIds),
        containsAll(const {
          'ct_f1_electron_drift_velocity',
          'ct_f2_hole_drift_velocity',
          'ct_f3_electron_drift_current_density',
          'ct_f4_hole_drift_current_density',
          'ct_f5_electron_diffusion_current_density',
          'ct_f6_hole_diffusion_current_density',
          'ct_f7_einstein_relation_electrons',
          'ct_f8_einstein_relation_holes',
          'ct_f9_conductivity',
          'ct_f10_resistivity',
        }),
      );

      final registryIndex =
          formulaCategories.indexWhere((c) => c.id == 'carrier_transport_fundamentals');
      final eqIndex =
          formulaCategories.indexWhere((c) => c.id == 'carrier_concentration_equilibrium');
      expect(registryIndex, isNonNegative);
      expect(eqIndex, isNonNegative);
      expect(registryIndex, greaterThan(eqIndex));
    });

    test('Drift velocity: solve mobility with substitution steps', () {
      final result = solver.solve(
        formulaId: 'ct_f1_electron_drift_velocity',
        solveFor: 'mu_n',
        workspaceGlobals: const {},
        panelOverrides: const {
          'v_dn': SymbolValue(value: -150.0, unit: 'm/s', source: SymbolSource.user),
          'E_field': SymbolValue(value: 1000.0, unit: 'V/m', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['mu_n']!.value, closeTo(0.15, 1e-12));
      final step3 = _step3Math(result.stepsLatex);
      expect(step3.length, greaterThanOrEqualTo(2));
      expect(step3[1], contains(r'\mathrm{m}/\mathrm{s}'));
      expect(step3[1], contains(r'\mathrm{V}/\mathrm{m}'));
      expect(step3[1], contains(r'\times 10^{'));
    });

    test('Diffusion current: solve concentration gradient from hole diffusion', () {
      final result = solver.solve(
        formulaId: 'ct_f6_hole_diffusion_current_density',
        solveFor: 'dp_dx',
        workspaceGlobals: const {},
        panelOverrides: const {
          'J_p_diff': SymbolValue(value: -0.1602, unit: 'A/m^2', source: SymbolSource.user),
          'D_p': SymbolValue(value: 0.01, unit: 'm^2/s', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['dp_dx']!.value, closeTo(1e20, 1e18));
      final step3 = _step3Math(result.stepsLatex);
      expect(step3.any((line) => line.contains(r'J_{p,\mathrm{diff}}')), isTrue);
      expect(step3.any((line) => line.contains(r'\times 10^{')), isTrue);
    });

    test('Einstein relation: solve mobility from diffusion coefficient', () {
      const dValue = 0.03; // m^2/s
      const temperature = 300.0; // K
      final k = constants.getConstantValue('k')!;
      final q = constants.getConstantValue('q')!;
      final expectedMu = dValue * q / (k * temperature);

      final result = solver.solve(
        formulaId: 'ct_f7_einstein_relation_electrons',
        solveFor: 'mu_n',
        workspaceGlobals: const {},
        panelOverrides: const {
          'D_n': SymbolValue(value: dValue, unit: 'm^2/s', source: SymbolSource.user),
          'T': SymbolValue(value: temperature, unit: 'K', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['mu_n']!.value, closeTo(expectedMu, expectedMu * 1e-6));
      final step2 = _step2Math(result.stepsLatex);
      expect(step2, isNotEmpty);
      expect(step2.first, contains(r'\mu_{n} = \dfrac{D_{n} q}{k T}'));

      final step3 = _step3Math(result.stepsLatex);
      expect(step3.length, 3);
      expect(step3[1], contains(r'1.60218 \times 10^{-19}'));
      expect(step3[1], contains(r'1.38065 \times 10^{-23}'));
      expect(step3[1].contains(r'D_{n}'), isFalse); // D_n must be substituted
      expect(step3[2], contains(r'\mu_{n} ='));
    });

    test('Conductivity and resistivity computations', () {
      final q = constants.getConstantValue('q')!;
      const n = 1.0e21; // m^-3
      const p = 5.0e20; // m^-3
      const muN = 0.14; // m^2/(V*s)
      const muP = 0.05; // m^2/(V*s)
      final expectedSigma = q * ((n * muN) + (p * muP));
      final expectedRho = 1 / expectedSigma;

      final sigmaResult = solver.solve(
        formulaId: 'ct_f9_conductivity',
        solveFor: 'sigma',
        workspaceGlobals: const {},
        panelOverrides: const {
          'n': SymbolValue(value: n, unit: 'm^-3', source: SymbolSource.user),
          'p': SymbolValue(value: p, unit: 'm^-3', source: SymbolSource.user),
          'mu_n': SymbolValue(value: muN, unit: 'm^2/(V*s)', source: SymbolSource.user),
          'mu_p': SymbolValue(value: muP, unit: 'm^2/(V*s)', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(sigmaResult.status, PanelStatus.solved);
      expect(sigmaResult.outputs['sigma']!.value, closeTo(expectedSigma, expectedSigma * 1e-6));

      final rhoResult = solver.solve(
        formulaId: 'ct_f10_resistivity',
        solveFor: 'rho',
        workspaceGlobals: const {},
        panelOverrides: {
          'sigma': SymbolValue(
            value: sigmaResult.outputs['sigma']!.value,
            unit: 'S/m',
            source: SymbolSource.user,
          ),
        },
        latexMap: latexMap,
      );

      expect(rhoResult.status, PanelStatus.solved);
      expect(rhoResult.outputs['rho']!.value, closeTo(expectedRho, expectedRho * 1e-6));
    });

    test('Einstein relation: solve temperature shows full substitution', () {
      final result = solver.solve(
        formulaId: 'ct_f7_einstein_relation_electrons',
        solveFor: 'T',
        workspaceGlobals: const {},
        panelOverrides: const {
          'D_n': SymbolValue(value: 0.0025852, unit: 'm^2/s', source: SymbolSource.user),
          'mu_n': SymbolValue(value: 0.1, unit: 'm^2/(V*s)', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      final temperature = result.outputs['T']!;
      expect(temperature.value, closeTo(300, 1e-4));

      final step2 = _step2Math(result.stepsLatex);
      expect(step2.first, contains(r'T = \dfrac{D_{n} q}{k \mu_{n}}'));

      final step3 = _step3Math(result.stepsLatex);
      expect(step3.length, 3);
      expect(step3[1], contains(r'1.60218 \times 10^{-19}'));
      expect(step3[1], contains(r'1.38065 \times 10^{-23}'));
      expect(step3[1].contains(r'D_{n}'), isFalse);
      expect(step3[1].contains(r'\mu_{n}'), isFalse);
      expect(step3[2], contains(r'T ='));
    });
  });
}

List<String> _step2Math(StepLatex? steps) {
  if (steps == null) return const [];
  final items = steps.workingItems;
  bool isStep2Heading(StepItem item) =>
      (item.type == StepItemType.text && item.value.contains('Step 2')) ||
      (item.type == StepItemType.math && item.latex.contains('Step 2'));
  bool isStep3Heading(StepItem item) =>
      (item.type == StepItemType.text && item.value.contains('Step 3')) ||
      (item.type == StepItemType.math && item.latex.contains('Step 3'));

  final start = items.indexWhere(isStep2Heading);
  final end = items.indexWhere(isStep3Heading);
  if (start == -1 || end == -1 || end <= start) {
    return items.where((item) => item.type == StepItemType.math).map((e) => e.latex).toList();
  }
  return items
      .sublist(start + 1, end)
      .where((item) => item.type == StepItemType.math)
      .map((e) => e.latex)
      .toList();
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
  final slice = items.where((item) => item.type == StepItemType.math).toList();
  if (start == -1 || end == -1) {
    return slice.map((e) => e.latex).toList();
  }
  final mathBetween = items
      .sublist(start + 1, end)
      .where((item) => item.type == StepItemType.math)
      .map((e) => e.latex)
      .toList();
  return mathBetween;
}
