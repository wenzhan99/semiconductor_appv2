import 'package:flutter/material.dart';

import '../common/graph_panels.dart';
import '../common/graph_scaffold_tokens.dart';
import '../core/graph_config.dart';

/// Controls panel for StandardGraphPageScaffold.
///
/// Displays parameter sliders, switches, buttons, and other controls.
class ControlsPanel extends StatelessWidget {
  final ControlsConfig config;
  final GraphScaffoldTokens? tokensOverride;

  const ControlsPanel({
    super.key,
    required this.config,
    this.tokensOverride,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = GraphScaffoldTokens.of(context, override: tokensOverride);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: config.children,
    );

    return GraphCard(
      title: 'Controls',
      tokens: tokens,
      collapsible: config.collapsible,
      initiallyExpanded: config.initiallyExpanded,
      child: content,
    );
  }
}
