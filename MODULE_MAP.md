# Module Map - Semiconductor Calculator Architecture

## Overview

This document defines clear module boundaries, ownership, and dependency rules for the Flutter semiconductor calculator project.

## Module Structure

```
lib/
├── core/              ← Core business logic (no UI, no Flutter-specific)
│   ├── constants/    ← Physical constants management
│   ├── formulas/     ← Formula definitions and parsing
│   └── solver/       ← Formula solving and computation
├── models/           ← Shared data models (domain objects)
├── services/         ← Application services (state, storage, auth)
├── ui/               ← User interface (Flutter widgets)
│   ├── pages/        ← Full-screen pages
│   └── widgets/      ← Reusable UI components
└── themes/           ← Theme configuration
```

---

## Module Boundaries

### 1. `core/constants/` - Constants Module

**What It Owns**:
- ✅ Physical constants data models (`PhysicalConstant`, `PhysicalConstantsTable`)
- ✅ Constants loading from JSON assets (`ConstantsLoader`)
- ✅ Constants repository/cache (`ConstantsRepository`)
- ✅ LaTeX symbol mapping (`LatexSymbolMap`)

**What It Should NOT Own**:
- ❌ UI widgets (belongs in `ui/widgets/`)
- ❌ Application state management (belongs in `services/`)
- ❌ Unit conversion logic (belongs in `core/solver/`)
- ❌ Formula definitions (belongs in `core/formulas/`)

**Dependencies**:
- ✅ Can depend on: Flutter (`package:flutter/services.dart` for `rootBundle`), `equatable` package
- ❌ Should NOT depend on: UI, services, other core modules (except via interfaces)

**Public API**:
- `ConstantsRepository` (singleton) - main access point
- `ConstantsLoader` (static utility) - for direct loading
- `PhysicalConstant`, `PhysicalConstantsTable` - data models
- `LatexSymbolMap` - symbol mapping

---

### 2. `core/formulas/` - Formulas Module

**What It Owns**:
- ✅ Formula definitions (`Formula`, `FormulaDefinition`)
- ✅ Formula variables (`FormulaVariable`)
- ✅ Formula constants (`FormulaConstant`)
- ✅ Formula categories (`FormulaCategory`)
- ✅ Formula repository/registry (`FormulaRepository`, `FormulaRegistry`)
- ✅ Formula parsing from JSON

**What It Should NOT Own**:
- ❌ Formula solving logic (belongs in `core/solver/`)
- ❌ UI rendering (belongs in `ui/`)
- ❌ Physical constants (belongs in `core/constants/`)

**Dependencies**:
- ✅ Can depend on: `core/constants/` (for constant lookups)
- ❌ Should NOT depend on: UI, services, solver (formulas are data, solver uses formulas)

**Public API**:
- `FormulaRepository` - loads and provides formulas
- `Formula`, `FormulaDefinition` - data models
- `FormulaVariable`, `FormulaConstant` - formula components

---

### 3. `core/solver/` - Solver Module

**What It Owns**:
- ✅ Formula solving logic (`FormulaSolver`)
- ✅ Expression evaluation (`ExpressionEvaluator`)
- ✅ Unit conversion (`UnitConverter`)
- ✅ Number formatting (`NumberFormatter`)
- ✅ Step-by-step LaTeX generation (`StepLaTeXBuilder`)
- ✅ Symbol context management (`SymbolContext`)
- ✅ Input parsing (`InputNumberParser`)

**What It Should NOT Own**:
- ❌ Formula definitions (belongs in `core/formulas/`)
- ❌ Constants data (belongs in `core/constants/`)
- ❌ UI rendering (belongs in `ui/`)

**Dependencies**:
- ✅ Can depend on: `core/formulas/` (to read formula definitions), `core/constants/` (for constant values)
- ❌ Should NOT depend on: UI, services, models (except domain models)

**Public API**:
- `FormulaSolver` - main solving interface
- `UnitConverter` - unit conversion utilities
- `NumberFormatter` - number formatting
- `StepLaTeXBuilder` - LaTeX step generation
- `InputNumberParser` - safe number parsing

---

### 4. `models/` - Domain Models

**What It Owns**:
- ✅ Workspace model (`Workspace`, `WorkspacePanel`)
- ✅ Unit preferences (`UnitPreferences`, `UnitSystem`, `TemperatureUnit`, `EnergyUnit`)
- ✅ Shared domain objects that multiple modules need

**What It Should NOT Own**:
- ❌ Constants models (belongs in `core/constants/`)
- ❌ Formula models (belongs in `core/formulas/`)
- ❌ UI-specific models

**Dependencies**:
- ✅ Can depend on: Nothing (pure data models)
- ❌ Should NOT depend on: Any other module

**Public API**:
- `Workspace`, `WorkspacePanel` - workspace data structures
- `UnitSystem`, `TemperatureUnit`, `EnergyUnit` - unit enums

**Note**: Currently has duplicate files (`physical_constant.dart`, `physical_constants_table.dart`) that should be removed - these belong in `core/constants/`.

---

