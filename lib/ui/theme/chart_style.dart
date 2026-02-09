import 'dart:ui';
import 'package:flutter/material.dart';

/// Shared chart styling for consistent typography and spacing across all graphs.
/// 
/// Usage:
/// ```dart
/// final chartStyle = AppChartStyle.of(context);
/// 
/// AxisTitles(
///   axisNameWidget: Text('E (eV)', style: chartStyle.axisTitleTextStyle),
///   sideTitles: SideTitles(
///     showTitles: true,
///     reservedSize: chartStyle.leftReservedSize,
///     getTitlesWidget: (value, meta) {
///       return Text(
///         value.toStringAsFixed(1),
///         style: chartStyle.tickTextStyle,
///       );
///     },
///   ),
/// )
/// ```
class AppChartStyle {
  // Text styles
  final TextStyle axisTitleTextStyle;
  final TextStyle tickTextStyle;
  final TextStyle legendTextStyle;
  final TextStyle tooltipTextStyle;
  final TextStyle tooltipTitleTextStyle;
  final TextStyle panelTitleTextStyle;
  final TextStyle panelBodyTextStyle;

  // Layout constants
  final double leftReservedSize;
  final double bottomReservedSize;
  final double topReservedSize;
  final double rightReservedSize;

  // Padding
  final EdgeInsets tickPadding;
  final EdgeInsets axisTitlePadding;
  final EdgeInsets legendItemPadding;

  // Spacing thresholds
  final double minTickSpacingPx;
  final double minLegendItemSpacing;

  const AppChartStyle({
    required this.axisTitleTextStyle,
    required this.tickTextStyle,
    required this.legendTextStyle,
    required this.tooltipTextStyle,
    required this.tooltipTitleTextStyle,
    required this.panelTitleTextStyle,
    required this.panelBodyTextStyle,
    required this.leftReservedSize,
    required this.bottomReservedSize,
    required this.topReservedSize,
    required this.rightReservedSize,
    required this.tickPadding,
    required this.axisTitlePadding,
    required this.legendItemPadding,
    required this.minTickSpacingPx,
    required this.minLegendItemSpacing,
  });

  /// Get the chart style from the current theme context.
  static AppChartStyle of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppChartStyle(
      // Axis title: medium-large, bold
      axisTitleTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
        letterSpacing: 0.2,
      ),

      // Tick labels: small, regular weight
      tickTextStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),

      // Legend: medium, semi-bold
      legendTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: theme.colorScheme.onSurface,
      ),

      // Tooltip body: medium, regular
      tooltipTextStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: isDark ? Colors.white : Colors.black87,
        height: 1.4,
      ),

      // Tooltip title: medium, bold
      tooltipTitleTextStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : Colors.black87,
      ),

      // Panel title: large, bold
      panelTitleTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),

      // Panel body: medium, regular
      panelBodyTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: theme.colorScheme.onSurface,
        height: 1.4,
      ),

      // Reserved sizes for axis titles and tick labels
      leftReservedSize: 56,
      bottomReservedSize: 36,
      topReservedSize: 24,
      rightReservedSize: 24,

      // Padding
      tickPadding: const EdgeInsets.all(4),
      axisTitlePadding: const EdgeInsets.all(8),
      legendItemPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),

      // Spacing thresholds
      minTickSpacingPx: 40, // Minimum pixels between tick labels
      minLegendItemSpacing: 12,
    );
  }

  /// Create a custom chart style with specific overrides.
  AppChartStyle copyWith({
    TextStyle? axisTitleTextStyle,
    TextStyle? tickTextStyle,
    TextStyle? legendTextStyle,
    TextStyle? tooltipTextStyle,
    TextStyle? tooltipTitleTextStyle,
    TextStyle? panelTitleTextStyle,
    TextStyle? panelBodyTextStyle,
    double? leftReservedSize,
    double? bottomReservedSize,
    double? topReservedSize,
    double? rightReservedSize,
    EdgeInsets? tickPadding,
    EdgeInsets? axisTitlePadding,
    EdgeInsets? legendItemPadding,
    double? minTickSpacingPx,
    double? minLegendItemSpacing,
  }) {
    return AppChartStyle(
      axisTitleTextStyle: axisTitleTextStyle ?? this.axisTitleTextStyle,
      tickTextStyle: tickTextStyle ?? this.tickTextStyle,
      legendTextStyle: legendTextStyle ?? this.legendTextStyle,
      tooltipTextStyle: tooltipTextStyle ?? this.tooltipTextStyle,
      tooltipTitleTextStyle: tooltipTitleTextStyle ?? this.tooltipTitleTextStyle,
      panelTitleTextStyle: panelTitleTextStyle ?? this.panelTitleTextStyle,
      panelBodyTextStyle: panelBodyTextStyle ?? this.panelBodyTextStyle,
      leftReservedSize: leftReservedSize ?? this.leftReservedSize,
      bottomReservedSize: bottomReservedSize ?? this.bottomReservedSize,
      topReservedSize: topReservedSize ?? this.topReservedSize,
      rightReservedSize: rightReservedSize ?? this.rightReservedSize,
      tickPadding: tickPadding ?? this.tickPadding,
      axisTitlePadding: axisTitlePadding ?? this.axisTitlePadding,
      legendItemPadding: legendItemPadding ?? this.legendItemPadding,
      minTickSpacingPx: minTickSpacingPx ?? this.minTickSpacingPx,
      minLegendItemSpacing: minLegendItemSpacing ?? this.minLegendItemSpacing,
    );
  }

  /// Helper to compute safe tick interval based on available space.
  /// 
  /// [axisRangeLogical] is the range in data units (e.g., 10.0 for -5 to +5).
  /// [axisSizePx] is the pixel size of the axis (width for X, height for Y).
  /// [baseInterval] is the desired interval in data units (e.g., 0.5).
  /// 
  /// Returns adjusted interval that ensures labels don't overlap.
  double safeTickInterval({
    required double axisRangeLogical,
    required double axisSizePx,
    required double baseInterval,
  }) {
    if (axisSizePx <= 0 || axisRangeLogical <= 0) return baseInterval;

    // How many ticks would baseInterval produce?
    final numTicks = (axisRangeLogical / baseInterval).ceil();
    if (numTicks <= 1) return baseInterval;

    // Pixel spacing between ticks
    final spacingPx = axisSizePx / numTicks;

    // If too dense, increase interval
    if (spacingPx < minTickSpacingPx) {
      final factor = (minTickSpacingPx / spacingPx).ceil();
      return baseInterval * factor;
    }

    return baseInterval;
  }

  /// Helper to decide if a tick label should be shown (for manual filtering).
  /// 
  /// [value] is the tick value.
  /// [interval] is the tick interval.
  /// [skipFactor] determines how many ticks to skip (e.g., 2 = show every other).
  bool shouldShowTick(double value, double interval, {int skipFactor = 1}) {
    if (skipFactor <= 1) return true;
    final index = (value / interval).round();
    return index % skipFactor == 0;
  }
}

/// Extension to easily access chart style from BuildContext.
extension ChartStyleContext on BuildContext {
  AppChartStyle get chartStyle => AppChartStyle.of(this);
}
