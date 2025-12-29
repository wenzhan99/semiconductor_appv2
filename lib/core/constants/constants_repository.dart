import 'dart:math' as math;

import '../models/workspace.dart';
import 'constants_loader.dart';
import 'physical_constants_table.dart';
import 'physical_constant.dart';

/// Repository for accessing physical constants.
class ConstantsRepository {
  static final ConstantsRepository _instance = ConstantsRepository._internal();
  factory ConstantsRepository() => _instance;
  ConstantsRepository._internal();

  // Normalize known aliases to canonical keys (e.g., "\hbar", "ħ" -> "hbar").
  static const Map<String, String> _aliasToCanonical = {
    r'\hbar': 'hbar',
    r'\\hbar': 'hbar',
    'ħ': 'hbar',
    'ℏ': 'hbar',
    'h_bar': 'hbar',
  };

  PhysicalConstantsTable? _constantsTable;
  bool _loaded = false;

  /// Load constants from assets.
  Future<void> load() async {
    if (_loaded) return;
    _constantsTable = await ConstantsLoader.loadConstants();
    _loaded = true;
  }

  /// Normalize a constant key or alias to a canonical lookup key.
  String normalizeConstantKey(String symbolKey) {
    var key = symbolKey.trim();
    if (key.isEmpty) return '';
    // Strip braces used in LaTeX-style identifiers, e.g. "{hbar}".
    key = key.replaceAll(RegExp(r'[{}]'), '');
    final lower = key.toLowerCase();
    final hbarAlias = _aliasToCanonical[lower] ?? _aliasToCanonical[key];
    if (hbarAlias != null) return hbarAlias;
    return key;
  }

  /// Get a constant value by its symbol key (e.g., "q", "k", "eps_0").
  double? getConstantValue(String symbolKey) {
    if (!_loaded || _constantsTable == null) return null;

    final normalized = normalizeConstantKey(symbolKey);

    if (normalized == 'hbar') {
      return getHbar();
    }

    final constant = _constantsTable!.bySymbol(normalized);
    return constant?.value;
  }

  /// Get hbar (reduced Planck constant) = h / (2*pi).
  double? getHbar() {
    final h = _constantsTable?.bySymbol('h')?.value;
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

    final normalized = normalizeConstantKey(symbolKey);
    if (normalized == 'hbar') {
      final hbar = getHbar();
      if (hbar == null) return null;
      return PhysicalConstant(
        id: 'hbar',
        name: 'Reduced Planck constant',
        symbol: 'hbar',
        aliases: const ['ħ', r'\hbar', 'h_bar'],
        value: hbar,
        unit: 'J*s',
        category: 'derived',
        expression: 'h/(2\\pi)',
        note: 'Derived from Planck constant',
      );
    }

    return _constantsTable!.bySymbol(normalized);
  }

  /// Get all constants.
  List<PhysicalConstant> getAllConstants() {
    if (!_loaded || _constantsTable == null) return [];
    final list = _constantsTable!.constants.toList();
    final hbar = getConstant('hbar');
    if (hbar != null && list.every((c) => c.symbol != 'hbar')) {
      list.add(hbar);
    }
    return list;
  }

  /// Resolve a constant key (or alias) to a SymbolValue with canonical key.
  /// Returns null if the constant cannot be found.
  MapEntry<String, SymbolValue>? resolveConstant(String symbolKey) {
    final normalized = normalizeConstantKey(symbolKey);
    if (normalized.isEmpty) return null;

    if (normalized == 'hbar') {
      final hbar = getHbar();
      if (hbar == null) return null;
      return MapEntry(
        normalized,
        SymbolValue(value: hbar, unit: 'J*s', source: SymbolSource.material),
      );
    }

    final constant = getConstant(normalized);
    if (constant == null) return null;

    return MapEntry(
      constant.symbol,
      SymbolValue(
        value: constant.value,
        unit: constant.unit,
        source: SymbolSource.material,
      ),
    );
  }

  /// Resolve a set of constant keys/aliases to SymbolValues using canonical keys.
  Map<String, SymbolValue> resolveConstants(Iterable<String>? rawKeys) {
    final resolved = <String, SymbolValue>{};
    final keys = rawKeys?.toSet() ??
        getAllConstants().map((c) => c.symbol).toSet()
          ..add('hbar');

    for (final key in keys) {
      final entry = resolveConstant(key);
      if (entry != null) {
        resolved[entry.key] = entry.value;
      }
    }
    return resolved;
  }
}
