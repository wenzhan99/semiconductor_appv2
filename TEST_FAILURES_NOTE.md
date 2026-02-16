# Flutter Test Failures (Unrelated to Graph UI)

Date: 2026-02-16

`flutter test` currently fails in solver/step rendering suites, not in graph panel/scaffold UI code.

Failing suites observed:
- `test/dos_stats_steps_test.dart`
- `test/dos_formulas_test.dart`
- `test/energy_band_steps_test.dart`
- `test/pn_built_in_potential_steps_test.dart`
- `test/pn_depletion_partition_steps_test.dart`
- `test/pn_peak_field_test.dart`

Common failure pattern:
- Step formatting/expectation mismatches in symbolic derivation strings (e.g., expected rearrangement fragments, `exp(x)` markers, exact latex/unit token forms).
- These failures are within solver/step-generation outputs and are outside graph right-panel standardization and mojibake cleanup scope.
