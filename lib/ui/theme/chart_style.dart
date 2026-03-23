import 'package:flutter/material.dart';

@immutable
class ChartStyle {
  final double leftReservedSize;
  final double bottomReservedSize;
  final EdgeInsets tickPadding;
  final TextStyle tickTextStyle;

  const ChartStyle({
    required this.leftReservedSize,
    required this.bottomReservedSize,
    required this.tickPadding,
    required this.tickTextStyle,
  });

  factory ChartStyle.fromTheme(ThemeData theme) {
    final base = theme.textTheme.bodySmall ?? const TextStyle(fontSize: 11);
    final color = theme.colorScheme.onSurfaceVariant;
    return ChartStyle(
      leftReservedSize: 56,
      bottomReservedSize: 44,
      tickPadding: const EdgeInsets.only(top: 6, right: 8),
      tickTextStyle: base.copyWith(
        fontSize: 11,
        color: color,
        height: 1.1,
      ),
    );
  }
}

extension ChartStyleContext on BuildContext {
  ChartStyle get chartStyle => ChartStyle.fromTheme(Theme.of(this));
}

