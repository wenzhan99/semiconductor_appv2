# Constants Module

## Overview

The Constants module manages physical constants used throughout the semiconductor calculator application. It handles loading constants from JSON assets, caching them, and providing access to both numeric values and LaTeX symbol representations.

## Purpose

- **Centralized Constant Management**: All physical constants stored in a single JSON file
- **Unit Safety**: Constants stored in SI base units (J, kg, m, s, C, K)
- **LaTeX Rendering**: Provides symbol-to-LaTeX mappings for formula display
- **Energy Conversion Support**: Provides `q` constant for J ↔ eV conversion

## Files

### 1. constants_loader.dart

**Purpose**: Static utility class that loads JSON files from Flutter assets and parses them into Dart objects.

**Key Methods**:
- `loadConstants()` - Loads physical constants from `assets/constants/ee2103_physical_constants.json`
  - Returns: `Future<PhysicalConstantsTable>`
  - Uses `rootBundle.loadString()` to read JSON file
  - Parses JSON and creates `PhysicalConstantsTable` object
- `loadLatexSymbols()` - Loads LaTeX symbol mappings from `assets/constants/ee2103_latex_symbols.json`
  - Returns: `Future<LatexSymbolMap>`
  - Parses JSON and creates `LatexSymbolMap` object

**Usage**:
```dart
final table = await ConstantsLoader.loadConstants();
final latexMap = await ConstantsLoader.loadLatexSymbols();
```

**Called From**:
- `main.dart` (app initialization) - loads LaTeX symbols
- `ConstantsRepository.load()` - loads constants table
- `ConstantsUnitsPage._loadData()` - loads both for display

**Error Handling**: 
- Currently not handled - exceptions propagate to caller
- JSON decode errors will throw `FormatException`
- Missing asset files will throw `Unable to load asset` exception
- **Recommendation**: Wrap in try-catch at app initialization level

**Dependencies**:
- `package:flutter/services.dart` - For `rootBundle` to load assets
- `dart:convert` - For `jsonDecode()`

---

### 2. constants_repository.dart

**Purpose**: Singleton repository that caches loaded constants and provides convenient access methods. This is the main API for other modules to retrieve constant values.

**Key Methods**:
- `load()` - Loads constants from assets (called once at app startup)
  - Uses `ConstantsLoader.loadConstants()` internally
  - Sets `_loaded` flag to prevent multiple loads
  - Stores `PhysicalConstantsTable` in private `_constantsTable` field
- `getConstantValue(String symbolKey)` - Get numeric value by symbol (e.g., "q", "h")
  - Returns: `double?` (null if constant not found)
  - Looks up constant in table and returns its `value` field
- `getConstant(String symbolKey)` - Get full `PhysicalConstant` object
  - Returns: `PhysicalConstant?` (null if not found)
  - Useful when you need unit, name, or other metadata
- `getAllConstants()` - Get all constants as a list
  - Returns: `List<PhysicalConstant>`
  - Returns empty list if not loaded
- `getHbar()` - Returns reduced Planck constant (h / 2π)
  - Returns: `double?`
  - Computes hbar from Planck's constant `h`
  - Formula: `hbar = h / (2 * π)`
- `getElectronVoltJoules()` - Returns elementary charge `q` for eV↔J conversion
  - Returns: `double?`
  - Returns the value of `q` constant (1.602176634 × 10⁻¹⁹ C)
  - Used by `UnitConverter` for energy conversion

**Caching Strategy**:
- Uses singleton pattern (`_instance`)
- Loads once via `load()` method
- Stores `PhysicalConstantsTable` in private field
- `_loaded` flag prevents multiple loads
- **No automatic reload** - constants are loaded once at app startup

**Usage**:
```dart
final repo = ConstantsRepository();
await repo.load();
final q = repo.getConstantValue('q');  // 1.602176634e-19
final hbar = repo.getHbar();  // 1.054571817e-34
final constant = repo.getConstant('q');  // Full PhysicalConstant object
```

**Provided To**: UI via `Provider` in `main.dart`, accessed via `context.read<ConstantsRepository>()`

