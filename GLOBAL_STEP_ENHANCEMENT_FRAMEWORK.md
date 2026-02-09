# Global Step-by-Step Enhancement Framework

## Executive Summary
This document provides a systematic framework for ensuring ALL formulas have:
1. **Detailed Step 2** algebraic rearrangement (not just final form)
2. **Clear Step 3** substitution with bracketed values
3. **Unit-consistent Step 4** respecting user's target unit selection
4. **Safe LaTeX** rendering without duplicate keys or crashes

## Core Design Principles

### Canonical Units for Computation
All computations happen in these canonical units:
- **Concentration**: `m^{-3}`
- **Energy**: `J` (Joules)
- **Electric Field**: `V/m`
- **Current Density**: `A/m^{2}`
- **Mobility**: `m^{2}/(V \cdot s)`
- **Temperature**: `K` (Kelvin)

### Unit Flow Through Steps
```
User Input (any unit) 
  → Step 1: Convert to canonical units (if needed)
  → Step 2: Show rearrangement (unit-agnostic algebra)
  → Step 3: Substitute in canonical units
  → Step 4: Convert to user's requested target unit & round
```

### Step 2 Rearrangement Philosophy
**DO show detailed steps for:**
- Multiply/divide both sides
- Add/subtract terms
- Take logarithm
- Exponentiate
- Square/square root
- Isolate nested terms

**DON'T show steps for:**
- Already isolated: `target = f(others)`
- Direct substitution formulas

## Implementation Pattern

### Template for Each Formula Builder

```dart
static List<StepItem>? _buildFormulaX({
  required String solveFor,
  required SymbolContext context,
  required Map<String, SymbolValue> outputs,
  required LatexSymbolMap latexMap,
  required NumberFormatter formatter,
  UnitConverter? unitConverter,
  String primaryEnergyUnit = 'J',
}) {
  // 1. EXTRACT VALUES
  final targetValue = outputs[solveFor];
  final input1 = context.getSymbolValue('input1');
  // ... other inputs
  
  // 2. UNIT CONVERSIONS (Step 1)
  final unitConversionLines = <String>[];
  
  // Only convert what needs converting
  final input1Conv = _maybeConvert(
    input1,
    unitConverter,
    targetUnit: 'canonical_unit',
    formatter: formatter,
  );
  if (input1Conv?.line != null) {
    unitConversionLines.add(input1Conv!.line!);
  }
  
  // 3. REARRANGEMENT (Step 2)
  final rearrangeLines = <String>[];
  switch (solveFor) {
    case 'target1':
      // If already isolated, just show the equation
      rearrangeLines.add(r'target_1 = f(others)');
      break;
      
    case 'target2':
      // If needs rearrangement, show ALL steps
      rearrangeLines.addAll([
        r'base equation',
        r'operation 1 result',
        r'operation 2 result',
        r'final isolated form',
      ]);
      break;
  }
  
  // 4. SUBSTITUTION (Step 3)
  final substitutionLines = <String>[];
  
  // List known values (skip the target to avoid identity)
  if (solveFor != 'input1' && input1Conv != null) {
    substitutionLines.add('symbol1 = ${formatValue(input1Conv.baseValue, input1Conv.baseUnit)}');
  }
  
  // Show intermediate calculations if helpful
  if (compoundTerm != null) {
    substitutionLines.add(r'intermediate = calculated_value');
  }
  
  // Show bracketed substitution
  final exprWithBrackets = 'target = formula_with_(bracketed_values)';
  substitutionLines.add(exprWithBrackets);
  
  // 5. EVALUATION LINE (end of Step 3)
  String substitutionEvaluation;
  if (needsSimplification) {
    final simplified = 'target = simplified_form';
    substitutionEvaluation = targetValue != null 
        ? '$simplified = ${formatResult6(targetValue)}' 
        : simplified;
  } else {
    substitutionEvaluation = targetValue != null 
        ? '$exprWithBrackets = ${formatResult6(targetValue)}' 
        : exprWithBrackets;
  }
  
  // 6. FORMAT RESULT (Step 4)
  final result6 = _formatResultValue(
    formatter,
    targetValue,
    sigFigs: 6,
    context: context,
    unitConverter: unitConverter,
    primaryEnergyUnit: primaryEnergyUnit,
  );
  
  final result3 = _formatResultValue(
    formatter,
    targetValue,
    sigFigs: 3,
    context: context,
    unitConverter: unitConverter,
    primaryEnergyUnit: primaryEnergyUnit,
  );
  
  // 7. BUILD WITH TEMPLATE
  return UniversalStepTemplate.build(
    targetLabelLatex: _latexLabel(solveFor, latexMap),
    unitConversionLines: unitConversionLines,
    rearrangeLines: rearrangeLines,
    substitutionLines: substitutionLines,
    substitutionEvaluationLine: substitutionEvaluation,
    computedValueLine: 'target = $result6',
    roundedValueLine: 'target = $result3',
  );
}
```

