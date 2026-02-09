# Step 2 & Step 3 Rearrangement Fix for Drift Current Density

## Problem Statement

When solving for **μ_n** (electron mobility) in the drift current density formula `J_{n,drift} = q n μ_n E`:

### Before Fix
- **Step 2** incorrectly showed: "No rearrangement required"
- **Step 3** still displayed the original equation `J = q n μ_n E` and jumped directly to `μ_n = 0.135`
- The algebraic manipulation to isolate μ_n was completely missing
- Users could not verify the calculation or understand how μ_n was derived

### Expected Behavior
- **Step 2** must show explicit rearrangement: `μ_n = J / (q n E)`
- **Step 3** must substitute values into the **rearranged form**, not the original equation

## Root Cause

**File**: `lib/core/solver/step_latex_builder.dart` (lines 2133-2135)

```dart
if (solveFor != jKey) {
  return null;  // ❌ Returns null when solving for anything except J!
}
```

The `_buildDriftCurrentDensitySteps` function only handled the case where `solveFor == J_n_drift`. When solving for μ_n, n, or E_field, it returned `null`, causing the system to fall back to a generic builder that:
1. Didn't know how to rearrange the equation properly
2. Used the original equation form in Step 3 instead of the isolated form

## Solution Implemented

### 1. Removed Early Return, Added Multi-Target Support

**File**: `lib/core/solver/step_latex_builder.dart` (lines 2120-2254)

Changed the condition to handle all valid targets:
```dart
// Only handle drift current density formula variables
if (solveFor != jKey && solveFor != muKey && solveFor != carrierKey && solveFor != eKey) {
  return null;
}
```

### 2. Implemented Rearrangement Logic for Each Target

#### Solving for J (current density) - No Rearrangement
```dart
if (solveFor == jKey) {
  rearrangeLines.add('$driftSym = $qSym\\,$carrierSym\\,$muSym\\,$eSym');
  
  substitutionLines.add('$driftSym = $symbolicRhs');
  substitutionLines.add('$driftSym = $substitutionRhs');
}
```

**Step 2**: `J_{n,drift} = q n μ_n E`  
**Step 3**: Substitute into `J = q n μ_n E`

#### Solving for μ (mobility) - **Main Fix**
```dart
else if (solveFor == muKey) {
  rearrangeLines.add('$driftSym = $qSym\\,$carrierSym\\,$muSym\\,$eSym');
  rearrangeLines.add('$muSym = \\dfrac{$driftSym}{$qSym\\,$carrierSym\\,$eSym}');
  
  substitutionLines.add('$muSym = \\dfrac{$driftSym}{$qSym\\,$carrierSym\\,$eSym}');
  substitutionLines.add('$muSym = \\dfrac{$numerator}{${denomParts.join('')}}');
}
```

**Step 2**:
1. `J_{n,drift} = q n μ_n E`
2. `μ_n = \dfrac{J_{n,drift}}{q n E}`

**Step 3**:
1. `μ_n = \dfrac{J_{n,drift}}{q n E}`
2. `μ_n = \dfrac{(2.16294 × 10^{4} A/m²)}{(1.60218 × 10^{-19} C)(1.00000 × 10^{21} m^{-3})(1.00000 × 10^{3} V/m)}`

#### Solving for n (carrier concentration)
```dart
else if (solveFor == carrierKey) {
  rearrangeLines.add('$driftSym = $qSym\\,$carrierSym\\,$muSym\\,$eSym');
  rearrangeLines.add('$carrierSym = \\dfrac{$driftSym}{$qSym\\,$muSym\\,$eSym}');
  
  substitutionLines.add('$carrierSym = \\dfrac{$driftSym}{$qSym\\,$muSym\\,$eSym}');
  substitutionLines.add('$carrierSym = \\dfrac{$numerator}{${denomParts.join('')}}');
}
```

**Step 2**: `n = \dfrac{J_{n,drift}}{q μ_n E}`  
**Step 3**: Substitute into rearranged form

#### Solving for E (electric field)
```dart
else if (solveFor == eKey) {
  rearrangeLines.add('$driftSym = $qSym\\,$carrierSym\\,$muSym\\,$eSym');
  rearrangeLines.add('$eSym = \\dfrac{$driftSym}{$qSym\\,$carrierSym\\,$muSym}');
  
  substitutionLines.add('$eSym = \\dfrac{$driftSym}{$qSym\\,$carrierSym\\,$muSym}');
  substitutionLines.add('$eSym = \\dfrac{$numerator}{${denomParts.join('')}}');
}
```

**Step 2**: `E = \dfrac{J_{n,drift}}{q n μ_n}`  
**Step 3**: Substitute into rearranged form

