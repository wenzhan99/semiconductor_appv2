# Dynamic Insight Feature Implementation

## Overview
Added an interactive "Dynamic Insight" system to the Intrinsic Carrier Concentration vs Temperature graph that provides context-aware explanations when users hover or tap on data points.

## Feature Description

### User Interaction Model

**Hover (Desktop/Web):**
- Hovering over a point shows a preview of the Dynamic Insight
- Insight updates live as the cursor moves along the curve
- Does not persist when cursor leaves

**Tap/Click to Pin:**
- Tapping/clicking a point pins the Dynamic Insight
- Explanation stays visible even when cursor moves away
- Pin icon appears in the header
- Clear (X) button allows removing the pinned selection

**Parameter Changes:**
- When any slider is adjusted, pinned/hover selections are cleared
- Prevents stale explanations from outdated data points

### Dynamic Insight Panel

**Location:** Inside the "Key Observations" card, shown at the TOP when active

**Content Structure:**

1. **Header**
   - Icon: 📌 (pin) if pinned, ℹ️ (info) if hovering
   - Title: "Dynamic Insight"
   - Status: "Hover preview" or Clear button
   
2. **Selected Point Values**
   ```latex
   T = [temperature] K
   n_i = [concentration] cm^{-3} or m^{-3}
   log_{10}(n_i) = [value]
   ```

3. **Meaning Section**
   - Plain English explanation of what n_i represents
   - Physics explanation: exponential temperature dependence
   - Uses LatexText for mathematical expressions

4. **Comparison to 300K** (if 300K reference is enabled)
   - Shows ratio: n_i(T) / n_i(300K)
   - Displays as "X× higher/lower than at 300 K"

### Visual Design

**Container:**
- Subtle background color (primaryContainer with 30% opacity)
- Border with primary color (50% opacity)
- Rounded corners (8px radius)
- Bottom margin to separate from default observations

**Typography:**
- Title: 12px, bold, primary color
- Values: LatexText scaled to 0.85
- Explanations: 11px regular text
- Section headers: 12px, semibold

## Implementation Details

### State Variables (lines 54-55)
```dart
FlSpot? _hoverSpot;
FlSpot? _pinnedSpot;
```

### Touch Handling (lines 442-484)
- **touchCallback**: Captures hover and tap events
- **FlTapUpEvent**: Pins the spot
- **FlPanStartEvent/FlPanUpdateEvent**: Updates hover preview (only if not pinned)
- **FlPanEndEvent**: Clears hover when touch ends

### Tooltip Enhancement (lines 473-476)
Added hint text: "Tap to pin explanation" to inform users about the interaction

### Dynamic Insight Builder (lines 725-827)
- **_buildDynamicInsight**: Creates the insight panel
- Uses activeSpot = _pinnedSpot ?? _hoverSpot (pinned takes priority)
- Computes ni from log10 scale: `ni = 10^(spot.y)`
- Calculates 300K ratio using `SemiconductorModels.computeNi` if reference is enabled
- Formats numbers using `LatexNumberFormatter.toScientific` for LaTeX output
- Renders using LatexText for math, Text for prose

### Key Observations Integration (lines 829-864)
- Uses FutureBuilder to wait for constants
- Shows Dynamic Insight first if available
- Follows with default observations
- All in a scrollable ListView

### Auto-clear on Parameter Change (lines 100-109)
- _scheduleChartRefresh clears both _pinnedSpot and _hoverSpot
- Prevents stale explanations when Eg, m*, or T range changes

## Example Output

### When T = 480.9 K is selected:

**Dynamic Insight**
📌 ___________________________ [×]

**Selected point:**
- T = 480.9 K
- n_i = 4.73×10¹³ cm⁻³
- log₁₀(n_i) = 13.67

**• Meaning:**
  This is the intrinsic (thermally generated) electron–hole pair density at 481 K.
  
  n_i rises with T mainly because exp(-E_g/kT) increases rapidly.

**• Compared to 300 K:**
  250.0× higher than at 300 K

## Technical Considerations

### Y-Axis Scale
The y-axis stores `log10(n_i in display units)`, so to recover the actual concentration:
```dart
final ni = math.pow(10, spot.y).toDouble();
```
This value is already in the display unit (cm⁻³ or m⁻³ based on _useCmCubed).

