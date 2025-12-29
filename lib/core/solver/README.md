# Solver Module

## Overview

The Solver module contains all the logic for solving formulas, evaluating expressions, converting units, formatting numbers, and generating step-by-step LaTeX derivations.

## Purpose

- **Formula Solving**: Solve formulas for target variables
- **Expression Evaluation**: Evaluate mathematical expressions
- **Unit Conversion**: Convert between different units (J↔eV, m↔cm, etc.)
- **Number Formatting**: Format numbers in scientific notation for display
- **LaTeX Generation**: Generate step-by-step working in LaTeX format
- **Input Parsing**: Safely parse user input (including scientific notation)

## Files

### 1. formula_solver.dart

**Purpose**: Main solver that orchestrates formula solving process.

**Key Classes**:

#### `SolveResult`
Result of solving a formula.

**Fields**:
- `status` (PanelStatus) - Success, error, or needs inputs
- `outputs` (Map<String, SymbolValue>) - Computed results
- `errorMessage` (String?) - Error message if failed
- `stepsLatex` (StepLatex?) - Step-by-step LaTeX derivation

#### `FormulaSolver`
Main solver class.

**Key Methods**:
- `solve()` - Solve a formula for a target variable
  - Parameters: `formulaId`, `solveFor`, `workspaceGlobals`, `panelOverrides`, `latexMap`
  - Returns: `SolveResult`

**Process**:
1. Load formula definition from repository
2. Check if formula can be solved for target variable
3. Build `SymbolContext` with constants and user inputs
4. Evaluate compute expression using `ExpressionEvaluator`
5. Generate step-by-step LaTeX using `StepLaTeXBuilder`
6. Return results

**Dependencies**: `FormulaRepository`, `ConstantsRepository`, `ExpressionEvaluator`

---

### 2. expression_evaluator.dart

**Purpose**: Evaluates mathematical expressions (e.g., "(hbar*hbar*k*k)/(2*m_star)").

**Key Classes**:

#### `ExpressionEvaluator`
Parses and evaluates mathematical expressions.

**Key Methods**:
- `evaluate(String expression, SymbolContext context)` - Evaluate expression with given context
  - Returns: `EvaluationResult` with value or error message

**Supported Operations**:
- Arithmetic: `+`, `-`, `*`, `/`
- Functions: `sqrt()`, `pow()`, `sin()`, `cos()`, `tan()`, `ln()`, `log()`, `exp()`
- Constants: `pi`
- Variables: Looked up from `SymbolContext`

**Parser**: Uses recursive descent parser with operator precedence.

**Error Handling**: Returns error message in `EvaluationResult.error` if expression is invalid.

---

### 3. symbol_context.dart

**Purpose**: Context that holds symbol values and units for expression evaluation.

**Key Classes**:

#### `SymbolContext`
Maps symbol keys to values and units.

**Key Methods**:
- `getValue(String key)` - Get numeric value for symbol
- `getUnit(String key)` - Get unit string for symbol
- `setValue(String key, double value, String unit)` - Set symbol value

**Usage**: Built by `FormulaSolver` with constants and user inputs, then passed to `ExpressionEvaluator`.

---

### 4. unit_converter.dart

**Purpose**: Converts values between different units.

**Key Classes**:

#### `UnitConverter`
Handles unit conversions.

**Key Methods**:
- `convertEnergy(double value, String fromUnit, String toUnit)` - Convert J ↔ eV using `q` constant
- `convertLength(double value, String fromUnit, String toUnit)` - Convert m ↔ cm ↔ nm ↔ μm
- `convertDensity(double value, String fromUnit, String toUnit)` - Convert density units (e.g., m^-3 ↔ cm^-3)
- `convertWavevector(double value, String fromUnit, String toUnit)` - Convert wavevector units

**Energy Conversion**:
- Uses `q` constant from `ConstantsRepository`
- `1 eV = q J` where `q = 1.602176634 × 10⁻¹⁹ C`
- Returns `null` if conversion fails (e.g., `q` not loaded)

**Dependencies**: `ConstantsRepository` (for `q` constant)

---

### 5. number_formatter.dart

**Purpose**: Formats numbers for display in LaTeX and plain text.

**Key Classes**:

#### `NumberFormatter`
Formats numbers in scientific notation.

