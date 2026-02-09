# Direct vs Indirect Bandgap - Comprehensive Test Plan

**Date:** 2026-02-09  
**Features:** 5 major upgrades  
**Status:** Ready for Testing

---

## Quick Test (5 minutes)

### 1. Open Page (10 sec)
- Navigate: **Graphs** → **Direct vs Indirect Bandgap**
- ✅ Page loads without errors

### 2. Responsive Layout (30 sec)
- Resize window to very narrow (< 750px)
- ✅ No crash, layout stacks vertically
- ✅ Chart appears first, controls below
- ✅ Everything scrollable

### 3. Band-Edge Readout (20 sec)
- Find "Band-edge readout" card (right panel)
- ✅ Shows Ec, Ev, Eg values
- ✅ No overlapping labels on plot

### 4. Zoom & Pan (1 min)
- Find zoom controls (top-right of chart)
- Click **[+] Zoom In** → chart zooms
- Click **[-] Zoom Out** → chart zooms out
- Try **Ctrl+Scroll** on desktop
- When zoomed, drag chart to pan
- Click **[⊡] Reset/Fit** → view restores
- ✅ All zoom/pan features work

### 5. Animation (2 min)
- Open "Animation" panel (expand if collapsed)
- Select "k0" parameter
- Click **Play** → watch CBM shift
- ✅ Smooth animation, progress bar fills
- Try **Pause**, **Restart**, **Loop** toggle
- Change **Speed** slider
- Try other parameters (Eg, mn*, mp*)

### 6. Dynamic Observations (1 min)
- Open "Dynamic Observations" panel
- Read current observations
- Switch Direct ↔ Indirect
- ✅ Observations change
- Drag k0 slider
- ✅ See "You changed k0: CBM shifted by Δk = X"
- Tap on curve
- ✅ See selected point analysis

---

## Detailed Testing

## Feature 1: Responsive Layout Guards

### Test 1A: Wide Layout (>= 1100px)
**Setup:** Window width >= 1100px

**Expected Layout:**
```
┌────────────────┬─────────────┐
│                │ Gap Readout │
│                │ Band-Edge   │
│   Chart (2/3)  │ Inspector   │
│                │ Animation   │
│                │ Observations│
│                │ Parameters  │
└────────────────┴─────────────┘
```

**Check:**
- [ ] Chart on left (2/3 width)
- [ ] Controls on right (1/3 width)
- [ ] Right panel scrollable
- [ ] No overflow warnings

### Test 1B: Medium Layout (750-1099px)
**Setup:** Window width 750-1099px

**Expected:**
- Same as wide, but tighter spacing
- Right panel definitely scrollable

**Check:**
- [ ] Layout similar to wide
- [ ] Right panel scrolls
- [ ] No content cut off

### Test 1C: Narrow Layout (< 750px)
**Setup:** Window width < 750px

**Expected Layout:**
```
┌─────────────────────┐
│ Chart (300-400px)   │
├─────────────────────┤
│ Gap Readout         │
│ Band-Edge           │
│ Inspector           │
│ Animation           │
│ Observations        │
│ Parameters          │
│ (scrollable)        │
└─────────────────────┘
```

**Check:**
- [ ] Chart appears first (constrained height)
- [ ] All controls below
- [ ] Entire page scrollable
- [ ] No crash
- [ ] No "Invalid argument" error
- [ ] No RenderFlex overflow

### Test 1D: Extreme Narrow (< 400px)
**Setup:** Window width < 400px (mobile)

**Check:**
- [ ] No crash
- [ ] Chart still visible (minimum 300px height)
- [ ] Controls stacked and scrollable
- [ ] Text readable (no truncation)

---

## Feature 2: Band-Edge Readout Card

### Test 2A: Readout Card Presence
**Location:** Right panel, second card

**Expected Content:**
```
Band-edge readout
Ec        +0.710 eV
Ev        -0.710 eV
Eg (Ec-Ev)  1.420 eV
```

