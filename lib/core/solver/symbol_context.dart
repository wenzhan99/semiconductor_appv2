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
    Map<String, SymbolValue>? constants,
    Map<String, SymbolValue>? globals,
    Map<String, SymbolValue>? overrides,
  }) {
    _merged.clear();

    // 1. Add constants (read-only, from repository)
    _addConstants(constants);

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

  void _addConstants(Map<String, SymbolValue>? resolved) {
    final constants = resolved ?? _constantsRepo.resolveConstants(null);
    _merged.addAll(constants);
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



