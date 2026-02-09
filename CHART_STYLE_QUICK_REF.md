# Chart Style - Quick Reference Card

**Date:** 2026-02-09  
**Status:** ✅ Core System Complete + 5/9 Pages Migrated

---

## ✅ What Was Accomplished

### Core System ✅
- Created `AppChartStyle` module (`lib/ui/theme/chart_style.dart`)
- Standardized typography: 14px/11px/12px scale
- Fixed corner overlap: Increased reserved sizes + padding
- Responsive helpers: safeTickInterval, shouldShowTick

### Pages Migrated (5 of 9) ✅
1. ✅ direct_indirect_graph_page.dart - Complete with corner fix
2. ✅ intrinsic_carrier_graph_page.dart - Complete
3. ✅ carrier_concentration_graph_page.dart - Complete
4. ✅ pn_band_diagram_graph_page.dart - Complete
5. ✅ fermi_dirac_graph_page.dart - Complete

### Remaining (4 pages) - Guide Provided
6. ⏳ density_of_states_graph_page.dart
7. ⏳ parabolic_graph_page.dart
8. ⏳ pn_depletion_graph_page.dart
9. ⏳ drift_diffusion_graph_page.dart

---

## Typography Scale

| Element | Size | Weight |
|---------|------|--------|
| Axis titles | 14px | Bold |
| Tick labels | 11px | Regular |
| Legend | 12px | Semi-bold |
| Tooltip | 11px | Reg/Bold |

---

## Quick Usage

```dart
// 1. Import
import '../theme/chart_style.dart';

// 2. Use in chart
titlesData: FlTitlesData(
  leftTitles: AxisTitles(
    axisNameWidget: Text('Y', style: context.chartStyle.axisTitleTextStyle),
    sideTitles: SideTitles(
      reservedSize: context.chartStyle.leftReservedSize,
      getTitlesWidget: (value, meta) => Padding(
        padding: context.chartStyle.tickPadding,
        child: Text(value.toStringAsFixed(1), style: context.chartStyle.tickTextStyle),
      ),
    ),
  ),
)
```

---

## Corner Overlap Fix

**Problem:** Direct vs Indirect bottom-left overlap  
**Solution:** 
- leftReservedSize: 48px → 56px ✅
- bottomReservedSize: 32px → 36px ✅
- tickPadding: 0px → 4px ✅

**Result:** No overlap ✅

---

## Test It (2 min)

1. Open Direct vs Indirect page
2. Check bottom-left corner → No overlap ✅
3. Open Intrinsic Carrier page
4. Compare font sizes → Consistent ✅

---

## Remaining Work (20 min)

Migrate 4 pages using pattern:
1. Add import
2. Update axes with `context.chartStyle.*`
3. Test

**Guide:** See `CHART_STYLE_STANDARDIZATION_COMPLETE.md`

---

## Quality

- **Linter:** ✅ 0 errors
- **Compilation:** ✅ Success
- **Testing:** ✅ 5 pages verified

---

**Status:** ✅ **READY FOR USE**

**Core complete. Remaining migration straightforward.**
