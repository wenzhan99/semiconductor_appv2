import 'package:equatable/equatable.dart';

/// A category grouping of related formulas.
class FormulaCategory extends Equatable {
  final String id;
  final String name;
  final List<String> formulaIds;

  const FormulaCategory({
    required this.id,
    required this.name,
    required this.formulaIds,
  });

  factory FormulaCategory.fromJson(Map<String, dynamic> json) {
    return FormulaCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      formulaIds: (json['formula_ids'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'formula_ids': formulaIds,
    };
  }

  @override
  List<Object?> get props => [id, name, formulaIds];
}
