import 'package:flutter/material.dart';
import 'graph_config.dart';
import '../panels/point_inspector_panel.dart';
import '../panels/animation_parameters_panel.dart';
import '../panels/insights_and_pins_panel.dart';
import '../panels/controls_panel.dart';
import '../common/enhanced_animation_panel.dart';
import '../../widgets/latex_text.dart';

/// Standard panel stack for graph pages.
/// 
/// Enforces fixed panel order:
/// 1. Readouts
/// 2. Point Inspector
/// 3. Animation Parameters
/// 4. Insights & Pins
/// 5. Controls
/// 
/// All panels are driven by GraphConfig.
class StandardPanelStack extends StatelessWidget {
  final GraphConfig config;

  const StandardPanelStack({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final hasReadouts = config.readouts != null && config.readouts!.isNotEmpty;
    final hasInspector = config.pointInspector != null && config.pointInspector!.enabled;
    final hasAnimation = config.animation != null;
    final hasInsights = config.insights != null;
    final hasControls = config.controls.children.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        children: [
          // 1. Readouts panel
          if (hasReadouts) ...[
            _ReadoutsPanel(items: config.readouts!),
            const SizedBox(height: 12),
          ],

          // 2. Point Inspector panel
          if (hasInspector) ...[
            PointInspectorPanel(config: config.pointInspector!),
            const SizedBox(height: 12),
          ],

          // 3. Animation Parameters panel
          if (hasAnimation) ...[
            AnimationParametersPanel(config: config.animation!),
            const SizedBox(height: 12),
          ],

          // 4. Insights & Pins panel
          if (hasInsights) ...[
            InsightsAndPinsPanel(config: config.insights!),
            const SizedBox(height: 12),
          ],

          // 5. Controls panel
          if (hasControls) ControlsPanel(config: config.controls),
        ],
      ),
    );
  }
}

typedef _Typo = GraphPanelTextStyles;

class _ReadoutsPanel extends StatelessWidget {
  final List<ReadoutItem> items;

  const _ReadoutsPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Readouts',
              style: TextStyle(
                fontSize: _Typo.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => _ReadoutRow(item: item)),
          ],
        ),
      ),
    );
  }
}

class _ReadoutRow extends StatelessWidget {
  final ReadoutItem item;

  const _ReadoutRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _buildLabel(
                  item.label,
                  TextStyle(
                    fontSize: _Typo.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              LatexText(
                item.value,
                style: TextStyle(
                  fontSize: _Typo.value,
                  fontWeight: item.boldValue ? FontWeight.w700 : FontWeight.w400,
                  color: item.valueColor,
                ),
              ),
            ],
          ),
          if (item.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              item.subtitle!,
              style: TextStyle(
                fontSize: _Typo.small,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLabel(String text, TextStyle style) {
    if (_looksLikeLatex(text)) {
      return LatexText(text, style: style);
    }
    return Text(text, style: style);
  }

  bool _looksLikeLatex(String text) {
    return text.contains(r'\') ||
        text.contains('^') ||
        text.contains('_') ||
        text.contains('{') ||
        text.contains('}');
  }
}
