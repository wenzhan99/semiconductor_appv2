import 'package:flutter/material.dart';

/// Configuration for a standardized graph page.
/// 
/// Provides data to drive:
/// - Point Inspector panel
/// - Animation Parameters panel
/// - Insights & Pins panel
/// - Controls panel
/// 
/// The chart widget is provided separately to StandardGraphPageScaffold.
class GraphConfig {
  /// Optional title for the graph page (displayed in header)
  final String? title;
  
  /// Optional subtitle for the graph page
  final String? subtitle;
  
  /// Optional main equation to display in header
  final String? mainEquation;
  
  /// Configuration for the Point Inspector panel
  final PointInspectorConfig? pointInspector;
  
  /// Configuration for the Animation Parameters panel
  final AnimationConfig? animation;
  
  /// Configuration for the Insights & Pins panel
  final InsightsConfig? insights;
  
  /// Configuration for the Controls panel
  final ControlsConfig controls;
  
  /// Optional readouts to display (computed values, constants, etc.)
  final List<ReadoutItem>? readouts;

  const GraphConfig({
    this.title,
    this.subtitle,
    this.mainEquation,
    this.pointInspector,
    this.animation,
    this.insights,
    required this.controls,
    this.readouts,
  });
}

/// Configuration for Point Inspector panel
class PointInspectorConfig {
  /// Whether point inspector is enabled
  final bool enabled;
  
  /// Message to show when no point is selected
  final String emptyMessage;
  
  /// Builder that returns list of strings to display for selected point
  final List<String> Function()? builder;
  
  /// Custom widget builder for selected point (overrides builder if provided)
  final Widget Function()? customBuilder;
  
  /// Callback to clear selection
  final VoidCallback? onClear;

  /// Whether the current inspector content represents a pinned snapshot
  /// (true) or live/hover state (false). Used only for UI labeling; no
  /// behavioral effect.
  final bool isPinned;

  const PointInspectorConfig({
    this.enabled = true,
    this.emptyMessage = 'Tap or hover over the chart to inspect a point.',
    this.builder,
    this.customBuilder,
    this.onClear,
    this.isPinned = false,
  });
}

/// Configuration for Animation Parameters panel
class AnimationConfig {
  /// List of animatable parameters
  final List<AnimatableParameter> parameters;
  
  /// Currently selected parameter
  final String selectedParameterId;
  
  /// Callback when parameter selection changes
  final void Function(String parameterId) onParameterSelected;
  
  /// Global animation state
  final AnimationState state;
  
  /// Callbacks for animation controls
  final AnimationCallbacks callbacks;

  const AnimationConfig({
    required this.parameters,
    required this.selectedParameterId,
    required this.onParameterSelected,
    required this.state,
    required this.callbacks,
  });
}

/// Represents a single animatable parameter
class AnimatableParameter {
  /// Unique identifier for this parameter
  final String id;
  
  /// LaTeX label for dropdown (e.g., r'V_a (Applied Voltage)')
  final String label;
  
  /// Pure LaTeX symbol (e.g., r'V_a')
  final String symbol;
  
  /// Unit (e.g., 'V', 'eV', 'cm^{-3}')
  final String unit;
  
  /// Current value
  final double currentValue;
  
  /// Range min
  final double rangeMin;
  
  /// Range max
  final double rangeMax;
  
  /// Absolute min (constraint)
  final double absoluteMin;
  
  /// Absolute max (constraint)
  final double absoluteMax;
  
  /// Whether this parameter is enabled for animation (checkbox)
  final bool enabled;
  
  /// Callback when enabled state changes
  final void Function(bool enabled)? onEnabledChanged;
  
  /// Callback when current value changes
  final void Function(double value) onValueChanged;
  
  /// Callback when range changes
  final void Function(double min, double max) onRangeChanged;
  
  /// Optional physics note about this parameter
  final String? physicsNote;

  const AnimatableParameter({
    required this.id,
    required this.label,
    required this.symbol,
    required this.unit,
    required this.currentValue,
    required this.rangeMin,
    required this.rangeMax,
    required this.absoluteMin,
    required this.absoluteMax,
    this.enabled = false,
    this.onEnabledChanged,
    required this.onValueChanged,
    required this.onRangeChanged,
    this.physicsNote,
  });
  
