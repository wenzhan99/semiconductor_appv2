import 'package:flutter/material.dart';
import '../core/graph_config.dart';
import '../common/enhanced_animation_panel.dart';

typedef _Typo = GraphPanelTextStyles;

/// Controls panel for StandardGraphPageScaffold.
/// 
/// Displays parameter sliders, switches, buttons, and other controls.
class ControlsPanel extends StatelessWidget {
  final ControlsConfig config;

  const ControlsPanel({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!config.collapsible) ...[
          Text(
            'Controls',
            style: TextStyle(
              fontSize: _Typo.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
        ],
        ...config.children,
      ],
    );

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: config.collapsible
          ? ExpansionTile(
              title: Text(
                'Controls',
                style: TextStyle(
                    fontSize: _Typo.title, fontWeight: FontWeight.w700),
              ),
              initiallyExpanded: config.initiallyExpanded,
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [content],
            )
          : Padding(
              padding: const EdgeInsets.all(12),
              child: content,
            ),
    );
  }
}
