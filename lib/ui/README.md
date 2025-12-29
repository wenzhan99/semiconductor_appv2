# UI Module

## Overview

The UI module contains all Flutter widgets, pages, and UI components. This is the presentation layer of the application.

## Purpose

- **User Interface**: All Flutter widgets and pages
- **User Interaction**: Handle user input and display results
- **Navigation**: Manage app navigation and routing
- **Presentation**: Display formulas, constants, and calculations

## Structure

```
ui/
├── main_app.dart          # Main app widget with tab navigation
├── pages/                  # Full-screen pages
│   ├── topics_page.dart
│   ├── workspace_page.dart
│   ├── constants_units_page.dart
│   └── settings_page.dart
└── widgets/               # Reusable UI components
    ├── formula_panel.dart
    ├── latex_text.dart
    └── formula_latex_view.dart
```

## Files

### 1. main_app.dart

**Purpose**: Main app widget that sets up tab navigation and routing.

**Key Class**: `MainApp`

**Features**:
- Tab-based navigation (5 tabs)
- Integrates with `AppState` via `Consumer`
- Auto-selects first workspace if none selected
- Provides navigation to all pages

**Tabs**:
1. Topics (formula selection)
2. Workspace (formula panels)
3. Constants & Units
4. Settings
5. (Additional tab)

**Usage**: Root widget of the application (after `MaterialApp`).

---

### 2. pages/topics_page.dart

**Purpose**: Page for browsing and selecting formulas by category.

**Key Features**:
- Displays formula categories in expandable tiles
- Shows formulas with LaTeX rendering
- Allows selecting formulas to add to workspace
- Shows unit system and temperature unit selectors

**Key Widgets**:
- `ExpansionTile` for categories
- `Checkbox` for formula selection
- `LatexText` for formula equations
- `SegmentedButton` for unit selection

**State Management**: Uses `AppState` via `Provider` to manage selected formulas.

---

### 3. pages/workspace_page.dart

**Purpose**: Page for managing workspace and viewing formula panels.

**Key Features**:
- Displays current workspace
- Shows unit system and temperature unit selectors
- Lists formula panels in workspace
- Allows workspace management

**Key Widgets**:
- `SegmentedButton` for unit system selection
- `SegmentedButton` for temperature unit selection
- `FormulaPanel` widgets for each formula

**State Management**: Uses `AppState` to get current workspace.

---

### 4. pages/constants_units_page.dart

**Purpose**: Page for viewing all physical constants and their values.

**Key Features**:
- Displays all constants in a table
- Groups constants by category
- Shows LaTeX symbols, values, and units
- Formatted with scientific notation

**Key Widgets**:
- `DataTable` or `ListView` for constants display
- `LatexText` for symbol rendering
- `NumberFormatter` for value formatting

**Data Loading**: Loads constants directly via `ConstantsLoader` and `ConstantsRepository`.

---

### 5. pages/settings_page.dart

**Purpose**: Settings page for app configuration.

**Note**: Check actual implementation for features.

---

### 6. widgets/formula_panel.dart

**Purpose**: Reusable widget that displays a single formula with inputs, compute button, and results.

**Key Features**:
- Displays formula name and LaTeX equation
- Shows "Constants used" section
- Input fields for formula variables
- Energy unit dropdown (J/eV)
- Unit chips for variables (m^-1, kg)
- Compute and Clear buttons
- Results section with step-by-step working

**Key Components**:
- Formula header with LaTeX
- Constants used card
- Input fields with unit chips/dropdowns
- Action buttons
- Results display
- Step-by-step LaTeX working

**State Management**: Manages local state for input controllers and results.

**Dependencies**: `ConstantsRepository`, `FormulaSolver`, `LatexSymbolMap`, `NumberFormatter`

---

### 7. widgets/latex_text.dart

**Purpose**: Widget for rendering LaTeX strings using `flutter_math_fork`.

**Key Class**: `LatexText`

**Properties**:
- `latex` (String) - LaTeX string to render
- `style` (TextStyle?) - Text style
- `displayMode` (bool) - Use display mode (centered, larger) or inline mode

**Features**:
- Uses `Math.tex()` from `flutter_math_fork`
- Error fallback: shows raw LaTeX if rendering fails
- Supports both inline and display math

**Usage**: Used throughout UI to render formulas, constants, and step-by-step working.

---

### 8. widgets/formula_latex_view.dart

**Purpose**: Additional LaTeX rendering widget (check implementation for specific use case).

**Note**: May be a specialized version of `LatexText` or used for specific formula display needs.

---

## Data Flow

```
User interacts with UI
    ↓
UI reads from AppState / Providers
    ↓
User input → FormulaPanel
    ↓
FormulaPanel calls FormulaSolver
    ↓
Results displayed in UI
    ↓
AppState updated
    ↓
StorageService persists
```

## Dependencies

- `package:flutter/material.dart` - Flutter widgets
- `package:provider/provider.dart` - State management
- `package:flutter_math_fork/flutter_math.dart` - LaTeX rendering
- `services/` - For `AppState`
- `core/` - For formulas, constants, solver
- `models/` - For data models

## State Management

**Pattern**: Provider pattern
- `AppState` provided at root
- `ConstantsRepository` provided at root
- `LatexSymbolMap` provided at root
- UI consumes via `Consumer` or `context.read()`

**Local State**: Widgets use `StatefulWidget` and `setState()` for local UI state (e.g., input controllers).

## Error Handling

- Missing data: UI shows placeholder or hides sections
- Rendering errors: `LatexText` falls back to raw text
- Computation errors: Displayed in error message

## Testing

Key test cases:
1. Pages render without errors
2. Formula selection works
3. Input fields accept values
4. Compute button triggers solving
5. Results display correctly
6. LaTeX renders properly
7. Navigation works

