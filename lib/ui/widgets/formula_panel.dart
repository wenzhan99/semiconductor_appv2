import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/constants_repository.dart';
import '../../core/constants/latex_symbols.dart';
import '../../core/formulas/formula_definition.dart';
import '../../core/formulas/formula_extensions.dart';
import '../../core/models/unit_preferences.dart';
import '../../core/models/workspace.dart';
import '../../services/app_state.dart';
import '../controllers/formula_panel_controller.dart';
import 'formula_panel/constants_card.dart';
import 'formula_panel/formula_panel_header.dart';
import 'formula_panel/panel_actions.dart';
import 'formula_panel/result_card.dart';
import 'formula_panel/status_banner.dart';
import 'formula_panel/steps_card.dart';
import 'formula_panel/variable_inputs.dart';

/// Rebuilt FormulaPanel widget for rendering and solving formulas.
class FormulaPanel extends StatefulWidget {
  final FormulaDefinition formula;
  final WorkspacePanel panel;
  final bool showHeader;
  final bool showTitleInHeader;
  final Widget? headerTrailing;

  const FormulaPanel({
    super.key,
    required this.formula,
    required this.panel,
    this.showHeader = true,
    this.showTitleInHeader = true,
    this.headerTrailing,
  });

  @override
  State<FormulaPanel> createState() => _FormulaPanelState();
}

class _FormulaPanelState extends State<FormulaPanel> {
  late FormulaPanelController _controller;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FormulaPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.formula.id != widget.formula.id || oldWidget.panel.id != widget.panel.id) {
      _controller.removeListener(_handleControllerChanged);
      _controller.dispose();
      _setupController();
    }
  }

  @override
  Widget build(BuildContext context) {
    final latexMap = context.read<LatexSymbolMap>();
    final constantsRepo = context.read<ConstantsRepository>();
    final appState = context.read<AppState>();
    final unitSystem = appState.currentWorkspace?.unitSystem ?? UnitSystem.cm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          FormulaPanelHeader(
            formula: widget.formula,
            latexMap: latexMap,
            showTitle: widget.showTitleInHeader,
            trailing: widget.headerTrailing,
          ),
          const SizedBox(height: 12),
        ],
        ConstantsCard(
          formula: widget.formula,
          latexMap: latexMap,
          constantsRepo: constantsRepo,
        ),
        const SizedBox(height: 12),
        VariableInputs(
          controller: _controller,
          variables: widget.formula.variablesResolved,
          latexMap: latexMap,
          constantsRepo: constantsRepo,
          unitSystem: unitSystem,
        ),
        const SizedBox(height: 12),
        PanelActions(
          isComputing: _controller.isComputing,
          onCompute: () {
            _controller.compute(context);
          },
          onClear: _controller.clear,
        ),
        const SizedBox(height: 12),
        if (_controller.lastError != null)
          StatusBanner.error(
            message: _controller.lastError ?? '',
            background: Theme.of(context).colorScheme.errorContainer,
            foreground: Theme.of(context).colorScheme.onErrorContainer,
          ),
        if (_controller.lastOutputs != null && _controller.lastOutputs!.isNotEmpty) ...[
          const SizedBox(height: 12),
          ResultCard(
            controller: _controller,
            latexMap: latexMap,
            constantsRepo: constantsRepo,
          ),
        ],
        if (_controller.lastSteps != null) ...[
          const SizedBox(height: 12),
          StepsCard(
            controller: _controller,
            latexMap: latexMap,
          ),
        ],
      ],
    );
  }

  void _setupController() {
    _controller = FormulaPanelController(formula: widget.formula, panel: widget.panel);
    _controller.addListener(_handleControllerChanged);
    _controller.initControllers(context);
    unawaited(_controller.initSolver(context));
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }
}
