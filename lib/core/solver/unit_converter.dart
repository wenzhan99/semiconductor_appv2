import 'dart:math' as math;

import '../constants/constants_repository.dart';
import '../utils/parse_utils.dart';

/// A single recorded unit conversion.
class UnitConversionStep {
  final String symbol;
  final double fromValue;
  final String fromUnit;
  final double toValue;
  final String toUnit;
  final String reason;

  const UnitConversionStep({
    required this.symbol,
    required this.fromValue,
    required this.fromUnit,
    required this.toValue,
    required this.toUnit,
    required this.reason,
  });
}

/// Aggregates conversion steps so they can be surfaced in the UI (Step 1).
class UnitConversionLog {
  final List<UnitConversionStep> _steps = [];

  void add({
    required String symbol,
    required double fromValue,
    required String fromUnit,
    required double toValue,
    required String toUnit,
    String reason = '',
  }) {
    _steps.add(
      UnitConversionStep(
        symbol: symbol,
        fromValue: fromValue,
        fromUnit: fromUnit,
        toValue: toValue,
        toUnit: toUnit,
        reason: reason,
      ),
    );
  }

  List<UnitConversionStep> get steps => List.unmodifiable(_steps);

  bool get isEmpty => _steps.isEmpty;
}

/// Converts between different units.
class UnitConverter {
  final ConstantsRepository _constantsRepo;
  final UnitConversionLog? log;

  UnitConverter(this._constantsRepo, {this.log});

  /// Convert energy from J to eV or vice versa.
  double? convertEnergy(
    dynamic value,
    String fromUnit,
    String toUnit, {
    UnitConversionLog? log,
    String? symbol,
    String reason = '',
  }) {
    final coerced = coerceDouble(value, context: 'UnitConverter.convertEnergy');
    if (coerced == null) return null;
    final q = _constantsRepo.getElectronVoltJoules();
    if (q == null) return null;

    double? converted;
    if (fromUnit == 'J' && toUnit == 'eV') {
      converted = coerced / q;
    } else if (fromUnit == 'eV' && toUnit == 'J') {
      converted = coerced * q;
    }
    if (converted == null) return null;

    final activeLog = log ?? this.log;
    if (activeLog != null && (converted != coerced || fromUnit != toUnit)) {
      final sym = symbol ?? toUnit;
      activeLog.add(
        symbol: sym,
        fromValue: coerced,
        fromUnit: fromUnit,
        toValue: converted,
        toUnit: toUnit,
        reason: reason.isNotEmpty ? reason : 'unit conversion',
      );
    }
    return converted;
  }

  /// Convert length from one unit to another.
  double? convertLength(
    dynamic value,
    String fromUnit,
    String toUnit, {
    UnitConversionLog? log,
    String? symbol,
    String reason = '',
  }) {
    final coerced = coerceDouble(value, context: 'UnitConverter.convertLength');
    if (coerced == null) return null;
    if (fromUnit == toUnit) return coerced;

    // Convert to meters first
    double meters = coerced;
    switch (fromUnit) {
      case 'm':
        meters = coerced;
        break;
      case 'cm':
        meters = coerced / 100;
        break;
      case 'nm':
        meters = coerced / 1e9;
        break;
      case 'um':
      case 'Aćm':
        meters = coerced / 1e6;
        break;
      default:
        return null;
    }

    // Convert from meters to target
    double? converted;
    switch (toUnit) {
      case 'm':
        converted = meters;
        break;
      case 'cm':
        converted = meters * 100;
        break;
      case 'nm':
        converted = meters * 1e9;
        break;
      case 'um':
      case 'Aćm':
        converted = meters * 1e6;
        break;
      default:
        return null;
    }

    if (converted == null) return null;
    final activeLog = log ?? this.log;
    if (activeLog != null && (converted != coerced || fromUnit != toUnit)) {
      final sym = symbol ?? toUnit;
      activeLog.add(
        symbol: sym,
        fromValue: coerced,
        fromUnit: fromUnit,
        toValue: converted,
        toUnit: toUnit,
        reason: reason.isNotEmpty ? reason : 'unit conversion',
      );
    }
    return converted;
  }

  /// Convert density from one unit to another (e.g., m^-3 to cm^-3).
  double? convertDensity(
    dynamic value,
    String fromUnit,
    String toUnit, {
    UnitConversionLog? log,
    String? symbol,
    String reason = '',
  }) {
    final coerced = coerceDouble(value, context: 'UnitConverter.convertDensity');
    if (coerced == null) return null;
    if (fromUnit == toUnit) return coerced;

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
    final converted = coerced * math.pow(baseConversion, fromPower).toDouble();
    final activeLog = log ?? this.log;
    if (activeLog != null && (converted != coerced || fromUnit != toUnit)) {
      final sym = symbol ?? toUnit;
      activeLog.add(
        symbol: sym,
        fromValue: coerced,
        fromUnit: fromUnit,
        toValue: converted,
        toUnit: toUnit,
        reason: reason.isNotEmpty ? reason : 'unit conversion',
      );
    }
    return converted;
  }

  /// Convert wavevector from one unit to another (e.g., 1/m to 1/cm).
  double? convertWavevector(
    dynamic value,
    String fromUnit,
    String toUnit, {
    UnitConversionLog? log,
    String? symbol,
    String reason = '',
  }) {
    return convertDensity(
      value,
      fromUnit,
      toUnit,
      log: log,
      symbol: symbol,
      reason: reason,
    );
  }
}