**Check:**
- [ ] Card visible and readable
- [ ] All three rows present
- [ ] Values have correct sign (+/-)
- [ ] Values formatted with 3 decimal places

### Test 2B: Energy Reference Changes
**Action:** Change energy reference dropdown
- Midgap = 0
- Ev = 0
- Ec = 0

**Expected:**
- Midgap: Ec = +X, Ev = -X (symmetric)
- Ev = 0: Ec = +Eg, Ev = 0
- Ec = 0: Ec = 0, Ev = -Eg

**Check:**
- [ ] Readout updates correctly
- [ ] Chart reference shifts (midgap/edges)
- [ ] Eg always equals Ec - Ev

### Test 2C: Plot Label Removal
**Action:** Enable "Band edges" toggle

**Expected:**
- Dashed horizontal lines for Ec and Ev (no numeric labels)
- All numeric values in readout card only

**Check:**
- [ ] No cramped labels on plot
- [ ] Dashed lines visible
- [ ] Plot is clean and uncluttered

---

## Feature 3: Zoom + Pan + Ctrl+Scroll

### Test 3A: Zoom Buttons
**Location:** Top-right overlay on chart

**Actions:**
1. Click [+] Zoom In button 3 times
2. Verify zoom scale increases
3. Click [-] Zoom Out button 2 times
4. Verify zoom scale decreases
5. Click [⊡] Reset/Fit button
6. Verify zoom resets to 1.0×

**Check:**
- [ ] Zoom In increases scale (max 5.0×)
- [ ] Zoom Out decreases scale (min 0.5×)
- [ ] Reset/Fit restores to 1.0×
- [ ] Chart updates immediately
- [ ] Tick intervals adjust with zoom

### Test 3B: Ctrl+Scroll Zoom (Desktop)
**Setup:** Desktop/web browser

**Actions:**
1. Hold Ctrl key
2. Scroll mouse wheel up (away from you)
3. Verify chart zooms in
4. Scroll mouse wheel down (toward you)
5. Verify chart zooms out

**Check:**
- [ ] Ctrl+Scroll zoom works
- [ ] Zoom increments by ~0.1 per scroll step
- [ ] Zoom clamped to 0.5× - 5.0× range
- [ ] Chart updates smoothly

### Test 3C: Pan (When Zoomed)
**Setup:** Zoom to 2.0× or higher

**Actions:**
1. Click and drag on chart
2. Verify view shifts
3. Drag horizontally → X-axis shifts
4. Drag vertically → Y-axis shifts

**Check:**
- [ ] Pan only works when zoom > 1.0×
- [ ] Pan disabled when zoom = 1.0×
- [ ] Smooth dragging (no lag)
- [ ] Can pan in all directions

### Test 3D: Point Inspector with Zoom
**Setup:** Zoom to 2.0×, pan to a region

**Actions:**
1. Tap on conduction or valence curve
2. Verify point selected
3. Check Point Inspector card
4. Verify k and E values correct

**Check:**
- [ ] Point selection works when zoomed
- [ ] Inspector shows correct values
- [ ] Selected point visible on chart

---

## Feature 4: Animation Panel

### Test 4A: Animation Controls
**Location:** "Animation" expansion panel (right panel)

**Expected UI:**
- Dropdown: Animate parameter (k0, Eg, mn*, mp*)
- Slider: Speed (0.25× to 4.0×)
- Buttons: Play/Pause, Restart
- Checkboxes: Loop, Hold selected k
- Progress bar (when animating)

**Check:**
- [ ] All controls visible
- [ ] Dropdown has 4 options
- [ ] Speed slider works
- [ ] Checkboxes toggle

### Test 4B: Animate k0
**Setup:** 
- Select "Indirect" gap type
- Animation parameter: k0
- Speed: 1.0×
- Loop: OFF

