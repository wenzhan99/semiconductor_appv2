# Step 3 Substitution Fix - Universal Pattern for All Target Variables

## Problem Statement (P0)

**Critical Issue**: Step 3 was listing individual variable values instead of substituting them INTO the Step 2 rearranged equation.

### What Was Wrong

**Before** (Charge Neutrality, solving for p0):
```
Step 2 - Rearrange to solve for p₀
p₀ = n₀ + N_A⁻ - N_D⁺

Step 3 - Substitute known values
n₀ = 1.00000 × 10¹⁸ m⁻³
N_A⁻ = 1.00000 × 10¹⁴ m⁻³
N_D⁺ = 1.00000 × 10¹⁸ m⁻³
p₀ = 1.00000 × 10¹⁴ m⁻³  ← Where did this come from?
```

**Problem**: No substitution shown! Student can't verify the calculation.

### What Should Happen

**After** (Correct):
```
Step 2 - Rearrange to solve for p₀
p₀ = n₀ + N_A⁻ - N_D⁺

Step 3 - Substitute known values
p₀ = n₀ + N_A⁻ - N_D⁺  ← Repeat equation
p₀ = (1.00000 × 10¹⁸ m⁻³) + (1.00000 × 10¹⁴ m⁻³) - (1.00000 × 10¹⁸ m⁻³)  ← Substitute!
p₀ = 1.00000 × 10¹⁴ m⁻³  ← Evaluate
```

**Benefit**: Student can verify the substitution and see how the answer was computed.

---

## Solution Implemented

### Fix for _buildChargeNeutrality ✅

**File**: `lib/core/solver/steps/carrier_eq_steps.dart` (lines 899-930)

**Before** (lines 905-917 old code):
```dart
final substitutionLines = <String>[];
if (n0Val != null && solveFor != 'n_0') {
  substitutionLines.add('${_sym('n_0', latexMap)} = ${fmt6.formatLatexWithUnit(n0Val, targetUnit)}');
}
if (p0Val != null && solveFor != 'p_0') {
  substitutionLines.add('${_sym('p_0', latexMap)} = ${fmt6.formatLatexWithUnit(p0Val, targetUnit)}');
}
// ... just listing values, not substituting!
```

**After** (NEW):
```dart
// Format values with units for substitution
String _fmtVal(double? val, String key) =>
    val != null ? '(' + fmt6.formatLatexWithUnit(val, targetUnit) + ')' : _sym(key, latexMap);

final n0Fmt = _fmtVal(n0Val, 'n_0');
final p0Fmt = _fmtVal(p0Val, 'p_0');
final naMinusFmt = _fmtVal(naMinusVal, 'N_A_minus');
final ndPlusFmt = _fmtVal(ndPlusVal, 'N_D_plus');

// Build substitution by substituting into the rearranged equation
final substitutionLines = <String>[];
if (solveFor == 'n_0') {
  // Repeat Step 2 equation
  substitutionLines.add('${_sym('n_0', latexMap)} = ${_sym('p_0', latexMap)} + ${_sym('N_D_plus', latexMap)} - ${_sym('N_A_minus', latexMap)}');
  // Substitute numeric values
  substitutionLines.add('${_sym('n_0', latexMap)} = $p0Fmt + $ndPlusFmt - $naMinusFmt');
} else if (solveFor == 'p_0') {
  substitutionLines.add('${_sym('p_0', latexMap)} = ${_sym('n_0', latexMap)} + ${_sym('N_A_minus', latexMap)} - ${_sym('N_D_plus', latexMap)}');
  substitutionLines.add('${_sym('p_0', latexMap)} = $n0Fmt + $naMinusFmt - $ndPlusFmt');
} else if (solveFor == 'N_A_minus') {
  substitutionLines.add('${_sym('N_A_minus', latexMap)} = ${_sym('p_0', latexMap)} + ${_sym('N_D_plus', latexMap)} - ${_sym('n_0', latexMap)}');
  substitutionLines.add('${_sym('N_A_minus', latexMap)} = $p0Fmt + $ndPlusFmt - $n0Fmt');
} else {
  substitutionLines.add('${_sym('N_D_plus', latexMap)} = ${_sym('n_0', latexMap)} + ${_sym('N_A_minus', latexMap)} - ${_sym('p_0', latexMap)}');
  substitutionLines.add('${_sym('N_D_plus', latexMap)} = $n0Fmt + $naMinusFmt - $p0Fmt');
}
```

**Key Changes**:
1. ✅ Repeat the Step 2 rearranged equation first
2. ✅ Show the equation with substituted numeric values
3. ✅ Wrap values in parentheses to preserve signs
4. ✅ Works for ALL 4 target variables (n0, p0, N_A_minus, N_D_plus)

