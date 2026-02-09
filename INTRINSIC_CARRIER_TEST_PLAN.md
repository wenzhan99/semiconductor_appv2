# Intrinsic Carrier Graph UX Fixes - Test Verification Plan

## Test Environment
- **Platform**: Windows (Chrome)
- **Flutter**: Debug mode
- **File**: `lib/ui/pages/intrinsic_carrier_graph_page.dart`
- **Date**: 2026-02-09

---

## Test 1: About Section Math Rendering

### Objective
Verify that E_g and n_i render as proper LaTeX with subscripts instead of raw text.

### Steps
1. Navigate to "Graphs" → "Intrinsic Carrier Concentration vs T"
2. Locate the "About" card at the top of the page (grey background)
3. Read the about text

### Expected Results
✅ **Pass Criteria:**
- Text should read: "Shows how intrinsic carrier concentration increases exponentially with temperature. The bandgap E_g has a strong (exponential) effect on n_i."
- E_g should display with subscript 'g' (not "E_g" in plain text)
- n_i should display with subscript 'i' (not "n_i" in plain text)
- Math symbols should be slightly different font/style from surrounding text

❌ **Fail Criteria:**
- Raw text "E_g" or "n_i" appears
- No subscripts visible
- Layout broken or text overflows

### Screenshot Points
- [ ] About card showing proper LaTeX rendering

---

## Test 2: Key Observation - Quantified Decades Span

### Objective
Verify that the "log scaling" bullet point shows concrete numeric information about the decades span.

### Steps
1. On the same page, scroll down to the "Insights & Pins" card on the right
2. Locate the "Key observations" section
3. Read the third bullet point about log scaling

### Expected Results
✅ **Pass Criteria:**
- Bullet should read: "Log scale needed: n_i spans [X.X] decades (≈ 10^[min] to 10^[max])"
- Example: "Log scale needed: n_i spans 9.5 decades (≈ 10^6 to 10^15)"
- Numbers [X.X], [min], and [max] should be computed values, not placeholders
- Exponents should render properly (superscript notation)

❌ **Fail Criteria:**
- Vague text like "spans many decades" without numbers
- Missing exponent range
- "null" or error text appears

### Dynamic Test
1. Change E_g slider to 0.5 eV
2. Verify decades span updates (should be larger span at lower E_g)
3. Change E_g slider to 2.0 eV
4. Verify decades span updates (should be smaller span at higher E_g)

### Screenshot Points
- [ ] Key observation showing quantified decades at E_g = 1.12 eV (Silicon)
- [ ] Key observation showing different values at E_g = 0.5 eV

---

## Test 3A: Animation - Curve Movement

### Objective
Verify that the animation causes the curve to visibly move on the chart.

### Steps
1. Set parameters to default (click "Reset to Silicon" button)
2. Locate the "Animation" card on the right panel
3. Click the Play button (▶)
4. Observe the chart for ~2.5 seconds

### Expected Results
✅ **Pass Criteria:**
- Curve should visibly shift downward as E_g increases from 0.6 to 1.6 eV
- Movement should be smooth and continuous (~60 fps)
- No stutter, lag, or freezing
- Grey "ghost" baseline curve appears and stays fixed
- Primary curve (colored) moves relative to baseline
- Progress bar at bottom of Animation card fills from 0% to 100%

❌ **Fail Criteria:**
- Curve appears static/frozen during animation
- Only parameter value changes but curve doesn't move
- Animation stutters or lags
- No baseline curve visible
- Chart doesn't rebuild

### Screenshot Points
- [ ] Animation at 0% (E_g = 0.6 eV) with baseline captured
- [ ] Animation at 50% (E_g ≈ 1.1 eV) showing both baseline and animated curve
- [ ] Animation at 100% (E_g = 1.6 eV) 

---

## Test 3B: Animation - Live E_g Readout

### Objective
Verify that current E_g value updates in real-time during animation.

### Steps
1. Locate the "Current: E_g = X.XXX eV" line in the Animation card
2. Click Play button
3. Watch the E_g value during animation

### Expected Results
✅ **Pass Criteria:**
- Line reads "Current: E_g = [value] eV" with proper LaTeX formatting
- E_g displays with subscript 'g'
- Value should start at 0.600 eV
- Value should smoothly increment to 1.600 eV over 2.5 seconds
- Value updates every animation tick (~60 Hz)
- Final value should be exactly 1.600 eV

❌ **Fail Criteria:**
- E_g value doesn't change during animation
- Value jumps instead of smooth progression
- Raw "E_g" text without subscript
- Value doesn't reach 1.600 eV at completion

### Screenshot Points
- [ ] Animation card showing E_g = 0.600 eV at start
- [ ] Animation card showing E_g ≈ 1.100 eV mid-animation
- [ ] Animation card showing E_g = 1.600 eV at end

---

## Test 3C: Animation - Baseline Ghost Curve

### Objective
Verify that a semi-transparent baseline curve appears during animation for visual comparison.

