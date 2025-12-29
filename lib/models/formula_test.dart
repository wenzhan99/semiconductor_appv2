import 'package:equatable/equatable.dart';

/// Test case for a formula.
class FormulaTest extends Equatable {
  final Map<String, dynamic> given;
  final String solveFor;
  final Map<String, dynamic> expect;
  final Map<String, dynamic>? tolerance;

  const FormulaTest({
    required this.given,
    required this.solveFor,
    required this.expect,
    this.tolerance,
  });

  factory FormulaTest.fromJson(Map<String, dynamic> json) {
    return FormulaTest(
      given: (json['given'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v),
      ),
      solveFor: json['solve_for'] as String,
      expect: (json['expect'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v),
      ),
      tolerance: json['tolerance'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'given': given,
      'solve_for': solveFor,
      'expect': expect,
      if (tolerance != null) 'tolerance': tolerance,
    };
  }

  @override
  List<Object?> get props => [given, solveFor, expect, tolerance];
}



