import '../models/workspace.dart';
import '../constants/constants_repository.dart';

/// Context that merges constants, globals, and overrides in priority order.
class SymbolContext {
  final ConstantsRepository _constantsRepo;
  final Map<String, SymbolValue> _merged = {};

  SymbolContext(this._constantsRepo);

  /// Merge constants, globals, and overrides in priority order.
  /// Priority: constants (lowest) -> globals -> overrides (highest)
  void mergeIn({
    Map<String, SymbolValue>? globals,
    Map<String, SymbolValue>? overrides,
  }) {
    _merged.clear();

    // 1. Add constants (read-only, from repository)
    _addConstants();

    // 2. Add globals (user inputs shared across panels)
    if (globals != null) {
      for (final entry in globals.entries) {
        _merged[entry.key] = entry.value;
      }
    }

    // 3. Add overrides (panel-specific, highest priority)
    if (overrides != null) {
      for (final entry in overrides.entries) {
        _merged[entry.key] = entry.value;
      }
    }
  }

  void _addConstants() {
    // Add common physical constants
    final constants = [
      'q', 'k', 'h', 'c', 'eps_0', 'mu_0', 'm_0', 'm_p', 'N_A', 'R', 'eV', 'V_T'
    ];

    for (final symbol in constants) {
      final value = _constantsRepo.getConstantValue(symbol);
      if (value != null) {
        final constant = _constantsRepo.getConstant(symbol);
        _merged[symbol] = SymbolValue(
          value: value,
          unit: constant?.unit ?? '',
          source: SymbolSource.material,
        );
      }
    }

    // Add hbar (derived constant)
    final hbar = _constantsRepo.getHbar();
    if (hbar != null) {
      _merged['hbar'] = SymbolValue(
        value: hbar,
        unit: 'J*s',
        source: SymbolSource.material,
      );
    }
  }

  /// Get the numeric value for a symbol key.
  double? getValue(String symbolKey) {
    return _merged[symbolKey]?.value;
  }

  /// Get the unit for a symbol key.
  String? getUnit(String symbolKey) {
    return _merged[symbolKey]?.unit;
  }

  /// Get the full SymbolValue for a symbol key.
  SymbolValue? getSymbolValue(String symbolKey) {
    return _merged[symbolKey];
  }

  /// Get all merged symbols.
  Map<String, SymbolValue> getAll() {
    return Map.unmodifiable(_merged);
  }

  /// Check if a symbol exists in the context.
  bool hasSymbol(String symbolKey) {
    return _merged.containsKey(symbolKey);
  }
}



