import 'package:flutter_test/flutter_test.dart';

import 'package:semiconductor_appv2/core/constants/constants_repository.dart';
import 'package:semiconductor_appv2/core/constants/constants_loader.dart';
import 'package:semiconductor_appv2/core/formulas/formula_repository.dart';
import 'package:semiconductor_appv2/core/solver/formula_solver.dart';
import 'package:semiconductor_appv2/core/models/workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Density of States & Statistics', () {
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

    test('Nc: T=0 should error (positive constraint)', () {
      final result = solver.solve(
        formulaId: 'dos_Nc_effective_density_conduction',
        solveFor: 'N_c',
        workspaceGlobals: const {},
        panelOverrides: {
          'm_n_star': const SymbolValue(value: 9.11e-31, unit: 'kg', source: SymbolSource.user),
          'T': const SymbolValue(value: 0.0, unit: 'K', source: SymbolSource.user),
        },
        latexMap: null,
      );
      expect(result.status, PanelStatus.error);
      expect(result.errorMessage, contains('T'));
    });

    test('Fermi-Dirac: solve for E_F given f, E, T', () {
      // f = 0.5 implies E_F == E (for any T), so E_F should equal E.
      final E = 0.1; // J (we test SI-level solver, UI handles eV conversion)
      final result = solver.solve(
        formulaId: 'dos_fermi_dirac_probability',
        solveFor: 'E_F',
        workspaceGlobals: const {},
        panelOverrides: {
          'f_E': const SymbolValue(value: 0.5, unit: '1', source: SymbolSource.user),
          'E': SymbolValue(value: E, unit: 'J', source: SymbolSource.user),
          'T': const SymbolValue(value: 300.0, unit: 'K', source: SymbolSource.user),
        },
        latexMap: null,
      );
      expect(result.status, PanelStatus.solved);
      final ef = result.outputs['E_F']!.value;
      expect((ef - E).abs(), lessThan(1e-12));
    });

    test('Fermi-Dirac: f must be in (0,1) for inverse solve', () {
      final result = solver.solve(
        formulaId: 'dos_fermi_dirac_probability',
        solveFor: 'E_F',
        workspaceGlobals: const {},
        panelOverrides: {
          'f_E': const SymbolValue(value: 1.0, unit: '1', source: SymbolSource.user),
          'E': const SymbolValue(value: 0.1, unit: 'J', source: SymbolSource.user),
          'T': const SymbolValue(value: 300.0, unit: 'K', source: SymbolSource.user),
        },
        latexMap: null,
      );
      expect(result.status, PanelStatus.error);
      expect(result.errorMessage, contains('(0, 1)'));
    });

    test('Carrier stats: n0 equals ni when E_F == E_i', () {
      const ni = 1.0e21; // m^-3
      const t = 300.0;
      const ef = 0.2; // J
      const ei = 0.2; // J
      final result = solver.solve(
        formulaId: 'carrier_electron_concentration_n0',
        solveFor: 'n_0',
        workspaceGlobals: const {},
        panelOverrides: const {
          'n_i': SymbolValue(value: ni, unit: 'm^-3', source: SymbolSource.user),
          'T': SymbolValue(value: t, unit: 'K', source: SymbolSource.user),
          'E_F': SymbolValue(value: ef, unit: 'J', source: SymbolSource.user),
          'E_i': SymbolValue(value: ei, unit: 'J', source: SymbolSource.user),
          '__meta__unit_system': SymbolValue(value: 0, unit: 'si', source: SymbolSource.computed),
        },
        latexMap: latexMap,
      );
      expect(result.status, PanelStatus.solved);
      expect((result.outputs['n_0']!.value - ni).abs(), lessThan(1e-6));
      expect(result.stepsLatex?.alignedWorking, isNotNull);
    });

    testWidgets('Carrier electron UI solve n0: ignores stale n0 input, overwrites with result', (tester) async {
      // This is a light widget-free check: we validate solver math + formatting expectations indirectly
      // by checking that solving n0 with EF==Ei yields n0==ni.
      const ni = 2.0e21; // m^-3
      const t = 300.0;
      const ef = 0.2; // J
      const ei = 0.2; // J
      final result = solver.solve(
        formulaId: 'carrier_electron_concentration_n0',
        solveFor: 'n_0',
        workspaceGlobals: const {},
        panelOverrides: const {
          // Stale n0 input should not affect compute expression for n0.
          'n_0': SymbolValue(value: 9.0e30, unit: 'm^-3', source: SymbolSource.user),
          'n_i': SymbolValue(value: ni, unit: 'm^-3', source: SymbolSource.user),
          'T': SymbolValue(value: t, unit: 'K', source: SymbolSource.user),
          'E_F': SymbolValue(value: ef, unit: 'J', source: SymbolSource.user),
          'E_i': SymbolValue(value: ei, unit: 'J', source: SymbolSource.user),
          '__meta__unit_system': SymbolValue(value: 0, unit: 'si', source: SymbolSource.computed),
        },
        latexMap: latexMap,
      );
      expect(result.status, PanelStatus.solved);
      expect((result.outputs['n_0']!.value - ni).abs(), lessThan(1e-6));
    });

    test('Carrier electron reverse solve: solve n_i (steps include exp(x) and x fixed 5dp)', () {
      const n0 = 1.0e21; // m^-3
      const t = 300.0;
      // Use realistic energy scales in Joules (~0.1 eV), otherwise exp() overflows.
      const ef = 4.8e-20; // J
      const ei = 3.2e-20; // J
      final result = solver.solve(
        formulaId: 'carrier_electron_concentration_n0',
        solveFor: 'n_i',
        workspaceGlobals: const {},
        panelOverrides: const {
          'n_0': SymbolValue(value: n0, unit: 'm^-3', source: SymbolSource.user),
          'T': SymbolValue(value: t, unit: 'K', source: SymbolSource.user),
          'E_F': SymbolValue(value: ef, unit: 'J', source: SymbolSource.user),
          'E_i': SymbolValue(value: ei, unit: 'J', source: SymbolSource.user),
          '__meta__unit_system': SymbolValue(value: 0, unit: 'si', source: SymbolSource.computed),
        },
        latexMap: latexMap,
      );
      expect(result.status, PanelStatus.solved);
      final latex = result.stepsLatex?.alignedWorking ?? '';
      expect(latex, contains(r'\exp(x)'));
      expect(latex, contains('x &= '));
      expect(RegExp(r'x\s*&=.*\d+\.\d{5}').hasMatch(latex), isTrue);
    });

    test('Carrier hole reverse solve: solve n_i from p0 (steps show rearrangement and exp(x))', () {
      const p0 = 2.0e21; // m^-3
      const t = 300.0;
      const ef = 3.2e-20; // J
      const ei = 4.8e-20; // J
      final result = solver.solve(
        formulaId: 'carrier_hole_concentration_p0',
        solveFor: 'n_i',
        workspaceGlobals: const {},
        panelOverrides: const {
          'p_0': SymbolValue(value: p0, unit: 'm^-3', source: SymbolSource.user),
          'T': SymbolValue(value: t, unit: 'K', source: SymbolSource.user),
          'E_F': SymbolValue(value: ef, unit: 'J', source: SymbolSource.user),
          'E_i': SymbolValue(value: ei, unit: 'J', source: SymbolSource.user),
          '__meta__unit_system': SymbolValue(value: 0, unit: 'si', source: SymbolSource.computed),
        },
        latexMap: latexMap,
      );
      expect(result.status, PanelStatus.solved);
      final latex = result.stepsLatex?.alignedWorking ?? '';
      expect(latex, contains(r'n_i &= \frac{p_0}'));
      expect(latex, contains(r'\exp(x)'));
    });

    test('Carrier hole: missing input should prompt needsInputs error', () {
      final result = solver.solve(
        formulaId: 'carrier_hole_concentration_p0',
        solveFor: 'n_i',
        workspaceGlobals: const {},
        panelOverrides: const {
          'p_0': SymbolValue(value: 1.0e21, unit: 'm^-3', source: SymbolSource.user),
          'T': SymbolValue(value: 300.0, unit: 'K', source: SymbolSource.user),
          // missing E_F
          'E_i': SymbolValue(value: 0.25, unit: 'J', source: SymbolSource.user),
        },
        latexMap: latexMap,
      );
      expect(result.status, PanelStatus.needsInputs);
      expect(result.errorMessage, contains('Missing required inputs'));
    });

    test('Mass action law: solve n_i from n0 and p0', () {
      const n0 = 1.0e21; // m^-3
      const p0 = 4.0e20; // m^-3
      final result = solver.solve(
        formulaId: 'mass_action_law',
        solveFor: 'n_i',
        workspaceGlobals: const {},
        panelOverrides: const {
          'n_0': SymbolValue(value: n0, unit: 'm^-3', source: SymbolSource.user),
          'p_0': SymbolValue(value: p0, unit: 'm^-3', source: SymbolSource.user),
          '__meta__unit_system': SymbolValue(value: 0, unit: 'si', source: SymbolSource.computed),
        },
        latexMap: latexMap,
      );
      expect(result.status, PanelStatus.solved);
      final ni = result.outputs['n_i']!.value;
      expect((ni * ni - (n0 * p0)).abs(), lessThan(1e20));
      expect(result.stepsLatex?.alignedWorking, contains('n_i^2 &= n_0 p_0'));
    });
  });
}


