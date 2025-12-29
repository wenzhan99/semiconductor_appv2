# Models Module

## Overview

The Models module contains core domain models that represent the application's data structures. These are pure data models with no business logic - they define the shape of data used throughout the app.

## Purpose

- **Workspace Management**: Models for workspaces and panels
- **Unit Preferences**: Enums and models for unit system preferences
- **Domain Objects**: Shared data structures used across modules
- **Serialization**: JSON serialization/deserialization for persistence

## Files

### 1. workspace.dart

**Purpose**: Core data models for workspace and panel management, including enums for status and value sources.

**Key Classes and Enums**:

#### `SymbolSource` (Enum)
Represents the source of a symbol value:
- `user` - Value entered by user
- `material` - Value from material properties (constants)
- `computed` - Value computed by formula solver

**Methods**:
- `fromJson(String)` - Parse from JSON string
- `toJson()` - Convert to JSON string

**Usage**: Used in `SymbolValue` to track where a value came from.

---

#### `PanelStatus` (Enum)
Represents the status of a workspace panel:
- `solved` - Formula has been solved successfully
- `needsInputs` - Waiting for user input
- `error` - Error occurred during solving
- `stale` - Panel needs to be recomputed

**Methods**:
- `fromJson(String)` - Parse from JSON string
- `toJson()` - Convert to JSON string

**Usage**: Used in `WorkspacePanel` to track panel state.

---

#### `SymbolValue`
Represents a value with unit and source information.

**Fields**:
- `value` (double) - Numeric value
- `unit` (String) - Unit string (e.g., "J", "eV", "kg", "m^-1")
- `source` (SymbolSource) - Where the value came from (user, material, computed)

**Methods**:
- `fromJson(Map<String, dynamic>)` - Parse from JSON
- `toJson()` - Convert to JSON
- Implements `Equatable` for value equality

**Usage**: Used throughout the solver and workspace to track variable values. Stored in `WorkspacePanel.overrides` (user inputs) and `WorkspacePanel.outputs` (computed results).

**Example**:
```dart
final symbolValue = SymbolValue(
  value: 2.35e-20,
  unit: 'J',
  source: SymbolSource.computed,
);
```

---

#### `GraphConfig`
Configuration for a graph visualization (future feature).

**Fields**:
- `id` (String) - Graph identifier
- `title` (String) - Graph title
- `xAxis` (String) - X-axis label
- `yAxis` (String) - Y-axis label
- `parameters` (Map<String, dynamic>) - Graph parameters

**Methods**:
- `fromJson(Map<String, dynamic>)` - Parse from JSON
- `toJson()` - Convert to JSON

**Usage**: Currently defined but may not be actively used yet.

---

#### `WorkspacePanel`
Represents a single formula panel in a workspace.

**Fields**:
- `id` (String) - Unique panel identifier (UUID)
- `formulaId` (String) - ID of the formula this panel uses
- `overrides` (Map<String, SymbolValue>) - User-provided values (inputs)
- `outputs` (Map<String, SymbolValue>) - Computed results
- `status` (PanelStatus) - Current panel status
- `orderIndex` (int) - Display order in workspace

**Methods**:
- `create(String formulaId, int orderIndex)` - Factory to create new panel
  - Generates UUID for `id`
  - Sets default status to `needsInputs`
  - Initializes empty `overrides` and `outputs`
- `copyWith(...)` - Create a copy with modified fields
  - Used for immutable updates
- `fromJson(Map<String, dynamic>)` - Parse from JSON
- `toJson()` - Convert to JSON
- Implements `Equatable` for value equality

**Usage**: Main data structure for individual formula panels. Stored in `Workspace.panels` list.

**Example**:
```dart
final panel = WorkspacePanel.create('parabolic_band_dispersion', 0);
final updated = panel.copyWith(
  overrides: {'k': SymbolValue(value: 1e9, unit: 'm^-1', source: SymbolSource.user)},
);
```

---

#### `Workspace`
Represents a user workspace containing multiple formula panels.

**Fields**:
- `schemaVersion` (int) - Schema version for migration
- `id` (String) - Unique workspace identifier (UUID)
- `name` (String) - Workspace name
- `panels` (List<WorkspacePanel>) - List of panels in this workspace
- `unitSystem` (UnitSystem) - Preferred unit system (SI or cm)
- `temperatureUnit` (TemperatureUnit) - Preferred temperature unit (Kelvin or Celsius)
- `createdAt` (DateTime) - Creation timestamp
- `updatedAt` (DateTime) - Last update timestamp

**Methods**:
- `create(String name)` - Factory to create new workspace
  - Generates UUID for `id`
  - Sets default `unitSystem` to `cm`
  - Sets default `temperatureUnit` to `kelvin`
  - Initializes empty `panels` list
  - Sets `createdAt` and `updatedAt` to current time
- `copyWith(...)` - Create a copy with modified fields
  - Used for immutable updates
