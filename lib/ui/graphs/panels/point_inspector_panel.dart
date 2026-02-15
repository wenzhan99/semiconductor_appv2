import 'package:flutter/material.dart';
import '../core/graph_config.dart';
import '../../widgets/latex_text.dart';
import '../common/enhanced_animation_panel.dart';

typedef _Typo = GraphPanelTextStyles;

/// Point Inspector panel for StandardGraphPageScaffold.
/// 
/// Displays information about the currently selected/hovered point on the chart.
class PointInspectorPanel extends StatelessWidget {
  final PointInspectorConfig config;

  const PointInspectorPanel({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = config.builder != null || config.customBuilder != null;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Point Inspector',
                  style: TextStyle(
                    fontSize: _Typo.title,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                _StateChip(isPinned: config.isPinned),
                const Spacer(),
                if (hasContent && config.onClear != null)
                  TextButton(
                    onPressed: config.onClear,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasContent)
              Text(
                config.emptyMessage,
                style: TextStyle(fontSize: _Typo.hint),
              )
            else if (config.customBuilder != null)
              config.customBuilder!()
            else if (config.builder != null)
              ...config.builder!().map((line) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: LatexText(
                    line,
                    style: TextStyle(fontSize: _Typo.value),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final bool isPinned;

  const _StateChip({required this.isPinned});

  @override
  Widget build(BuildContext context) {
    final label = isPinned ? 'Pinned' : 'Live';
    final color = isPinned
        ? Colors.blueAccent.withValues(alpha: 0.15)
        : Colors.green.withValues(alpha: 0.15);
    final textColor = isPinned ? Colors.blueAccent : Colors.green.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: _Typo.hint,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
