# Carrier Concentration vs Fermi Level - Test Verification Guide

**Status:** ✅ Ready for Testing  
**Date:** 2026-02-09

---

## Quick Test (5 minutes)

### 1. Open the Page
- Run app → **Graphs** → **Carrier Concentration vs Fermi Level**

### 2. Visual Check (30 seconds)
✅ **Look for these improvements:**
- Top chips show: `n(E_F): 1.50 × 10^10 cm⁻³` (not `1.5^10 cm^-3`)
- Info panel bullets have proper subscripts (not raw E_F, E_c, E_v)
- Chart labels show: nᵢ, Eᵥ, Eᴄ (Unicode subscripts)
- Segmented control shows: `[n only] [p only] [n & p]` (no error message)

### 3. Interaction Test (2 minutes)
✅ **Try these actions:**
- Click segmented control segments → All three work
- Hover over curves → Tooltip shows E_F once at top
- Switch mode to "n only" → Tooltip adapts (shows only n)
- Scroll right panel → No overflow, smooth scrolling
- Collapse Parameters section → Works smoothly

---

## Detailed Testing

### Test 1: LaTeX Rendering (2 min)

#### A. Info Panel ("What to observe")
**Location:** Top of page, grey expansion card

**Expected:**
- ✅ "n rises exponentially as E_F moves toward Eᴄ" (subscript c)
- ✅ "p rises exponentially as E_F moves toward Eᵥ" (subscript v)
- ✅ "At intrinsic conditions, n ≈ p ≈ nᵢ" (subscript i)

**Check:**
- [ ] No raw underscores (E_F, E_c, E_v)
- [ ] All subscripts render properly
- [ ] Text is readable and professional

#### B. Result Chips (Top of chart area)
**Location:** Below header, above chart

**Expected:**
- ✅ `T: 300 K`
- ✅ `E_F: 0.560 eV` (subscript F)
- ✅ `n(E_F): 1.50 × 10^10 cm⁻³` (LaTeX subscript and proper notation)
- ✅ `p(E_F): 2.30 × 10^9 cm⁻³`
- ✅ `n_i(T): 1.45 × 10^10 cm⁻³` (if n_i line enabled)

**Check:**
- [ ] Labels have subscripts (E_F, n_i)
- [ ] Values use scientific notation: "a × 10^b"
- [ ] Units show as "cm⁻³" or "m⁻³" (superscript -3)
- [ ] No caret notation (^10 or ^-3)

#### C. Chart Labels
**Location:** Inside chart area

**Expected:**
- ✅ Horizontal line label: "nᵢ" (Unicode subscript i)
- ✅ Vertical line at E_v: "Eᵥ" (Unicode subscript v)
- ✅ Vertical line at E_c: "Eᴄ" (Unicode subscript c)

**Check:**
- [ ] All labels have visible subscripts
- [ ] Labels are readable at normal zoom

#### D. Key Observations (Right panel, bottom)
**Location:** Grey card at bottom right

**Expected:**
- ✅ "n increases exponentially as E_F approaches Eᴄ"
- ✅ "p increases exponentially as E_F approaches Eᵥ"
- ✅ "nᵢ marks the intrinsic point (n = p)"

**Check:**
- [ ] All bullets use LaTeX formatting
- [ ] Subscripts render correctly
- [ ] No raw underscores visible

---

### Test 2: Segmented Control (1 min)

**Location:** Right panel, Parameters section, after unit toggle

#### A. Visual Check
**Expected:**
```
[n only] [p only] [n & p]
```

**Check:**
- [ ] No error message "Step contains unsupported formatting"
- [ ] All three segments show correct labels
- [ ] Labels are readable

#### B. Functionality Check
**Actions:**
1. Click "n only" → Chart shows only n curve (blue)
2. Click "p only" → Chart shows only p curve (purple/tertiary color)
3. Click "n & p" → Chart shows both curves

**Check:**
- [ ] All segments selectable
- [ ] Chart updates correctly for each mode
- [ ] Result chips adapt (n chip hidden in "p only", etc.)

---

### Test 3: Numeric Formatting (2 min)

#### A. Result Chips
**Action:** Read values in top chips

**Expected Format:**
```
n(E_F): 1.50 × 10^10 cm⁻³
p(E_F): 2.30 × 10^9 cm⁻³
n_i(T): 1.45 × 10^10 cm⁻³
```

