# Constants Module Documentation

## Overview

The Constants module is responsible for loading, storing, and providing access to physical constants used throughout the semiconductor calculator application. It handles both numeric values (like Planck's constant, elementary charge) and their LaTeX symbol representations for display in formulas and step-by-step derivations.

### Purpose

The Constants subsystem solves several key problems:

1. **Centralized Constant Management**: All physical constants are stored in a single JSON file, making updates easy and ensuring consistency across the app.
2. **Unit Safety**: Constants are stored with their SI units, preventing silent unit mismatches (e.g., mixing eV and J).
3. **LaTeX Rendering**: Provides symbol-to-LaTeX mappings so formulas display correctly in the UI.
4. **Energy Conversion**: Supports J ↔ eV conversion using the elementary charge constant `q`.

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

### Detailed Flow

1. **App Initialization** (`lib/main.dart`):
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

## Unit Selection Impact

The Constants module is unit-aware:

- **All constants are stored in SI base units** (J, kg, m, s, C, K, etc.)
- **Energy conversion** (J ↔ eV) uses the elementary charge `q`:
  - `1 eV = q J` where `q = 1.602176634 × 10⁻¹⁹ C`
  - Conversion is handled by `UnitConverter.convertEnergy()`
- **Constants are displayed with their stored units** in the UI
- **No automatic unit conversion** is performed on constant values themselves (they remain in SI)

### Example: Energy Constants

When a formula uses energy:
- If user selects **eV** for input/output, the UI converts using `q` at the boundary
- The constant `q` is automatically shown in the "Constants used" section when eV is selected
- Internal computations always use **J** (SI base unit)

## Public APIs

### ConstantsRepository (Singleton)

**Location**: `lib/core/constants/constants_repository.dart`

**Key Methods**:

```dart
// Load constants from assets (called once at app startup)
Future<void> load()

// Get numeric value by symbol key (e.g., "q", "h", "k")
double? getConstantValue(String symbolKey)

// Get full PhysicalConstant object
PhysicalConstant? getConstant(String symbolKey)

// Get all constants as a list
List<PhysicalConstant> getAllConstants()

// Specialized getters
double? getHbar()  // Returns h / (2*pi)
double? getElectronVoltJoules()  // Returns q (for eV↔J conversion)
```

**Usage Example**:
```dart
final repo = ConstantsRepository();
await repo.load();
final q = repo.getConstantValue('q');  // 1.602176634e-19
final hbar = repo.getHbar();  // 1.054571817e-34
```

### ConstantsLoader (Static Utility)

**Location**: `lib/core/constants/constants_loader.dart`

**Key Methods**:

```dart
// Load physical constants table from JSON
static Future<PhysicalConstantsTable> loadConstants()

// Load LaTeX symbol map from JSON
static Future<LatexSymbolMap> loadLatexSymbols()
```

**Usage Example**:
```dart
final table = await ConstantsLoader.loadConstants();
final latexMap = await ConstantsLoader.loadLatexSymbols();
```

### PhysicalConstantsTable

**Location**: `lib/core/constants/physical_constants_table.dart`

**Key Methods**:

```dart
// Find constant by stable ID (e.g., "elementary_charge")
PhysicalConstant? byId(String id)

// Find constant by symbol or alias (e.g., "q" or "e")
PhysicalConstant? bySymbol(String symbolOrAlias)
```

### LatexSymbolMap

**Location**: `lib/core/constants/latex_symbols.dart`

**Key Methods**:

```dart
// Get LaTeX string for a symbol key (falls back to key if not found)
String latexOf(String symbolKey)
```

**Usage Example**:
```dart
final map = await ConstantsLoader.loadLatexSymbols();
final latex = map.latexOf('hbar');  // Returns "\hbar"
final latex2 = map.latexOf('eps_0');  // Returns "\varepsilon_0"
```

## Error Handling

### Missing JSON Keys

- **JSON parsing**: Uses null-safe operators (`as String?`, `?? const []`)
- **Missing constants**: `getConstantValue()` returns `null` if constant not found
- **UI handling**: Components check for `null` before displaying values

### Invalid Units

- **Unit strings are stored as-is** in the JSON (e.g., "J*s", "F/m", "m^-1")
- **No validation** is performed on unit strings (they are display-only)
- **Unit conversion** in `UnitConverter` handles known unit pairs; returns `null` for unknown conversions

### Null Values

- **Repository methods return nullable types** (`double?`, `PhysicalConstant?`)
- **Callers must check for null** before using values
- **UI components** show placeholder text or hide sections when constants are missing

### Parsing Failures

- **JSON decode errors**: Will throw `FormatException` (not caught by Constants module)
- **Type casting errors**: Will throw `TypeError` if JSON structure is wrong
- **Recommendation**: Wrap `load()` calls in try-catch at the app initialization level

## Testing Strategy

### Unit Tests

**Test File Structure**:
```
test/
  constants/
    constants_loader_test.dart
    constants_repository_test.dart
    physical_constant_test.dart
    physical_constants_table_test.dart
    latex_symbols_test.dart
```

**Key Test Cases**:

1. **ConstantsLoader**:
   - Load valid JSON successfully
   - Handle missing JSON file gracefully
   - Handle malformed JSON (invalid structure)
   - Load LaTeX symbols correctly

2. **ConstantsRepository**:
   - Singleton pattern works correctly
   - Load caches data (doesn't reload if already loaded)
   - `getConstantValue()` returns correct values
   - `getHbar()` calculates correctly from `h`
   - Returns `null` for non-existent constants

3. **PhysicalConstant**:
   - `fromJson()` parses all required fields
   - `fromJson()` handles optional fields (category, note, etc.)
   - `toJson()` produces valid JSON

4. **PhysicalConstantsTable**:
   - `byId()` finds constants correctly
   - `bySymbol()` finds by symbol
   - `bySymbol()` finds by alias (e.g., "e" → "q")
   - Returns `null` for non-existent constants

5. **LatexSymbolMap**:
   - `latexOf()` returns correct LaTeX for known symbols
   - `latexOf()` falls back to symbol key for unknown symbols

### Sample Test Data

**Minimal Valid JSON**:
```json
{
  "source": "Test",
  "type": "physical_constants",
  "constants": [
    {
      "id": "test_constant",
      "name": "Test Constant",
      "symbol": "t",
      "aliases": [],
      "value": 1.0,
      "unit": "unitless"
    }
  ]
}
```

**Expected Parsed Object**:
```dart
PhysicalConstant(
  id: "test_constant",
  name: "Test Constant",
  symbol: "t",
  aliases: [],
  value: 1.0,
  unit: "unitless",
  category: null,
  expression: null,
  note: null,
  definition: null,
  assumedTemperatureK: null,
)
```

---

## File-by-File Explanation

### 1. constants_loader.dart

**Location**: `lib/core/constants/constants_loader.dart`

**Primary Responsibility**: 
Static utility class that loads JSON files from Flutter assets and parses them into Dart objects.

**Inputs/Outputs**:
- **Input**: JSON files in `assets/constants/` (must be declared in `pubspec.yaml`)
  - `ee2103_physical_constants.json` - Physical constants data
  - `ee2103_latex_symbols.json` - LaTeX symbol mappings
- **Output**: 
  - `PhysicalConstantsTable` object (from constants JSON)
  - `LatexSymbolMap` object (from LaTeX symbols JSON)

**Where It's Called From**:
- `main.dart` (app initialization) - loads LaTeX symbols
- `ConstantsRepository.load()` - loads constants table
- `ConstantsUnitsPage._loadData()` - loads both for display

**Typical Failure Modes**:
1. **Missing asset file**: Throws `Unable to load asset` exception
2. **Invalid JSON**: Throws `FormatException` from `jsonDecode()`
3. **Wrong JSON structure**: Throws `TypeError` when casting to expected types

**How Handled**:
- Currently **not handled** - exceptions propagate to caller
- **Recommendation**: Wrap in try-catch at app initialization, show error dialog to user

---

### 2. constants_repository.dart

**Location**: `lib/core/constants/constants_repository.dart`

**Primary Responsibility**: 
Singleton repository that caches loaded constants and provides convenient access methods. Acts as the main API for other modules to retrieve constant values.

**Caching Strategy**:
- Uses singleton pattern (`_instance`)
- Loads constants once via `load()` method
- Stores `PhysicalConstantsTable` in private `_constantsTable` field
- `_loaded` flag prevents multiple loads
- **No automatic reload** - constants are loaded once at app startup

**How Constants Are Retrieved**:
- **By symbol key**: `getConstantValue('q')` or `getConstant('q')`
- **By alias**: `bySymbol()` in `PhysicalConstantsTable` checks aliases
- **All constants**: `getAllConstants()` returns the full list
- **Specialized**: `getHbar()` computes h/(2π), `getElectronVoltJoules()` returns `q`

**How It Interacts with Loader + UI**:
- **Loader**: Uses `ConstantsLoader.loadConstants()` internally
- **UI**: Provided via `Provider` in `main.dart`, accessed via `context.read<ConstantsRepository>()`
- **Formula Solver**: Retrieves constants to populate `SymbolContext` for formula evaluation

---

### 3. latex_symbols.dart

**Location**: `lib/core/constants/latex_symbols.dart`

**Why LaTeX Symbol Mapping is Needed**:
- Formulas need to display mathematical symbols correctly (e.g., `ħ` instead of `hbar`, `ε₀` instead of `eps_0`)
- Step-by-step derivations render in LaTeX format using `flutter_math_fork`
- UI components need to convert symbol keys (used in code) to LaTeX strings (used in display)

**How Symbols Are Represented**:
- **Data structure**: `Map<String, String>` where key is symbol identifier (e.g., "hbar") and value is LaTeX string (e.g., "\\hbar")
- **Loaded from JSON**: `assets/constants/ee2103_latex_symbols.json`
- **Immutable**: Uses `const` constructor, implements `Equatable` for value equality

**How This Supports Step-by-Step Derivations and UI Display**:
- **StepLaTeXBuilder**: Uses `latexOf()` to convert symbol keys to LaTeX for formula rendering
- **FormulaPanel**: Uses `latexOf()` to display constant symbols in "Constants used" section
- **TopicsPage**: Uses `latexOf()` to render formula equations in LaTeX format
- **Fallback behavior**: If symbol not found, returns the key itself (prevents crashes)

**Example**:
```dart
final map = LatexSymbolMap(...);
map.latexOf('hbar')  // Returns "\hbar"
map.latexOf('eps_0')  // Returns "\varepsilon_0"
map.latexOf('unknown')  // Returns "unknown" (fallback)
```

---

### 4. physical_constant.dart

**Location**: `lib/core/constants/physical_constant.dart`

**Data Model Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `String` | Yes | Stable identifier (snake_case, e.g., "elementary_charge") |
| `name` | `String` | Yes | Human-readable name (e.g., "Electronic charge") |
| `symbol` | `String` | Yes | Canonical symbol key (e.g., "q") |
| `aliases` | `List<String>` | Yes | Alternative symbols (e.g., ["e"] for "q") |
| `value` | `double` | Yes | Numeric value in SI units |
| `unit` | `String` | Yes | Unit string (e.g., "C", "J*s", "F/m") |
| `category` | `String?` | No | Grouping (e.g., "semiconductor", "quantum") |
| `expression` | `String?` | No | Formula expression (e.g., "4*pi*1e-7") |
| `note` | `String?` | No | Additional notes |
| `definition` | `String?` | No | Definition formula (e.g., "k*T/q") |
| `assumedTemperatureK` | `double?` | No | Temperature if definition assumes T (e.g., 300 for V_T) |

**Serialization/Deserialization Expectations from JSON**:

**Required JSON Fields**:
```json
{
  "id": "string",
  "name": "string",
  "symbol": "string",
  "aliases": ["string", ...],  // Can be empty array
  "value": number,
  "unit": "string"
}
```

**Optional JSON Fields**:
```json
{
  "category": "string",
  "expression": "string",
  "note": "string",
  "definition": "string",
  "assumed_temperature_K": number
}
```

**Parsing Behavior**:
- `aliases` defaults to empty list if missing
- All optional fields default to `null` if missing
- `value` is converted from `num` to `double`
- `assumed_temperature_K` uses snake_case in JSON, camelCase in Dart

**How to Represent Dual-Units or Selectable Units (eV vs J)**:
- **Current approach**: Constants are stored in **SI base units only** (J for energy)
- **eV conversion**: Handled separately via `UnitConverter.convertEnergy()` using `q`
- **No dual-unit storage**: The constant `q` is stored in Coulombs (C), not as an energy unit
- **UI display**: When showing constants, units are displayed as stored (no conversion)
- **Recommendation**: If you need to show constants in multiple units, add a display formatter that converts at render time, but keep storage in SI

---

### 5. physical_constants_table.dart

**Location**: `lib/core/constants/physical_constants_table.dart`

**How Constants Are Organized**:
- **Container class**: Holds a `List<PhysicalConstant>` and metadata (`source`, `type`)
- **No grouping**: Constants are stored in a flat list (grouping is done via `category` field on individual constants)
- **Lookup methods**: `byId()` and `bySymbol()` provide O(n) linear search (acceptable for small datasets)

**How It Is Rendered or Provided to UI**:
- **ConstantsUnitsPage**: Calls `getAllConstants()` and groups by `category` for display
- **FormulaPanel**: Uses `getConstant()` to retrieve specific constants for "Constants used" section
- **Not directly rendered**: UI components iterate over the list and build widgets

**Formatting Rules**:
- **Scientific notation**: Handled by `NumberFormatter` (not in this module)
- **Significant figures**: Determined by `NumberFormatter` (typically 3-4 sig figs)
- **Unit strings**: Stored as-is from JSON (e.g., "J*s", "F/m", "m^-1")
- **LaTeX units**: Converted by `NumberFormatter.formatLatexUnit()` when rendering

**Example Usage**:
```dart
final table = await ConstantsLoader.loadConstants();
final q = table.bySymbol('q');  // Finds by symbol "q"
final e = table.bySymbol('e');  // Finds by alias "e" (returns same constant as above)
final all = table.constants;  // Gets full list
```

---

### 6. constants_loader.dart (Duplicate File Issue)

**Location**: 
- `lib/core/constants/constants_loader.dart` ✅ **ACTIVE**
- `lib/services/constants_loader.dart` ❌ **UNUSED/DUPLICATE**

**If There Are Two constants_loader.dart Files**:

**Current Situation**:
- **`lib/core/constants/constants_loader.dart`**: 
  - Imports from `core/constants/` (correct)
  - Used by `main.dart` and `ConstantsRepository`
  - ✅ **This is the active version**

- **`lib/services/constants_loader.dart`**:
  - Imports from `models/` (old structure)
  - References `PhysicalConstantsTable` and `LatexSymbolMap` from `models/`
  - ❌ **Not imported anywhere, appears to be legacy code**

**Difference**:
- The `services/` version imports from `models/` instead of `core/constants/`
- This suggests an old architecture where constants were in `models/`
- The codebase has migrated to `core/constants/` but the old file wasn't deleted

**Recommended Architecture**:

```
lib/
  core/
    constants/           ← Single source of truth
      constants_loader.dart
      constants_repository.dart
      physical_constant.dart
      physical_constants_table.dart
      latex_symbols.dart
  services/             ← Should NOT have constants_loader.dart
  models/               ← Should NOT have physical_constant.dart or physical_constants_table.dart
```

**Action Items**:
1. **Delete** `lib/services/constants_loader.dart` (unused)
2. **Delete** `lib/models/physical_constant.dart` and `lib/models/physical_constants_table.dart` (if they exist and are unused)
3. **Update imports**: Ensure all files import from `core/constants/`
4. **Verify**: Run `grep -r "services/constants_loader"` and `grep -r "models/physical_constant"` to confirm no references

**Final Recommended Architecture**:

```
Constants Module Structure:
├── lib/core/constants/
│   ├── constants_loader.dart          ← Static loader utility
│   ├── constants_repository.dart      ← Singleton repository (main API)
│   ├── physical_constant.dart         ← Data model (single constant)
│   ├── physical_constants_table.dart  ← Data model (table container)
│   └── latex_symbols.dart             ← LaTeX symbol mapping
└── assets/constants/
    ├── ee2103_physical_constants.json ← Source data
    └── ee2103_latex_symbols.json      ← LaTeX mappings
```

**Dependency Rules**:
- ✅ `core/constants/` can depend on Flutter (`package:flutter/services.dart`)
- ✅ `core/constants/` can depend on `equatable` package
- ❌ `core/constants/` should NOT depend on UI or services
- ✅ Other modules can depend on `core/constants/`

---

## Summary

The Constants module provides a clean, centralized way to manage physical constants in the semiconductor calculator app. It separates concerns:

- **Loading** (ConstantsLoader): Handles asset loading and JSON parsing
- **Storage** (ConstantsRepository): Caches and provides access
- **Data Models** (PhysicalConstant, PhysicalConstantsTable): Represent constants as structured data
- **Presentation** (LatexSymbolMap): Maps symbols to LaTeX for display

The module is unit-aware (all values in SI) and supports energy conversion via the `q` constant. Error handling is minimal (returns null for missing constants), so callers must check for null values.

