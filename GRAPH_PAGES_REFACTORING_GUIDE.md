# Graph Pages Standardization & Refactoring Guide

## Executive Summary

This guide documents the complete revamp and standardization of all 9 semiconductor graph pages to provide consistent:
- **Layout** (responsive, no overflow)
- **LaTeX rendering** (all math symbols properly formatted)
- **Behavior** (charts rebuild correctly, pins work consistently)
- **Features** (animation, zoom, point inspector, dynamic insights)

## Shared Components Created

All components are in `lib/ui/graphs/common/`:

### 1. Core Utilities
- **`graph_controller.dart`**: Mixin providing `chartVersion` and `bumpChart()` for forcing chart rebuilds
- **`viewport_state.dart`**: Manages zoom and pan state
- **`latex_rich_text.dart`**: Renders text with inline LaTeX tokens (`$E_g$`, `$n_i$`, etc.)
- **`latex_bullet_list.dart`**: Bullet lists with LaTeX support

### 2. Card Components
- **`readouts_card.dart`**: Displays numeric readouts with LaTeX labels
- **`point_inspector_card.dart`**: Shows selected/hovered point details
- **`animation_card.dart`**: Animation controls with LaTeX labels
- **`parameters_card.dart`**: Parameter sliders, switches, dropdowns with LaTeX labels
- **`key_observations_card.dart`**: Dynamic + static observations with LaTeX

### 3. UI Components
- **`chart_toolbar.dart`**: Zoom in/out/reset/fit buttons
- **`plot_selector.dart`**: Tabs/chips for multi-plot pages

### 4. Layout
- **`graph_scaffold.dart`**: Complete standardized layout scaffold (header, formula, about, observe, chart + right panel)

## Standardized Page Structure

Every graph page follows this structure:

```
┌─────────────────────────────────────────────────────┐
│ Title + Category                                     │
│ Main Formula (LaTeX, centered, highlighted)         │
│ About Card (with inline LaTeX)                      │
│ What You Should Observe (collapsible, LaTeX bullets)│
├──────────────────┬──────────────────────────────────┤
│                  │  RIGHT PANEL (scrollable)         │
│                  │  1. Readouts Card                 │
│  CHART CARD      │  2. Point Inspector Card          │
│  - Legend        │  3. Animation Card (if supported) │
│  - Toolbar       │  4. Parameters Card               │
│  - Chart         │  5. Key Observations Card         │
│                  │                                   │
└──────────────────┴──────────────────────────────────┘

On narrow screens: stacks vertically (chart first, then cards)
```

## LaTeX Rendering Rules

### Problem Before
- Math symbols appeared as plain text: `E_g`, `n_i`, `N_cN_v`
- Underscores caused layout issues
- Inconsistent formatting between sections

### Solution
1. **Inline LaTeX in Text**: Use `LatexRichText.parse()` with `$` delimiters
   ```dart
   LatexRichText.parse(
     'The bandgap $E_g$ affects carrier concentration $n_i$.',
   )
   ```

2. **Standalone LaTeX**: Use `LatexText()` directly
   ```dart
   LatexText(r'n_i = \sqrt{N_c N_v}\,\exp\!\left(-\frac{E_g}{2kT}\right)')
   ```

3. **Bullet Lists**: Use `LatexBulletList()`
   ```dart
   LatexBulletList(
     bullets: [
       r'$n_i$ rises exponentially with T.',
       r'Larger $E_g$ suppresses $n_i$.',
     ],
   )
   ```

4. **Parameter Labels**: Use `ParameterSlider()` / `ParameterSwitch()` with LaTeX labels
   ```dart
   ParameterSlider(
     label: r'$E_g$ (eV)',  // Renders LaTeX
     value: _bandgap,
     ...
   )
   ```

## Chart Rebuild Pattern

### Problem Before
- Sliders updated values but chart didn't redraw
- In-place list mutation broke FL Chart's change detection

### Solution
Use `GraphController` mixin:

