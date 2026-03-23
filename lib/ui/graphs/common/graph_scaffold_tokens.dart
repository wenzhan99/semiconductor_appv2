import 'package:flutter/material.dart';

@immutable
class GraphScaffoldTokens {
  final TextStyle sectionTitle;
  final TextStyle label;
  final TextStyle value;
  final TextStyle hint;
  final TextStyle tooltip;

  final double cardPadding;
  final double cardGap;
  final double rowGap;
  final double rightPanelMinWidth;
  final double rightPanelMaxWidth;
  final double cardRadius;

  const GraphScaffoldTokens({
    required this.sectionTitle,
    required this.label,
    required this.value,
    required this.hint,
    required this.tooltip,
    required this.cardPadding,
    required this.cardGap,
    required this.rowGap,
    required this.rightPanelMinWidth,
    required this.rightPanelMaxWidth,
    required this.cardRadius,
  });

  factory GraphScaffoldTokens.standard(ThemeData theme) {
    final textTheme = theme.textTheme;

    TextStyle base(TextStyle? style) => style ?? const TextStyle();

    return GraphScaffoldTokens(
      sectionTitle: base(textTheme.titleSmall).copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      label: base(textTheme.bodySmall).copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
      value: base(textTheme.bodyMedium).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      hint: base(textTheme.bodySmall).copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.25,
      ),
      tooltip: base(textTheme.bodyMedium).copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      cardPadding: 16,
      cardGap: 12,
      rowGap: 8,
      rightPanelMinWidth: 320,
      rightPanelMaxWidth: 420,
      cardRadius: 14,
    );
  }

  GraphScaffoldTokens copyWith({
    TextStyle? sectionTitle,
    TextStyle? label,
    TextStyle? value,
    TextStyle? hint,
    TextStyle? tooltip,
    double? cardPadding,
    double? cardGap,
    double? rowGap,
    double? rightPanelMinWidth,
    double? rightPanelMaxWidth,
    double? cardRadius,
  }) {
    return GraphScaffoldTokens(
      sectionTitle: sectionTitle ?? this.sectionTitle,
      label: label ?? this.label,
      value: value ?? this.value,
      hint: hint ?? this.hint,
      tooltip: tooltip ?? this.tooltip,
      cardPadding: cardPadding ?? this.cardPadding,
      cardGap: cardGap ?? this.cardGap,
      rowGap: rowGap ?? this.rowGap,
      rightPanelMinWidth: rightPanelMinWidth ?? this.rightPanelMinWidth,
      rightPanelMaxWidth: rightPanelMaxWidth ?? this.rightPanelMaxWidth,
      cardRadius: cardRadius ?? this.cardRadius,
    );
  }

  static GraphScaffoldTokens of(
    BuildContext context, {
    GraphScaffoldTokens? override,
  }) {
    return override ?? GraphScaffoldTokens.standard(Theme.of(context));
  }
}
