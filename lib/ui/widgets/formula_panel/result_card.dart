import 'package:flutter/material.dart';

import '../../../core/constants/constants_repository.dart';
import '../../../core/constants/latex_symbols.dart';
import '../../../core/models/workspace.dart';
import '../../../core/solver/number_formatter.dart';
import '../../../core/solver/unit_converter.dart';
import '../../controllers/formula_panel_controller.dart';
import '../latex_text.dart';

class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.controller,
    required this.latexMap,
    required this.constantsRepo,
  });

  final FormulaPanelController controller;
  final LatexSymbolMap latexMap;
  final ConstantsRepository constantsRepo;

  @override
  Widget build(BuildContext context) {
    final outputs = controller.lastOutputs;
    if (outputs == null || outputs.isEmpty) return const SizedBox.shrink();
    final formatter = const NumberFormatter(significantFigures: 3, sciThresholdExp: 3);
    final unitConverter = UnitConverter(constantsRepo);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Result',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...outputs.entries.map((entry) {
              final key = entry.key;
              final value = entry.value;
              final latexLabel = latexMap.latexOf(key);
              final isEnergyVar = controller.isEnergyVariable(key);
              SymbolValue displayValue = controller.convertResultForDisplay(key, value, constantsRepo);
              SymbolValue? altDisplay;
              if (isEnergyVar) {
                final primaryUnit = controller.primaryEnergyUnitFor(key);
                final baseUnit = value.unit.isNotEmpty ? value.unit : 'J';
                final altUnit = primaryUnit == 'eV' ? 'J' : 'eV';
                final altConverted = unitConverter.convertEnergy(value.value, baseUnit, altUnit);
                altDisplay = altConverted != null
                    ? SymbolValue(value: altConverted, unit: altUnit, source: value.source)
                    : null;
                // Ensure primary display respects chosen unit even if solver output is different.
                if (displayValue.unit != primaryUnit) {
                  final primaryConverted = unitConverter.convertEnergy(value.value, baseUnit, primaryUnit);
                  if (primaryConverted != null) {
                    displayValue = SymbolValue(value: primaryConverted, unit: primaryUnit, source: value.source);
                  }
                }
              }
              final latexVal = displayValue.unit.isNotEmpty
                  ? formatter.formatLatexWithUnit(displayValue.value, displayValue.unit)
                  : formatter.formatLatex(displayValue.value);
              final altLatex = altDisplay != null
                  ? formatter.formatLatexWithUnit(altDisplay.value, altDisplay.unit)
                  : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      LatexText(
                        latexLabel,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      LatexText(
                        r'\;=\;' + latexVal,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (altLatex != null)
                        LatexText(
                          r'\;\approx\;' + altLatex,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
