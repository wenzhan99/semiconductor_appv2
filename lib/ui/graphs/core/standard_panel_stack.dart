import 'package:flutter/material.dart';

import '../common/graph_panels.dart';
import '../common/graph_scaffold_tokens.dart';
import '../panels/animation_parameters_panel.dart';
import '../panels/controls_panel.dart';
import '../panels/insights_and_pins_panel.dart';
import '../panels/point_inspector_panel.dart';
import 'graph_config.dart';

/// Standard panel stack for graph pages.
///
/// Enforces fixed panel order:
/// 1. Readouts
/// 2. Point Inspector
/// 3. Animation Parameters
/// 4. Controls
/// 5. Notes (Insights)
class StandardPanelStack extends StatelessWidget {
  final GraphConfig config;
  final GraphScaffoldTokens? tokensOverride;

  const StandardPanelStack({
    super.key,
    required this.config,
    this.tokensOverride,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = GraphScaffoldTokens.of(context, override: tokensOverride);
    final hasReadouts = config.readouts != null && config.readouts!.isNotEmpty;
    final hasInspector =
        config.pointInspector != null && config.pointInspector!.enabled;
    final hasAnimation = config.animation != null;
    final hasControls = config.controls.children.isNotEmpty;
    final hasInsights = config.insights != null;

    final panels = <Widget>[];

    if (hasReadouts) {
      panels.add(
        GraphCard(
          title: 'Readouts',
          tokens: tokens,
          child: GraphKeyValueTable(
            tokens: tokens,
            rows: config.readouts!
                .map(
                  (item) => GraphKeyValueEntry(
                    label: item.label,
                    value: item.value,
                    subtitle: item.subtitle,
                    boldValue: item.boldValue,
                    valueColor: item.valueColor,
                  ),
                )
                .toList(growable: false),
          ),
        ),
      );
    }

    if (hasInspector) {
      panels.add(
        PointInspectorPanel(
          config: config.pointInspector!,
          tokensOverride: tokens,
        ),
      );
    }

    if (hasAnimation) {
      panels.add(
        AnimationParametersPanel(
          config: config.animation!,
          tokensOverride: tokens,
        ),
      );
    }

    if (hasControls) {
      panels.add(
        ControlsPanel(
          config: config.controls,
          tokensOverride: tokens,
        ),
      );
    }

    if (hasInsights) {
      panels.add(
        InsightsAndPinsPanel(
          config: config.insights!,
          tokensOverride: tokens,
        ),
      );
    }

    return _PanelStackScrollView(
      child: Column(
        children: [
          for (var i = 0; i < panels.length; i++) ...[
            panels[i],
            if (i != panels.length - 1) SizedBox(height: tokens.cardGap),
          ],
        ],
      ),
    );
  }
}

class _PanelStackScrollView extends StatefulWidget {
  const _PanelStackScrollView({required this.child});

  final Widget child;

  @override
  State<_PanelStackScrollView> createState() => _PanelStackScrollViewState();
}

class _PanelStackScrollViewState extends State<_PanelStackScrollView> {
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
      child: SingleChildScrollView(
        controller: _controller,
        padding: EdgeInsets.zero,
        child: widget.child,
      ),
    );
  }
}