### 3. Added Helper Function for Default Units

```dart
String _defaultUnitFor(String key) {
  if (key == 'J_n_drift' || key == 'J_p_drift') return 'A/m^2';
  if (key == 'mu_n' || key == 'mu_p') return 'm^2/(V*s)';
  if (key == 'n' || key == 'p') return 'm^{-3}';
  if (key == 'E_field') return 'V/m';
  return '';
}
```

## Test Coverage

**File**: `test/carrier_transport_fundamentals_test.dart`

Added 3 comprehensive tests:

### Test 1: Solve for Mobility (μ_n) - **Primary Test**
```dart
test('Solve for mobility (μ_n): Step 2 shows rearrangement, Step 3 uses rearranged form', () {
  // Verifies:
  // - Step 2 contains rearrangement with \dfrac
  // - Step 3 uses fraction form with J in numerator
  // - Final result: μ_n = 0.135 m²/(V·s)
});
```

### Test 2: Solve for Carrier Concentration (n)
```dart
test('Solve for carrier concentration (n): Step 2 shows rearrangement', () {
  // Verifies:
  // - Step 2 shows n = J/(q μ E)
  // - Step 3 uses rearranged fraction form
});
```

### Test 3: Solve for Electric Field (E)
```dart
test('Solve for electric field (E): Step 2 shows rearrangement', () {
  // Verifies:
  // - Step 2 shows E = J/(q n μ)
  // - Step 3 uses rearranged fraction form
});
```

### Test Results
```
✓ All 10 tests pass in carrier_transport_fundamentals_test.dart
✓ No regressions: solving for J still works correctly
✓ All new tests validate correct rearrangement and substitution
```

## Example Output: Solving for μ_n

### User Inputs
- J_{n,drift} = 21629.43 A/m²
- n = 1×10²¹ m⁻³
- E = 1×10³ V/m

### Step 1 - Unit Conversion
No unit conversion required.

### Step 2 - Rearrange to solve for μ_n
```
J_{n,drift} = q n μ_n E
μ_n = J_{n,drift} / (q n E)
```

### Step 3 - Substitute known values
```
μ_n = J_{n,drift} / (q n E)
μ_n = (2.16294 × 10^4 A/m²) / ((1.60218 × 10^-19 C)(1.00000 × 10^21 m^-3)(1.00000 × 10^3 V/m))
```

### Step 4 - Computed Value
```
μ_n = 0.135000 m²/(V·s)
```

### Rounded off to 3 s.f.
```
μ_n = 0.135 m²/(V·s)
```

## Acceptance Criteria ✅

✅ When target=μ_n, Step 2 shows explicit manipulation to isolate μ_n (division by q n E)  
✅ Step 3 substitution uses μ_n = J/(q n E), not J = q n μ E  
✅ Final Step 4 result remains μ_n = 0.135 m²/(V·s) (rounded to 3 s.f.)  
✅ No regressions: solving for J correctly shows "No rearrangement required" when appropriate  
✅ Same fix applies to hole drift current density (J_p_drift) and other targets  

## Generalization: Product Form Equations

The fix implements a general pattern for equations of the form `J = q n μ E`:

| Target | Rearranged Form | Step 2 Manipulation |
|--------|----------------|---------------------|
| J | J = q n μ E | (no rearrangement) |
| μ | μ = J / (q n E) | Divide both sides by q n E |
| n | n = J / (q μ E) | Divide both sides by q μ E |
| E | E = J / (q n μ) | Divide both sides by q n μ |

This pattern can be reused for other multiplicative formulas in semiconductor physics.

## Benefits

1. **Educational Clarity**: Students can now see and verify every step of the algebraic manipulation
2. **Consistency**: All target variables in the drift current formula now show proper rearrangement
3. **Maintainability**: Single unified function handles all cases instead of falling back to generic builders
4. **Extensibility**: Pattern can be applied to hole drift current and similar multiplicative equations

## Files Modified

1. **lib/core/solver/step_latex_builder.dart** (lines 2120-2254)
   - Removed early return that limited function to J_n_drift only
   - Added comprehensive rearrangement logic for all targets
   - Added `_defaultUnitFor` helper function

2. **test/carrier_transport_fundamentals_test.dart**
   - Added 3 new tests for μ_n, n, and E_field
   - Validates Step 2 rearrangement and Step 3 substitution
   - Ensures no regressions

## Related Documentation

- `STEP3_LATEX_RENDER_FIX.md` - Fix for aligned environment rendering issues
- `STEP3_SUBSTITUTION_FIX.md` - Earlier substitution pattern improvements
- `DUPLICATE_KEYS_SETSTATE_FIX.md` - Key management in step rendering

