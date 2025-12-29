import 'package:equatable/equatable.dart';

/// Variable definition for a formula.
class FormulaVariable extends Equatable {
  final String key;
  final String name;
  final String siUnit;
  final List<String> preferredUnits;
  final Map<String, dynamic>? constraints;

  const FormulaVariable({
    required this.key,
    required this.name,
    required this.siUnit,
    required this.preferredUnits,
    this.constraints,
  });

  factory FormulaVariable.fromJson(Map<String, dynamic> json) {
    return FormulaVariable(
      key: json['key'] as String,
      name: json['name'] as String,
      siUnit: json['si_unit'] as String,
      preferredUnits: (json['preferred_units'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      constraints: json['constraints'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
      'si_unit': siUnit,
      'preferred_units': preferredUnits,
      if (constraints != null) 'constraints': constraints,
    };
  }

  @override
  List<Object?> get props => [key, name, siUnit, preferredUnits, constraints];
}