**Dependencies**:
- `constants_loader.dart` - For loading constants
- `physical_constants_table.dart` - For table structure
- `physical_constant.dart` - For constant model
- `dart:math` - For `pi` constant (in `getHbar()`)

---

### 3. latex_symbols.dart

**Purpose**: Maps symbol keys (used in code) to LaTeX strings (used in display). This enables proper mathematical typesetting in formulas and step-by-step derivations.

**Key Class**: `LatexSymbolMap`

**Fields**:
- `source` (String) - Source identifier (e.g., "EE2103 LaTeX symbols")
- `symbols` (Map<String, String>) - Mapping from symbol key to LaTeX string
  - Key: Symbol identifier (e.g., "hbar", "eps_0")
  - Value: LaTeX string (e.g., "\\hbar", "\\varepsilon_0")

**Key Methods**:
- `latexOf(String symbolKey)` - Returns LaTeX string for symbol, falls back to key if not found
  - Returns: `String`
  - If symbol found in map, returns LaTeX string
  - If not found, returns the symbol key itself (prevents crashes)

**JSON Parsing**:
- Loaded from `assets/constants/ee2103_latex_symbols.json`
- JSON structure: `{"source": "...", "symbols": {"hbar": "\\hbar", ...}}`
- Missing `source` defaults to "unknown"
- Missing `symbols` defaults to empty map

**Usage**:
```dart
final map = await ConstantsLoader.loadLatexSymbols();
final latex = map.latexOf('hbar');  // Returns "\hbar"
final latex2 = map.latexOf('eps_0');  // Returns "\varepsilon_0"
final latex3 = map.latexOf('unknown');  // Returns "unknown" (fallback)
```

**Used By**:
- `StepLaTeXBuilder` - For formula rendering in step-by-step working
- `FormulaPanel` - For displaying constant symbols in "Constants used" section
- `TopicsPage` - For rendering formula equations in LaTeX format
- `ConstantsUnitsPage` - For displaying constant symbols

**Dependencies**:
- `package:equatable/equatable.dart` - For value equality

---

### 4. physical_constant.dart

**Purpose**: Data model representing a single physical constant entry from the JSON file.

**Key Class**: `PhysicalConstant`

**Fields**:
- `id` (String) - Stable identifier (snake_case, e.g., "elementary_charge")
- `name` (String) - Human-readable name (e.g., "Electronic charge")
- `symbol` (String) - Canonical symbol key (e.g., "q")
- `aliases` (List<String>) - Alternative symbols (e.g., ["e"] for "q")
- `value` (double) - Numeric value in SI units
- `unit` (String) - Unit string (e.g., "C", "J*s", "F/m")
- `category` (String?) - Optional grouping (e.g., "semiconductor", "quantum")
- `expression` (String?) - Optional formula expression (e.g., "4*pi*1e-7")
- `note` (String?) - Optional notes/description
- `definition` (String?) - Optional definition formula (e.g., "k*T/q")
- `assumedTemperatureK` (double?) - Temperature if definition assumes T (e.g., 300 for V_T)

**JSON Parsing**:
- Required fields: `id`, `name`, `symbol`, `aliases`, `value`, `unit`
- Optional fields: `category`, `expression`, `note`, `definition`, `assumed_temperature_K`
- `aliases` defaults to empty list if missing
- All optional fields default to `null`
- `value` is converted from `num` to `double`
- `assumed_temperature_K` uses snake_case in JSON, camelCase in Dart

**Example JSON**:
```json
{
  "id": "elementary_charge",
  "name": "Electronic charge",
  "symbol": "q",
  "aliases": ["e"],
  "value": 1.6e-19,
  "unit": "C",
  "category": "semiconductor"
}
```

**Usage**: Created via `PhysicalConstant.fromJson()` when loading from JSON. Used throughout the app to represent constant data.

**Dependencies**:
- `package:equatable/equatable.dart` - For value equality

---

### 5. physical_constants_table.dart

**Purpose**: Container class that holds a list of `PhysicalConstant` objects and provides lookup methods.

**Key Class**: `PhysicalConstantsTable`

