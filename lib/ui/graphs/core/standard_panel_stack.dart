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
/// 1. Point Inspector
/// 2. Animation Parameters
/// 3. Insights & Pins
/// 4. Controls
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
    return SingleChildScrollView(
      child: Column(
        children: [
          // 1. Point Inspector Panel
          if (config.pointInspector != null && config.pointInspector!.enabled)
            PointInspectorPanel(config: config.pointInspector!),
          
          if (config.pointInspector != null && config.pointInspector!.enabled)
            const SizedBox(height: 12),

          // 2. Animation Parameters Panel
          if (config.animation != null)
            AnimationParametersPanel(config: config.animation!),
          
          if (config.animation != null)
            const SizedBox(height: 12),

          // 3. Insights & Pins Panel
          if (config.insights != null)
            InsightsAndPinsPanel(config: config.insights!),
          
          if (config.insights != null)
            const SizedBox(height: 12),

          // 4. Optional Readouts panel (static computed values)
          if (config.readouts != null && config.readouts!.isNotEmpty) ...[
            _ReadoutsPanel(items: config.readouts!),
            const SizedBox(height: 12),
          ],

          // 4. Controls Panel
          ControlsPanel(config: config.controls),
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
    String? mathPart;
    String? descPart;
    final label = item.label;
    final start = label.indexOf(r'\(');
    final end = label.indexOf(r'\)');
    if (start != -1 && end != -1 && end > start) {
      mathPart = label.substring(start, end + 2);
      descPart = label.substring(end + 2).trim();
      if (descPart.isEmpty) {
        descPart = null;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (mathPart != null)
                      LatexText(
                        mathPart,
                        style: TextStyle(
                          fontSize: _Typo.body,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: _Typo.body,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
          if (descPart != null) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                descPart,
                style: TextStyle(fontSize: _Typo.body),
              ),
            ),
          ]
                  ],
                ),
              ),
              const SizedBox(width: 8),
              LatexText(
                _ensureInlineMath(item.value),
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

  String _ensureInlineMath(String value) {
    if (value.startsWith(r'\(') && value.endsWith(r'\)')) return value;
    return r'\(' + value + r'\)';
  }
}