```dart
class _MyGraphState extends State<MyGraph> with GraphController {
  // chartVersion and bumpChart() available automatically
  
  void _onParameterChanged(double value) {
    setState(() {
      _parameter = value;
      bumpChart();  // Increments chartVersion
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return LineChart(
      key: ValueKey('my-graph-$chartVersion'),  // Forces rebuild
      LineChartData(/* ... */),
    );
  }
}
```

**CRITICAL**: Always generate fresh `List<FlSpot>` and `LineChartBarData` objects. Never mutate in place.

## Pins & Selection Pattern

### Problem Before
- Pins count label said "4 max" but 5 markers appeared
- No dynamic insights computed from pins
- Inconsistent selection/clear behavior

### Solution
```dart
// State
FlSpot? _hoverSpot;
final List<FlSpot> _pinnedSpots = [];
static const int _maxPins = 4;

// Touch handler
lineTouchData: LineTouchData(
  touchCallback: (event, response) {
    final spot = /* extract spot */;
    
    if (event is FlTapUpEvent) {
      setState(() {
        _pinnedSpots.removeWhere((p) => (p.x - spot.x).abs() < 1e-6);
        _pinnedSpots.add(spot);
        if (_pinnedSpots.length > _maxPins) {
          _pinnedSpots.removeAt(0);  // FIFO
        }
        _hoverSpot = spot;
      });
    } else if (event is FlPointerHoverEvent) {
      setState(() => _hoverSpot = spot);
    }
  },
)

// Draw markers (exactly _pinnedSpots.length)
if (_pinnedSpots.isNotEmpty)
  LineChartBarData(
    spots: _pinnedSpots,  // Exact list, no extras
    // ... draw orange markers
  ),
```

## Dynamic Insight Pattern

Key Observations card should have two sections:

1. **Dynamic Insight**: Computed from `_pinnedSpots`, `_hoverSpot`, or current parameter values
2. **Static Observations**: Always shown, explain theory

```dart
KeyObservationsCard(
  dynamicObservations: _pinnedSpots.length >= 2
      ? [
          'Between ${_pins.first.x} and ${_pins.last.x}, $n_i$ changes ${delta} decades.',
          'Your selected range: ${minRatio}× to ${maxRatio}× vs 300K.',
        ]
      : null,  // No dynamic insight if < 2 pins
  staticObservations: [
    r'$n_i$ rises exponentially with T.',
    r'Larger $E_g$ suppresses $n_i$.',
  ],
)
```

## Numeric Formatting

Use `LatexNumberFormatter` for consistency:

```dart
import '../graphs/utils/latex_number_formatter.dart';

// For LaTeX rendering
final latexStr = LatexNumberFormatter.toScientific(value, sigFigs: 3);
// Returns: "1.42\\times10^{10}"

// For Text widgets / tooltips
final unicodeStr = LatexNumberFormatter.toUnicodeSci(value, sigFigs: 3);
// Returns: "1.42×10¹⁰"

// With units
final withUnit = LatexNumberFormatter.withUnit(value, 'cm^{-3}', sigFigs: 3);
// Returns: "1.42\\times10^{10}\\,\\mathrm{cm^{-3}}"
```

## Zoom & Viewport Pattern

Use `ViewportState` class:

```dart
final _viewport = ViewportState(
  defaultMinX: -1.0,
  defaultMaxX: 1.0,
  defaultMinY: -1.0,
  defaultMaxY: 1.0,
);

// In chart
LineChartData(
  minX: _viewport.minX,
  maxX: _viewport.maxX,
  minY: _viewport.minY,
  maxY: _viewport.maxY,
)

// Toolbar
ChartToolbar(
  onZoomIn: () { _viewport.zoom(0.2); setState(() => bumpChart()); },
  onZoomOut: () { _viewport.zoom(-0.2); setState(() => bumpChart()); },
  onReset: () { _viewport.reset(); setState(() => bumpChart()); },
)
```

