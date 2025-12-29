import 'dart:convert';

import 'package:flutter/services.dart';

import 'formula.dart';
import 'formula_category.dart';

/// Repository for loading and accessing formulas from JSON assets.
class FormulaRepository {
  static final FormulaRepository _instance = FormulaRepository._internal();
  factory FormulaRepository() => _instance;
  FormulaRepository._internal();

  final Map<String, Formula> _formulas = {};
  final Map<String, FormulaCategory> _categories = {};
  bool _loaded = false;

  /// Load all formula categories and formulas from assets.
  Future<void> load() async {
    if (_loaded) return;
    await preloadAll();
  }

  /// Preload all formula JSON files from assets.
  Future<void> preloadAll() async {
    if (_loaded) return;

    // Load energy_band_structure category
    await _loadCategory('assets/formulas/energy_band_structure.json');

    // Load other category JSON files
    await _loadCategory('assets/formulas/density_of_states_statistics.json');
    await _loadCategory('assets/formulas/carrier_concentration_equilibrium.json');
    await _loadCategory('assets/formulas/carrier_transport_fundamentals.json');
    await _loadCategory('assets/formulas/pn_junction.json');

    _loaded = true;
  }

  Future<void> _loadCategory(String assetPath) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final map = jsonDecode(raw) as Map<String, dynamic>;

      // Extract categoryId from JSON or map from filename
      String categoryId;
      if (map.containsKey('id')) {
        categoryId = map['id'] as String;
      } else {
        // Fallback: map filename to categoryId
        // e.g., "assets/formulas/energy_band_structure.json" -> "energy_band_structure"
        final filename = assetPath.split('/').last.replaceAll('.json', '');
        categoryId = filename;
      }

      // Load category (use fromJson if available, otherwise create from id)
      FormulaCategory category;
      if (map.containsKey('name') && map.containsKey('formula_ids')) {
        category = FormulaCategory.fromJson(map);
      } else {
        // If category JSON is incomplete, we'll use the registry categories
        // For now, just store the categoryId mapping
        category = FormulaCategory(
          id: categoryId,
          name: map['name'] as String? ?? categoryId,
          formulaIds: (map['formula_ids'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
        );
      }
      _categories[category.id] = category;

      // Load formulas and ensure they're associated with this category
      final formulasList = map['formulas'] as List<dynamic>? ?? [];
      for (final formulaJson in formulasList) {
        try {
          final formulaMap = formulaJson as Map<String, dynamic>;
          final formula = Formula.fromJson(formulaMap);
          _formulas[formula.id] = formula;
        } catch (e, stackTrace) {
          // Log which formula failed to parse
          final formulaId = (formulaJson as Map<String, dynamic>?)?['id'] as String? ?? 'unknown';
          print('Error parsing formula "$formulaId" from $assetPath: $e');
          print('Stack trace: $stackTrace');
        }
      }
    } catch (e, stackTrace) {
      // Handle loading errors gracefully
      print('Error loading formula category from $assetPath: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Get a formula by its ID.
  Formula? getFormulaById(String formulaId) {
    return _formulas[formulaId];
  }

  /// Get a category by its ID.
  FormulaCategory? getCategoryById(String categoryId) {
    return _categories[categoryId];
  }

  /// Get all categories.
  List<FormulaCategory> getAllCategories() {
    return _categories.values.toList();
  }

  /// Get all formulas in a category.
  List<Formula> getFormulasInCategory(String categoryId) {
    final category = _categories[categoryId];
    if (category == null) return [];
    return getByIds(category.formulaIds);
  }

  /// Get multiple formulas by their IDs.
  List<Formula> getByIds(List<String> formulaIds) {
    return formulaIds
        .map((id) => _formulas[id])
        .whereType<Formula>()
        .toList();
  }
}