**Actions:**
1. Click Play
2. Watch CBM marker shift from k=0 to k=1.2 ×10¹⁰ m⁻¹
3. Watch gap readout update
4. Wait for completion (should stop at 100%)

**Check:**
- [ ] CBM shifts smoothly (60 FPS)
- [ ] Gap readout updates live
- [ ] Band-edge readout updates live
- [ ] Dynamic observations update
- [ ] Progress bar fills 0% → 100%
- [ ] Animation stops at 100% (no loop)

### Test 4C: Animate Eg
**Setup:**
- Animation parameter: Eg
- Speed: 2.0×
- Loop: ON

**Actions:**
1. Click Play
2. Watch bandgap change from 0.5 → 2.0 eV
3. Verify both bands shift vertically
4. Wait for first cycle to complete
5. Verify animation restarts (loop mode)

**Check:**
- [ ] Eg animates smoothly
- [ ] Both bands shift together
- [ ] Gap readout shows changing Eg values
- [ ] Animation loops continuously
- [ ] Speed 2.0× is faster (~1.25 seconds)

### Test 4D: Animate mn* and mp*
**Setup:**
- Animation parameter: mn* or mp*
- Speed: 1.0×
- Loop: OFF

**Actions:**
1. Animate mn*
2. Verify conduction band curvature changes
3. Smaller mn* → steeper curve
4. Animate mp*
5. Verify valence band curvature changes

**Check:**
- [ ] mn* animation changes conduction curvature
- [ ] mp* animation changes valence curvature
- [ ] Curvature observation updates with numeric ΔE
- [ ] Smooth 60 FPS animation

### Test 4E: Animation Controls
**Actions:**
1. Play → Pause mid-animation
2. Verify animation freezes
3. Play again → resumes
4. Click Restart → resets to 0%
5. Enable Loop → verify continuous playback
6. Change speed during animation → verify speed changes

**Check:**
- [ ] Pause works
- [ ] Resume works
- [ ] Restart works
- [ ] Loop works
- [ ] Speed changes apply immediately

### Test 4F: Hold Selected K Option
**Setup:**
- Select a point on curve
- Enable "Hold selected k" checkbox
- Start animation (k0 or Eg)

**Expected:**
- Selected point stays at same k value
- E value updates as band structure changes

**Check:**
- [ ] Selected k stays constant
- [ ] Selected E updates during animation
- [ ] Inspector shows live updates

---

## Feature 5: Dynamic Observations

### Test 5A: Gap Type Observations
**Action:** Switch between Direct and Indirect

**Expected Observations:**

**Direct:**
```
• Direct gap: CBM and VBM at k≈0 → vertical photon transition. Eg_dir = 1.420 eV.
• Curvature: At k=0.60 ×10¹⁰ m⁻¹, ΔEc=0.045 eV, ΔEv=0.018 eV.
```

**Indirect:**
```
• Indirect gap: CBM at k0 = 0.850 ×10¹⁰ m⁻¹ → phonon needed. Eg_ind = 1.120 eV.
• CBM shift: Δk = 0.850 ×10¹⁰ m⁻¹ from Γ. Larger k0 makes gap more indirect.
• Curvature: At k=0.60 ×10¹⁰ m⁻¹, ΔEc=0.023 eV, ΔEv=0.012 eV.
```

**Check:**
- [ ] Observations switch based on gap type
- [ ] Numeric values shown
- [ ] Explains physics clearly

### Test 5B: Parameter Change Detection
**Action:** Drag k0 slider from 0.0 to 0.5

**Expected:**
```
• You changed k0: CBM shifted by Δk = 0.500 ×10¹⁰ m⁻¹.
```

**Check:**
- [ ] Change detected (dK0 > 0.05)
- [ ] Observation appears
- [ ] Δk value correct

**Action:** Drag mn* slider from 1.08 to 0.30

**Expected:**
```
• Curvature changed: Smaller m* → steeper parabola (energy grows faster with k).
```

