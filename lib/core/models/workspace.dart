import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'unit_preferences.dart';

const _uuid = Uuid();

/// Source of a symbol value.
enum SymbolSource {
  user,
  material,
  computed;

  static SymbolSource fromJson(String jsonValue) {
    return SymbolSource.values.firstWhere(
      (e) => e.name == jsonValue,
      orElse: () => SymbolSource.user,
    );
  }

  String toJson() => name;
}

/// Status of a workspace panel.
enum PanelStatus {
  solved,
  needsInputs,
  error,
  stale;

  static PanelStatus fromJson(String jsonValue) {
    return PanelStatus.values.firstWhere(
      (e) => e.name == jsonValue,
      orElse: () => PanelStatus.needsInputs,
    );
  }

  String toJson() => name;
}

/// A symbol value with unit and source information.
class SymbolValue extends Equatable {
  final double value;
  final String unit;
  final SymbolSource source;

  const SymbolValue({
    required this.value,
    required this.unit,
    required this.source,
  });

  factory SymbolValue.fromJson(Map<String, dynamic> json) {
    return SymbolValue(
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      source: SymbolSource.fromJson(json['source'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'unit': unit,
      'source': source.toJson(),
    };
  }

  @override
  List<Object?> get props => [value, unit, source];
}

/// Configuration for a graph visualization.
class GraphConfig extends Equatable {
  final String id;
  final String title;
  final String xAxis;
  final String yAxis;
  final Map<String, dynamic> parameters;

  const GraphConfig({
    required this.id,
    required this.title,
    required this.xAxis,
    required this.yAxis,
    required this.parameters,
  });

  factory GraphConfig.fromJson(Map<String, dynamic> json) {
    return GraphConfig(
      id: json['id'] as String,
      title: json['title'] as String,
      xAxis: json['x_axis'] as String,
      yAxis: json['y_axis'] as String,
      parameters: (json['parameters'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(k, v)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'x_axis': xAxis,
      'y_axis': yAxis,
      'parameters': parameters,
    };
  }

  @override
  List<Object?> get props => [id, title, xAxis, yAxis, parameters];
}

/// A panel in the workspace representing a formula calculation.
class WorkspacePanel extends Equatable {
  final String id;
  final String formulaId;
  final Map<String, SymbolValue> overrides;
  final Map<String, SymbolValue> outputs;
  final PanelStatus status;
  final int orderIndex;

  const WorkspacePanel({
    required this.id,
    required this.formulaId,
    required this.overrides,
    required this.outputs,
    required this.status,
    required this.orderIndex,
  });

  factory WorkspacePanel.create(String formulaId, int orderIndex) {
    return WorkspacePanel(
      id: _uuid.v4(),
      formulaId: formulaId,
      overrides: const {},
      outputs: const {},
      status: PanelStatus.needsInputs,
      orderIndex: orderIndex,
    );
  }

  factory WorkspacePanel.fromJson(Map<String, dynamic> json) {
    return WorkspacePanel(
      id: json['id'] as String,
      formulaId: json['formula_id'] as String,
      overrides: (json['overrides'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(
                k,
                SymbolValue.fromJson(v as Map<String, dynamic>),
              )),
      outputs: (json['outputs'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(
                k,
                SymbolValue.fromJson(v as Map<String, dynamic>),
              )),
      status: PanelStatus.fromJson(json['status'] as String? ?? 'needsInputs'),
      orderIndex: json['order_index'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'formula_id': formulaId,
      'overrides': overrides.map((k, v) => MapEntry(k, v.toJson())),
      'outputs': outputs.map((k, v) => MapEntry(k, v.toJson())),
      'status': status.toJson(),
      'order_index': orderIndex,
    };
  }

  WorkspacePanel copyWith({
    String? id,
    String? formulaId,
    Map<String, SymbolValue>? overrides,
    Map<String, SymbolValue>? outputs,
    PanelStatus? status,
    int? orderIndex,
  }) {
    return WorkspacePanel(
      id: id ?? this.id,
      formulaId: formulaId ?? this.formulaId,
      overrides: overrides ?? this.overrides,
      outputs: outputs ?? this.outputs,
      status: status ?? this.status,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  @override
  List<Object?> get props => [id, formulaId, overrides, outputs, status, orderIndex];
}

/// Main workspace model storing user inputs, panels, and preferences.
class Workspace extends Equatable {
  final int schemaVersion;
  final String id;
  final String name;
  final Map<String, SymbolValue> globals;
  final List<WorkspacePanel> panels;
  final List<GraphConfig> graphs;
  final UnitSystem unitSystem;
  final TemperatureUnit temperatureUnit;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Workspace({
    required this.schemaVersion,
    required this.id,
    required this.name,
    required this.globals,
    required this.panels,
    required this.graphs,
    required this.unitSystem,
    required this.temperatureUnit,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Workspace.create(String name) {
    final now = DateTime.now();
    return Workspace(
      schemaVersion: 1,
      id: _uuid.v4(),
      name: name,
      globals: const {},
      panels: const [],
      graphs: const [],
      unitSystem: UnitSystem.cm,
      temperatureUnit: TemperatureUnit.kelvin,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      schemaVersion: json['schema_version'] as int? ?? 1,
      id: json['id'] as String,
      name: json['name'] as String,
      globals: (json['globals'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(
                k,
                SymbolValue.fromJson(v as Map<String, dynamic>),
              )),
      panels: (json['panels'] as List<dynamic>? ?? const [])
          .map((e) => WorkspacePanel.fromJson(e as Map<String, dynamic>))
          .toList(),
      graphs: (json['graphs'] as List<dynamic>? ?? const [])
          .map((e) => GraphConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      unitSystem: UnitSystem.fromJson(json['unit_system'] as String? ?? 'cm'),
      temperatureUnit: TemperatureUnit.fromJson(
        json['temperature_unit'] as String? ?? 'kelvin',
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'id': id,
      'name': name,
      'globals': globals.map((k, v) => MapEntry(k, v.toJson())),
      'panels': panels.map((p) => p.toJson()).toList(),
      'graphs': graphs.map((g) => g.toJson()).toList(),
      'unit_system': unitSystem.toJson(),
      'temperature_unit': temperatureUnit.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Workspace copyWith({
    String? name,
    Map<String, SymbolValue>? globals,
    List<WorkspacePanel>? panels,
    List<GraphConfig>? graphs,
    UnitSystem? unitSystem,
    TemperatureUnit? temperatureUnit,
  }) {
    return Workspace(
      schemaVersion: schemaVersion,
      id: id,
      name: name ?? this.name,
      globals: globals ?? this.globals,
      panels: panels ?? this.panels,
      graphs: graphs ?? this.graphs,
      unitSystem: unitSystem ?? this.unitSystem,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        schemaVersion,
        id,
        name,
        globals,
        panels,
        graphs,
        unitSystem,
        temperatureUnit,
        createdAt,
        updatedAt,
      ];
}

