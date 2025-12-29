import 'package:equatable/equatable.dart';

import 'formula_constant.dart';
import 'formula_test.dart';
import 'formula_variable.dart';

/// A single formula/equation entry.
class Formula extends Equatable {
  final String id;
  final String name;
  final String equationLatex;
  final String description;
  final List<FormulaVariable>? variables;
  final List<FormulaConstant>? constantsUsed;
  final List<String>? solvableFor;
  final Map<String, String>? compute; // key -> expression
  final List<String>? notes;
  final List<FormulaTest>? tests;
  final int? version;

  const Formula({
    required this.id,
    required this.name,
    required this.equationLatex,
    required this.description,
    this.variables,
    this.constantsUsed,
    this.solvableFor,
    this.compute,
    this.notes,
    this.tests,
    this.version,
  });

  factory Formula.fromJson(Map<String, dynamic> json) {
    List<FormulaVariable>? parsedVars;
    final rawVars = json['variables'];
    if (rawVars is List) {
      if (rawVars.isNotEmpty && rawVars.first is String) {
        // Simple mode: variables: ["E", "k", ...]
        parsedVars = rawVars
            .map((e) => FormulaVariable(
                  key: e.toString(),
                  name: e.toString(),
                  siUnit: '',
                  preferredUnits: const [],
                  constraints: null,
                ))
            .toList();
      } else if (rawVars.isNotEmpty && rawVars.first is Map) {
        // Full mode: variables: [{key: "...", name: "...", ...}]
        parsedVars = rawVars
            .map((e) => FormulaVariable.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList();
      } else {
        parsedVars = [];
      }
    }

    return Formula(
      id: json['id'] as String,
      name: json['name'] as String,
      equationLatex: json['equation_latex'] as String,
      description: (json['description'] as String?) ?? '',
      variables: parsedVars,
      constantsUsed: (json['constants_used'] as List<dynamic>?)
          ?.map((e) => FormulaConstant.fromJson(e as Map<String, dynamic>))
          .toList(),
      solvableFor: (json['solvable_for'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      compute: (json['compute'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      notes: (json['notes'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      tests: (json['tests'] as List<dynamic>?)
          ?.map((e) => FormulaTest.fromJson(e as Map<String, dynamic>))
          .toList(),
      version: json['version'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'equation_latex': equationLatex,
      'description': description,
      if (variables != null) 'variables': variables!.map((v) => v.toJson()).toList(),
      if (constantsUsed != null)
        'constants_used': constantsUsed!.map((c) => c.toJson()).toList(),
      if (solvableFor != null) 'solvable_for': solvableFor,
      if (compute != null) 'compute': compute,
      if (notes != null) 'notes': notes,
      if (tests != null) 'tests': tests!.map((t) => t.toJson()).toList(),
      if (version != null) 'version': version,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        equationLatex,
        description,
        variables,
        constantsUsed,
        solvableFor,
        compute,
        notes,
        tests,
        version,
      ];
}