**Check:**
- [ ] Change detected (dm* > 0.01)
- [ ] Observation appears
- [ ] Explains curvature effect

### Test 5C: Selected Point Observations
**Action:** Tap on valence band at k ≈ 0.4 ×10¹⁰ m⁻¹

**Expected:**
```
• Selected: k=0.423 ×10¹⁰ m⁻¹, E=-0.812 eV. Nearest: VBM (k≈0), ΔE=0.234 eV.
```

**Check:**
- [ ] Observation appears
- [ ] Shows k, E values
- [ ] Identifies nearest edge (VBM or CBM)
- [ ] Shows ΔE (distance from edge)

**Action:** Tap on conduction band near CBM

**Expected:**
```
• Selected: k=0.850 ×10¹⁰ m⁻¹, E=0.712 eV. Nearest: CBM (k≈0.85 ×10¹⁰ m⁻¹), ΔE=0.002 eV.
```

**Check:**
- [ ] Identifies CBM as nearest edge
- [ ] Shows CBM k position
- [ ] ΔE is small (near edge)

### Test 5D: Observations During Animation
**Setup:**
- Start animation (k0 parameter)
- Observe observations panel

**Expected:**
- Observations update live as k0 changes
- No flicker or layout shift
- Observation count stays <= 6

**Check:**
- [ ] Observations update smoothly
- [ ] No performance issues
- [ ] Max bullets enforced
- [ ] Teaching insights remain clear

### Test 5E: Bullet Count Cap
**Action:** 
- Switch to Indirect
- Enable all features
- Select a point
- Drag multiple parameters

**Expected:**
- Maximum 6 bullets shown
- Most recent/relevant observations prioritized

**Check:**
- [ ] Never more than 6 bullets
- [ ] No vertical overflow
- [ ] Relevant observations shown

---

## Integration Testing

### Test 6: Zoom + Animation
**Action:**
- Zoom to 2.0×
- Start animation (k0)
- Watch animation in zoomed view

**Check:**
- [ ] Animation works when zoomed
- [ ] CBM marker visible and animates
- [ ] Pan position stable during animation
- [ ] No visual glitches

### Test 7: Zoom + Point Selection
**Action:**
- Zoom to 3.0×
- Pan to a region
- Tap on curve

**Check:**
- [ ] Point selection works
- [ ] Inspector shows correct values
- [ ] Observation mentions selected point

### Test 8: Animation + Point Selection
**Action:**
- Select a point on curve
- Enable "Hold selected k" checkbox
- Start animation (Eg)

**Expected:**
- Selected k stays constant
- Selected E updates as bands shift
- Inspector shows live E updates

**Check:**
- [ ] Selected k constant
- [ ] Selected E updates
- [ ] Inspector updates live
- [ ] Observation updates

### Test 9: Reset Demo During Animation
**Action:**
- Start animation
- Click "Reset Demo" button mid-animation

**Check:**
- [ ] Animation stops immediately
- [ ] Timer cleaned up
- [ ] All parameters reset
- [ ] No orphaned timers
- [ ] No memory leaks

---

## Edge Cases & Error Handling

### Test 10: Extreme Window Sizes

#### A. Very Wide (> 2000px)
**Check:**
- [ ] Layout works
- [ ] Chart expands appropriately
- [ ] No stretched/distorted appearance

#### B. Very Narrow (< 350px)
**Check:**
- [ ] No crash
- [ ] Stacked layout works
- [ ] Chart minimum height respected (300px)
- [ ] Content readable

#### C. Very Short (< 400px height)
**Check:**
- [ ] Scrolling works
- [ ] Chart visible
- [ ] Controls accessible via scroll

### Test 11: Zoom Edge Cases

#### A. Max Zoom (5.0×)
**Actions:**
- Zoom to 5.0×
- Verify can't zoom further
- Pan to edges
- Verify bounded