**Key Methods**:
- `formatLatex(double value)` - Format for LaTeX (e.g., "2.35 \\times 10^{-20}")
- `formatPlainText(double value)` - Format for plain text (e.g., "2.35 × 10^-20")
- `formatLatexWithUnit(double value, String unit)` - Format with unit (e.g., "2.35 \\times 10^{-20}\\,\\mathrm{J}")
- `formatLatexUnit(String unit)` - Convert unit string to LaTeX (e.g., "J*s" → "J\\cdot s")
- `formatLatexFullPrecision(double value)` - Format with 9 significant figures (for intermediate calculations)
- `formatLatexWithUnitFullPrecision(double value, String unit)` - Full precision with unit

**Formatting Rules**:
- Uses `floor()` for exponent calculation (ensures mantissa in [1, 10))
- 3 significant figures by default
- Scientific notation for |exp| >= 3
- Normal notation for small numbers (0.001 to 1000)

**Unit Formatting**:
- Handles compound units: "J*s" → "J\\cdot s"
- Handles exponents: "m^-1" → "m^{-1}"
- Handles special cases: "eV" kept as-is

---

### 6. step_latex_builder.dart

**Purpose**: Generates step-by-step LaTeX derivations for formula solving.

**Key Classes**:

#### `StepLatex`
LaTeX representation of solving steps.

**Fields**:
- `formulaLatex` (String) - Original formula in LaTeX
- `substitutionLatex` (String) - Formula with values substituted
- `resultLatex` (String) - Final result in LaTeX
- `alignedWorking` (String?) - Full aligned LaTeX block for detailed steps

#### `StepLaTeXBuilder`
Builds step-by-step LaTeX.

**Key Methods**:
- `build()` - Build basic step LaTeX (formula, substitution, result)
- `buildAlignedWorking()` - Build detailed aligned LaTeX block for specific formulas
  - Supports: `parabolic_band_dispersion` (E, m_star, k)
  - Supports: `effective_mass_from_curvature` (m_star, d2E_dk2)

**Features**:
- Shows algebraic manipulation steps
- Substitutes values with units
- Shows intermediate calculations
- Uses full precision for intermediate steps
- Uses 3 significant figures for final results

**Dependencies**: `LatexSymbolMap`, `NumberFormatter`, `UnitConverter`

---

### 7. input_number_parser.dart

**Purpose**: Safely parses numeric input from text fields, handling scientific notation correctly.

**Key Classes**:

#### `InputNumberParser`
Static utility for parsing numbers.

**Key Methods**:
- `parseFlexibleDouble(String raw)` - Parse number from string
  - Handles: normal decimals (0.146, -12.3)
  - Handles: scientific notation (2.37e-31, 1e9, 1.0E+3)
  - Handles: whitespace and commas (sanitized)
  - **Never strips '-' after 'e' or 'E'** (fixes parsing bug)

**Usage**: Used in `FormulaPanel` when parsing user input from text fields.

**Error Handling**: Returns `null` if input is invalid.

---

## Data Flow

```
User inputs values
    ↓
InputNumberParser.parseFlexibleDouble()
    ↓
FormulaSolver.solve()
    ↓
Build SymbolContext (constants + inputs)
    ↓
ExpressionEvaluator.evaluate()
    ↓
UnitConverter (if needed)
    ↓
NumberFormatter.formatLatex()
    ↓
StepLaTeXBuilder.buildAlignedWorking()
    ↓
Display results in UI
```

## Dependencies

- `core/formulas/` - For formula definitions
- `core/constants/` - For constant values
- `core/models/` - For `Workspace`, `SymbolValue`, etc.
- `package:equatable/equatable.dart` - For value equality

## Error Handling

- Invalid expressions: `ExpressionEvaluator` returns error message
- Missing constants: `SymbolContext` returns `null`, solver handles gracefully
- Unit conversion failures: `UnitConverter` returns `null`
- Invalid input: `InputNumberParser` returns `null`

## Testing

Key test cases:
1. `ExpressionEvaluator` evaluates simple expressions
2. `ExpressionEvaluator` handles operator precedence
3. `UnitConverter` converts J ↔ eV correctly
4. `NumberFormatter` formats scientific notation correctly
5. `InputNumberParser` parses "2.37e-31" correctly (negative exponent)
6. `StepLaTeXBuilder` generates valid LaTeX
7. `FormulaSolver` solves formulas correctly