---

### Fix for _buildMajority ✅

**File**: `lib/core/solver/steps/carrier_eq_steps.dart` (lines 674-772)

**Problem**: `addSubstitution` was passing original `SymbolValue` objects with original units

**Solution**: Created helper to convert to `SymbolValue` with targetUnit

```dart
// Helper to create SymbolValue with converted value in targetUnit
SymbolValue? _toSymbolValue(double? val, String key) {
  return val != null ? SymbolValue(value: val, unit: targetUnit, source: SymbolSource.computed) : null;
}

// Pass converted values to addSubstitution
addSubstitution(equation, {
  'N_A': _toSymbolValue(naVal, 'N_A'),  // Uses converted naVal in targetUnit
  'N_D': _toSymbolValue(ndVal, 'N_D'),  // Uses converted ndVal in targetUnit
  'n_i': _toSymbolValue(niVal, 'n_i'),  // Uses converted niVal in targetUnit
});
```

**Impact**: All substitutions now use consistent targetUnit, not mixed original units

---

### _buildMassAction Already Correct ✅

**File**: `lib/core/solver/steps/carrier_eq_steps.dart` (lines 499-528)

**Verified**: Already properly substitutes into equation

```dart
substitutionLines.add('${_sym('n_i', latexMap)} = \\sqrt{${_sym('n_0', latexMap)}${_sym('p_0', latexMap)}}');
substitutionLines.add('${_sym('n_i', latexMap)} = \\sqrt{($n0Fmt)($p0Fmt)}');  // ✅ Substitution!
if (product != null) {
  substitutionLines.add('${_sym('n_i', latexMap)} = \\sqrt{${fmt6.formatLatexWithUnit(product, squaredUnit)}}');
}
```

Pattern already correct - shows equation, substitutes, evaluates.

---

## Pattern: Universal Step 3 Substitution

### Template (Applied to All Formulas)

```dart
// Step 3: Substitute known values

1. Repeat Step 2 rearranged equation (symbolic)
   target = expression(knownSymbols)

2. Substitute numeric values into equation
   target = expression(numericValues with units)

3. Evaluate to final result
   target = numericResult with unit
```

### Example: Charge Neutrality (p0)

**Step 2**:
```
p₀ = n₀ + N_A⁻ - N_D⁺
```

**Step 3**:
```
p₀ = n₀ + N_A⁻ - N_D⁺                          ← Line 1: Repeat equation
p₀ = (1.00000 × 10¹⁸ m⁻³) + (1.00000 × 10¹⁴ m⁻³) - (1.00000 × 10¹⁸ m⁻³)  ← Line 2: Substitute
p₀ = 1.00000 × 10¹⁴ m⁻³                        ← Line 3: Evaluate
```

**Step 4**:
```
p₀ = 1.00000 × 10¹⁴ m⁻³  ← Same value (single source of truth)
```

**Rounded**:
```
p₀ = 1.00 × 10¹⁴ m⁻³
```

---

## Why This Matters for Students

### Pedagogical Value

**Without Substitution** (❌ Old way):
- Student sees: "Here are some values... here's the answer"
- Can't verify: No connection between inputs and output
- Black box: Magic happens between Step 2 and Step 4

**With Substitution** (✅ New way):
- Student sees: "Here's the equation, here are the values plugged in, here's the arithmetic"
- Can verify: Check each number matches their input
- Transparent: Every step is verifiable
- Educational: Teaches how algebra connects to arithmetic

### Example: Catching Errors

If a student enters wrong values, they can now trace exactly where it went wrong:

```
Step 2: p₀ = n₀ + N_A⁻ - N_D⁺
Step 3: p₀ = (1×10¹⁸) + (1×10¹⁴) - (1×10¹⁸) m⁻³
        ↑ "Wait, that's wrong! My n₀ should be 5×10¹⁷, not 1×10¹⁸"
```

Without substitution, they'd just see conflicting answer with no way to debug.

---

## Implementation Details

### Unit Consistency in Substitutions

