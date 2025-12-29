import 'package:semiconductor_appv2/core/solver/step_items.dart';

/// Canonical step template used by all formulas.
/// Enforces the shared headings and limits Step 4 / rounding
/// to a single computed line each.
class UniversalStepTemplate {
  static const String _step1Title = 'Step 1 - Unit Conversion';
  static const String _step2Prefix = 'Step 2 - Rearrange to solve for ';
  static const String _step3Title = 'Step 3 - Substitute known values';
  static const String _step4Title = 'Step 4 - Computed Value';
  static const String _roundingTitle = 'Rounded off to 3 s.f.';

  static List<StepItem> build({
    required String targetLabelLatex,
    required List<String> unitConversionLines,
    required List<String> rearrangeLines,
    required List<String> substitutionLines,
    required String substitutionEvaluationLine,
    required String computedValueLine,
    required String roundedValueLine,
  }) {
    final steps = <StepItem>[];

    // Step 1
    steps.add(const StepItem.text(_step1Title));
    final conversions = unitConversionLines.where((l) => l.trim().isNotEmpty).toList();
    if (conversions.isEmpty) {
      steps.add(const StepItem.math(r'\text{No unit conversion required.}'));
    } else {
      for (final line in conversions) {
        steps.add(StepItem.math(line));
      }
    }

    // Step 2
    steps.add(StepItem.text('$_step2Prefix$targetLabelLatex'));
    final rearrange = rearrangeLines.where((l) => l.trim().isNotEmpty).toList();
    if (rearrange.isEmpty) {
      steps.add(const StepItem.math(r'\text{No rearrangement required.}'));
    } else {
      for (final line in rearrange) {
        steps.add(StepItem.math(line));
      }
    }

    // Step 3
    steps.add(const StepItem.text(_step3Title));
    for (final line in substitutionLines.where((l) => l.trim().isNotEmpty)) {
      steps.add(StepItem.math(line));
    }
    if (substitutionEvaluationLine.trim().isNotEmpty) {
      steps.add(StepItem.math(substitutionEvaluationLine));
    }

    // Step 4
    steps.add(const StepItem.text(_step4Title));
    steps.add(StepItem.math(computedValueLine));

    // Rounded
    steps.add(const StepItem.text(_roundingTitle));
    steps.add(StepItem.math(roundedValueLine));

    return steps;
  }
}
