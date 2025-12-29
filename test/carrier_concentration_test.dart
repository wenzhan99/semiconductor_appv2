import 'package:flutter_test/flutter_test.dart';
import 'package:semiconductor_appv2/core/formulas/formula_repository.dart';
import 'package:semiconductor_appv2/core/constants/constants_repository.dart';
import 'package:semiconductor_appv2/core/solver/formula_solver.dart';
import 'package:semiconductor_appv2/core/models/workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Carrier Concentration (Equilibrium)', () {
    late FormulaRepository formulaRepo;
    late ConstantsRepository constantsRepo;
    late FormulaSolver solver;

    setUpAll(() async {
      formulaRepo = FormulaRepository();
      await formulaRepo.preloadAll();
      
      constantsRepo = ConstantsRepository();
      await constantsRepo.load();
      
      solver = FormulaSolver(
        formulaRepo: formulaRepo,
        constantsRepo: constantsRepo,
      );
    });

    test('Midgap energy: solve E_mid from E_c and E_v', () async {
      final formula = formulaRepo.getFormulaById('dos_stats_midgap_energy');
      expect(formula, isNotNull);
      expect(formula!.name, 'Midgap energy');
      
      // E_c = 1 eV, E_v = 0 eV => E_mid = 0.5 eV
      final q = constantsRepo.getElectronVoltJoules()!;
      final inputs = {
        'E_c': const SymbolValue(value: 1.602176634e-19, unit: 'J', source: SymbolSource.user),
        'E_v': const SymbolValue(value: 0.0, unit: 'J', source: SymbolSource.user),
      };
      
      final result = solver.solve(
        formulaId: formula.id,
        solveFor: 'E_mid',
        workspaceGlobals: const {},
        panelOverrides: inputs,
      );
      
      expect(result.status, PanelStatus.solved);
      expect(result.outputs, isNotEmpty);
      expect(result.outputs['E_mid'], isNotNull);
      
      final emid = result.outputs['E_mid']!.value;
      expect(emid, closeTo(0.5 * q, 1e-21));
    });

    test('Intrinsic Fermi level: solve E_i from E_mid, T, masses', () async {
      final formula = formulaRepo.getFormulaById('dos_stats_intrinsic_fermi_level');
      expect(formula, isNotNull);
      expect(formula!.name, 'Intrinsic Fermi level position');
      
      final q = constantsRepo.getElectronVoltJoules()!;
      final m0 = constantsRepo.getConstantValue('m_0')!;
      
      // E_mid = 0.5 eV, T = 300 K, m_p* = m_n* = m0 => E_i = E_mid (ln(1) = 0)
      final inputs = {
        'E_mid': SymbolValue(value: 0.5 * q, unit: 'J', source: SymbolSource.user),
        'T': const SymbolValue(value: 300.0, unit: 'K', source: SymbolSource.user),
        'm_p_star': SymbolValue(value: m0, unit: 'kg', source: SymbolSource.user),
        'm_n_star': SymbolValue(value: m0, unit: 'kg', source: SymbolSource.user),
      };
      
      final result = solver.solve(
        formulaId: formula.id,
        solveFor: 'E_i',
        workspaceGlobals: const {},
        panelOverrides: inputs,
      );
      
      expect(result.status, PanelStatus.solved);
      expect(result.outputs, isNotEmpty);
      expect(result.outputs['E_i'], isNotNull);
      
      final ei = result.outputs['E_i']!.value;
      // When masses are equal, ln(1) = 0, so E_i = E_mid
      expect(ei, closeTo(0.5 * q, 1e-25));
    });

    test('Doped n-type: solve n_0 from N_D, N_A, n_i', () async {
      final formula = formulaRepo.getFormulaById('doped_n_type_majority');
      expect(formula, isNotNull);
      expect(formula!.name, 'Equilibrium majority carrier (n-type, compensated)');
      
      // N_D = 1e16 cm^-3, N_A = 0, n_i = 1e10 cm^-3
      // n_0 ≈ (N_D + sqrt(N_D^2 + 4ni^2))/2 ≈ N_D (since N_D >> ni)
      final inputs = {
        'N_D': const SymbolValue(value: 1e22, unit: 'm^-3', source: SymbolSource.user),
        'N_A': const SymbolValue(value: 0.0, unit: 'm^-3', source: SymbolSource.user),
        'n_i': const SymbolValue(value: 1e16, unit: 'm^-3', source: SymbolSource.user),
      };
      
      final result = solver.solve(
        formulaId: formula.id,
        solveFor: 'n_0',
        workspaceGlobals: const {},
        panelOverrides: inputs,
      );
      
      expect(result.status, PanelStatus.solved);
      expect(result.outputs, isNotEmpty);
      expect(result.outputs['n_0'], isNotNull);
      
      final n0 = result.outputs['n_0']!.value;
      // Should be close to N_D since N_D >> n_i
      expect(n0, closeTo(1e22, 1e21));
    });

    test('Charge neutrality: solve n_0 from p_0, N_A-, N_D+', () async {
      final formula = formulaRepo.getFormulaById('charge_neutrality_equilibrium');
      expect(formula, isNotNull);
      expect(formula!.name, 'Charge neutrality (equilibrium)');
      
      // p_0 = 1e15, N_D+ = 1e16, N_A- = 0 => n_0 = p_0 + N_D+ - N_A- = 1.01e16
      final inputs = {
        'p_0': const SymbolValue(value: 1e21, unit: 'm^-3', source: SymbolSource.user),
        'N_D_plus': const SymbolValue(value: 1e22, unit: 'm^-3', source: SymbolSource.user),
        'N_A_minus': const SymbolValue(value: 0.0, unit: 'm^-3', source: SymbolSource.user),
      };
      
      final result = solver.solve(
        formulaId: formula.id,
        solveFor: 'n_0',
        workspaceGlobals: const {},
        panelOverrides: inputs,
      );
      
      expect(result.status, PanelStatus.solved);
      expect(result.outputs, isNotEmpty);
      expect(result.outputs['n_0'], isNotNull);
      
      final n0 = result.outputs['n_0']!.value;
      expect(n0, closeTo(1.01e22, 1e21));
    });

    tearDownAll(() {
      // Cleanup if needed
    });
  });
}

