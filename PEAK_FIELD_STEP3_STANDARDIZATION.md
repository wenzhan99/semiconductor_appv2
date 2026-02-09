# Peak Electric Field (Charge Form) - Step 3 Standardization

## Problem Summary

Peak electric field (charge form) formulas were using the generic universal step builder, which:
- Did not show numerator/denominator breakdown for fraction forms
- Made Step 3 less readable for verification
- Lacked the structured approach used in other formulas

## Solution Implemented

Created a custom step builder (`_buildPeakFieldChargeFormSteps`) that provides clear numerator/denominator breakdown for all target variables.

## Formulas Fixed

### N-Side Formula
**Equation**: `E_max = (q N_D x_n) / eps_s`

**Targets Supported**:
- `E_max`: Peak electric field
- `N_D`: Donor concentration
- `x_n`: Depletion width on n-side
- `eps_s`: Semiconductor permittivity

### P-Side Formula
**Equation**: `E_max = (q N_A x_p) / eps_s`

**Targets Supported**:
- `E_max`: Peak electric field
- `N_A`: Acceptor concentration
- `x_p`: Depletion width on p-side
- `eps_s`: Semiconductor permittivity

## Example Output: Solving for E_max (N-Side)

### Step 1 - Unit Conversion
```
No unit conversion required.
```

### Step 2 - Rearrange to solve for E_max
```
No rearrangement required.
```

### Step 3 - Substitute known values
```
E_max = (q N_D x_n) / eps_s

Numerator: q N_D x_n = (1.60218 × 10^{-19} C)(1.00000 × 10^{22} m^{-3})(1.00000 × 10^{-6} m)
Numerator = 1.60218 × 10^{-3} C·m^{-2}

Denominator: eps_s = 1.04000 × 10^{-10} F/m

E_max = (1.60218 × 10^{-3}) / (1.04000 × 10^{-10} F/m)
```

### Step 4 - Computed Value
```
E_max = 1.54055 × 10^{7} V/m
```

### Rounded off to 3 s.f.
```
E_max = 1.54 × 10^{7} V/m
```

## Example Output: Solving for N_A (P-Side)

### Step 2 - Rearrange to solve for N_A
```
E_max = (q N_A x_p) / eps_s
N_A = (E_max · eps_s) / (q · x_p)
```

### Step 3 - Substitute known values
```
N_A = (E_max · eps_s) / (q · x_p)

Numerator: E_max · eps_s = (1.54000 × 10^{6} V/m)(1.04000 × 10^{-10} F/m)
Numerator = 1.60160 × 10^{-4}

Denominator: q · x_p = (1.60218 × 10^{-19} C)(1.00000 × 10^{-6} m)
Denominator = 1.60218 × 10^{-25} C·m

N_A = (1.60160 × 10^{-4}) / (1.60218 × 10^{-25})
```

## Implementation Details

**File**: `lib/core/solver/step_latex_builder.dart` (lines 2927-3095)

### Key Features

1. **Target-Specific Rearrangement**
   - Each target variable gets proper algebraic rearrangement
   - Fraction forms use `\dfrac` for clarity

2. **Numerator/Denominator Breakdown**
   - Shows what goes in numerator
   - Shows what goes in denominator
   - Computes each separately before final division

3. **Full Substitution**
   - ALL known values are substituted numerically
   - No leftover symbolic values in Step 3
   - Uses 6 significant figures for intermediate calculations

4. **Proper Units**
   - Units tracked through numerator/denominator
   - Final result shows correct derived units
   - Uses LaTeX formatting: `\mathrm{C}`, `\mathrm{m^{-3}}`, `\mathrm{F/m}`, etc.

### Code Structure

```dart
if (solveFor == 'E_max') {
  // No rearrangement
  // Show numerator: q N x
  // Show denominator: eps_s
  // Show final division
  
} else if (solveFor == dopingKey) {
  // Rearrange: N = (E_max · eps_s) / (q · x)
  // Show numerator: E_max · eps_s
  // Show denominator: q · x
  // Show final division
  
} else if (solveFor == depthKey) {
  // Rearrange: x = (E_max · eps_s) / (q · N)
  // Show numerator: E_max · eps_s
  // Show denominator: q · N
  // Show final division
  
} else if (solveFor == 'eps_s') {
  // Rearrange: eps_s = (q · N · x) / E_max
  // Show numerator: q · N · x
  // Show denominator: E_max
  // Show final division
}
```

## Test Coverage

**File**: `test/pn_peak_field_test.dart` (new file)

Created 4 comprehensive tests:

1. **N-side: solve for E_max** - Validates numerator/denominator breakdown
2. **P-side: solve for N_A** - Validates rearrangement and full substitution
3. **N-side: solve for x_n** - Validates numerator/denominator for depth
4. **P-side: solve for eps_s** - Validates permittivity calculation

**Results**: ✅ 4/4 tests pass

## Acceptance Criteria Status

✅ **Full Substitution**: All known values are substituted numerically in Step 3  
✅ **Numerator/Denominator Breakdown**: Clearly shows computation structure  
✅ **Consistent Formatting**: Same pattern for all target variables  
✅ **Proper LaTeX**: Scientific notation, units, and symbols all correctly formatted  
✅ **No Partial Substitutions**: No leftover known symbols in Step 3  

## Benefits

1. **Educational Clarity**: Students can verify numerator and denominator separately
2. **Verification**: Each calculation step is explicit and checkable
3. **Consistency**: Same pattern as other carrier transport formulas
4. **Readability**: Breaking down complex fractions makes them easier to follow

## Integration

The custom builder is automatically invoked through `tryBuildModuleSteps`:

```dart
// In tryBuildModuleSteps
final peakFieldSteps = _buildPeakFieldChargeFormSteps(
  formula: formula,
  solveFor: solveFor,
  context: context,
  outputs: outputs,
  conversionLines: conversionLines,
);
if (peakFieldSteps != null) return peakFieldSteps;
```

## Files Modified

1. **lib/core/solver/step_latex_builder.dart**
   - Lines 233-241: Added peak field step builder invocation
   - Lines 2927-3095: Implemented `_buildPeakFieldChargeFormSteps`
   - Handles all 4 target variables for both n-side and p-side

2. **test/pn_peak_field_test.dart** (new file)
   - Comprehensive tests for all scenarios
   - Validates numerator/denominator breakdown
   - Verifies full substitution

3. **assets/constants/ee2103_latex_symbols.json**
   - Added missing mappings for `n` and `p` symbols

## Related Documentation

- `TOTAL_CURRENT_STEP3_CLARITY_FIX.md` - Total current density 3-part narrative
- `STEP2_STEP3_REARRANGEMENT_FIX.md` - Drift current density rearrangement
- `CARRIER_TRANSPORT_AUDIT_FIX.md` - Complete carrier transport audit
- `STEP3_LATEX_RENDER_FIX.md` - LaTeX rendering fixes

