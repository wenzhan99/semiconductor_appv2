# Formulas Module

## Overview

The Formulas module manages formula definitions, categories, and their metadata. It loads formulas from JSON assets, organizes them into categories, and provides access to formula data structures used throughout the application.

## Purpose

- **Formula Definitions**: Load and parse formula definitions from JSON
- **Category Organization**: Group related formulas into categories
- **Variable Management**: Define formula variables with units and constraints
- **Computation Expressions**: Store expressions for solving formulas
- **Formula Registry**: Provide lookup and access to formulas

## Files

### 1. formula.dart

**Purpose**: Core data model representing a single formula/equation entry.

**Key Class**: `Formula`

**Fields**:
- `id` (String) - Unique formula identifier (e.g., "parabolic_band_dispersion")
- `name` (String) - Human-readable formula name (e.g., "Parabolic band dispersion")
- `equationLatex` (String) - LaTeX representation of the formula (e.g., "E = \\frac{\\hbar^2 k^2}{2 m^{*}}")
- `description` (String) - Description of what the formula calculates
- `variables` (List<FormulaVariable>?) - List of variables in the formula
- `constantsUsed` (List<FormulaConstant>?) - Constants required by the formula
- `solvableFor` (List<String>?) - Variables that can be solved for (e.g., ["E", "m_star", "k"])
- `compute` (Map<String, String>?) - Expressions for solving each variable (key → expression)
  - Example: `{"E": "(hbar*hbar*k*k)/(2*m_star)", "m_star": "(hbar*hbar*k*k)/(2*E)"}`
- `notes` (List<String>?) - Additional notes about the formula
- `tests` (List<FormulaTest>?) - Test cases for validation
- `version` (int?) - Version number for schema evolution

**JSON Parsing**:
- Supports two variable formats for backward compatibility:
  1. **Simple**: `variables: ["E", "k", ...]` (strings) - automatically converted to `FormulaVariable` objects
  2. **Full**: `variables: [{key: "...", name: "...", ...}]` (objects) - parsed directly
- All other fields are optional except `id`, `name`, `equationLatex`, `description`

**Usage**: Created via `Formula.fromJson()` when loading from JSON assets. Used throughout the app to represent formula data.

**Dependencies**:
- `formula_variable.dart` - For variable model
- `formula_constant.dart` - For constant model
- `formula_test.dart` - For test model
- `package:equatable/equatable.dart` - For value equality

---

### 2. formula_variable.dart

**Purpose**: Data model for a variable in a formula.

**Key Class**: `FormulaVariable`

**Fields**:
- `key` (String) - Variable identifier (e.g., "E", "k", "m_star")
- `name` (String) - Human-readable name (e.g., "Energy above band edge")
- `siUnit` (String) - SI base unit (e.g., "J", "m^-1", "kg")
- `preferredUnits` (List<String>) - Allowed UI units (e.g., ["J", "eV"] for energy)
- `constraints` (Map<String, dynamic>?) - Constraints (e.g., `{type: "positive"}`, `{type: "nonnegative"}`)

**JSON Parsing**:
- Required fields: `key`, `name`, `siUnit`, `preferredUnits`
- `preferredUnits` defaults to empty list if missing
- `constraints` is optional

**Usage**: Used in `Formula.variables` list to define what variables a formula has. Also used by UI to generate input fields.

**Dependencies**:
- `package:equatable/equatable.dart` - For value equality

---

### 3. formula_constant.dart

**Purpose**: Data model for a constant used by a formula (different from physical constants in `core/constants/`).

**Key Class**: `FormulaConstant`

**Fields**:
- `key` (String) - Constant identifier (e.g., "hbar", "q")
- `source` (String) - Source (e.g., "physical_constants_table", "derived")
- `definition` (String?) - Optional definition (e.g., "h/(2*pi)")
- `note` (String?) - Optional note/description

**Usage**: Used in `Formula.constantsUsed` to list which constants a formula requires. These constants are then looked up from `ConstantsRepository` when solving.

**Dependencies**:
- `package:equatable/equatable.dart` - For value equality

---

### 4. formula_category.dart

**Purpose**: Data model for a category that groups related formulas.

**Key Class**: `FormulaCategory`

**Fields**:
- `id` (String) - Category identifier (e.g., "energy_band_structure")
- `name` (String) - Category name (e.g., "Energy & Band Structure")
- `formulaIds` (List<String>) - List of formula IDs in this category

**Usage**: Used to organize formulas in the UI (e.g., Topics page shows categories). Categories are defined in `categories/` subfolder and registered in `formula_registry.dart`.

**Dependencies**:
- `package:equatable/equatable.dart` - For value equality

---

### 5. formula_repository.dart

