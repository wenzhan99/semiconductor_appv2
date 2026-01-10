import 'package:flutter/material.dart';

import '../../../core/constants/latex_symbols.dart';
import '../../../core/solver/step_items.dart';
import '../../controllers/formula_panel_controller.dart';
import '../formula_ui_theme.dart';
import '../latex_text.dart';

class StepsCard extends StatefulWidget {
  const StepsCard({
    super.key,
    required this.controller,
    required this.latexMap,
  });

  final FormulaPanelController controller;
  final LatexSymbolMap latexMap;

  @override
  State<StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends State<StepsCard> {
  @override
  Widget build(BuildContext context) {
    final steps = widget.controller.lastSteps;
    if (steps == null || steps.workingItems.isEmpty) return const SizedBox.shrink();
    final sectionTitleStyle = FormulaUiTheme.stepSectionTitleStyle(context);
    final headerStyle = FormulaUiTheme.stepHeaderTextStyle(context);
    final mathStyle = FormulaUiTheme.stepMathTextStyle(context);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step-by-step working', style: sectionTitleStyle),
            const SizedBox(height: 8),
            ...steps.workingItems.map((item) {
              final isMathHeader =
                  item.type == StepItemType.math && item.latex.trim().startsWith(r'\textbf{Step');
              if (item.type == StepItemType.text) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildStepHeaderText(item.value, headerStyle),
                );
              } else if (isMathHeader) {
                // Render step headers that arrive as LaTeX (e.g., Step 2 title) using the header style.
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildStepHeaderLatex(item.latex, headerStyle),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _StepMathLine(
                  latex: item.latex,
                  style: mathStyle,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeaderText(String text, TextStyle style) {
    return Text(text, style: style);
  }

  Widget _buildStepHeaderLatex(String latex, TextStyle style) {
    return LatexText(
      latex,
      style: style,
      displayMode: false,
      scale: 1.0,
    );
  }
}

class _StepMathLine extends StatefulWidget {
  const _StepMathLine({
    required this.latex,
    required this.style,
  });

  final String latex;
  final TextStyle style;

  @override
  State<_StepMathLine> createState() => _StepMathLineState();
}

class _StepMathLineState extends State<_StepMathLine> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      notificationPredicate: (notif) => notif.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: LatexText(
          widget.latex,
          style: widget.style,
          displayMode: true,
          scale: FormulaUiTheme.stepMathScale,
        ),
      ),
    );
  }
}
