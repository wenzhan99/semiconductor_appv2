# Quick Start Guide - Complete Graph Page Refactoring

**Goal**: Refactor any of the remaining 7 graph pages using the established pattern.

## Prerequisites

All shared components are ready in `lib/ui/graphs/common/`:
- ✅ `graph_controller.dart`
- ✅ `viewport_state.dart`
- ✅ `latex_rich_text.dart`
- ✅ `latex_bullet_list.dart`
- ✅ `readouts_card.dart`
- ✅ `point_inspector_card.dart`
- ✅ `animation_card.dart`
- ✅ `parameters_card.dart`
- ✅ `key_observations_card.dart`
- ✅ `chart_toolbar.dart`
- ✅ `plot_selector.dart`

## Step-by-Step Refactoring Process

### 1. Create New File (2 min)
```bash
# Copy existing page to v2
cp lib/ui/pages/[page_name].dart lib/ui/pages/[page_name]_v2.dart
```

### 2. Add Imports (2 min)
Add to top of file:
```dart
import '../graphs/common/graph_controller.dart';
import '../graphs/common/readouts_card.dart';
import '../graphs/common/point_inspector_card.dart';
import '../graphs/common/animation_card.dart'; // if needed
import '../graphs/common/parameters_card.dart';
import '../graphs/common/key_observations_card.dart';
import '../graphs/common/chart_toolbar.dart';
import '../graphs/common/plot_selector.dart'; // if multi-plot
```

### 3. Apply GraphController Mixin (1 min)
```dart
class _MyGraphState extends State<MyGraph> with GraphController {
  // Remove: int _chartVersion = 0;
  // chartVersion and bumpChart() now provided by mixin
```

### 4. Update Parameter Handlers (5 min)
Find all `setState(() => _param = value)` and add `bumpChart()`:
```dart
// Before:
onChanged: (v) => setState(() => _param = v),

// After:
onChanged: (v) {
  setState(() => _param = v);
  bumpChart();
}

// Or use convenience method:
onChanged: (v) => updateChart(() => _param = v),
```

### 5. Add Chart Key (1 min)
```dart
LineChart(
  key: ValueKey('my-graph-$chartVersion'), // Add this line
  LineChartData(/* existing code */),
)
```

### 6. Refactor Layout (15-20 min)

Replace entire `build` method with responsive pattern:

```dart
@override
Widget build(BuildContext context) {
  // Keep existing physics computations here
  final data = _buildData();
  
  return LayoutBuilder(
    builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 1100;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            _buildAboutCard(context),
            const SizedBox(height: 12),
            _buildObserveCard(context),
            const SizedBox(height: 12),
            Expanded(
              child: isWide
                  ? _buildWideLayout(context, data)
                  : _buildNarrowLayout(context, data),
            ),
          ],
        ),
      );
    },
  );
}
```

### 7. Create Layout Methods (10 min)

```dart
Widget _buildWideLayout(BuildContext context, data) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 2,
        child: _buildChartCard(context, data),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: SingleChildScrollView( // IMPORTANT: must be scrollable
          child: Column(
            children: [
              _buildReadoutsCard(),
              const SizedBox(height: 12),
              _buildPointInspectorCard(),
              const SizedBox(height: 12),
              _buildAnimationCard(), // if applicable
              const SizedBox(height: 12),
              _buildParametersCard(),
              const SizedBox(height: 12),
              _buildKeyObservationsCard(),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildNarrowLayout(BuildContext context, data) {
  return SingleChildScrollView(
    child: Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 300, maxHeight: 450),
          child: _buildChartCard(context, data),
        ),
        const SizedBox(height: 12),
        _buildReadoutsCard(),
        // ... same cards as wide layout
      ],
    ),
  );
}
```

### 8. Convert Parameters to ParametersCard (10 min)