**Purpose**: Singleton repository that loads and provides access to formulas from JSON assets.

**Key Class**: `FormulaRepository`

**Key Methods**:
- `load()` - Loads all formula categories and formulas
  - Calls `preloadAll()` internally
  - Sets `_loaded` flag to prevent multiple loads
- `preloadAll()` - Preloads all formula JSON files
  - Currently loads: `energy_band_structure.json`
  - TODO: Add other category JSON files as they are created
- `getFormulaById(String id)` - Get formula by ID
  - Returns: `Formula?` (null if not found)
  - Looks up in `_formulas` map
- `getFormulasInCategory(String categoryId)` - Get all formulas in a category
  - Returns: `List<Formula>`
  - Filters formulas by category ID
- `getAllCategories()` - Get all categories
  - Returns: `List<FormulaCategory>`
  - Returns categories from `_categories` map

**Caching Strategy**:
- Uses singleton pattern (`_instance`)
- Loads once via `load()` method
- Stores formulas in `_formulas` map (keyed by ID)
- Stores categories in `_categories` map (keyed by ID)
- `_loaded` flag prevents multiple loads

**Asset Loading**:
- Loads from `assets/formulas/*.json` files
- Each JSON file represents one category
- Automatically extracts category info and formulas from JSON
- Uses `rootBundle.loadString()` to read files

**Usage**:
```dart
final repo = FormulaRepository();
await repo.load();
final formula = repo.getFormulaById('parabolic_band_dispersion');
final formulas = repo.getFormulasInCategory('energy_band_structure');
final categories = repo.getAllCategories();
```

**Dependencies**:
- `package:flutter/services.dart` - For `rootBundle` to load assets
- `dart:convert` - For JSON parsing
- `formula.dart` - For formula model
- `formula_category.dart` - For category model

---

### 6. formula_definition.dart

**Purpose**: Type alias for `Formula` to match naming convention used by solver.

**Key Definition**:
```dart
typedef FormulaDefinition = Formula;
```

**Usage**: Used in `FormulaSolver` and other solver components to refer to formula definitions. This is purely a naming convention - `FormulaDefinition` and `Formula` are the same type.

**Dependencies**:
- `formula.dart` - Just an alias

---

### 7. formula_extensions.dart

**Purpose**: Extension methods for `Formula` and `FormulaVariable` to provide convenient accessors and display helpers.

**Key Extensions**:

#### `FormulaExtensions` on `Formula`:
- `variablesResolved` - Returns variables list (never null, returns empty list if null)
  - Usage: `formula.variablesResolved` instead of `formula.variables ?? []`
- `constantsUsedResolved` - Returns constants list (never null, returns empty list if null)
  - Usage: `formula.constantsUsedResolved` instead of `formula.constantsUsed ?? []`

#### `FormulaVariableExtensions` on `FormulaVariable`:
- `displayName(LatexSymbolMap latexMap)` - Gets display name using LaTeX symbol map
  - Returns LaTeX symbol if available, otherwise uses `name`, otherwise uses `key`
  - Usage: `variable.displayName(latexMap)` to get formatted display name
- `unitLabel` - Gets unit label for display
  - Returns `siUnit` if available, otherwise first `preferredUnit`, otherwise empty string
  - Usage: `variable.unitLabel` to get unit string

**Usage**: Provides safe access to formula properties without null checks. Used throughout UI components.

**Dependencies**:
- `formula.dart` - For `Formula` extension
- `formula_variable.dart` - For `FormulaVariable` extension
- `formula_constant.dart` - For constants
- `../constants/latex_symbols.dart` - For LaTeX symbol mapping

---

### 8. formula_registry.dart

**Purpose**: Central registry that defines all formula categories as constants.

**Key Content**:
- Exports all category files from `categories/` subfolder
- Defines `formulaCategories` constant list containing all categories:
  - `energyBandStructure`
  - `densityOfStatesStatistics`
  - `carrierConcentrationEquilibrium`
  - `carrierTransportDriftDiffusion`
  - `pnJunction`
  - `contactsBreakdown`

**Usage**: Used by `TopicsPage` to display all available categories. Categories are defined in individual files in `categories/` subfolder.

**Dependencies**:
- `formula_category.dart` - For category model
- `categories/*.dart` - All category definition files

---

### 9. formula_test.dart

**Purpose**: Data model for formula test cases used for validation.

**Key Class**: `FormulaTest`

**Fields**:
- `given` (Map<String, dynamic>) - Input values (e.g., `{"k": 1e9, "m_star": 2.37e-31}`)
- `solveFor` (String) - Variable to solve for (e.g., "E")
- `expect` (Map<String, dynamic>) - Expected result (e.g., `{"value": 2.35e-20, "unit": "J"}`)
- `tolerance` (Map<String, dynamic>?) - Tolerance (e.g., `{"relative": 0.05}` or `{"absolute": 1e-10}`)