### 5. `services/` - Application Services

**What It Owns**:
- ✅ Application state (`AppState`)
- ✅ Storage service (`StorageService`)
- ✅ Authentication service (`AuthService`)
- ✅ Service initialization and lifecycle

**What It Should NOT Own**:
- ❌ Constants loading (belongs in `core/constants/`)
- ❌ Business logic (belongs in `core/`)
- ❌ UI (belongs in `ui/`)

**Dependencies**:
- ✅ Can depend on: `core/` modules, `models/`
- ❌ Should NOT depend on: `ui/` (services provide data, UI consumes it)

**Public API**:
- `AppState` - main application state (ChangeNotifier)
- `StorageService` - persistence layer
- `AuthService` - authentication

**Note**: Currently has duplicate `constants_loader.dart` that should be removed - loading belongs in `core/constants/`.

---

### 6. `ui/` - User Interface

**What It Owns**:
- ✅ All Flutter widgets
- ✅ Page components (`pages/`)
- ✅ Reusable widgets (`widgets/`)
- ✅ UI state management (local `setState`, `StatefulWidget`)
- ✅ Navigation logic

**What It Should NOT Own**:
- ❌ Business logic (belongs in `core/`)
- ❌ Data models (belongs in `models/` or `core/`)
- ❌ Services (belongs in `services/`)

**Dependencies**:
- ✅ Can depend on: `core/`, `models/`, `services/`, Flutter packages
- ❌ Should NOT depend on: Nothing (UI is the top layer)

**Public API**:
- Widgets are consumed by Flutter framework
- Pages are navigated to via routing

---

## Dependency Direction Rules

### Allowed Dependencies

```
ui/
  ↓ (can depend on)
services/
  ↓ (can depend on)
core/ (all modules)
  ↓ (can depend on)
models/
  ↓ (can depend on)
  (nothing - pure data)
```

### Dependency Rules

1. **UI → Services → Core → Models** ✅
   - UI can use services, core, and models
   - Services can use core and models
   - Core can use models
   - Models use nothing

2. **Core modules can depend on each other** ✅
   - `core/solver/` can use `core/formulas/` and `core/constants/`
   - `core/formulas/` can use `core/constants/`
   - But avoid circular dependencies

3. **No reverse dependencies** ❌
   - Core should NOT depend on UI
   - Core should NOT depend on services
   - Models should NOT depend on anything

4. **Services are coordination layer** ✅
   - Services orchestrate core modules
   - Services provide state to UI via Provider

---

## Current Issues

### Duplicate Files

1. **`constants_loader.dart`**:
   - ✅ `lib/core/constants/constants_loader.dart` - ACTIVE
   - ❌ `lib/services/constants_loader.dart` - UNUSED (should delete)

2. **`physical_constant.dart`**:
   - ✅ `lib/core/constants/physical_constant.dart` - ACTIVE
   - ❌ `lib/models/physical_constant.dart` - UNUSED (should delete)

3. **`physical_constants_table.dart`**:
   - ✅ `lib/core/constants/physical_constants_table.dart` - ACTIVE
   - ❌ `lib/models/physical_constants_table.dart` - UNUSED (should delete)

### Import Inconsistencies

- Some files may import from `models/` instead of `core/constants/`
- Need to audit all imports and standardize

---

## Recommended Cleanup

### Step 1: Delete Duplicate Files
```bash
# Delete unused duplicates
rm lib/services/constants_loader.dart
rm lib/models/physical_constant.dart
rm lib/models/physical_constants_table.dart
```

### Step 2: Audit Imports
```bash
# Find all imports of deleted files
grep -r "services/constants_loader" lib/
grep -r "models/physical_constant" lib/
grep -r "models/physical_constants_table" lib/
```

### Step 3: Update Imports
- Replace `import '../models/physical_constant.dart'` with `import '../../core/constants/physical_constant.dart'`
- Replace `import '../services/constants_loader.dart'` with `import '../core/constants/constants_loader.dart'`

### Step 4: Verify
- Run `flutter analyze` to catch import errors
- Run tests to ensure nothing breaks

---

## Module Responsibilities Summary

| Module | Owns | Depends On | Used By |
|--------|------|------------|---------|
| `core/constants/` | Constants data, loading, repository | Flutter (services), equatable | solver, services, ui |
| `core/formulas/` | Formula definitions, parsing | constants | solver, services, ui |
| `core/solver/` | Solving logic, unit conversion, formatting | formulas, constants | services, ui |
| `models/` | Domain models (workspace, units) | Nothing | All modules |
| `services/` | App state, storage, auth | core, models | ui |
| `ui/` | All widgets and pages | Everything | Flutter framework |

---

## Best Practices

1. **Keep core/ pure**: No Flutter-specific code except where necessary (e.g., `rootBundle` in loader)
2. **Models are data only**: No business logic, no dependencies
3. **Services coordinate**: They don't contain business logic, they orchestrate core modules
4. **UI is presentation**: No business logic in widgets, delegate to services/core
5. **Single source of truth**: Each concept lives in one module only

