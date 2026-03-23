import 'package:flutter/material.dart';

/// Mixin for graph pages that provides standard chart rebuild management.
/// 
/// Usage:
/// ```dart
/// class _MyGraphState extends State<MyGraph> with GraphController {
///   double _parameter = 1.0;
///   
///   void _onParameterChanged(double value) {
///     setState(() {
///       _parameter = value;
///       bumpChart(); // Force chart rebuild
///     });
///   }
///   
///   @override
///   Widget build(BuildContext context) {
///     return LineChart(
///       key: ValueKey('my-graph-$chartVersion'), // Use chartVersion in key
///       // ... chart data
///     );
///   }
/// }
/// ```
mixin GraphController<T extends StatefulWidget> on State<T> {
  /// Version number incremented on every chart rebuild.
  /// Use this in your chart's ValueKey to force rebuild.
  int chartVersion = 0;

  /// Increment chart version to force a rebuild.
  /// Call this whenever parameters change that should redraw the chart.
  void bumpChart() {
    chartVersion++;
  }

  /// Update state and bump chart in one call.
  /// This is a convenience method for the common pattern of:
  /// setState(() { ... }); bumpChart();
  void updateChart(VoidCallback update) {
    setState(() {
      update();
      bumpChart();
    });
  }
}