## Formula-Specific Rearrangement Templates

### Midgap Energy: E_mid = (E_c + E_v) / 2

**Target: E_mid** (1 step - already isolated)
```latex
E_{\mathrm{mid}} = \frac{E_c + E_v}{2}
```

**Target: E_c** (4 steps)
```latex
E_{\mathrm{mid}} = \frac{E_c + E_v}{2}
2E_{\mathrm{mid}} = E_c + E_v
2E_{\mathrm{mid}} - E_v = E_c
E_c = 2E_{\mathrm{mid}} - E_v
```

**Target: E_v** (4 steps)
```latex
E_{\mathrm{mid}} = \frac{E_c + E_v}{2}
2E_{\mathrm{mid}} = E_c + E_v
2E_{\mathrm{mid}} - E_c = E_v
E_v = 2E_{\mathrm{mid}} - E_c
```

### Intrinsic Carrier: n_i² = N_c N_v exp(-E_g/kT)

**Target: E_g** (3 steps)
```latex
n_i^{2} = N_c N_v \exp\left(\frac{-E_g}{kT}\right)
\frac{n_i^{2}}{N_c N_v} = \exp\left(\frac{-E_g}{kT}\right)
\ln\left(\frac{n_i^{2}}{N_c N_v}\right) = \frac{-E_g}{kT}
E_g = -kT\,\ln\left(\frac{n_i^{2}}{N_c N_v}\right)
```

**Target: T** (3 steps)
```latex
n_i^{2} = N_c N_v \exp\left(\frac{-E_g}{kT}\right)
\frac{n_i^{2}}{N_c N_v} = \exp\left(\frac{-E_g}{kT}\right)
\ln\left(\frac{n_i^{2}}{N_c N_v}\right) = \frac{-E_g}{kT}
T = \frac{-E_g}{k\,\ln\left(\frac{n_i^{2}}{N_c N_v}\right)}
```

### Mass Action Law: np = n_i²

**Target: n** (2 steps)
```latex
np = n_i^{2}
n = \frac{n_i^{2}}{p}
```

**Target: p** (2 steps)
```latex
np = n_i^{2}
p = \frac{n_i^{2}}{n}
```

### Carrier Equilibrium: n = N_c exp((E_F - E_c) / kT)

**Target: E_F** (3 steps)
```latex
n = N_c \exp\left(\frac{E_F - E_c}{kT}\right)
\frac{n}{N_c} = \exp\left(\frac{E_F - E_c}{kT}\right)
\ln\left(\frac{n}{N_c}\right) = \frac{E_F - E_c}{kT}
E_F = E_c + kT\,\ln\left(\frac{n}{N_c}\right)
```

**Target: n** (2 steps)
```latex
n = N_c \exp\left(\frac{E_F - E_c}{kT}\right)
```
(Already isolated - only 1 line)

**Target: T** (4 steps)
```latex
n = N_c \exp\left(\frac{E_F - E_c}{kT}\right)
\frac{n}{N_c} = \exp\left(\frac{E_F - E_c}{kT}\right)
\ln\left(\frac{n}{N_c}\right) = \frac{E_F - E_c}{kT}
T = \frac{E_F - E_c}{k\,\ln\left(\frac{n}{N_c}\right)}
```

## Multi-Term Current Density Formulas

### Total Current Density for Holes

```latex
J_p = \underbrace{q p \mu_p \mathcal{E}}_{\text{drift}} - \underbrace{q D_p \frac{dp}{dx}}_{\text{diffusion}}
```

**Step 3 should show:**
```latex
\text{Drift component:} \quad J_{p,\mathrm{drift}} = q p \mu_p \mathcal{E} = [value]
\text{Diffusion component:} \quad J_{p,\mathrm{diff}} = -q D_p \frac{dp}{dx} = [value]
\text{Total current density:} \quad J_p = J_{p,\mathrm{drift}} + J_{p,\mathrm{diff}} = [value]
```

### Total Current Density for Electrons

```latex
J_n = \underbrace{q n \mu_n \mathcal{E}}_{\text{drift}} + \underbrace{q D_n \frac{dn}{dx}}_{\text{diffusion}}
```

**Note in Step 3:**
```latex
\text{Note: Diffusion term is positive for electrons (negative gradient convention)}
```

## LaTeX Safety and Rendering

### Stable Widget Keys
```dart
// DON'T key by LaTeX content (causes duplicates)
// BAD: Key(latex_string)

// DO use stable structural keys
// GOOD:
ValueKey('${formulaId}_step${stepNumber}_line${lineIndex}')
```