**Check:**
- [ ] Zoom stops at 5.0×
- [ ] Pan bounded appropriately
- [ ] No visual artifacts

#### B. Min Zoom (0.5×)
**Actions:**
- Zoom out to 0.5×
- Verify can't zoom further

**Check:**
- [ ] Zoom stops at 0.5×
- [ ] Full view visible

#### C. Rapid Zoom Changes
**Actions:**
- Click Zoom In rapidly 10 times
- Click Zoom Out rapidly 10 times
- Ctrl+Scroll rapidly

**Check:**
- [ ] No lag or freeze
- [ ] No visual glitches
- [ ] State remains consistent

### Test 12: Animation Edge Cases

#### A. Very Fast Speed (4.0×)
**Actions:**
- Set speed to 4.0×
- Play animation

**Check:**
- [ ] Animation completes in ~625ms
- [ ] Still smooth (60 FPS)
- [ ] No frame drops

#### B. Very Slow Speed (0.25×)
**Actions:**
- Set speed to 0.25×
- Play animation

**Check:**
- [ ] Animation takes ~10 seconds
- [ ] Still smooth
- [ ] Can pause mid-animation

#### C. Loop Mode Stability
**Actions:**
- Enable Loop
- Let animation run for 5-10 cycles
- Monitor performance

**Check:**
- [ ] No performance degradation
- [ ] No memory leaks
- [ ] Smooth across all cycles

#### D. Parameter Changes During Animation
**Actions:**
- Start animation (k0)
- Manually drag Eg slider mid-animation

**Expected:**
- Animation continues with new Eg
- Chart updates correctly

**Check:**
- [ ] No conflict between animation and manual changes
- [ ] Chart remains stable

### Test 13: Observations Edge Cases

#### A. Rapid Parameter Changes
**Actions:**
- Drag k0 slider rapidly back and forth

**Check:**
- [ ] Observations update
- [ ] No excessive re-renders
- [ ] No flicker
- [ ] Change detection works

#### B. All Parameters Changed
**Actions:**
- Change Eg, mn*, mp*, k0 in sequence

**Check:**
- [ ] All changes detected
- [ ] Observations update appropriately
- [ ] Max 6 bullets enforced
- [ ] Most recent changes prioritized

#### C. No Selected Point
**Actions:**
- Clear selected point
- Verify observations don't include selected-point bullet

**Check:**
- [ ] No "Selected:" bullet when none selected
- [ ] Other observations still present

---

## Performance Testing

### Test 14: Frame Rate
**Setup:** Chrome DevTools Performance tab

**Actions:**
1. Record performance
2. Play animation
3. Stop recording
4. Check frame rate

**Expected:**
- Animation: ~60 FPS
- No dropped frames
- Smooth CPU usage

**Check:**
- [ ] Frame rate stable at 60 FPS
- [ ] No jank or stutter
- [ ] CPU usage reasonable

### Test 15: Memory Usage
**Actions:**
1. Note initial memory usage
2. Run animations for 5 minutes
3. Zoom/pan extensively
4. Check memory usage

**Check:**
- [ ] No memory leaks
- [ ] Memory stays stable
- [ ] No runaway growth

---

## Regression Testing

### Test 16: Existing Features Still Work

#### A. Gap Type Switch
**Check:**
- [ ] Direct ↔ Indirect switch works
- [ ] Chart updates correctly
- [ ] k0 slider disabled in Direct mode

#### B. Presets
**Check:**
- [ ] GaAs preset loads correctly
- [ ] Si preset loads correctly
- [ ] Custom mode works

#### C. Parameter Sliders
**Check:**
- [ ] All sliders responsive
- [ ] Values update correctly
- [ ] Chart rebuilds on changes

#### D. Toggles
**Check:**
- [ ] Transitions toggle works
- [ ] Band edges toggle works
- [ ] Energy reference works

#### E. Point Inspector (Basic)
**Check:**
- [ ] Tap to select works
- [ ] Clear button works
- [ ] Inspector shows band, k, E

