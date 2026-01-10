import 'package:flutter/material.dart';

import '../../../core/constants/latex_symbols.dart';
import '../../../core/formulas/formula_definition.dart';
import '../latex_text.dart';

class FormulaPanelHeader extends StatelessWidget {
  const FormulaPanelHeader({
    super.key,
    required this.formula,
    required this.latexMap,
    this.showTitle = true,
    this.trailing,
  });

  final FormulaDefinition formula;
  final LatexSymbolMap latexMap;
  final bool showTitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final equation = LatexText(
      latexMap.sanitizeEquationLatexForRender(formula.equationLatex),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      displayMode: true,
      scale: 1.05,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle || trailing != null)
            Row(
              children: [
                if (showTitle)
                  Expanded(
                    child: Text(
                      formula.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: equation,
          ),
        ],
      ),
    );
  }
}
