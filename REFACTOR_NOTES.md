# Refactoring Notes - Constants Module

## Identified Issues

### 1. Duplicate File Names

#### Issue: `constants_loader.dart` exists in two locations

**Files**:
- ✅ `lib/core/constants/constants_loader.dart` - **ACTIVE** (used by `main.dart`, `ConstantsRepository`)
- ❌ `lib/services/constants_loader.dart` - **UNUSED** (not imported anywhere)

**Problem**:
- Confusing for developers (which one to use?)
- Risk of accidentally using the wrong one
- The `services/` version imports from `models/` (old structure), suggesting it's legacy code

**Solution**:
1. **Delete** `lib/services/constants_loader.dart`
2. **Verify** no imports reference it: `grep -r "services/constants_loader" lib/`
3. **Update** any references to use `core/constants/constants_loader.dart`

---

#### Issue: `physical_constant.dart` exists in two locations

**Files**:
- ✅ `lib/core/constants/physical_constant.dart` - **ACTIVE** (used throughout)
- ❌ `lib/models/physical_constant.dart` - **UNUSED** (duplicate, same content)

**Problem**:
- Same class defined twice
- Risk of import confusion
- Violates single source of truth principle

**Solution**:
1. **Delete** `lib/models/physical_constant.dart`
2. **Verify** no imports: `grep -r "models/physical_constant" lib/`
3. **Update** any references to use `core/constants/physical_constant.dart`

---

#### Issue: `physical_constants_table.dart` exists in two locations

**Files**:
- ✅ `lib/core/constants/physical_constants_table.dart` - **ACTIVE**
- ❌ `lib/models/physical_constants_table.dart` - **UNUSED** (duplicate, same content)

**Problem**:
- Same as above - duplicate definition

**Solution**:
1. **Delete** `lib/models/physical_constants_table.dart`
2. **Verify** no imports: `grep -r "models/physical_constants_table" lib/`
3. **Update** any references

---

### 2. Inconsistent Naming and Import Structure

#### Current State

**Active Imports** (correct):
```dart
// main.dart
import 'core/constants/constants_loader.dart';
import 'core/constants/constants_repository.dart';

// constants_repository.dart
import 'constants_loader.dart';
import 'physical_constants_table.dart';
```

**Legacy Imports** (should be removed):
```dart
// services/constants_loader.dart (UNUSED FILE)
import '../models/physical_constants_table.dart';  // ❌ Wrong location
import '../models/latex_symbols.dart';  // ❌ Wrong location
```

#### Recommended Structure

**Standard Import Pattern**:
```dart
// From outside core/constants/
import 'package:semiconductor_appv2/core/constants/constants_repository.dart';
import 'package:semiconductor_appv2/core/constants/physical_constant.dart';

// From within core/constants/
import 'constants_loader.dart';
import 'physical_constant.dart';
```

**Naming Conventions**:
- ✅ Use `snake_case` for file names: `constants_loader.dart`
- ✅ Use `PascalCase` for class names: `ConstantsLoader`
- ✅ Use `camelCase` for methods: `getConstantValue()`
- ✅ Use `lowercase` for constants: `_constantsPath`

---

### 3. LaTeX Mapping and Unit Formatting Responsibilities

#### Current Situation

**LaTeX Mapping**:
- ✅ `LatexSymbolMap` in `core/constants/` - **CORRECT**
- Maps symbol keys to LaTeX strings
- Used by `StepLaTeXBuilder` and UI components

**Unit Formatting**:
- ✅ `NumberFormatter.formatLatexUnit()` in `core/solver/` - **CORRECT**
- Converts unit strings (e.g., "J*s") to LaTeX (e.g., "J\\cdot s")
- Used when rendering constants and results

#### Recommendation