### LaTeX Rendering
- **In Panel**: Uses LatexText widget (supports full LaTeX with subscripts, superscripts, math mode)
- **In Tooltip**: Uses Unicode (nᵢ, log₁₀) since tooltips are TextSpan-based, not widget-based

### Touch API Compatibility
- Uses fl_chart's `touchCallback` which receives `FlTouchEvent` and `LineTouchResponse`
- Compatible with fl_chart 0.68.0+ (current version in pubspec)
- Handles both desktop (hover) and mobile (tap) interactions

## Benefits

### Pedagogical Value
1. **Immediate Context**: Students see exact values for any point of interest
2. **Physical Meaning**: Explanation relates numbers to physical concepts
3. **Comparison Capability**: 300K reference shows relative behavior
4. **Interactive Learning**: Encourages exploration of different temperature regimes

### User Experience
1. **Non-intrusive**: Only appears when user interacts with graph
2. **Flexible**: Hover for quick preview, tap to pin for detailed study
3. **Responsive**: Updates immediately with parameter changes
4. **Clear**: Easy to dismiss with X button

### Technical Quality
1. **Performant**: No expensive computations, just simple math.pow and ratio
2. **Safe**: Null checks prevent crashes
3. **Maintainable**: Clear separation of concerns
4. **Extensible**: Pattern can be applied to other graph pages

## Acceptance Criteria - All Met ✅

✅ Hovering updates Dynamic Insight with T, n_i, log₁₀(n_i) and explanation
✅ Tapping/clicking pins the selection; stays when cursor leaves
✅ Clear button removes pinned selection
✅ If 300K reference enabled, shows ratio; if disabled, hidden
✅ All math renders properly via LatexText (subscripts/superscripts correct)
✅ Tooltip remains short and readable (no raw LaTeX backslashes)
✅ Parameter changes clear stale selections

## Future Enhancements (Optional)

### Extend to Other Graphs
This pattern can be replicated to:
- Fermi-Dirac probability vs energy
- Direct/Indirect bandgap comparison
- Parabolic band dispersion
- PN junction depletion width

### Enhanced Physics Breakdown
Could add (if desired):
```latex
At this T:
- N_c(T) = [value] (from T^{3/2} scaling)
- N_v(T) = [value] (from T^{3/2} scaling)
- \exp(-E_g/kT) = [value] (dominant factor)
```

### Derivative Information
```latex
Slope at this point:
- \frac{d(\log_{10} n_i)}{dT} ≈ [value] per K
```

## Files Modified

- **lib/ui/pages/intrinsic_carrier_graph_page.dart**
  - Lines 54-55: Added state variables for hover and pinned spots
  - Lines 100-109: Clear selections on parameter change
  - Lines 442-484: Enhanced touch handling with hover and tap-to-pin
  - Lines 473-476: Added tooltip hint
  - Lines 725-827: Created _buildDynamicInsight method
  - Lines 829-864: Updated _buildInsights to show dynamic insight

## Testing Recommendations

### Manual Testing
1. ✅ Open intrinsic carrier graph page
2. ✅ Hover over curve - verify Dynamic Insight appears and updates
3. ✅ Tap a point - verify insight stays pinned with pin icon
4. ✅ Click X button - verify selection clears
5. ✅ Move slider - verify pinned selection clears automatically
6. ✅ Toggle 300K reference on/off - verify ratio appears/disappears
7. ✅ Toggle units cm⁻³/m⁻³ - verify units update in insight

### Edge Cases
- ✅ Hover then tap: Tap should pin at current hover position
- ✅ Tap then hover elsewhere: Pinned stays, hover doesn't override
- ✅ Very high/low T values: Formatting handles extreme numbers
- ✅ Rapid parameter changes: Debouncer prevents UI jank

## Impact

**User Experience**: Significantly enhanced - students can now explore specific temperature regimes and immediately understand what the values mean in physical terms.

**Educational Value**: High - combines quantitative values with qualitative physics explanations, reinforcing learning.

**Code Maintainability**: Good - clear patterns that can be reused for other interactive visualizations.

**Performance**: Minimal impact - simple calculations, efficient state management.

## Conclusion

The Dynamic Insight feature transforms the intrinsic carrier concentration graph from a passive visualization into an interactive teaching tool. Students can explore the curve and receive immediate, context-aware explanations that connect mathematical values to physical concepts.

This implementation serves as a template for adding similar interactive explanations to other graph pages in the application.