- `fromJson(Map<String, dynamic>)` - Parse from JSON
- `toJson()` - Convert to JSON
- Implements `Equatable` for value equality

**Usage**: Main data structure for persisting user's work. Stored via `StorageService` and managed by `AppState`.

**Example**:
```dart
final workspace = Workspace.create('My Workspace');
final updated = workspace.copyWith(
  panels: [...workspace.panels, newPanel],
  unitSystem: UnitSystem.si,
);
```

---

### 2. unit_preferences.dart

**Purpose**: Enums for unit system preferences used in workspaces.

**Key Enums**:

#### `UnitSystem`
Unit system preference:
- `si` - SI base units (meters, kilograms, etc.)
- `cm` - Centimeter-based units

**Methods**:
- `fromJson(String)` - Parse from JSON string
  - Returns `si` if string matches "si"
  - Returns `cm` if string matches "cm"
  - Defaults to `cm` if invalid
- `toJson()` - Convert to JSON string (returns enum name)

**Usage**: Stored in `Workspace.unitSystem` to remember user's unit preference. Used by UI to determine which units to display.

---

#### `TemperatureUnit`
Temperature unit preference:
- `kelvin` - Kelvin (absolute temperature)
- `celsius` - Celsius

**Methods**:
- `fromJson(String)` - Parse from JSON string
  - Returns `kelvin` if string matches "kelvin"
  - Returns `celsius` if string matches "celsius"
  - Defaults to `kelvin` if invalid
- `toJson()` - Convert to JSON string (returns enum name)

**Usage**: Stored in `Workspace.temperatureUnit` to remember user's temperature unit preference.

**Note**: There may also be an `EnergyUnit` enum defined elsewhere (eV vs J) for energy-specific unit selection.

---

## Data Flow

```
User creates workspace
    ↓
Workspace model created
    ↓
Stored via StorageService
    ↓
Loaded by AppState
    ↓
Displayed in UI
    ↓
User updates workspace
    ↓
Workspace.copyWith() creates new instance
    ↓
Stored via StorageService
```

**Detailed Flow**:
1. **Creation**: User creates workspace via `Workspace.create()`
2. **Storage**: `StorageService.saveWorkspace()` serializes to JSON and stores in Hive
3. **Loading**: `AppState.loadWorkspaces()` loads all workspaces from storage
4. **Updates**: UI calls `workspace.copyWith()` to create updated version
5. **Persistence**: Updated workspace is saved back to storage

## Dependencies

- `package:equatable/equatable.dart` - For value equality
- `package:uuid/uuid.dart` - For generating unique IDs
- No other dependencies (pure data models)

## Serialization

All models support JSON serialization:
- `fromJson(Map<String, dynamic>)` - Parse from JSON
- `toJson()` - Convert to JSON

**JSON Structure Examples**:

**SymbolValue**:
```json
{
  "value": 2.35e-20,
  "unit": "J",
  "source": "computed"
}
```

**WorkspacePanel**:
```json
{
  "id": "uuid-string",
  "formula_id": "parabolic_band_dispersion",
  "overrides": {
    "k": {"value": 1e9, "unit": "m^-1", "source": "user"}
  },
  "outputs": {
    "E": {"value": 2.35e-20, "unit": "J", "source": "computed"}
  },
  "status": "solved",
  "order_index": 0
}
```

**Workspace**:
```json
{
  "schema_version": 1,
  "id": "uuid-string",
  "name": "My Workspace",
  "panels": [...],
  "unit_system": "cm",
  "temperature_unit": "kelvin",
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

**Used By**: `StorageService` to persist workspaces to local storage (Hive).

## Immutability

All models are immutable:
- Fields are `final`
- Updates use `copyWith()` pattern
- This ensures safe state management and prevents accidental mutations

## Testing

Key test cases:
1. `Workspace.create()` generates unique ID
2. `WorkspacePanel.create()` generates unique ID
3. `copyWith()` creates correct copy with modified fields
4. JSON serialization/deserialization round-trip
5. `SymbolSource` enum parsing (user, material, computed)
6. `PanelStatus` enum parsing (solved, needsInputs, error, stale)
7. `UnitSystem` enum parsing (si, cm)
8. `TemperatureUnit` enum parsing (kelvin, celsius)
9. `Equatable` equality works correctly

## Public API Summary

**Main Models**:
- `Workspace` - Workspace container
- `WorkspacePanel` - Individual formula panel
- `SymbolValue` - Value with unit and source
- `GraphConfig` - Graph configuration (future)

**Enums**:
- `SymbolSource` - Value source (user, material, computed)
- `PanelStatus` - Panel status (solved, needsInputs, error, stale)

**Unit Preferences** (from `unit_preferences.dart`):
- `UnitSystem` - Unit system (si, cm)
- `TemperatureUnit` - Temperature unit (kelvin, celsius)
