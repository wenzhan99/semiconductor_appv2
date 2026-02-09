# Batch Refactoring Summary - 3 Pages

**Date**: February 9, 2026  
**Pages**: PN Junction Depletion, Drift vs Diffusion, Direct vs Indirect  
**Status**: Implementation Guide Ready

## Critical Refactoring Points for Each Page

### 1. PN Junction Depletion (Priority: HIGH)

**File**: `pn_depletion_graph_page.dart` → `pn_depletion_graph_page_v2.dart`

**Current Issue**: 3 stacked charts (ρ(x), E(x), V(x)) cause overflow

**Key Changes**:
```dart
// Add state:
String _selectedPlot = 'ρ(x)';

// Add PlotSelector in chart card:
PlotSelector(
  options: ['ρ(x)', 'E(x)', 'V(x)', 'All'],
  selected: _selectedPlot,
  onChanged: (plot) => updateChart(() => _selectedPlot = plot),
)

// Conditional rendering:
if (_selectedPlot == 'All') {
  return Column(
    children: [
      Expanded(child: _buildRhoChart(curves)),
      SizedBox(height: 8),
      Expanded(child: _buildEFieldChart(curves)),
      SizedBox(height: 8),
      Expanded(child: _buildVChart(curves)),
    ],
  );
} else if (_selectedPlot == 'ρ(x)') {
  return _buildRhoChart(curves);
} else if (_selectedPlot == 'E(x)') {
  return _buildEFieldChart(curves);
} else {
  return _buildVChart(curves);
}
```

**LaTeX to Fix**:
- Parameters: "N_A", "N_D", "V_a", "V_bi" → `$N_A$`, `$N_D$`, `$V_a$`, `$V_{bi}$`
- Readouts: Add W, xₚ, xₙ, Eₘₐₓ, Vbi as LaTeX labels

**Estimated Time**: 3 hours

---

### 2. Drift vs Diffusion (Priority: HIGH)

**File**: `drift_diffusion_graph_page.dart` → `drift_diffusion_graph_page_v2.dart`

**Current Issue**: 2 stacked plots cause overflow

**Key Changes**:
```dart
// Add state:
String _selectedPlot = 'n(x)';

// Add PlotSelector:
PlotSelector(
  options: ['n(x)', 'J components', 'All'],
  selected: _selectedPlot,
  onChanged: (plot) => updateChart(() => _selectedPlot = plot),
)

// Conditional rendering:
if (_selectedPlot == 'All') {
  return Column(
    children: [
      Expanded(child: _buildConcentrationChart()),
      SizedBox(height: 8),
      Expanded(child: _buildCurrentChart()),
    ],
  );
} else if (_selectedPlot == 'n(x)') {
  return _buildConcentrationChart();
} else {
  return _buildCurrentChart();
}
```

**LaTeX to Fix**:
- All n, p, J_drift, J_diff → LaTeX
- Parameters: μ, D, E → LaTeX

**Estimated Time**: 2.5 hours

---

### 3. Direct vs Indirect (Priority: MEDIUM)

**File**: `direct_indirect_graph_page.dart` → `direct_indirect_graph_page_v2.dart`

**Current Issue**: LaTeX inconsistency, needs standardization

**Key Changes**:
```dart
// Already has good structure, needs:
1. Convert all plain text labels to LaTeX
2. Add GraphController mixin
3. Standardize cards
4. Add dynamic insights

// LaTeX conversions:
'Eg (eV)' → r'$E_g$ (eV)'
'k0' → r'$k_0$'
'm* (electrons)' → r'$m_e^*$'
'Eg_direct' → r'$E_{g,\text{direct}}$'
'Eg_indirect' → r'$E_{g,\text{indirect}}$'
```

**Dynamic Insights**:
- Show selected point's distance to band edges
- Show gap type analysis
- Show k-offset impact

**Estimated Time**: 2.5 hours

---

## Standardized Components to Use

All three pages will use:

✅ **GraphController** mixin (chartVersion, bumpChart())  
✅ **ReadoutsCard** - Key numeric values with LaTeX  
✅ **PointInspectorCard** - Selected point details  
✅ **ParametersCard** - All sliders with LaTeX labels  
✅ **KeyObservationsCard** - Dynamic + static insights  
✅ **ChartToolbar** - Zoom controls (optional)  
✅ **PlotSelector** - Multi-plot navigation (PN & Drift only)

---

## Implementation Order

### Phase 1: PN Junction Depletion (3h)
1. Add PlotSelector state and UI (30min)
2. Split _buildCharts into 3 methods (45min)
3. Add conditional rendering (15min)
4. Standardize cards (60min)
5. Test & verify (30min)

### Phase 2: Drift vs Diffusion (2.5h)
1. Add PlotSelector (20min)
2. Split charts (30min)
3. Standardize cards (60min)
4. LaTeX conversions (30min)
5. Test (30min)

### Phase 3: Direct vs Indirect (2.5h)
1. Add GraphController (10min)
2. LaTeX all labels (45min)
3. Standardize cards (60min)
4. Dynamic insights (30min)
5. Test (25min)

**Total Sequential**: 8 hours  
**Total Parallel**: 3 hours (if 3 developers)

---

## Quick Reference: Standard Layout

```dart
@override
Widget build(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 1100;
      return Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(),
            SizedBox(height: 12),
            _buildAboutCard(),
            SizedBox(height: 12),
            _buildObserveCard(),
            SizedBox(height: 12),
            Expanded(
              child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildWideLayout() {
  return Row(
    children: [
      Expanded(flex: 2, child: _buildChartCard()),
      SizedBox(width: 12),
      Expanded(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildReadoutsCard(),
              SizedBox(height: 12),
              _buildPointInspectorCard(),
              SizedBox(height: 12),
              _buildParametersCard(),
              SizedBox(height: 12),
              _buildKeyObservationsCard(),
            ],
          ),
        ),
      ),
    ],
  );
}
```

---

## Testing Checklist (Per Page)

### LaTeX Rendering ✅
- [ ] No plain text math symbols anywhere
- [ ] All parameter labels use LaTeX
- [ ] All readout labels use LaTeX
- [ ] Observe bullets render LaTeX properly

### Chart Behavior ✅
- [ ] Sliders immediately redraw
- [ ] Plot selector switches correctly (if multi-plot)
- [ ] Chart key uses ValueKey with chartVersion

### Responsiveness ✅
- [ ] No overflow at 1200px, 1100px, 1000px
- [ ] Right panel scrolls
- [ ] Narrow layout stacks vertically

### Multi-Plot Specific ✅ (PN & Drift only)
- [ ] Plot selector visible and functional
- [ ] "All" option shows all plots stacked
- [ ] Individual plots show full-size
- [ ] Point inspector adapts to selected plot

---

## Success Criteria

After refactoring all 3 pages:

✅ **5 of 9 pages complete** (56%)  
✅ **All high-priority overflow issues fixed**  
✅ **LaTeX rendering standardized**  
✅ **Multi-plot pages functional**  
✅ **~50% reduction in bugs**  

---

## Files to Create

```
lib/ui/pages/
├── pn_depletion_graph_page_v2.dart         (NEW)
├── drift_diffusion_graph_page_v2.dart      (NEW)
└── direct_indirect_graph_page_v2.dart      (NEW)
```

---

**Ready to implement systematically using QUICK_START_GUIDE.md as reference.**

---

**Document Version**: 1.0  
**Last Updated**: February 9, 2026
