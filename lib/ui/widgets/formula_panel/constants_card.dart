import 'package:flutter/material.dart';

import '../../../core/constants/constants_repository.dart';
import '../../../core/constants/formula_constants_resolver.dart';
import '../../../core/constants/latex_symbols.dart';
import '../../../core/formulas/formula_definition.dart';
import '../../../core/formulas/formula_extensions.dart';
import '../../../core/solver/number_formatter.dart';
import '../formula_ui_theme.dart';
import '../latex_text.dart';

class ConstantsCard extends StatelessWidget {
  const ConstantsCard({
    super.key,
    required this.formula,
    required this.latexMap,
    required this.constantsRepo,
  });

  final FormulaDefinition formula;
  final LatexSymbolMap latexMap;
  final ConstantsRepository constantsRepo;

  @override
  Widget build(BuildContext context) {
    final constantsResolver = FormulaConstantsResolver(constantsRepo);
    final requiredKeys = <String>[];
    final seen = <String>{};

    for (final c in formula.constantsUsedResolved) {
      final normalized = constantsRepo.normalizeConstantKey(c.key);
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      requiredKeys.add(normalized);
    }
    for (final k in constantsResolver.requiredKeys(formula)) {
      final normalized = constantsRepo.normalizeConstantKey(k);
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      requiredKeys.add(normalized);
    }

    final resolved = constantsRepo.resolveConstants(requiredKeys);
    final noteByKey = {
      for (final c in formula.constantsUsedResolved)
        constantsRepo.normalizeConstantKey(c.key): c.note
    };
    final constantsFormatter = const NumberFormatter(significantFigures: 6, sciThresholdExp: 3);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: FormulaUiTheme.fieldRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Constants used:',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (requiredKeys.isEmpty)
            Text(
              'No constants required for this formula.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
          Table(
            columnWidths: const {
              0: FixedColumnWidth(52),
              1: FixedColumnWidth(10),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(1),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: requiredKeys.map((key) {
              final latex = latexMap.latexOf(key);
              final symbolValue = resolved[key];
              final unit = symbolValue?.unit ?? '';
              final valueLatex = symbolValue != null
                  ? constantsFormatter.formatLatexWithUnit(symbolValue.value, unit)
                  : r'\text{Missing constant}';
              final note = noteByKey[key];
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: LatexText(
                      latex,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '=',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, right: 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: LatexText(
                        valueLatex,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 4),
                    child: note != null && note.isNotEmpty
                        ? Text(
                            '($note)',
                            softWrap: true,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