**IMPORTANT**: Zoom must update viewport AND regenerate curve data if resampling is needed.

## Multi-Plot Pages Pattern

For pages with multiple stacked plots (Drift vs Diffusion, PN Depletion):

```dart
// State
String _selectedPlot = 'ρ(x)';  // or int _selectedPlotIndex = 0

// UI
PlotSelector(
  options: ['ρ(x)', 'E(x)', 'V(x)', 'All'],
  selected: _selectedPlot,
  onChanged: (plot) => setState(() {
    _selectedPlot = plot;
    bumpChart();
  }),
)

// Chart area
Widget _buildChartArea() {
  if (_selectedPlot == 'All' && isLargeScreen) {
    return Column(children: [/* all 3 plots stacked */]);
  } else if (_selectedPlot == 'ρ(x)') {
    return _buildRhoChart();
  } else if (_selectedPlot == 'E(x)') {
    return _buildEFieldChart();
  } else {
    return _buildVChart();
  }
}
```

## Responsiveness Rules

1. **Breakpoint**: 1100px width
   - Wide (≥1100px): Chart left (flex: 2), Panel right (flex: 1)
   - Narrow (<1100px): Vertical stack (chart height: 300-450px)

2. **Right panel**: MUST be `SingleChildScrollView`
3. **No hardcoded heights** except min/max constraints
4. **Long text**: Use `Wrap()` or `Expanded()` appropriately

## Animation Pattern

```dart
AnimationCard(
  description: r'Animate $E_g$: 0.6 → 1.6 eV',
  currentValue: 'Current: \$E_g = ${_bandgap.toStringAsFixed(3)}\\,\\mathrm{eV}\$',
  isAnimating: _isAnimating,
  progress: _animationProgress,
  onPlay: _startAnimation,
  onPause: _stopAnimation,
  onReset: _resetAnimation,
)
```

During animation:
- Show baseline curve (faint)
- Update parameter each tick
- Call `bumpChart()` each tick
- Optional: auto-switch to ScalingMode.auto for better visibility

## Page-Specific Notes

### 1. Parabolic Band Dispersion (E–k)
- **Issue**: Zoom doesn't resample curve
- **Fix**: On zoom, regenerate points based on new viewport range

### 2. Direct vs Indirect Bandgap
- **Issue**: Plain text labels
- **Fix**: All readouts use LaTeX (Eg_dir, Eg_ind, k0)

### 3. Fermi–Dirac Distribution
- **Issue**: Missing readouts card and point inspector
- **Fix**: Add ReadoutsCard (f(EF), kT, etc.) and PointInspectorCard

### 4. Density of States g(E)
- **Issue**: "unsupported formatting" warning in observe panel
- **Fix**: Replace observe renderer with LatexBulletList

### 5. Intrinsic Carrier Concentration vs T
- **Issue**: Pins count mismatch (label said 4, plot showed 5), plain text in About/Animation
- **Fix**: Use exact `_pinnedSpots` list for markers, LatexRichText everywhere

### 6. Carrier Concentration vs Fermi Level
- **Issue**: Need option to show n-only, p-only, or both
- **Fix**: Add SegmentedButton for curve visibility

### 7. Drift vs Diffusion Current
- **Issue**: Two stacked plots break layout
- **Fix**: Add PlotSelector: ['n(x)', 'J components', 'All']

### 8. PN Junction Depletion Profiles
- **Issue**: Three stacked plots break layout
- **Fix**: Add PlotSelector: ['ρ(x)', 'E(x)', 'V(x)', 'All']

### 9. PN Junction Band Diagram
- **Issue**: Observe panel LaTeX, series toggles
- **Fix**: LatexBulletList + legend toggles for Ec/Ev/EF/Ei

## Testing Checklist

For each page:

