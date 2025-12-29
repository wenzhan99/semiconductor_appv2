import 'dart:math' as math;

import '../constants/constants_repository.dart';

/// Converts between different units.
class UnitConverter {
  final ConstantsRepository _constantsRepo;

  UnitConverter(this._constantsRepo);

  /// Convert energy from J to eV or vice versa.
  double? convertEnergy(double value, String fromUnit, String toUnit) {
    final q = _constantsRepo.getElectronVoltJoules();
    if (q == null) return null;

    if (fromUnit == 'J' && toUnit == 'eV') {
      return value / q;
    } else if (fromUnit == 'eV' && toUnit == 'J') {
      return value * q;
    }
    return null;
  }

  /// Convert length from one unit to another.
  double? convertLength(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;

    // Convert to meters first
    double meters = value;
    switch (fromUnit) {
      case 'm':
        meters = value;
        break;
      case 'cm':
        meters = value / 100;
        break;
      case 'nm':
        meters = value / 1e9;
        break;
      case 'um':
      case 'μm':
        meters = value / 1e6;
        break;
      default:
        return null;
    }

    // Convert from meters to target
    switch (toUnit) {
      case 'm':
        return meters;
      case 'cm':
        return meters * 100;
      case 'nm':
        return meters * 1e9;
      case 'um':
      case 'μm':
        return meters * 1e6;
      default:
        return null;
    }
  }

  /// Convert density from one unit to another (e.g., m^-3 to cm^-3).
  double? convertDensity(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;

    // Extract base unit and power
    final fromMatch = RegExp(r'^(.+)\^(-?\d+)$').firstMatch(fromUnit);
    final toMatch = RegExp(r'^(.+)\^(-?\d+)$').firstMatch(toUnit);

    if (fromMatch == null || toMatch == null) return null;

    final fromBase = fromMatch.group(1)!;
    final fromPower = int.parse(fromMatch.group(2)!);
    final toBase = toMatch.group(1)!;
    final toPower = int.parse(toMatch.group(2)!);

    // For now, only support conversions that keep the same power (e.g. m^-3 <-> cm^-3).
    if (fromPower != toPower) return null;

    // Convert base unit: 1 fromBase in toBase (e.g. 1 m = 100 cm).
    final baseConversion = convertLength(1.0, fromBase, toBase);
    if (baseConversion == null) return null;

    // Apply the dimensional power, including negative exponents.
    // Example: m^-3 -> cm^-3: factor = (100)^(-3) = 1e-6
    return value * math.pow(baseConversion, fromPower).toDouble();
  }

  /// Convert wavevector from one unit to another (e.g., 1/m to 1/cm).
  double? convertWavevector(double value, String fromUnit, String toUnit) {
    return convertDensity(value, fromUnit, toUnit);
  }
}