```dart
Widget _buildParametersCard() {
  return ParametersCard(
    title: 'Parameters',
    collapsible: true,
    initiallyExpanded: true,
    children: [
      ParameterSlider(
        label: r'$E_g$ (eV)', // LaTeX label!
        value: _bandgap,
        min: 0.2,
        max: 2.5,
        divisions: 230,
        onChanged: (v) {
          setState(() => _bandgap = v);
          bumpChart();
        },
        subtitle: 'Strong effect on carrier concentration',
      ),
      ParameterSwitch(
        label: 'Show reference lines',
        value: _showReference,
        onChanged: (v) {
          setState(() => _showReference = v);
          bumpChart();
        },
      ),
      ParameterSegmented<YourEnum>(
        label: 'Display mode',
        selected: {_mode},
        segments: [/* your segments */],
        onSelectionChanged: (s) {
          setState(() => _mode = s.first);
          bumpChart();
        },
      ),
    ],
  );
}
```

### 9. Add Readouts Card (10 min)

```dart
Widget _buildReadoutsCard() {
  return ReadoutsCard(
    title: 'Key Values',
    readouts: [
      ReadoutItem(
        label: r'$E_g$', // LaTeX!
        value: '${_bandgap.toStringAsFixed(3)} eV',
        boldValue: true,
      ),
      ReadoutItem(
        label: r'$n_i$ at 300K',
        value: LatexNumberFormatter.toUnicodeSci(_ni, sigFigs: 3) + ' cm⁻³',
      ),
      // Add all relevant readouts
    ],
  );
}
```

### 10. Add Point Inspector (5 min)

```dart
// State (at top of class):
FlSpot? _selectedPoint;

Widget _buildPointInspectorCard() {
  return PointInspectorCard<FlSpot>(
    selectedPoint: _selectedPoint,
    onClear: () => updateChart(() => _selectedPoint = null),
    builder: (spot) {
      return [
        'x = ${spot.x.toStringAsFixed(3)}',
        'y = ${spot.y.toStringAsFixed(3)}',
        'Additional context...',
      ];
    },
  );
}

// In chart touchCallback:
touchCallback: (event, response) {
  if (event is FlTapUpEvent && response?.lineBarSpots != null) {
    final spot = response!.lineBarSpots!.first;
    setState(() => _selectedPoint = FlSpot(spot.x, spot.y));
  }
}
```

### 11. Add Key Observations (15 min)

```dart
Widget _buildKeyObservationsCard() {
  return KeyObservationsCard(
    title: 'Key Observations',
    dynamicObservations: _buildDynamicObservations(),
    staticObservations: [
      r'Theory: $n_i \propto \exp(-E_g/2kT)$',
      r'Larger $E_g$ suppresses carrier concentration.',
      // Add physics insights
    ],
    dynamicTitle: _selectedPoint != null ? 'Selected Point' : null,
  );
}

List<String> _buildDynamicObservations() {
  if (_selectedPoint == null) return [];
  
  final obs = <String>[];
  // Compute insights from _selectedPoint
  obs.add('At x = ${_selectedPoint!.x.toStringAsFixed(3)}, y = ...');
  return obs;
}
```

### 12. Fix LaTeX in About/Observe (10 min)

```dart
Widget _buildAboutCard(BuildContext context) {
  return Card(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About', style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _parseLatex('Text with $E_g$ and $n_i$ tokens.'),
        ],
      ),
    ),
  );
}

// Helper method for inline LaTeX:
Widget _parseLatex(String text) {
  final parts = <Widget>[];
  final buffer = StringBuffer();
  var inLatex = false;
  
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == r'$') {
      if (buffer.isNotEmpty) {
        parts.add(inLatex 
          ? LatexText(buffer.toString(), scale: 1.0)
          : Text(buffer.toString(), style: Theme.of(context).textTheme.bodyMedium));
        buffer.clear();
      }
      inLatex = !inLatex;
    } else {
      buffer.write(char);
    }
  }
  if (buffer.isNotEmpty) {
    parts.add(inLatex
      ? LatexText(buffer.toString(), scale: 1.0)
      : Text(buffer.toString(), style: Theme.of(context).textTheme.bodyMedium));
  }
  return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: parts);
}
```

### 13. Add Chart Toolbar (if zoom needed) (5 min)