- [ ] No LaTeX tokens appear as plain text (check header, about, observe, parameters, readouts, tooltips, key observations)
- [ ] No "unsupported formatting" errors
- [ ] No RenderFlex overflow at 100% zoom (desktop width ~1200px+)
- [ ] Slider/toggle changes immediately redraw chart
- [ ] Animation clearly shows curve movement
- [ ] Pins count label matches actual markers on chart
- [ ] Key Observations includes at least one dynamic statement when point selected/pinned
- [ ] Zoom buttons visibly change chart viewport
- [ ] Right panel scrollable, no content cut off
- [ ] Narrow screen (<1100px): layout stacks vertically without overflow

## Migration Example

### Before (Old Pattern)
```dart
Widget _buildControls(BuildContext context) {
  return Card(
    child: Column(
      children: [
        Text('Parameters'),
        Row([
          Text('Eg (eV)'),  // Plain text!
          Slider(
            value: _bandgap,
            onChanged: (v) => setState(() => _bandgap = v),  // No bumpChart!
          ),
        ]),
      ],
    ),
  );
}
```

### After (New Pattern)
```dart
Widget _buildParametersCard() {
  return ParametersCard(
    title: 'Parameters',
    collapsible: true,
    children: [
      ParameterSlider(
        label: r'$E_g$ (eV)',  // LaTeX!
        value: _bandgap,
        min: 0.2,
        max: 2.5,
        divisions: 230,
        onChanged: (v) {
          setState(() => _bandgap = v);
          bumpChart();  // Force rebuild!
        },
        subtitle: 'Strong (exponential) effect on nᵢ',
      ),
    ],
  );
}
```

## Summary of Fixes Applied

| Page | LaTeX Fixed | Pins Fixed | Overflow Fixed | Zoom Fixed | Dynamic Insight | Plot Selector |
|------|-------------|------------|----------------|------------|-----------------|---------------|
| Parabolic E-k | ✅ | ✅ | ✅ | ✅ | ✅ | N/A |
| Direct/Indirect | ✅ | ✅ | ✅ | ✅ | ✅ | N/A |
| Fermi-Dirac | ✅ | ✅ | ✅ | ✅ | ✅ | N/A |
| DOS g(E) | ✅ | ✅ | ✅ | ✅ | ✅ | N/A |
| Intrinsic nᵢ(T) | ✅ | ✅ | ✅ | ✅ | ✅ | N/A |
| Carrier Conc vs Ef | ✅ | ✅ | ✅ | ✅ | ✅ | N/A |
| Drift/Diffusion | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| PN Depletion | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| PN Band Diagram | ✅ | ✅ | ✅ | ✅ | ✅ | N/A |

## Files Modified

**New shared components** (14 files):
```
lib/ui/graphs/common/
├── graph_controller.dart
├── viewport_state.dart
├── latex_rich_text.dart
├── latex_bullet_list.dart
├── readouts_card.dart
├── point_inspector_card.dart
├── animation_card.dart
├── parameters_card.dart
├── key_observations_card.dart
├── chart_toolbar.dart
├── plot_selector.dart
└── graph_scaffold.dart
```

**Refactored pages** (9 files):
```
lib/ui/pages/
├── parabolic_graph_page.dart
├── direct_indirect_graph_page.dart
├── fermi_dirac_graph_page.dart
├── density_of_states_graph_page.dart
├── intrinsic_carrier_graph_page.dart
├── carrier_concentration_graph_page.dart
├── drift_diffusion_graph_page.dart
├── pn_depletion_graph_page.dart
└── pn_band_diagram_graph_page.dart
```

## Conclusion

All 9 graph pages now share:
1. **Consistent layout** (responsive, no overflow)
2. **Proper LaTeX rendering** (all math symbols formatted)
3. **Reliable chart rebuilds** (GraphController pattern)
4. **Standard features** (readouts, point inspector, animation, parameters, key observations)
5. **Dynamic insights** (computed from pins/selection)
6. **Professional UX** (zoom, pins, tooltips, animations work correctly)

The standardized components can be reused for any future graph pages.
