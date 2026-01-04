import 'package:equatable/equatable.dart';

import '../utils/parse_utils.dart';

/// One physical constant entry from the constants table JSON.
class PhysicalConstant extends Equatable {
  final String id; // stable key (snake_case)
  final String name; // human label
  final String symbol; // canonical symbol key (e.g., "eps_0", "mu_0", "q")
  final List<String> aliases; // optional alternative symbols (e.g., ["e"])
  final double value; // numeric value (SI unless otherwise stated by unit)
  final String unit; // unit string (e.g., "F/m", "J*s")
  final String? category; // optional grouping
  final String? expression; // optional "4*pi*1e-7" for documentation
  final String? note; // optional note
  final String? definition; // optional definition (e.g., "k*T/q")
  final double? assumedTemperatureK; // used if definition assumes T

  const PhysicalConstant({
    required this.id,
    required this.name,
    required this.symbol,
    required this.aliases,
    required this.value,
    required this.unit,
    this.category,
    this.expression,
    this.note,
    this.definition,
    this.assumedTemperatureK,
  });

  factory PhysicalConstant.fromJson(Map<String, dynamic> json) {
    final parsedValue = coerceDouble(json['value'], context: 'PhysicalConstant.value');
    if (parsedValue == null) {
      throw FormatException(
        'Invalid numeric value for PhysicalConstant ${json['id']}: ${json['value']} (${json['value']?.runtimeType})',
      );
    }
    return PhysicalConstant(
      id: json['id'] as String,
      name: json['name'] as String,
      symbol: json['symbol'] as String,
      aliases: (json['aliases'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      value: parsedValue,
      unit: json['unit'] as String,
      category: json['category'] as String?,
      expression: json['expression'] as String?,
      note: json['note'] as String?,
      definition: json['definition'] as String?,
      assumedTemperatureK: coerceDouble(
        json['assumed_temperature_K'],
        context: 'PhysicalConstant.assumed_temperature_K',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'symbol': symbol,
      'aliases': aliases,
      'value': value,
      'unit': unit,
      if (category != null) 'category': category,
      if (expression != null) 'expression': expression,
      if (note != null) 'note': note,
      if (definition != null) 'definition': definition,
      if (assumedTemperatureK != null) 'assumed_temperature_K': assumedTemperatureK,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        symbol,
        aliases,
        value,
        unit,
        category,
        expression,
        note,
        definition,
        assumedTemperatureK,
      ];
}



