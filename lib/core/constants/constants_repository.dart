import 'dart:math' as math;

import 'constants_loader.dart';
import 'physical_constants_table.dart';
import 'physical_constant.dart';

/// Repository for accessing physical constants.
class ConstantsRepository {
  static final ConstantsRepository _instance = ConstantsRepository._internal();
  factory ConstantsRepository() => _instance;
  ConstantsRepository._internal();

  PhysicalConstantsTable? _constantsTable;
  bool _loaded = false;

  /// Load constants from assets.
  Future<void> load() async {
    if (_loaded) return;
    _constantsTable = await ConstantsLoader.loadConstants();
    _loaded = true;
  }

  /// Get a constant value by its symbol key (e.g., "q", "k", "eps_0").
  double? getConstantValue(String symbolKey) {
    if (!_loaded || _constantsTable == null) return null;

    final constant = _constantsTable!.bySymbol(symbolKey);
    return constant?.value;
  }

  /// Get hbar (reduced Planck constant) = h / (2*pi).
  double? getHbar() {
    final h = getConstantValue('h');
    if (h == null) return null;
    return h / (2 * math.pi);
  }

  /// Get electron-volt conversion factor (1 eV = q joules).
  double? getElectronVoltJoules() {
    return getConstantValue('q');
  }

  /// Get a constant by symbol key.
  PhysicalConstant? getConstant(String symbolKey) {
    if (!_loaded || _constantsTable == null) return null;
    return _constantsTable!.bySymbol(symbolKey);
  }

  /// Get all constants.
  List<PhysicalConstant> getAllConstants() {
    if (!_loaded || _constantsTable == null) return [];
    return _constantsTable!.constants;
  }
}

