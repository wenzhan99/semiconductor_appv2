import 'package:equatable/equatable.dart';

import 'physical_constant.dart';

/// Full constants payload (table) loaded from JSON.
class PhysicalConstantsTable extends Equatable {
  final String source; // e.g. "EE2103 Appendix B"
  final String type;   // e.g. "physical_constants"
  final List<PhysicalConstant> constants;

  const PhysicalConstantsTable({
    required this.source,
    required this.type,
    required this.constants,
  });

  factory PhysicalConstantsTable.fromJson(Map<String, dynamic> json) {
    final list = (json['constants'] as List<dynamic>? ?? const [])
        .map((e) => PhysicalConstant.fromJson(e as Map<String, dynamic>))
        .toList();

    return PhysicalConstantsTable(
      source: (json['source'] as String?) ?? 'unknown',
      type: (json['type'] as String?) ?? 'unknown',
      constants: list,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'type': type,
      'constants': constants.map((c) => c.toJson()).toList(),
    };
  }

  /// Find constant by its stable id.
  PhysicalConstant? byId(String id) {
    for (final c in constants) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Find constant by symbol or alias (e.g., "q" or "e").
  PhysicalConstant? bySymbol(String symbolOrAlias) {
    for (final c in constants) {
      if (c.symbol == symbolOrAlias) return c;
      if (c.aliases.contains(symbolOrAlias)) return c;
    }
    return null;
  }

  @override
  List<Object?> get props => [source, type, constants];
}