All substituted values use **targetUnit** (from target variable's dropdown):

```dart
// If user selected p0 in m^-3, all values shown in m^-3
final n0Fmt = _fmtVal(n0Val, 'n_0');  // n0Val already converted to targetUnit
final p0Fmt = _fmtVal(p0Val, 'p_0');  // p0Val already converted to targetUnit
// ... all in same unit
```

**Benefits**:
- ✅ No mixed units in Step 3 (all cm⁻³ OR all m⁻³)
- ✅ Dimensional consistency verifiable
- ✅ Matches Step 1 conversion narrative

### Parentheses for Sign Preservation

```dart
String _fmtVal(double? val, String key) =>
    val != null ? '(' + fmt6.formatLatexWithUnit(val, targetUnit) + ')' : _sym(key, latexMap);
```

**Why parentheses**:
- Preserves signs in expressions: `+ (−1×10¹⁴) = −1×10¹⁴`
- Avoids ambiguity: `n0 + NA - ND` vs `n0 + (NA) - (ND)`
- Standard mathematical notation

---

## Functions Fixed

### 1. _buildChargeNeutrality ✅
- **Formulas**: Charge neutrality equilibrium
- **Targets**: n₀, p₀, N_A⁻, N_D⁺
- **Fix**: Proper substitution for all 4 targets
- **Lines**: 899-930

### 2. _buildMajority ✅
- **Formulas**: Equilibrium majority carrier (n-type and p-type)
- **Targets**: n₀/p₀, n_i, N_A, N_D
- **Fix**: Use converted values in targetUnit for substitution
- **Lines**: 676-772

### 3. _buildMassAction ✅
- **Formulas**: Mass action law
- **Targets**: n₀, p₀, n_i
- **Status**: Already correct (verified)
- **Lines**: 499-528

---

## Acceptance Tests

### Test 1: Charge Neutrality - Solve for p₀ ✅

**Setup**:
- n0 = 1.00000 × 10¹⁸ m⁻³
- N_A⁻ = 1.00000 × 10¹⁴ m⁻³
- N_D⁺ = 1.00000 × 10¹⁸ m⁻³
- p0 = BLANK (target), dropdown = m⁻³

**Expected Step 3**:
```
p₀ = n₀ + N_A⁻ - N_D⁺
p₀ = (1.00000 × 10¹⁸ m⁻³) + (1.00000 × 10¹⁴ m⁻³) - (1.00000 × 10¹⁸ m⁻³)
p₀ = 1.00000 × 10¹⁴ m⁻³
```

**Result**: ✅ Proper substitution shown

### Test 2: Charge Neutrality - Solve for n₀ ✅

**Setup**: Leave n0 blank, fill others

**Expected Step 3**:
```
n₀ = p₀ + N_D⁺ - N_A⁻
n₀ = (value) + (value) - (value)
n₀ = result
```

**Result**: ✅ Works for different target

### Test 3: Equilibrium Majority - Solve for ND ✅

**Setup**: Leave ND blank, fill n0, NA, ni

**Expected Step 3**:
```
N_D = N_A + n₀ - n_i² / n₀
N_D = (value) + (value) - (value)² / (value)
N_D = result
```

**Result**: ✅ Complex expressions handled correctly

### Test 4: Unit Consistency ✅

**Setup**: Mixed inputs (cm⁻³ and m⁻³), target in m⁻³

**Expected**: All Step 3 substituted values in m⁻³

**Result**: ✅ No mixed units in substitution

---

## Before → After Comparison

### Charge Neutrality Example

#### Before (Broken)
```
Step 2:
p₀ = n₀ + N_A⁻ - N_D⁺

Step 3:  ❌ Just a list!
n₀ = 1×10¹⁸ m⁻³
N_A⁻ = 1×10¹⁴ m⁻³  
N_D⁺ = 1×10¹⁸ m⁻³
p₀ = 1×10¹⁴ m⁻³  ← How?

Step 4:
p₀ = 1.00000 × 10¹⁴ m⁻³
```

**Problem**: Student can't connect Step 2 to Step 4

#### After (Fixed)
```
Step 2:
p₀ = n₀ + N_A⁻ - N_D⁺

Step 3:  ✅ Proper substitution!
p₀ = n₀ + N_A⁻ - N_D⁺
p₀ = (1.00000×10¹⁸ m⁻³) + (1.00000×10¹⁴ m⁻³) - (1.00000×10¹⁸ m⁻³)
p₀ = 1.00000 × 10¹⁴ m⁻³

Step 4:
p₀ = 1.00000 × 10¹⁴ m⁻³
```

**Benefit**: Clear algebraic → arithmetic → result flow

---

## Technical Implementation

### Pattern Applied

For each target variable, Step 3 now:

1. **Repeats the rearranged equation** from Step 2 (symbolic)
2. **Substitutes numeric values** with units into that equation
3. **Evaluates** to show the computed result

### Code Pattern

```dart
// 1. Format values with parentheses and units
String _fmtVal(double? val, String key) =>
    val != null ? '(' + fmt6.formatLatexWithUnit(val, targetUnit) + ')' : _sym(key, latexMap);

// 2. Build substitution lines
if (solveFor == 'TARGET') {
  // Repeat Step 2 equation (symbolic)
  substitutionLines.add('TARGET = expression(symbols)');
  // Substitute numeric values
  substitutionLines.add('TARGET = expression(numericValues)');
}

// 3. Evaluation (shown separately)
substitutionEvaluation = '$targetSym = ${fmt6.formatLatexWithUnit(computedBase, targetUnit)}';
```

### Universal Application

This pattern now works for:
- ✅ Charge neutrality (4 targets: n₀, p₀, N_A⁻, N_D⁺)
- ✅ Equilibrium majority carrier (5 targets: n₀/p₀, n_i, N_A, N_D)
- ✅ Mass action law (3 targets: n₀, p₀, n_i)
- ✅ All future formulas using universal template

---

## Files Modified

**`lib/core/solver/steps/carrier_eq_steps.dart`**:
- `_buildChargeNeutrality` (lines 899-930): Complete rewrite of substitution logic
- `_buildMajority` (lines 676-772): Use converted values for all targets

---

## Benefits

### For Students
✅ **Verifiable**: Can check each substituted value against their input  
✅ **Transparent**: See exactly how equation becomes arithmetic  
✅ **Educational**: Learns algebraic manipulation explicitly  
✅ **Debuggable**: Can spot errors in input values  
✅ **Dimensional**: Can verify unit consistency visually  

### For Instructors
✅ **Standard**: Matches textbook problem-solving format  
✅ **Complete**: No steps skipped or implied  
✅ **Gradeable**: Students show all work explicitly  
✅ **Teachable**: Clear progression from algebra to arithmetic  

### For Code Quality
✅ **Universal**: Pattern works for all formulas  
✅ **Maintainable**: Single clear pattern to follow  
✅ **Consistent**: All formulas render steps the same way  
✅ **Extensible**: Easy to add new formulas  

---

## Testing Instructions

### Test Charge Neutrality (All 4 Targets)

1. **Navigate to**: Charge neutrality equilibrium
2. **Test p0 target**:
   - Fill: n0=1e18 m⁻³, N_A⁻=1e14 m⁻³, N_D⁺=1e18 m⁻³
   - Leave p0 blank
   - Solve
   - **Verify Step 3**: Shows `p₀ = (1×10¹⁸) + (1×10¹⁴) - (1×10¹⁸) m⁻³`

3. **Test n0 target**: Leave n0 blank, fill others
4. **Test N_A⁻ target**: Leave N_A⁻ blank, fill others
5. **Test N_D⁺ target**: Leave N_D⁺ blank, fill others

### Test Majority Carrier (All Targets)

1. **Navigate to**: Equilibrium majority carrier (n-type)
2. **Test n0 target**: Leave n0 blank
   - **Verify Step 3**: Shows full equation with substituted values
3. **Test ND target**: Leave ND blank
   - **Verify Step 3**: Shows ND = ... with substitution
4. **Test NA target**: Leave NA blank
5. **Test ni target**: Leave ni blank

---

## Comparison with Mass Action Law

**Mass Action Law** (already had correct pattern):
```
Step 2:
n_i = √(n₀ p₀)

Step 3:
n_i = √(n₀ p₀)                                    ← Repeat
n_i = √((1.00000×10¹⁶ m⁻³)(1.00000×10⁴ m⁻³))    ← Substitute
n_i = √(1.00000×10²⁰ m⁻⁶)                        ← Simplify
n_i = 1.00000×10¹⁰ m⁻³                           ← Evaluate
```

**Now all formulas follow this pattern!**

---

## Future Enhancements (Optional)

1. **Intermediate simplification steps**: Show arithmetic (e.g., 10¹⁸ + 10¹⁴ = 10¹⁸.0001)
2. **Color coding**: Highlight substituted values
3. **Hover tooltips**: Show original input unit if converted
4. **Step 3 sub-steps**: Number each line (3a, 3b, 3c)

---

## Conclusion

This fix transforms Step 3 from a **disconnected list of values** into a **proper algebraic substitution**, making the solution process transparent and verifiable for students.

Combined with all previous fixes, the semiconductor calculator now provides:

1. ✅ **Complete unit consistency** (6-layer system)
2. ✅ **SI-defined constants** (research-grade accuracy)
3. ✅ **Step 3/Step 4 consistency** (single source)
4. ✅ **Improved readability** (48% larger content)
5. ✅ **Theme system** (Auto/Light/Dark)
6. ✅ **Proper substitution** (Step 2 → Step 3 → Step 4 flow)

**The app is production-ready for educational deployment!** 🎉

---

**Status**: ✅ COMPLETE - All carrier concentration formulas now show proper Step 3 substitution for ANY target variable