### LaTeX Sanitization
```dart
String sanitizeLatex(String raw) {
  var clean = raw;
  
  // Replace Unicode with LaTeX
  clean = clean.replaceAll('×', r'\times');
  clean = clean.replaceAll('−', '-');
  
  // Ensure exponent braces
  clean = clean.replaceAll(RegExp(r'\^([0-9\-]+)(?![{])'), r'^{$1}');
  
  // Wrap bare units
  clean = clean.replaceAll(RegExp(r'([0-9])\s*([a-zA-Z]+)(?![\\{])'), r'$1\,\mathrm{$2}');
  
  // Remove internal tags
  clean = clean.replaceAll(RegExp(r'<[^>]+>'), '');
  
  return clean;
}
```

### Fallback Rendering
```dart
try {
  return Math.tex(
    latexString,
    textStyle: style,
  );
} catch (e) {
  debugPrint('LaTeX render failed: $latexString');
  debugPrint('Formula: $formulaId, Step: $stepIndex, Line: $lineIndex');
  
  // Fallback in dev mode
  if (kDebugMode) {
    return Text(
      'LaTeX Error: $latexString',
      style: TextStyle(color: Colors.red),
    );
  }
  
  return const SizedBox.shrink();
}
```

## Unit Conversion Helpers

### Energy Conversion
```dart
class _EnergyConversion {
  final double baseValue;      // Value in canonical unit (J)
  final String baseUnit;        // 'J'
  final String? line;           // Optional Step 1 line
  final SymbolValue converted;  // SymbolValue with canonical unit
}

_EnergyConversion? _maybeEnergyConversion(
  SymbolValue? symbol,
  UnitConverter? converter, {
  required String preferredUnit,  // 'J' or 'eV'
}) {
  if (symbol == null) return null;
  
  // If already in preferred unit, no conversion needed
  if (symbol.unit == preferredUnit) {
    return _EnergyConversion(
      baseValue: symbol.value,
      baseUnit: preferredUnit,
      line: null,
      converted: symbol,
    );
  }
  
  // Convert to preferred unit
  final converted = converter?.convertEnergy(
    symbol.value,
    symbol.unit,
    preferredUnit,
  );
  
  if (converted == null) return null;
  
  // Generate Step 1 line
  final line = 'symbol = ${format(symbol.value, symbol.unit)} = ${format(converted, preferredUnit)}';
  
  return _EnergyConversion(
    baseValue: converted,
    baseUnit: preferredUnit,
    line: line,
    converted: SymbolValue(value: converted, unit: preferredUnit),
  );
}
```

### Concentration Conversion
Similar pattern for `m^{-3}` ↔ `cm^{-3}`

## Testing Strategy

### Test Template for Each Formula
```dart
test('Formula X: target Y shows detailed rearrangement', () {
  final result = solver.solve(
    formulaId: 'formula_x',
    solveFor: 'Y',
    workspaceGlobals: const {},
    panelOverrides: const {
      'input1': SymbolValue(value: 1.0, unit: 'unit1', source: SymbolSource.user),
      // ... other inputs
    },
    latexMap: latexMap,
  );
  
  expect(result.status, PanelStatus.solved);
  final items = result.stepsLatex!.workingItems;
  final math = items.where((i) => i.type == StepItemType.math).map((i) => i.latex).join(' ');
  
  // Verify Step 2 rearrangement
  expect(math, contains('base equation pattern'));
  expect(math, contains('intermediate step pattern'));
  expect(math, contains('final isolated form'));
  
  // Verify Step 3 substitution
  expect(math, contains('intermediate calculation'));
  expect(math, contains('bracketed substitution'));
  
  // Verify Step 4 unit
  expect(math, contains('expected unit'));
});
```

## Implementation Priority

### Phase 1: Critical Formulas (Already Done ✅)
- ✅ Intrinsic carrier concentration (N_v, N_c)
- ✅ Intrinsic Fermi level (E_mid, T, m_p*, m_n*)

### Phase 2: High-Priority Formulas (Next)
- Midgap energy (E_c, E_v) - currently only E_mid enhanced
- Carrier equilibrium (n, p, E_F, T)
- Mass action law (n, p)

### Phase 3: Remaining Formulas
- Effective DOS (N_c, N_v for different targets)
- Fermi-Dirac probability
- Energy band dispersion
- PN junction formulas
- Current density formulas

## Success Metrics

✅ **Step 2**: All non-trivial isolations show ≥2 intermediate steps
✅ **Step 3**: All substitutions use bracketed values and canonical units
✅ **Step 4**: All results display in user's requested target unit
✅ **LaTeX**: Zero render failures, zero duplicate key crashes
✅ **Tests**: 100% formula coverage with rearrangement verification
✅ **Units**: Consistent canonical-unit computation throughout

## Maintenance Guidelines

When adding a new formula:
1. Define rearrangement templates for each target
2. Use canonical units for all computation
3. Show bracketed substitution in Step 3
4. Convert to target unit in Step 4
5. Add comprehensive tests
6. Use stable widget keys
7. Sanitize all LaTeX strings

This framework ensures consistency, maintainability, and educational value across all formulas in the application.