**Usage**: Used for validating formula implementations. Tests can be run to ensure formulas compute correctly.

**Dependencies**:
- `package:equatable/equatable.dart` - For value equality

---

### 10. categories/ (Subfolder)

**Purpose**: Contains category definition files. Each file defines a `FormulaCategory` constant for one category.

**Files**:
- `energy_band_structure.dart` - Energy & Band Structure category
- `carrier_concentration_equilibrium.dart` - Carrier concentration category
- `carrier_transport_drift_diffusion.dart` - Carrier transport category
- `contacts_breakdown.dart` - Contacts & breakdown category
- `density_of_states_statistics.dart` - Density of states category
- `pn_junction.dart` - PN junction category
- `categories.dart` - Exports all category files

**Structure**: Each category file defines a constant like:
```dart
const FormulaCategory energyBandStructure = FormulaCategory(
  id: 'energy_band_structure',
  name: 'Energy & Band Structure',
  formulaIds: [
    'parabolic_band_dispersion',
    'effective_mass_from_curvature',
  ],
);
```

**Usage**: Categories are registered in `formula_registry.dart` and used by UI to organize formulas.

**Dependencies**:
- `../formula_category.dart` - For category model

---

## Data Flow

```
assets/formulas/*.json
    ↓
FormulaRepository.load()
    ↓
Parse JSON → FormulaCategory + List<Formula>
    ↓
Store in maps (cached)
    ↓
UI / Solver access via repository
```

**Detailed Flow**:
1. **App Initialization**: `FormulaRepository.load()` is called (typically lazy, when first needed)
2. **Loading**: Repository reads JSON files from `assets/formulas/`
3. **Parsing**: Each JSON file is parsed into `FormulaCategory` and `List<Formula>`
4. **Caching**: Formulas stored in `_formulas` map, categories in `_categories` map
5. **Access**: UI and solver access formulas via repository methods

## Dependencies

- `package:flutter/services.dart` - For `rootBundle` to load assets
- `package:equatable/equatable.dart` - For value equality
- `dart:convert` - For JSON parsing
- `core/constants/` - For constant lookups (via `FormulaConstant` references)

## JSON Structure

**Category JSON Format**:
```json
{
  "id": "energy_band_structure",
  "name": "Energy & Band Structure",
  "formula_ids": ["parabolic_band_dispersion", ...],
  "formulas": [
    {
      "id": "parabolic_band_dispersion",
      "name": "Parabolic band dispersion",
      "equation_latex": "E = \\frac{\\hbar^2 k^2}{2 m^{*}}",
      "description": "...",
      "variables": [
        {
          "key": "E",
          "name": "Energy above band edge",
          "si_unit": "J",
          "preferred_units": ["J", "eV"],
          "constraints": {"type": "nonnegative"}
        }
      ],
      "constants_used": [
        {"key": "hbar", "source": "physical_constants_table", "note": "..."}
      ],
      "solvable_for": ["E", "m_star", "k"],
      "compute": {
        "E": "(hbar*hbar*k*k)/(2*m_star)",
        "m_star": "(hbar*hbar*k*k)/(2*E)"
      }
    }
  ]
}
```

## Error Handling

- **Missing formulas**: `getFormulaById()` returns `null` if not found
- **JSON parsing errors**: Propagate as exceptions
- **Invalid formula structure**: May cause runtime errors during parsing
- **Callers should check for null** before using formulas

## Testing

Key test cases:
1. Load valid JSON successfully
2. Parse formulas with simple variable format (strings)
3. Parse formulas with full variable format (objects)
4. `getFormulaById()` returns correct formula
5. `getFormulasInCategory()` returns correct list
6. Handle missing formula gracefully
7. `variablesResolved` and `constantsUsedResolved` extensions work correctly
8. `displayName()` uses LaTeX symbols correctly

## Public API Summary

**Main Entry Point**: `FormulaRepository` (singleton)
- `load()` - Initialize (call once)
- `getFormulaById(String)` - Get formula by ID
- `getFormulasInCategory(String)` - Get formulas in category
- `getAllCategories()` - Get all categories

**Data Models**:
- `Formula` - Main formula model
- `FormulaVariable` - Variable definition
- `FormulaConstant` - Constant reference
- `FormulaCategory` - Category definition
- `FormulaTest` - Test case model

**Extensions**:
- `FormulaExtensions` - Safe accessors for `Formula`
- `FormulaVariableExtensions` - Display helpers for `FormulaVariable`
