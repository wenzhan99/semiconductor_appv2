import 'package:flutter/material.dart';

import 'latex_text.dart';

/// Shared metrics and widgets for formula input UI.
class FormulaUiTheme {
  static const double fieldHeight = 52;
  static const double unitMinWidth = 112;
  static const double dropdownWidth = 120;
  static const EdgeInsets contentPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 14);
  static const BorderRadius fieldRadius = BorderRadius.all(Radius.circular(8));
  // Step-by-step typography (universally applied across all formulas)
  static const double stepSectionTitleFontSize = 17; // "Step-by-step working"
  static const double stepHeaderFontSize = 16; // Step 1/2/3/4 headers
  static const double stepBodyFontSize = 17; // descriptive lines
  static const double stepMathFontSize = 20; // equations
  static const double stepMathScale = 1.2; // LaTeX scale multiplier

  // Step title styles
  static TextStyle stepSectionTitleStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.titleSmall;
    return (base ?? const TextStyle()).copyWith(
      fontSize: stepSectionTitleFontSize,
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle? inputTextStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15);

  static TextStyle? unitTextStyle(BuildContext context) =>
      inputTextStyle(context)?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
      );

  static TextStyle stepHeaderTextStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    return (base ?? const TextStyle()).copyWith(
      fontSize: stepHeaderFontSize,
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle stepBodyTextStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    return (base ?? const TextStyle()).copyWith(
      fontSize: stepBodyFontSize,
      fontWeight: FontWeight.w400,
      height: 1.35,
    );
  }

  static TextStyle stepMathTextStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    return (base ?? const TextStyle()).copyWith(
      fontSize: stepMathFontSize,
      fontWeight: FontWeight.w400,
      height: 1.2,
    );
  }

  static InputDecoration inputDecoration(
    BuildContext context, {
    Widget? label,
    String? labelText,
    Widget? prefix,
    String? hintText,
  }) {
    return InputDecoration(
      label: label,
      labelText: labelText,
      prefix: prefix,
      hintText: hintText,
      border: const OutlineInputBorder(
        borderRadius: fieldRadius,
      ),
      contentPadding: contentPadding,
      isDense: true,
    );
  }
}

class UnitCell extends StatelessWidget {
  final String latex;
  final Color? backgroundColor;

  const UnitCell({
    super.key,
    required this.latex,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: FormulaUiTheme.unitMinWidth,
        minHeight: FormulaUiTheme.fieldHeight,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: FormulaUiTheme.fieldRadius,
          color: backgroundColor ??
              Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
        child: Center(
          child: LatexText(
            latex,
            style: FormulaUiTheme.unitTextStyle(context),
          ),
        ),
      ),
    );
  }
}

class UnitDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double? width;

  const UnitDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? FormulaUiTheme.dropdownWidth,
      height: FormulaUiTheme.fieldHeight,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: FormulaUiTheme.inputDecoration(
          context,
          hintText: null,
        ),
        isDense: true,
        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
        items: items,
        style: FormulaUiTheme.unitTextStyle(context),
        onChanged: onChanged,
      ),
    );
  }
}