**Check:**
- [ ] Coefficient has 3 significant figures (e.g., 1.50, not 1.5)
- [ ] Uses "×" symbol (not "*" or "x")
- [ ] Exponent is superscript (10^10, not 10^10)
- [ ] Units have superscript -3 (cm⁻³, not cm^-3)
- [ ] Thin space between number and unit

#### B. Tooltip
**Action:** Hover over curves

**Expected Format:**
```
E_F: 0.560 eV
n: 1.50 × 10^10 cm⁻³
log₁₀(n) = 10.18
```

**Check:**
- [ ] Same scientific notation as chips
- [ ] Log₁₀ has subscript 10
- [ ] Units consistent

#### C. Unit Toggle
**Action:** Click unit toggle (cm⁻³ / m⁻³)

**Expected:**
- cm⁻³ mode: Values like 10^10, 10^15
- m⁻³ mode: Values like 10^16, 10^21 (6 orders of magnitude higher)

**Check:**
- [ ] All chips update units
- [ ] Tooltip updates units
- [ ] Chart y-axis range adjusts

---

### Test 4: Tooltip Clarity (2 min)

#### A. Mode: "n only"
**Action:** Select "n only" mode, hover over curve

**Expected Tooltip:**
```
E_F: 0.560 eV
n: 1.50 × 10^10 cm⁻³
log₁₀(n) = 10.18
```

**Check:**
- [ ] E_F shown once (bold)
- [ ] Only n concentration shown
- [ ] log₁₀ value included

#### B. Mode: "p only"
**Action:** Select "p only" mode, hover over curve

**Expected Tooltip:**
```
E_F: 0.560 eV
p: 2.30 × 10^9 cm⁻³
log₁₀(p) = 9.36
```

**Check:**
- [ ] E_F shown once (bold)
- [ ] Only p concentration shown
- [ ] log₁₀ value included

#### C. Mode: "n & p" (both)
**Action:** Select "n & p" mode, hover over chart

**Expected Tooltip:**
```
E_F: 0.560 eV
n: 1.50 × 10^10 cm⁻³
log₁₀(n) = 10.18
p: 2.30 × 10^9 cm⁻³
log₁₀(p) = 9.36
```

**Check:**
- [ ] E_F shown once at top (bold)
- [ ] Both n and p shown
- [ ] log₁₀ values for both
- [ ] No duplication of E_F

#### D. Tooltip Content Quality
**Check:**
- [ ] E_F line is bold (visual emphasis)
- [ ] Concentration values use proper notation
- [ ] log₁₀ values are slightly greyed out (visual hierarchy)
- [ ] No raw "log10" text (should be "log₁₀" with subscript)

---

### Test 5: Responsive Layout (2 min)

#### A. Right Panel Scrolling
**Action:** 
1. Resize window to make it shorter
2. Scroll right panel

**Check:**
- [ ] Right panel scrolls smoothly
- [ ] No content cut off
- [ ] Scroll indicator visible when needed

#### B. Parameters Collapse
**Action:** Click "Parameters" section header

**Expected:**
- Section collapses (hides sliders and controls)
- Click again to expand

**Check:**
- [ ] Collapse animation smooth
- [ ] Chart area remains visible
- [ ] No layout shift or jump

#### C. Key Observations Scroll
**Action:** 
1. Add more observations (if possible)
2. Or verify fixed 300px height

**Check:**
- [ ] Key Observations section has fixed height (300px)
- [ ] Internal scrolling works if content overflows
- [ ] No layout overflow

#### D. Zoom Test
**Action:** 
1. Set browser zoom to 100%
2. Set browser zoom to 150%
3. Set browser zoom to 75%

**Check:**
- [ ] No overflow warnings at any zoom level
- [ ] Content readable at all zoom levels
- [ ] Right panel always scrollable
- [ ] No horizontal scroll bars

---

### Test 6: Integration & Edge Cases (3 min)

#### A. Parameter Changes
**Action:** Adjust sliders (T, E_g, E_F, m_n*, m_p*)

**Check:**
- [ ] Result chips update immediately
- [ ] Chart rebuilds correctly
- [ ] Tooltip shows updated values
- [ ] No lag or stutter

#### B. Toggle Combinations
**Action:** Try different toggle combinations:
- cm⁻³ + n only
- m⁻³ + p only
- cm⁻³ + both
- Auto-scale Y on/off