  AnimatableParameter copyWith({
    String? id,
    String? label,
    String? symbol,
    String? unit,
    double? currentValue,
    double? rangeMin,
    double? rangeMax,
    double? absoluteMin,
    double? absoluteMax,
    bool? enabled,
    void Function(bool)? onEnabledChanged,
    void Function(double)? onValueChanged,
    void Function(double, double)? onRangeChanged,
    String? physicsNote,
  }) {
    return AnimatableParameter(
      id: id ?? this.id,
      label: label ?? this.label,
      symbol: symbol ?? this.symbol,
      unit: unit ?? this.unit,
      currentValue: currentValue ?? this.currentValue,
      rangeMin: rangeMin ?? this.rangeMin,
      rangeMax: rangeMax ?? this.rangeMax,
      absoluteMin: absoluteMin ?? this.absoluteMin,
      absoluteMax: absoluteMax ?? this.absoluteMax,
      enabled: enabled ?? this.enabled,
      onEnabledChanged: onEnabledChanged ?? this.onEnabledChanged,
      onValueChanged: onValueChanged ?? this.onValueChanged,
      onRangeChanged: onRangeChanged ?? this.onRangeChanged,
      physicsNote: physicsNote ?? this.physicsNote,
    );
  }
}

/// Global animation state
class AnimationState {
  /// Whether animation is currently playing
  final bool isPlaying;
  
  /// Speed multiplier (0.5x, 1.0x, 2.0x, etc.)
  final double speed;
  
  /// Whether reverse direction is enabled
  final bool reverse;
  
  /// Whether loop (wrap) is enabled
  final bool loop;
  
  /// Optional progress (0-1) for progress indicator
  final double? progress;

  const AnimationState({
    this.isPlaying = false,
    this.speed = 1.0,
    this.reverse = false,
    this.loop = false,
    this.progress,
  });
  
  AnimationState copyWith({
    bool? isPlaying,
    double? speed,
    bool? reverse,
    bool? loop,
    double? progress,
  }) {
    return AnimationState(
      isPlaying: isPlaying ?? this.isPlaying,
      speed: speed ?? this.speed,
      reverse: reverse ?? this.reverse,
      loop: loop ?? this.loop,
      progress: progress ?? this.progress,
    );
  }
}

/// Callbacks for animation controls
class AnimationCallbacks {
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onRestart;
  final void Function(double speed) onSpeedChanged;
  final void Function(bool reverse) onReverseChanged;
  final void Function(bool loop) onLoopChanged;

  const AnimationCallbacks({
    required this.onPlay,
    required this.onPause,
    required this.onRestart,
    required this.onSpeedChanged,
    required this.onReverseChanged,
    required this.onLoopChanged,
  });
}

/// Configuration for Insights & Pins panel
class InsightsConfig {
  /// Dynamic observations (change based on current state)
  final List<String>? dynamicObservations;
  
  /// Static observations (always shown)
  final List<String>? staticObservations;
  
  /// Title for dynamic section
  final String? dynamicTitle;
  
  /// Title for static section
  final String? staticTitle;
  
  /// Optional custom header widget
  final Widget? customHeader;

  const InsightsConfig({
    this.dynamicObservations,
    this.staticObservations,
    this.dynamicTitle = 'Current Configuration',
    this.staticTitle,
    this.customHeader,
  });
}

/// Configuration for Controls panel
class ControlsConfig {
  /// List of control widgets (sliders, switches, buttons, etc.)
  final List<Widget> children;
  
  /// Whether controls panel is collapsible
  final bool collapsible;
  
  /// Whether controls panel is initially expanded
  final bool initiallyExpanded;

  const ControlsConfig({
    required this.children,
    this.collapsible = true,
    this.initiallyExpanded = true,
  });
}

/// Readout item (for optional readouts display)
class ReadoutItem {
  /// Label (supports LaTeX with $ delimiters)
  final String label;
  
  /// Value as string (can include units)
  final String value;
  
  /// Whether to bold the value
  final bool boldValue;
  
  /// Optional color for value
  final Color? valueColor;
  
  /// Optional subtitle/description
  final String? subtitle;

  const ReadoutItem({
    required this.label,
    required this.value,
    this.boldValue = false,
    this.valueColor,
    this.subtitle,
  });
}
