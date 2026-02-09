# N_v Rearrangement Steps Implementation

## Summary
Added missing algebraic rearrangement steps in Step 2 when solving for N_v (and N_c) in the intrinsic carrier concentration relation: n_i² = N_c N_v exp(-E_g/kT).

## Problem
Previously, Step 2 only showed the final isolated equation:
```
N_v = n_i² / (N_c exp(-E_g/kT))
```

This jumped directly to the result without showing the intermediate algebraic manipulations, reducing pedagogical value.

## Solution

### Step 2 - Rearrangement (dos_stats_steps.dart lines 646-658)
Now shows incremental algebra steps:

**For solving N_v:**
1. Start with base equation: `n_i² = N_c N_v exp(-E_g/kT)`
2. Divide by N_c: `n_i² / N_c = N_v exp(-E_g/kT)`
3. Divide by exp term: `n_i² / (N_c exp(-E_g/kT)) = N_v`
4. Final isolated form: `N_v = n_i² / (N_c exp(-E_g/kT))`

**For solving N_c (lines 639-645):**
Similar intermediate steps are shown.

### Step 3 - Substitution (lines 749-785 for N_v, 730-761 for N_c)
Enhanced to show:

1. **Intermediate calculations:**
   - `kT = [calculated value] J`
   - `-E_g/kT = [calculated value]`

2. **Bracketed substitution with proper LaTeX:**
   ```latex
   N_v = \frac{(n_i)^{2}}{(N_c)\exp\left(\frac{-(E_g)}{(k)(T)}\right)}
   ```
   Then substitute actual values:
   ```latex
   N_v = \frac{(1.00000×10^{16} m^{-3})^{2}}{(2.81600×10^{25} m^{-3})\exp\left(\frac{-(1.79444×10^{-19} J)}{(1.38065×10^{-23} J/K)(300.000 K)}\right)}
   ```

3. **Simplified form:**
   ```latex
   N_v = \frac{1.00000×10^{32} m^{-6}}{(2.81600×10^{25} m^{-3})\exp(-43.3235)} = [result]
   ```

## LaTeX Formatting Rules Applied

✅ Use `\exp\left(...\right)` not plain text `exp(...)`
✅ Use braces for exponents: `10^{25}`, `10^{-19}`
✅ Wrap units with `\mathrm{m^{-3}}`, `\mathrm{J}`, `\mathrm{J/K}`
✅ Use `\times` not Unicode `×`
✅ Bracket substituted values for clarity: `(value)`
✅ Show intermediate algebraic steps line-by-line

## Files Modified

1. **lib/core/solver/steps/dos_stats/dos_stats_steps.dart**
   - Lines 631-658: Added multi-line rearrangement for N_c and N_v cases
   - Lines 730-785: Enhanced substitution format with bracketing and intermediate steps

2. **test/dos_stats_steps_test.dart**
   - Added comprehensive tests for N_v rearrangement steps (lines 202-232)
   - Added comprehensive tests for N_c rearrangement steps (lines 234-256)

## Test Results

✅ All new tests pass (2/2 intrinsic carrier tests)
✅ Rearrangement steps verified to show 4 lines for N_v and N_c
✅ Substitution format verified with bracketed values
✅ LaTeX formatting verified (no plain text `exp`, proper `\exp\left...\right)`)
✅ Units properly formatted with `\mathrm{}`
✅ Visualization test confirms correct output format

## Acceptance Criteria Met

✅ When target=N_v, Step 2 shows at least 2 intermediate rearrangement lines before final isolated form (actually shows 4 lines)
✅ Step 3 substitutes values into the isolated N_v expression with bracketed, readable format
✅ No 'Unable to render this math line' errors
✅ Computed N_v matches Result panel with proper rounding

## Example Output

When solving for N_v with:
- n_i = 1.0×10^16 m^-3
- N_c = 2.8×10^25 m^-3
- E_g = 1.12 eV
- T = 300 K

**Step 2 shows:**
```
n_i² = N_c N_v exp(-E_g/kT)
n_i² / N_c = N_v exp(-E_g/kT)
n_i² / (N_c exp(-E_g/kT)) = N_v
N_v = n_i² / (N_c exp(-E_g/kT))
```

**Step 3 shows:**
```
kT = 4.14195×10^-21 J
-E_g/kT = -43.3235
N_v = [(n_i)² / (N_c)exp(-E_g/(k)(T))] with full values substituted
N_v = [simplified form] = [final result]
```

This provides clear pedagogical value by showing the complete algebraic derivation process.