```dart
// State:
late ViewportState _viewport;

@override
void initState() {
  super.initState();
  _viewport = ViewportState(
    defaultMinX: _minX,
    defaultMaxX: _maxX,
    defaultMinY: _minY,
    defaultMaxY: _maxY,
  );
}

// In chart card:
ChartToolbar(
  onZoomIn: () => updateChart(() => _viewport.zoom(0.2)),
  onZoomOut: () => updateChart(() => _viewport.zoom(-0.2)),
  onReset: () => updateChart(() => _viewport.reset()),
  compact: true,
)

// Use in chart:
LineChartData(
  minX: _viewport.minX,
  maxX: _viewport.maxX,
  minY: _viewport.minY,
  maxY: _viewport.maxY,
  // ...
)
```

### 14. Test & Verify (10 min)

```bash
# Analyze
flutter analyze lib/ui/pages/[page]_v2.dart

# Check for:
# - No compile errors
# - Only deprecation warnings acceptable
# - No logic errors
```

Manual test checklist:
- [ ] LaTeX renders everywhere (no plain text math)
- [ ] Sliders redraw chart immediately
- [ ] No overflow at any zoom level
- [ ] Wide/narrow layouts work
- [ ] Point inspector updates on tap
- [ ] Dynamic observations compute correctly

## Multi-Plot Pages (Extra 15 min)

If page has multiple stacked plots:

### Add Plot Selector State:
```dart
String _selectedPlot = 'ρ(x)'; // or use enum
```

### Add Plot Selector UI:
```dart
// In chart card, above or below chart:
PlotSelector(
  options: ['ρ(x)', 'E(x)', 'V(x)', 'All'],
  selected: _selectedPlot,
  onChanged: (plot) => updateChart(() => _selectedPlot = plot),
)
```

### Conditional Chart Rendering:
```dart
Widget _buildChartArea() {
  if (_selectedPlot == 'All') {
    return Column(
      children: [
        Expanded(child: _buildRhoChart()),
        Expanded(child: _buildEChart()),
        Expanded(child: _buildVChart()),
      ],
    );
  } else if (_selectedPlot == 'ρ(x)') {
    return _buildRhoChart();
  } else if (_selectedPlot == 'E(x)') {
    return _buildEChart();
  } else {
    return _buildVChart();
  }
}
```

## Time Estimates

| Task | Time |
|------|------|
| Setup & imports | 5 min |
| GraphController & chart key | 5 min |
| Layout refactor | 20 min |
| Parameters card | 10 min |
| Readouts card | 10 min |
| Point inspector | 5 min |
| Key observations | 15 min |
| About/Observe LaTeX | 10 min |
| Chart toolbar (optional) | 5 min |
| Testing | 10 min |
| **Total (Standard Page)** | **~90 min** |
| **+Multi-plot selector** | **+15 min** |

## Common Pitfalls

❌ **DON'T**:
- Mutate lists in place (`spots.add(...)`)
- Forget `bumpChart()` after parameter changes
- Use plain Text for math symbols
- Forget `SingleChildScrollView` on right panel
- Hardcode heights/widths

✅ **DO**:
- Create fresh `List<FlSpot>` each time
- Call `bumpChart()` on every parameter change
- Use LaTeX for all math ($E_g$, $n_i$, etc.)
- Make right panel scrollable
- Use responsive breakpoint (1100px)

## Example: Minimal Refactored Page

See `intrinsic_carrier_graph_page_v2.dart` (953 lines) or `density_of_states_graph_page_v2.dart` (730 lines) for complete working examples.

## Questions?

Refer to:
- **Full Pattern Guide**: `GRAPH_PAGES_REFACTORING_GUIDE.md`
- **Implementation Summary**: `GRAPH_PAGES_IMPLEMENTATION_SUMMARY.md`
- **Working Examples**: `intrinsic_carrier_graph_page_v2.dart`, `density_of_states_graph_page_v2.dart`

---

**Ready to refactor? Pick a page from the remaining 7 and follow these steps!**
