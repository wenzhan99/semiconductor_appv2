import 'package:equatable/equatable.dart';

/// Constant used in a formula.
class FormulaConstant extends Equatable {
  final String key;
  final String source; // e.g., "derived", "physical_constants"
  final String? definition; // e.g., "h/(2*pi)"
  final String? note; // Optional note/description

  const FormulaConstant({
    required this.key,
    required this.source,
    this.definition,
    this.note,
  });

  factory FormulaConstant.fromJson(Map<String, dynamic> json) {
    return FormulaConstant(
      key: json['key'] as String,
      source: json['source'] as String,
      definition: json['definition'] as String?,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'source': source,
      if (definition != null) 'definition': definition,
      if (note != null) 'note': note,
    };
  }

  @override
  List<Object?> get props => [key, source, definition, note];
}

