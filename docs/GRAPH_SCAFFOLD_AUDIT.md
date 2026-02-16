# Graph Scaffold Audit

## Scope

Audit target:
- `lib/ui/pages/**/*graph*.dart`
- related `*band*`, `*dos*`, `*carrier*`, `*pn*` graph page files

Date: 2026-02-16

## Summary

- All graph pages currently use `StandardGraphPageScaffold` at the page shell level.
- No graph page remains on legacy top-level `LayoutBuilder/Row/ListView` page scaffolding.
- Multiple pages still use legacy right-panel card widgets (`ReadoutsCard`, `PointInspectorCard`, `ParametersCard`, `KeyObservationsCard`, `AnimationCard`) via `rightPanelBuilder`.
- Shared null-safety hardening was applied to `AnimationParametersPanel`.

## Page Inventory

| Page file | Uses StandardGraphPageScaffold | Uses rightPanelBuilder | Legacy panel widgets in page |
|---|---:|---:|---|
| `carrier_concentration_graph_page.dart` | Yes | Yes | Custom controls/observations cards |
| `density_of_states_graph_page.dart` | Yes | Yes | `ReadoutsCard`, `PointInspectorCard`, `ParametersCard`, `KeyObservationsCard` |
| `density_of_states_graph_page_v2.dart` | Yes | Yes | `ReadoutsCard`, `PointInspectorCard`, `ParametersCard`, `KeyObservationsCard` |
| `direct_indirect_graph_page.dart` | Yes | Yes | `ReadoutsCard`, `ParametersCard`, `KeyObservationsCard`, `EnhancedAnimationPanel` |
| `direct_indirect_graph_page_v3.dart` | Yes | Yes | `ReadoutsCard`, `PointInspectorCard`, `ParametersCard`, `KeyObservationsCard` |
| `drift_diffusion_graph_page.dart` | Yes | Yes | `ReadoutsCard`, `PointInspectorCard`, `ParametersCard`, `KeyObservationsCard` |
| `drift_diffusion_graph_page_v2.dart` | Yes | Yes | `ReadoutsCard`, `PointInspectorCard`, `ParametersCard`, `KeyObservationsCard` |
| `fermi_dirac_graph_page.dart` | Yes | Yes | Custom inspector/insights/controls + `EnhancedAnimationPanel` |
| `intrinsic_carrier_graph_page.dart` | Yes | Yes | `ReadoutsCard`, `PointInspectorCard`, `AnimationCard`, `ParametersCard`, `KeyObservationsCard` |
| `intrinsic_carrier_graph_page_v2.dart` | Yes | Yes | `ReadoutsCard`, `PointInspectorCard`, `AnimationCard`, `ParametersCard`, `KeyObservationsCard` |
| `parabolic_graph_page.dart` | Yes | Yes | Custom inspector/insights/controls + `EnhancedAnimationPanel` |
| `pn_band_diagram_graph_page.dart` | Yes | No | Uses scaffold + `GraphConfig` panels |
| `pn_depletion_graph_page.dart` | Yes | No | Uses scaffold + `GraphConfig` panels |
| `pn_depletion_graph_page_v2.dart` | Yes | Yes | `ReadoutsCard`, `PointInspectorCard`, `ParametersCard`, `KeyObservationsCard` |

## Legacy Layout Findings

Top-level graph page shells are standardized, but manual layout logic still appears inside content widgets for chart internals (expected, not top-level page shell regressions):
- `direct_indirect_graph_page.dart` (chart internals)
- `fermi_dirac_graph_page.dart` (chart internals)
- `parabolic_graph_page.dart` (chart internals)

## Issue Source Audit

### "Step contains unsupported formatting"

Primary source:
- `lib/ui/widgets/latex_text.dart`
  - `LatexText` fallback path returns this message when Math parsing fails.

This is a shared rendering fallback, not specific to one graph page.

### "Unexpected null value"

Most likely shared source before fix:
- `lib/ui/graphs/panels/animation_parameters_panel.dart`
  - stale selected parameter id / empty parameters edge cases
  - selection/control widgets potentially enabled in invalid empty states

## Fixes Applied In This Pass

### 1) Animation panel null-safety hardening

File:
- `lib/ui/graphs/panels/animation_parameters_panel.dart`

Changes:
- Added safe parameter retrieval (`_safeParameters`) with guarded fallback.
- Added robust selected-parameter reconciliation that auto-falls back to first valid parameter and never assumes validity.
- Added explicit empty-state handling when no animatable parameters exist.
- Disabled speed/loop/reverse/play/restart controls when no parameters are available.
- Added active-parameter dropdown bound to validated selected id.
- Removed null-assertion callback invocation in checkbox handler (no `!` usage needed there).
- Guarded/normalized progress rendering.

### 2) Scaffold usage confirmation

Confirmed all graph pages in scope are already on `StandardGraphPageScaffold`.

## Remaining Work (If strict standard-panels-only policy is required)

If required to fully remove legacy panel widgets from pages:
- Migrate right-panel content in the listed legacy pages to pure `GraphConfig` + `StandardPanelStack` outputs.
- Replace direct `ReadoutsCard` / `ParametersCard` / `PointInspectorCard` / `KeyObservationsCard` / `AnimationCard` usage with:
  - `GraphConfig.readouts`
  - `PointInspectorConfig`
  - `AnimationConfig`
  - `InsightsConfig`
  - `ControlsConfig`

This can be done without touching physics/curve generation logic.
