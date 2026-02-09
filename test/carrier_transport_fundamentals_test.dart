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

    test('Electron drift current density: Step 3 renders without aligned environment', () {
      final result = solver.solve(
        formulaId: 'ct_f3_electron_drift_current_density',
        solveFor: 'J_n_drift',
        workspaceGlobals: const {},
        panelOverrides: const {
          'n': SymbolValue(value: 1e21, unit: 'm^-3', source: SymbolSource.user),
          'mu_n': SymbolValue(value: 0.135, unit: 'm^2/(V*s)', source: SymbolSource.user),
          'E_field': SymbolValue(value: 1e3, unit: 'V/m', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['J_n_drift']!.value, closeTo(21629.43, 1));

      final step3 = _step3Math(result.stepsLatex);
      
      // Step 3 should have individual lines, not aligned environment
      expect(step3.length, greaterThanOrEqualTo(2));
      
      // Verify no line contains \begin{aligned} or \end{aligned}
      for (final line in step3) {
        expect(line.contains(r'\begin{aligned}'), isFalse, 
          reason: 'Step 3 should not contain aligned environment: $line');
        expect(line.contains(r'\end{aligned}'), isFalse,
          reason: 'Step 3 should not contain aligned environment: $line');
      }
      
      // Verify substitution line contains all factors
      final allStep3 = step3.join(' ');
      expect(allStep3.contains(r'1.60218'), isTrue,
        reason: 'Step 3 should contain elementary charge substitution');
      expect(allStep3.contains(r'10^{21}'), isTrue,
        reason: 'Step 3 should contain electron concentration substitution');
      expect(allStep3.contains(r'0.135') || allStep3.contains(r'1.35000 \times 10^{-1}'), isTrue,
        reason: 'Step 3 should contain mobility substitution');
      expect(allStep3.contains(r'10^{3}'), isTrue,
        reason: 'Step 3 should contain electric field substitution');
    });

    test('Solve for mobility (μ_n): Step 2 shows rearrangement, Step 3 uses rearranged form', () {
      final result = solver.solve(
        formulaId: 'ct_f3_electron_drift_current_density',
        solveFor: 'mu_n',
        workspaceGlobals: const {},
        panelOverrides: const {
          'J_n_drift': SymbolValue(value: 21629.43, unit: 'A/m^2', source: SymbolSource.user),
          'n': SymbolValue(value: 1e21, unit: 'm^-3', source: SymbolSource.user),
          'E_field': SymbolValue(value: 1e3, unit: 'V/m', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['mu_n']!.value, closeTo(0.135, 1e-6));

      // Step 2: Verify rearrangement is shown
      final step2 = _step2Math(result.stepsLatex);
      expect(step2.length, greaterThanOrEqualTo(2),
        reason: 'Step 2 should show rearrangement when solving for μ_n');
      expect(step2.any((line) => line.contains(r'\dfrac') && line.contains(r'\mu')), isTrue,
        reason: 'Step 2 should show μ = J/(q n E) rearrangement');

      // Step 3: Verify substitution uses rearranged form (fraction with J in numerator)
      final step3 = _step3Math(result.stepsLatex);
      expect(step3.length, greaterThanOrEqualTo(2));
      
      // First line should be the rearranged symbolic equation
      expect(step3[0].contains(r'\mu'), isTrue);
      expect(step3[0].contains(r'\dfrac'), isTrue);
      
      // Second line should substitute values into the fraction form
      expect(step3[1].contains(r'\mu'), isTrue);
      expect(step3[1].contains(r'\dfrac'), isTrue);
      expect(step3[1].contains(r'2.16') || step3[1].contains(r'21.6'), isTrue,
        reason: 'Step 3 should substitute J value in numerator');
    });

    test('Solve for carrier concentration (n): Step 2 shows rearrangement', () {
      final result = solver.solve(
        formulaId: 'ct_f3_electron_drift_current_density',
        solveFor: 'n',
        workspaceGlobals: const {},
        panelOverrides: const {
          'J_n_drift': SymbolValue(value: 21629.43, unit: 'A/m^2', source: SymbolSource.user),
          'mu_n': SymbolValue(value: 0.135, unit: 'm^2/(V*s)', source: SymbolSource.user),
          'E_field': SymbolValue(value: 1e3, unit: 'V/m', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['n']!.value, closeTo(1e21, 1e19));

      final step2 = _step2Math(result.stepsLatex);
      expect(step2.length, greaterThanOrEqualTo(2));
      expect(step2.any((line) => line.contains(r'\dfrac') && line.contains('n')), isTrue,
        reason: 'Step 2 should show n = J/(q μ E) rearrangement');

      final step3 = _step3Math(result.stepsLatex);
      expect(step3.length, greaterThanOrEqualTo(2));
      expect(step3[0].contains(r'\dfrac'), isTrue);
      expect(step3[1].contains(r'\dfrac'), isTrue);
    });

    test('Solve for electric field (E): Step 2 shows rearrangement', () {
      final result = solver.solve(
        formulaId: 'ct_f3_electron_drift_current_density',
        solveFor: 'E_field',
        workspaceGlobals: const {},
        panelOverrides: const {
          'J_n_drift': SymbolValue(value: 21629.43, unit: 'A/m^2', source: SymbolSource.user),
          'n': SymbolValue(value: 1e21, unit: 'm^-3', source: SymbolSource.user),
          'mu_n': SymbolValue(value: 0.135, unit: 'm^2/(V*s)', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['E_field']!.value, closeTo(1e3, 1));

      final step2 = _step2Math(result.stepsLatex);
      expect(step2.length, greaterThanOrEqualTo(2));
      expect(step2.any((line) => line.contains(r'\dfrac') && line.contains(r'\mathcal{E}')), isTrue,
        reason: 'Step 2 should show E = J/(q n μ) rearrangement');

      final step3 = _step3Math(result.stepsLatex);
      expect(step3.length, greaterThanOrEqualTo(2));
      expect(step3[0].contains(r'\dfrac'), isTrue);
      expect(step3[1].contains(r'\dfrac'), isTrue);
    });

    test('Drift velocity: solve for μ_n with rearranged Step 3', () {
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

      // Step 2: Should show rearrangement μ_n = -v_dn/E
      final step2 = _step2Math(result.stepsLatex);
      expect(step2.length, greaterThanOrEqualTo(2));
      expect(step2.any((line) => line.contains(r'\mu') && line.contains(r'\dfrac')), isTrue,
        reason: 'Step 2 should show μ = -v/E rearrangement');

      // Step 3: Should substitute into rearranged form (fraction)
      final step3 = _step3Math(result.stepsLatex);
      expect(step3.length, greaterThanOrEqualTo(2));
      expect(step3[0].contains(r'\dfrac'), isTrue,
        reason: 'Step 3 first line should be rearranged symbolic equation');
      expect(step3[1].contains(r'\dfrac'), isTrue,
        reason: 'Step 3 second line should substitute into fraction form');
      expect(step3[1].contains(r'150') || step3[1].contains(r'1.50'), isTrue,
        reason: 'Step 3 should substitute velocity value');
    });

    test('Drift velocity: solve for E_field with rearranged Step 3', () {
      final result = solver.solve(
        formulaId: 'ct_f1_electron_drift_velocity',
        solveFor: 'E_field',
        workspaceGlobals: const {},
        panelOverrides: const {
          'v_dn': SymbolValue(value: -150.0, unit: 'm/s', source: SymbolSource.user),
          'mu_n': SymbolValue(value: 0.15, unit: 'm^2/(V*s)', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['E_field']!.value, closeTo(1000.0, 1e-9));

      final step2 = _step2Math(result.stepsLatex);
      expect(step2.length, greaterThanOrEqualTo(2));
      expect(step2.any((line) => line.contains(r'\mathcal{E}') && line.contains(r'\dfrac')), isTrue);

      final step3 = _step3Math(result.stepsLatex);
      expect(step3.length, greaterThanOrEqualTo(2));
      expect(step3[0].contains(r'\dfrac'), isTrue);
      expect(step3[1].contains(r'\dfrac'), isTrue);
    });

    test('Hole drift velocity: solve for μ_p (no negative sign)', () {
      final result = solver.solve(
        formulaId: 'ct_f2_hole_drift_velocity',
        solveFor: 'mu_p',
        workspaceGlobals: const {},
        panelOverrides: const {
          'v_dp': SymbolValue(value: 50.0, unit: 'm/s', source: SymbolSource.user),
          'E_field': SymbolValue(value: 1000.0, unit: 'V/m', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['mu_p']!.value, closeTo(0.05, 1e-12));

      final step2 = _step2Math(result.stepsLatex);
      expect(step2.any((line) => line.contains(r'\mu') && line.contains(r'\dfrac')), isTrue);

      final step3 = _step3Math(result.stepsLatex);
      expect(step3.length, greaterThanOrEqualTo(2));
      expect(step3[0].contains(r'\dfrac'), isTrue);
      expect(step3[1].contains(r'\dfrac'), isTrue);
      // Hole velocity has no negative sign
      expect(step3[0].contains('-'), isFalse);
    });

    test('Diffusion current: solve for D_n with rearranged Step 3', () {
      final result = solver.solve(
        formulaId: 'ct_f5_electron_diffusion_current_density',
        solveFor: 'D_n',
        workspaceGlobals: const {},
        panelOverrides: const {
          'J_n_diff': SymbolValue(value: 0.1602, unit: 'A/m^2', source: SymbolSource.user),
          'dn_dx': SymbolValue(value: 1e20, unit: 'm^-4', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['D_n']!.value, closeTo(0.01, 1e-5));

      final step2 = _step2Math(result.stepsLatex);
      expect(step2.any((line) => line.contains('D') && line.contains(r'\dfrac')), isTrue,
        reason: 'Step 2 should show D = J/(q * gradient) rearrangement');

      final step3 = _step3Math(result.stepsLatex);
      expect(step3.length, greaterThanOrEqualTo(2));
      expect(step3[0].contains(r'\dfrac'), isTrue);
      expect(step3[1].contains(r'\dfrac'), isTrue);
    });

    test('Total electron current: solve for dn/dx with clear drift/diffusion separation', () {
      final result = solver.solve(
        formulaId: 'ct_total_electron_current_density',
        solveFor: 'dn_dx',
        workspaceGlobals: const {},
        panelOverrides: const {
          'J_n': SymbolValue(value: 100.0, unit: 'A/m^2', source: SymbolSource.user),
          'n': SymbolValue(value: 1e21, unit: 'm^-3', source: SymbolSource.user),
          'mu_n': SymbolValue(value: 0.14, unit: 'm^2/(V*s)', source: SymbolSource.user),
          'E_field': SymbolValue(value: 1000.0, unit: 'V/m', source: SymbolSource.user),
          'D_n': SymbolValue(value: 0.0036, unit: 'm^2/s', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );

      expect(result.status, PanelStatus.solved);
      expect(result.outputs['dn_dx'], isNotNull);

      final steps = result.stepsLatex;
      expect(steps, isNotNull);

      // Check that step structure includes the 3-part narrative
      final allItems = steps!.workingItems;
      final textItems = allItems.where((i) => i.type == StepItemType.text).map((i) => i.value).toList();
      
      // Should have section for drift component
      expect(textItems.any((t) => t.contains('3.1') && t.contains('Drift')), isTrue,
        reason: 'Step 3 should have "3.1 Drift component" section');
      
      // Should have section for diffusion component with subtraction
      expect(textItems.any((t) => t.contains('3.2') && t.contains('Diffusion')), isTrue,
        reason: 'Step 3 should have "3.2 Diffusion component" section');
      
      // Should have section for solving gradient
      expect(textItems.any((t) => t.contains('3.3') && t.contains('gradient')), isTrue,
        reason: 'Step 3 should have "3.3 Solve gradient" section');

      final mathItems = allItems.where((i) => i.type == StepItemType.math).map((i) => i.latex).toList();
      
      // Should have the critical subtraction line: J_diff = J_n - J_drift
      expect(mathItems.any((m) => m.contains(r'J_{n,\mathrm{diff}}') && m.contains(r'J_{n}') && m.contains(r'J_{n,\mathrm{drift}}') && m.contains('-')), isTrue,
        reason: 'Step 3 should show J_diff = J_total - J_drift');
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