**Check:**
- [ ] All combinations work
- [ ] No errors or crashes
- [ ] Chart updates correctly

#### C. Show/Hide Features
**Action:** Toggle switches:
- Show E_v / E_c markers
- Show n_i(T) reference
- Show intrinsic point
- Auto-scale Y

**Check:**
- [ ] Chart updates immediately
- [ ] No visual glitches
- [ ] Tooltip adapts (if applicable)

#### D. Reset to Silicon
**Action:** 
1. Change several parameters
2. Click "Reset to Silicon" button

**Expected:**
- T = 300 K
- E_g = 1.12 eV
- m_n* = 1.08
- m_p* = 0.56
- E_F = 0.56 eV (E_g/2)
- Units: cm⁻³
- Mode: both

**Check:**
- [ ] All parameters reset correctly
- [ ] Chart resets to Silicon defaults
- [ ] No errors

---

## Regression Testing

### Verify No Breaking Changes

#### A. Other Graph Pages
**Action:** Check that other graph pages still work

**Pages to test:**
- Fermi-Dirac Distribution
- Density of States
- Intrinsic Carrier vs T
- PN Junction graphs

**Check:**
- [ ] All pages load correctly
- [ ] No LaTeX rendering issues
- [ ] No layout issues

#### B. Formula Workspace
**Action:** Go to Workspace, solve a formula

**Check:**
- [ ] Formulas solve correctly
- [ ] Steps display properly
- [ ] No errors

#### C. Settings & Constants
**Action:** Open Settings and Constants/Units pages

**Check:**
- [ ] Pages load correctly
- [ ] Theme toggle works
- [ ] Constants display properly

---

## Performance Testing

### A. Initial Load Time
**Action:** Navigate to page from menu

**Expected:** < 1 second

**Check:**
- [ ] Page loads quickly
- [ ] No visible lag
- [ ] Smooth animation

### B. Chart Interaction
**Action:** Hover over chart, drag sliders

**Expected:** Smooth, no stuttering

**Check:**
- [ ] Tooltip appears immediately
- [ ] Slider updates are smooth
- [ ] Chart rebuilds quickly (< 100ms)

### C. Memory Usage
**Action:** 
1. Interact with page for 2-3 minutes
2. Switch between modes multiple times
3. Adjust sliders repeatedly

**Check:**
- [ ] No memory leaks
- [ ] No performance degradation
- [ ] No browser warnings

---

## Acceptance Criteria

### Critical (Must Pass)
- [ ] No "Step contains unsupported formatting" error
- [ ] All math symbols render with subscripts
- [ ] Scientific notation is correct everywhere
- [ ] Tooltip shows E_F once and is mode-aware
- [ ] Right panel scrolls without overflow
- [ ] Segmented control works for all modes

### Important (Should Pass)
- [ ] LaTeX rendering is consistent
- [ ] Numeric formatting is teaching-friendly
- [ ] Log₁₀ values appear in tooltip
- [ ] Parameters section is collapsible
- [ ] No layout issues at different zoom levels

### Nice-to-Have (Ideal)
- [ ] Smooth animations
- [ ] Professional appearance
- [ ] Intuitive UX
- [ ] Clear visual hierarchy

---

## Bug Reporting Template

If you find issues, please report with this format:

```markdown
### Issue: [Brief description]

**Location:** [Where in the UI]

**Steps to Reproduce:**
1. [First step]
2. [Second step]
3. [Third step]

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happened]

**Severity:** [Critical / High / Medium / Low]

**Screenshot:** [If applicable]

**Browser/Platform:** [Chrome, Firefox, etc. + version]
```

---

## Success Metrics

### Must Achieve (100%)
- ✅ All critical criteria pass
- ✅ No console errors
- ✅ No layout overflow
- ✅ No visual regressions

### Target (95%+)
- ✅ All important criteria pass
- ✅ Smooth performance
- ✅ Professional appearance

### Stretch Goal (90%+)
- ✅ All nice-to-have criteria pass
- ✅ User feedback is positive

---

## Sign-Off

**Tester:** ___________________  
**Date:** ___________________  
**Result:** ☐ PASS ☐ FAIL ☐ CONDITIONAL  

**Notes:**
```
[Space for tester notes, observations, or issues found]
```

---

**Happy Testing!** 🎉

If you find any issues, refer to `CARRIER_CONCENTRATION_FERMI_LEVEL_FIXES.md` for implementation details.