---

## Accessibility Testing

### Test 17: Keyboard Navigation
**Actions:**
- Tab through controls
- Verify all controls focusable
- Try Space/Enter to activate

**Check:**
- [ ] All buttons keyboard accessible
- [ ] Sliders keyboard adjustable
- [ ] Dropdowns keyboard operable

### Test 18: Screen Reader (Optional)
**Actions:**
- Enable screen reader
- Navigate page

**Check:**
- [ ] Labels announced
- [ ] Values announced
- [ ] Interactive elements identified

---

## Browser Compatibility (Web)

### Test 19: Chrome
**Check:**
- [ ] All features work
- [ ] Ctrl+Scroll zoom works
- [ ] Pan works
- [ ] Animation smooth

### Test 20: Firefox
**Check:**
- [ ] All features work
- [ ] Ctrl+Scroll zoom works
- [ ] Pan works
- [ ] Animation smooth

### Test 21: Safari (if available)
**Check:**
- [ ] All features work
- [ ] Cmd+Scroll zoom works (Mac)
- [ ] Pan works
- [ ] Animation smooth

---

## Acceptance Criteria Summary

### Critical (Must Pass)
- [ ] No crash on narrow windows
- [ ] Band-edge readout card works
- [ ] Zoom buttons work
- [ ] Animation plays smoothly
- [ ] Observations update dynamically

### Important (Should Pass)
- [ ] Ctrl+Scroll zoom works (desktop)
- [ ] Pan works when zoomed
- [ ] Animation loop mode works
- [ ] Parameter change detection works
- [ ] Selected point observations work

### Nice-to-Have (Ideal)
- [ ] 60 FPS animation
- [ ] Smooth zoom/pan
- [ ] No memory leaks
- [ ] Professional appearance
- [ ] Clear teaching insights

---

## Bug Reporting Template

```markdown
### Issue: [Brief description]

**Feature:** [1-Responsive / 2-Readout / 3-Zoom / 4-Animation / 5-Observations]

**Severity:** [Critical / High / Medium / Low]

**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected:**
[What should happen]

**Actual:**
[What actually happened]

**Screenshot:** [If applicable]

**Platform:** [Windows/Mac/Linux + Browser]
**Window size:** [Width × Height]
**Zoom level:** [If relevant]
```

---

## Sign-Off

**Tester:** ___________________  
**Date:** ___________________  
**Test Duration:** ___ minutes  
**Result:** ☐ PASS ☐ FAIL ☐ CONDITIONAL

**Summary:**
```
Features tested: __ / 5
Tests run: __ / 21
Issues found: __
Severity: [Critical: __ / High: __ / Medium: __ / Low: __]
```

**Notes:**
```
[Space for observations, feedback, or suggestions]
```

---

## Final Checklist

### All 5 Features
- [ ] Feature 1: Responsive layout guards (3 tests)
- [ ] Feature 2: Band-edge readout card (3 tests)
- [ ] Feature 3: Zoom + pan + Ctrl+Scroll (4 tests)
- [ ] Feature 4: Animation panel (6 tests)
- [ ] Feature 5: Dynamic observations (5 tests)

### Integration
- [ ] Integration tests (4 tests)
- [ ] Edge cases (13 tests)
- [ ] Performance (2 tests)
- [ ] Regression (6 tests)
- [ ] Accessibility (2 tests)
- [ ] Browser compat (3 tests)

### Quality
- [ ] No console errors
- [ ] No layout warnings
- [ ] No memory leaks
- [ ] Professional appearance
- [ ] Smooth performance

---

**Total Tests:** 21 test scenarios  
**Estimated Time:** 30-45 minutes (full test suite)  
**Quick Test:** 5 minutes (basic verification)

---

**Ready for testing!** 🎉

For implementation details, see `DIRECT_INDIRECT_BANDGAP_COMPLETE_UPGRADE.md`
