## lib/core

Core computation and data for the app.

- `constants/` — Loading and mapping of physical constants and LaTeX symbols.
  - `constants_repository.dart` — Provides constant values (e.g., k, q).
  - `latex_symbols.dart` — Canonical symbol→LaTeX mapping helper.
  - `formula_constants_resolver.dart` — Resolves constants per formula.
- `formulas/` — Formula metadata (IDs, variables, categories).
  - `formula_definition.dart` / `formula_repository.dart` — Definitions and registry.
  - `categories/` — Groups formulas by topic.
- `solver/` — Expression evaluation and step-by-step rendering.
  - `formula_solver.dart` — Orchestrates solving a formula, builds steps, tracks unit conversions.
  - `step_latex_builder.dart` — Builds step-by-step LaTeX and working items.
  - `steps/` — Template-specific step builders (energy band, DOS/stats, carrier equilibrium, transport).
  - `unit_converter.dart` — Unit conversion utilities with logging for Step 1.
  - `number_formatter.dart`, `expression_evaluator.dart` — Formatting and expression evaluation utilities.
- `models/` — Shared models used by the solver (e.g., `workspace.dart`, `unit_preferences.dart`).