### Steps
1. Start animation (Play button)
2. Observe the chart area
3. Look for two curves: one grey (baseline) and one colored (animated)

### Expected Results
✅ **Pass Criteria:**
- Grey baseline curve appears when animation starts
- Baseline curve is semi-transparent (grey with ~40% opacity)
- Baseline curve stays fixed at E_g = 0.6 eV position throughout animation
- Primary colored curve moves relative to baseline
- Both curves render smoothly without overlap artifacts
- Baseline disappears when animation completes or is stopped

❌ **Fail Criteria:**
- No baseline curve visible
- Baseline moves during animation
- Baseline doesn't clear after animation
- Visual artifacts or rendering issues

### Screenshot Points
- [ ] Chart showing both baseline (grey) and animated curve (colored) mid-animation

---

## Test 3D: Animation - Auto-Scaling Behavior

### Objective
Verify that y-axis scaling switches to Auto during animation for better visibility.

### Steps
1. Set Y-axis scaling to "Locked" mode (default)
2. Note the current y-axis range (e.g., 4 to 18 for cm^-3)
3. Start animation
4. Observe y-axis range during animation
5. Let animation complete
6. Observe y-axis range after completion

### Expected Results
✅ **Pass Criteria:**
- Before animation: Y-axis shows locked range (4 to 18 for cm^-3)
- During animation: Y-axis expands to Auto range to fit curve movement
- After animation: Y-axis returns to Locked range
- Scaling mode button still shows "Locked" selected throughout
- Transition is smooth without jarring jumps

❌ **Fail Criteria:**
- Y-axis doesn't change during animation
- Curve moves off-screen during animation
- Scaling mode button changes to "Auto" (should remain "Locked")
- Y-axis doesn't restore after animation

### Manual Scaling Test
1. Set Y-axis to "Auto" mode
2. Start animation → should stay in Auto mode
3. Set Y-axis to "Wide" mode
4. Start animation → should switch to Auto, then restore to Wide

### Screenshot Points
- [ ] Before animation: Y-axis Locked (4-18)
- [ ] During animation: Y-axis Auto (expanded range)
- [ ] After animation: Y-axis Locked (4-18) restored

---

## Test 3E: Animation - Pinned Points Update

### Objective
Verify that pinned/selected insight values update during animation.

### Steps
1. Reset to Silicon defaults
2. Tap on the curve at T = 300 K to pin a point
3. Note the displayed n_i value, Nc, Nv, and ratio
4. Start animation
5. Observe the pinned insight values during animation

### Expected Results
✅ **Pass Criteria:**
- Pinned point values (n_i, Nc, Nv, kT, E_g/kT, exp factor) update during animation
- Values reflect the current animated E_g, not the original 0.6 eV
- Updates are smooth and continuous
- No "null" or error values appear
- Ratio to 300 K baseline updates correctly

❌ **Fail Criteria:**
- Values stay frozen at initial values
- "null" or error messages appear
- Values update sporadically or lag behind animation
- Derived calculations show incorrect values

### Screenshot Points
- [ ] Pinned point breakdown at animation start (E_g = 0.6)
- [ ] Pinned point breakdown mid-animation (E_g ≈ 1.1)
- [ ] Pinned point breakdown at animation end (E_g = 1.6)

---

## Test 4: Animation Controls

### Objective
Verify all animation control buttons work correctly.

### Test 4A: Play/Pause
**Steps:**
1. Click Play → animation starts
2. Wait 1 second → click Pause
3. Verify curve stops moving
4. Verify E_g value frozen at current position
5. Click Play again → animation resumes from current position

**Pass Criteria:**
- ✅ Play starts animation from 0.6 eV
- ✅ Pause freezes at current E_g
- ✅ Resume continues from paused position
- ✅ Icon toggles between ▶ (Play) and ⏸ (Pause)

### Test 4B: Reset
**Steps:**
1. Start animation
2. Wait 1 second
3. Click Reset button
4. Verify E_g returns to 0.6 eV
5. Verify curve resets to initial position

**Pass Criteria:**
- ✅ E_g resets to 0.600 eV
- ✅ Curve returns to starting position
- ✅ Progress bar resets to 0%
- ✅ Baseline curve clears

### Test 4C: Parameter Locking During Animation
**Steps:**
1. Start animation
2. Try to drag E_g slider
3. Try to drag m_n* slider
4. Try to drag m_p* slider

**Pass Criteria:**
- ✅ All parameter sliders are disabled (greyed out) during animation
- ✅ Sliders re-enable after animation completes or is stopped

---

## Test 5: Edge Cases & Error Handling

### Test 5A: Reduced Motion Preference
**Steps:**
1. Enable reduced motion in system accessibility settings (if possible)
2. Try to start animation
3. Verify appropriate behavior

**Pass Criteria:**
- ✅ Snackbar message: "Animation disabled due to reduced motion preference"
- ✅ Animation doesn't start
- ✅ No error thrown

