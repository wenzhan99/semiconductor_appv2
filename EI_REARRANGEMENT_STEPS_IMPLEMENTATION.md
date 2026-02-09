# Intrinsic Fermi Level (E_i) Rearrangement Steps Implementation

## Summary
Added detailed algebraic rearrangement steps in Step 2 when solving for E_mid, T, m_p*, and m_n* in the intrinsic Fermi level position formula: E_i = E_mid + (3/4) kT ln(m_p*/m_n*).

## Problem
Previously, Step 2 only showed the final isolated equation for each target variable, jumping directly to the result without showing intermediate algebraic manipulations. This reduced pedagogical value and made it harder for students to understand the derivation process.

## Solution

### Step 2 - Rearrangement (dos_stats_steps.dart lines 1014-1063)

**For solving E_mid (3 steps):**
1. Start: `E_i = E_mid + (3/4) k T ln(m_p*/m_n*)`
2. Subtract term: `E_i - (3/4) k T ln(m_p*/m_n*) = E_mid`
3. Final: `E_mid = E_i - (3/4) k T ln(m_p*/m_n*)`

**For solving T (4 steps):**
1. Start: `E_i = E_mid + (3/4) k T ln(m_p*/m_n*)`
2. Subtract E_mid: `E_i - E_mid = (3/4) k T ln(m_p*/m_n*)`
3. Divide: `(E_i - E_mid) / ((3/4) k ln(m_p*/m_n*)) = T`
4. Final: `T = (E_i - E_mid) / ((3/4) k ln(m_p*/m_n*))`

**For solving m_p* (5 steps):**
1. Start: `E_i = E_mid + (3/4) k T ln(m_p*/m_n*)`
2. Subtract E_mid: `E_i - E_mid = (3/4) k T ln(m_p*/m_n*)`
3. Divide: `(E_i - E_mid) / ((3/4) k T) = ln(m_p*/m_n*)`
4. Exponentiate: `exp((E_i - E_mid) / ((3/4) k T)) = m_p*/m_n*`
5. Final: `m_p* = m_n* exp((4/3)(E_i - E_mid)/(kT))`

**For solving m_n* (7 steps):**
Similar progression with additional steps to isolate m_n* in the denominator, ending with:
`m_n* = m_p* exp(-(4/3)(E_i - E_mid)/(kT))`

### Step 3 - Substitution Enhancement (lines 1109-1155)

**For E_mid, now shows:**

1. **Intermediate calculations:**
   ```latex
   \frac{3}{4}kT = [calculated value] J
   \ln\left(\frac{m_p^{*}}{m_n^{*}}\right) = [calculated value]
   ```

2. **Bracketed substitution:**
   ```latex
   E_{mid} = (E_i) - \frac{3}{4}(k)(T)\ln\left(\frac{m_p^{*}}{m_n^{*}}\right)
   ```
   With actual values:
   ```latex
   E_{mid} = (8.97219×10^{-20} J) - \frac{3}{4}(1.38065×10^{-23} J/K)(300.000 K)\ln\left(\frac{8.10000×10^{-31} kg}{2.60000×10^{-31} kg}\right)
   ```

3. **Simplified evaluation:**
   ```latex
   E_{mid} = 8.97219×10^{-20} J - (3.10646×10^{-21} J)(1.13635) = 8.61919×10^{-20} J
   ```

## LaTeX Formatting Rules Applied

✅ Use `\ln\left(...\right)` not plain text `ln(...)`
✅ Use `\exp\left(...\right)` for exponential expressions
✅ Wrap ratios with `\left(` `\right)` for readability
✅ Use braces for exponents: `10^{-20}`, `m_p^{*}`
✅ Wrap units with `\mathrm{J}`, `\mathrm{kg}`, `\mathrm{K}`
✅ Use `\times` not Unicode `×`
✅ Bracket substituted values for clarity: `(value)`

## Files Modified

1. **lib/core/solver/steps/dos_stats/dos_stats_steps.dart**
   - Lines 1014-1063: Added multi-step rearrangement for E_mid, T, m_p*, m_n*
   - Lines 1109-1155: Enhanced substitution format for E_mid with bracketing and intermediate steps

2. **test/dos_stats_steps_test.dart**
   - Added test for E_mid rearrangement steps (lines 272-303)
   - Added test for T rearrangement steps (lines 305-324)
   - Added test for m_p* rearrangement steps with exp transformation (lines 326-348)

## Test Results

✅ All 3 new Intrinsic Fermi level tests pass
✅ E_mid shows 3 rearrangement lines
✅ T shows 4 rearrangement lines
✅ m_p* shows 5 rearrangement lines including exp transformation
✅ Bracketed substitution format verified
✅ LaTeX formatting verified (proper `\ln`, `\exp`, bracketing)
✅ Intermediate calculations shown before final substitution

## Acceptance Criteria Met

✅ When solving for E_mid, Step 2 shows at least 3 intermediate rearrangement lines
✅ Step 3 substitutes values into the isolated E_mid expression with bracketed format
✅ Step 3 shows intermediate calculations ((3/4)kT, ln term) before final substitution
✅ No rendering errors
✅ Computed values match with proper rounding
✅ Similar enhancements applied to T, m_p*, and m_n* targets

## Example Output

When solving for E_mid with:
- E_i = 0.56 eV
- m_p* = 0.81×10^-30 kg
- m_n* = 0.26×10^-30 kg
- T = 300 K

**Step 2 shows:**
```
E_i = E_mid + (3/4) k T ln(m_p*/m_n*)
E_i - (3/4) k T ln(m_p*/m_n*) = E_mid
E_mid = E_i - (3/4) k T ln(m_p*/m_n*)
```

**Step 3 shows:**
```
(3/4)kT = 3.10646×10^-21 J
ln(m_p*/m_n*) = 1.13635
E_mid = (8.97219×10^-20 J) - (3/4)(1.38065×10^-23 J/K)(300.000 K)ln(...)
E_mid = 8.97219×10^-20 J - (3.10646×10^-21 J)(1.13635) = 8.61919×10^-20 J
```

**Step 4 shows:**
```
E_mid = 8.61919×10^-20 J
E_mid = 8.62×10^-20 J  (rounded to 3 s.f.)
```

This provides complete pedagogical value by showing:
1. The full algebraic derivation process
2. Intermediate calculations
3. Clear substitution with bracketed values
4. Step-by-step evaluation leading to the final answer

## Unit Consistency

The implementation respects the user's selected unit preference:
- Energy values converted to J or eV based on `primaryEnergyUnit` setting
- Unit conversions shown in Step 1 if needed
- Final answer displayed in the user's preferred unit
- The `_formatResultValue` function handles unit preference consistently

## Generalization

The same pattern can be applied to other formulas that need detailed rearrangement steps:
1. Identify the base equation
2. List the algebraic operations needed to isolate the target
3. Show each operation as a separate line in rearrangeLines
4. Ensure Step 3 substitutes into the isolated form
5. Show intermediate calculations before the final substitution