**Keep Current Structure**:
- LaTeX symbol mapping stays in `core/constants/` (it's about constant symbols)
- Unit formatting stays in `core/solver/` (it's about number/result formatting)
- This separation is appropriate

**Potential Improvement**:
- Consider a `UnitFormatter` class in `core/solver/` if unit formatting logic grows
- Keep `NumberFormatter` focused on numeric formatting
- Keep unit formatting as a separate concern

---

### 4. Unit Safety (Avoiding eV/J Mixing)

#### Current Approach

**Storage**:
- ✅ All constants stored in **SI base units** (J, kg, m, s, C, K)
- ✅ No dual-unit storage

**Conversion**:
- ✅ `UnitConverter.convertEnergy()` handles J ↔ eV using `q`
- ✅ Conversion happens at UI boundary (input/output), not in constants

**Potential Issues**:
1. **Silent unit mixing**: If a developer accidentally uses eV where J is expected
2. **No type safety**: Units are strings, not types
3. **Runtime errors**: Unit mismatches only discovered at runtime

#### Recommendations

**Short-term (Low Risk)**:
1. **Add unit validation** in `UnitConverter`:
   ```dart
   double? convertEnergy(double value, String fromUnit, String toUnit) {
     if (fromUnit != 'J' && fromUnit != 'eV') {
       throw ArgumentError('Invalid energy unit: $fromUnit');
     }
     if (toUnit != 'J' && toUnit != 'eV') {
       throw ArgumentError('Invalid energy unit: $toUnit');
     }
     // ... rest of conversion
   }
   ```

2. **Document unit expectations** in method signatures:
   ```dart
   /// Converts energy between J (Joules) and eV (electron-volts).
   /// 
   /// [fromUnit] and [toUnit] must be either 'J' or 'eV'.
   /// Returns null if conversion fails (e.g., q constant not loaded).
   double? convertEnergy(double value, String fromUnit, String toUnit)
   ```

**Long-term (Higher Risk, More Work)**:
1. **Create unit types** (enum or sealed class):
   ```dart
   enum EnergyUnit { joules, electronVolts }
   
   class Energy {
     final double value;
     final EnergyUnit unit;
     Energy(this.value, this.unit);
   }
   ```
   - Prevents mixing units at compile time
   - Requires refactoring all energy-related code

2. **Use a units library** (e.g., `package:units/units.dart`):
   - Provides type-safe unit handling
   - More robust but adds dependency

**Current Recommendation**: Keep string-based units for now, but add validation and documentation. Consider type-safe units if the codebase grows significantly.

---

## Refactoring Plan

### Phase 1: Cleanup (Low Risk)

**Tasks**:
1. ✅ Delete `lib/services/constants_loader.dart`
2. ✅ Delete `lib/models/physical_constant.dart`
3. ✅ Delete `lib/models/physical_constants_table.dart`
4. ✅ Audit all imports: `grep -r "services/constants_loader\|models/physical_constant\|models/physical_constants_table" lib/`
5. ✅ Update any found imports to use `core/constants/`
6. ✅ Run `flutter analyze` to verify no errors
7. ✅ Run tests to ensure nothing breaks

**Estimated Time**: 30 minutes
**Risk Level**: Low (deleting unused files)

---

### Phase 2: Standardize Imports (Medium Risk)

**Tasks**:
1. ✅ Audit all imports of constants module files
2. ✅ Standardize to use `core/constants/` prefix
3. ✅ Update any relative imports to absolute (package) imports where appropriate
4. ✅ Verify with `flutter analyze`

**Estimated Time**: 1 hour
**Risk Level**: Medium (import changes can break things)

---

### Phase 3: Add Unit Validation (Low Risk)

**Tasks**:
1. ✅ Add unit validation to `UnitConverter.convertEnergy()`
2. ✅ Add documentation comments explaining unit expectations
3. ✅ Add unit tests for invalid unit handling
4. ✅ Consider adding a `UnitValidator` helper class

**Estimated Time**: 2 hours
**Risk Level**: Low (additive changes)

---

### Phase 4: Consider Type-Safe Units (High Risk, Optional)

**Tasks**:
1. ⚠️ Design unit type system (enum or sealed class)
2. ⚠️ Refactor `PhysicalConstant` to use typed units
3. ⚠️ Refactor `UnitConverter` to use typed units
4. ⚠️ Update all call sites
5. ⚠️ Extensive testing

**Estimated Time**: 1-2 days
**Risk Level**: High (major refactoring)
**Recommendation**: Only do this if unit mixing becomes a real problem

---

## File Structure After Refactoring

```
lib/
├── core/
│   └── constants/              ← Single source of truth
│       ├── constants_loader.dart
│       ├── constants_repository.dart
│       ├── physical_constant.dart
│       ├── physical_constants_table.dart
│       └── latex_symbols.dart
├── services/                   ← No constants files
├── models/                     ← No constants files (only workspace, units)
└── ...
```

---

## Testing Strategy After Refactoring

### Unit Tests

**Test Files**:
```
test/
  core/
    constants/
      constants_loader_test.dart
      constants_repository_test.dart
      physical_constant_test.dart
      physical_constants_table_test.dart
      latex_symbols_test.dart
```

**Key Test Cases**:
1. **ConstantsLoader**: Load valid JSON, handle missing file, handle malformed JSON
2. **ConstantsRepository**: Singleton pattern, caching, getConstantValue(), getHbar()
3. **PhysicalConstant**: JSON parsing, optional fields, serialization
4. **PhysicalConstantsTable**: byId(), bySymbol(), alias lookup
5. **LatexSymbolMap**: latexOf(), fallback behavior

### Integration Tests

**Test Scenarios**:
1. App initialization loads constants successfully
2. Constants are available in UI via Provider
3. Unit conversion uses correct constant values
4. Formula solving retrieves constants correctly

---

## Migration Checklist

- [ ] Phase 1: Delete duplicate files
- [ ] Phase 1: Audit and update imports
- [ ] Phase 1: Verify with `flutter analyze`
- [ ] Phase 1: Run existing tests
- [ ] Phase 2: Standardize all imports
- [ ] Phase 2: Update documentation
- [ ] Phase 3: Add unit validation
- [ ] Phase 3: Add unit tests for validation
- [ ] Phase 4: (Optional) Design type-safe units
- [ ] Phase 4: (Optional) Implement type-safe units
- [ ] Phase 4: (Optional) Update all call sites

---

## Summary

The main issues are:
1. **Duplicate files** in `services/` and `models/` that should be deleted
2. **Import inconsistencies** that should be standardized
3. **Unit safety** could be improved with validation (and optionally type-safe units)

The refactoring is straightforward and low-risk for Phases 1-3. Phase 4 (type-safe units) is optional and should only be done if unit mixing becomes a real problem.