### Test 5B: Multiple Animation Cycles
**Steps:**
1. Click Play → let animation complete
2. Click Play again → let animation complete
3. Click Play a third time → let animation complete
4. Check for memory leaks or performance degradation

**Pass Criteria:**
- ✅ Each cycle runs smoothly
- ✅ No accumulated lag
- ✅ Baseline captured correctly each time
- ✅ Scaling mode restored each time

### Test 5C: Stop Mid-Animation
**Steps:**
1. Start animation
2. Click "Reset to Silicon" button mid-animation
3. Verify cleanup happens correctly

**Pass Criteria:**
- ✅ Animation stops immediately
- ✅ Baseline curve clears
- ✅ E_g resets to 1.12 eV (Silicon)
- ✅ Scaling mode restored
- ✅ No orphaned timers or memory leaks

---

## Test 6: Cross-Feature Integration

### Test 6A: Animation + Unit Toggle
**Steps:**
1. Start with cm^-3 units
2. Start animation
3. Toggle units to m^-3 mid-animation
4. Verify behavior

**Pass Criteria:**
- ✅ Chart rebuilds with new units
- ✅ Animation continues smoothly
- ✅ Decades span updates in Key Observations
- ✅ No errors or visual glitches

### Test 6B: Animation + Arrhenius Mode
**Steps:**
1. Enable Arrhenius plot (x-axis = 1/T)
2. Start animation
3. Verify curve moves correctly in 1/T space

**Pass Criteria:**
- ✅ Curve animates smoothly in 1/T coordinates
- ✅ Baseline captured correctly
- ✅ Movement visible and correct direction

### Test 6C: Animation + Pinning
**Steps:**
1. Pin 2-3 points on the curve
2. Start animation
3. Pin another point mid-animation
4. Verify pinned insights update correctly

**Pass Criteria:**
- ✅ Pre-existing pins update with new E_g during animation
- ✅ Can add new pins during animation (if not disabled)
- ✅ All pinned values reflect current animated E_g

---

## Regression Tests

### Verify No Breaking Changes
- [ ] Other graph pages still work (Fermi-Dirac, DOS, etc.)
- [ ] PN Junction graphs still work
- [ ] Formula workspace still solves correctly
- [ ] Settings page works
- [ ] Constants/Units page works

### Performance
- [ ] Page loads in < 2 seconds
- [ ] Animation runs at 60 fps (no stutter)
- [ ] No console errors during animation
- [ ] No memory leaks after 10 animation cycles
- [ ] Hot reload works without errors

---

## Final Acceptance Checklist

### Issue 1: About Section (LaTeX Rendering)
- [ ] E_g renders with subscript
- [ ] n_i renders with subscript
- [ ] No raw text tokens visible
- [ ] Layout is clean and readable

### Issue 2: Key Observation (Decades Span)
- [ ] Shows numeric decades span (e.g., "9.5 decades")
- [ ] Shows exponent range (e.g., "10^6 to 10^15")
- [ ] Values are computed from actual curve data
- [ ] Updates dynamically when parameters change

### Issue 3: Animation (Visible Movement)
- [ ] Curve visibly moves during animation
- [ ] Live E_g readout updates (~60 Hz)
- [ ] Grey baseline curve shows for comparison
- [ ] Auto-scaling during animation (optional restore after)
- [ ] Smooth 60 fps animation
- [ ] Pinned insights update during animation
- [ ] Play/Pause/Reset controls work correctly

### No Regressions
- [ ] No new linter errors
- [ ] No compilation errors
- [ ] No runtime errors
- [ ] No layout overflows
- [ ] Other pages unaffected

---

## Test Results Summary

**Tester:** [Name]  
**Date:** [YYYY-MM-DD]  
**Build:** [Git commit hash]  
**Platform:** [Windows/Mac/Linux + Browser]  

### Overall Status
- [ ] All tests passed ✅
- [ ] Some tests failed (see details below) ⚠️
- [ ] Critical failures (blocking) ❌

### Test Results by Category
| Category | Tests Run | Passed | Failed | Notes |
|----------|-----------|--------|--------|-------|
| About Section | 1 | | | |
| Key Observations | 2 | | | |
| Animation - Movement | 1 | | | |
| Animation - Readout | 1 | | | |
| Animation - Baseline | 1 | | | |
| Animation - Scaling | 2 | | | |
| Animation - Insights | 1 | | | |
| Animation Controls | 3 | | | |
| Edge Cases | 3 | | | |
| Integration | 3 | | | |
| Regression | 2 | | | |
| **TOTAL** | **20** | | | |

### Issues Found
(List any bugs, regressions, or unexpected behavior discovered during testing)

1. [Issue description]
   - Severity: [Critical/High/Medium/Low]
   - Steps to reproduce: ...
   - Expected: ...
   - Actual: ...

---

## Sign-Off

**Developer:** [Name] - ✅ Code complete  
**Tester:** [Name] - ✅ Testing complete  
**Date:** [YYYY-MM-DD]

---

**Status:** Ready for User Acceptance Testing
