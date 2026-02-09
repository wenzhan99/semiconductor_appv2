import 'dart:math' as math;

/// Manages zoom and pan state for graph viewports.
/// 
/// Usage:
/// ```dart
/// final viewport = ViewportState(
///   defaultMinX: -1.0,
///   defaultMaxX: 1.0,
///   defaultMinY: -1.0,
///   defaultMaxY: 1.0,
/// );
/// 
/// // Zoom in
/// viewport.zoom(0.2);
/// 
/// // Pan
/// viewport.pan(dx: 0.1, dy: 0.05);
/// 
/// // Reset
/// viewport.reset();
/// 
/// // Use in chart
/// LineChartData(
///   minX: viewport.minX,
///   maxX: viewport.maxX,
///   minY: viewport.minY,
///   maxY: viewport.maxY,
/// )
/// ```
class ViewportState {
  // Default viewport bounds (original view)
  final double defaultMinX;
  final double defaultMaxX;
  final double defaultMinY;
  final double defaultMaxY;

  // Zoom constraints
  final double minZoom;
  final double maxZoom;

  // Current state
  double _zoomScale = 1.0;
  double _panOffsetX = 0.0;
  double _panOffsetY = 0.0;

  ViewportState({
    required this.defaultMinX,
    required this.defaultMaxX,
    required this.defaultMinY,
    required this.defaultMaxY,
    this.minZoom = 0.5,
    this.maxZoom = 5.0,
  });

  double get zoomScale => _zoomScale;
  double get panOffsetX => _panOffsetX;
  double get panOffsetY => _panOffsetY;

  /// Current visible X range
  double get minX {
    final centerX = (defaultMinX + defaultMaxX) / 2;
    final rangeX = (defaultMaxX - defaultMinX) / _zoomScale;
    return centerX - rangeX / 2 + _panOffsetX;
  }

  double get maxX {
    final centerX = (defaultMinX + defaultMaxX) / 2;
    final rangeX = (defaultMaxX - defaultMinX) / _zoomScale;
    return centerX + rangeX / 2 + _panOffsetX;
  }

  /// Current visible Y range
  double get minY {
    final centerY = (defaultMinY + defaultMaxY) / 2;
    final rangeY = (defaultMaxY - defaultMinY) / _zoomScale;
    return centerY - rangeY / 2 + _panOffsetY;
  }

  double get maxY {
    final centerY = (defaultMinY + defaultMaxY) / 2;
    final rangeY = (defaultMaxY - defaultMinY) / _zoomScale;
    return centerY + rangeY / 2 + _panOffsetY;
  }

  /// Zoom in (positive delta) or out (negative delta)
  void zoom(double delta) {
    _zoomScale = (_zoomScale + delta).clamp(minZoom, maxZoom);
  }

  /// Pan by offset
  void pan({double dx = 0.0, double dy = 0.0}) {
    _panOffsetX += dx;
    _panOffsetY += dy;
  }

  /// Reset to default view
  void reset() {
    _zoomScale = 1.0;
    _panOffsetX = 0.0;
    _panOffsetY = 0.0;
  }

  /// Check if currently zoomed or panned (not at default)
  bool get isModified => _zoomScale != 1.0 || _panOffsetX != 0.0 || _panOffsetY != 0.0;

  /// Fit bounds to data (optional feature for auto-fit)
  void fitToData({
    required double dataMinX,
    required double dataMaxX,
    required double dataMinY,
    required double dataMaxY,
    double padding = 0.1,
  }) {
    // Calculate zoom to fit data within viewport
    final xRangeData = dataMaxX - dataMinX;
    final yRangeData = dataMaxY - dataMinY;
    final xRangeDefault = defaultMaxX - defaultMinX;
    final yRangeDefault = defaultMaxY - defaultMinY;

    // Apply padding
    final xPad = xRangeData * padding;
    final yPad = yRangeData * padding;

    final xZoom = xRangeDefault / (xRangeData + 2 * xPad);
    final yZoom = yRangeDefault / (yRangeData + 2 * yPad);

    _zoomScale = math.min(xZoom, yZoom).clamp(minZoom, maxZoom);

    // Center on data
    final dataCenterX = (dataMinX + dataMaxX) / 2;
    final dataCenterY = (dataMinY + dataMaxY) / 2;
    final defaultCenterX = (defaultMinX + defaultMaxX) / 2;
    final defaultCenterY = (defaultMinY + defaultMaxY) / 2;

    _panOffsetX = dataCenterX - defaultCenterX;
    _panOffsetY = dataCenterY - defaultCenterY;
  }
}