**Fields**:
- `source` (String) - Source identifier (e.g., "EE2103 Appendix B")
- `type` (String) - Type identifier (e.g., "physical_constants")
- `constants` (List<PhysicalConstant>) - List of all constants

**Key Methods**:
- `byId(String id)` - Find constant by stable ID (e.g., "elementary_charge")
  - Returns: `PhysicalConstant?`
  - Uses linear search through constants list
  - Returns `null` if not found
- `bySymbol(String symbolOrAlias)` - Find by symbol or alias (e.g., "q" or "e")
  - Returns: `PhysicalConstant?`
  - Checks both `symbol` field and `aliases` list
  - Returns `null` if not found
  - Uses O(n) linear search (acceptable for small datasets)

**JSON Parsing**:
- Loaded from `assets/constants/ee2103_physical_constants.json`
- JSON structure: `{"source": "...", "type": "...", "constants": [...]}`
- Missing `source` defaults to "unknown"
- Missing `type` defaults to "unknown"
- Missing `constants` defaults to empty list

**Usage**:
```dart
final table = await ConstantsLoader.loadConstants();
final q = table.bySymbol('q');  // Finds by symbol
final e = table.bySymbol('e');  // Finds by alias (returns same constant as above)
final charge = table.byId('elementary_charge');  // Finds by ID
```

**Lookup Behavior**:
- `bySymbol()` checks both `symbol` field and `aliases` list
- Returns `null` if constant not found
- Uses O(n) linear search (acceptable for small datasets, typically < 20 constants)

**Dependencies**:
- `physical_constant.dart` - For constant model
- `package:equatable/equatable.dart` - For value equality

---

## Data Flow

```
assets/constants/ee2103_physical_constants.json
    ↓
ConstantsLoader.loadConstants()
    ↓
PhysicalConstantsTable.fromJson()
    ↓
ConstantsRepository (singleton, caches table)
    ↓
UI Components / Formula Solver / Unit Converter
```

**Detailed Flow**:
1. **App Initialization** (`main.dart`):
   - `ConstantsRepository()` is instantiated (singleton)
   - `constantsRepo.load()` is called, which internally uses `ConstantsLoader.loadConstants()`
   - `ConstantsLoader.loadLatexSymbols()` loads the LaTeX symbol map
   - Both are provided via `Provider` to the widget tree

2. **Usage in UI**:
   - `ConstantsUnitsPage` displays all constants in a table
   - `FormulaPanel` shows constants used by a specific formula
   - `UnitConverter` uses constants for unit conversions (especially `q` for eV↔J)

3. **Usage in Solver**:
   - `FormulaSolver` retrieves constants via `ConstantsRepository` to populate `SymbolContext`
   - Constants are substituted into formulas during computation

## Dependencies

- `package:flutter/services.dart` - For `rootBundle` to load assets
- `package:equatable/equatable.dart` - For value equality
- `dart:convert` - For JSON parsing
- `dart:math` - For mathematical constants (π in `getHbar()`)

## Error Handling

- **Missing constants**: Methods return `null` if constant not found
- **JSON parsing errors**: Propagate as exceptions (not caught by module)
- **Callers must check for `null`** before using values
- **Recommendation**: Wrap `load()` calls in try-catch at app initialization level

## Testing

Key test cases:
1. Load valid JSON successfully
2. Handle missing JSON file gracefully
3. Handle malformed JSON
4. `getConstantValue()` returns correct values
5. `getHbar()` calculates correctly (h / 2π)
6. `bySymbol()` finds by alias (e.g., "e" → "q")
7. `latexOf()` falls back to key for unknown symbols
8. Singleton pattern works correctly
9. Caching prevents multiple loads

## Public API Summary

**Main Entry Point**: `ConstantsRepository` (singleton)
- `load()` - Initialize (call once at app startup)
- `getConstantValue(String)` - Get numeric value
- `getConstant(String)` - Get full constant object
- `getAllConstants()` - Get all constants
- `getHbar()` - Get reduced Planck constant
- `getElectronVoltJoules()` - Get elementary charge (for conversion)

**Utility**: `ConstantsLoader` (static)
- `loadConstants()` - Load constants table
- `loadLatexSymbols()` - Load LaTeX symbol map
