import 'package:flutter/material.dart';
import '../core/graph_config.dart';
import '../common/latex_bullet_list.dart';
import '../common/enhanced_animation_panel.dart';

typedef _Typo = GraphPanelTextStyles;

/// Insights & Pins panel for StandardGraphPageScaffold.
/// 
/// Displays dynamic and static observations based on current configuration.
class InsightsAndPinsPanel extends StatelessWidget {
  final InsightsConfig config;

  const InsightsAndPinsPanel({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final hasDynamic = config.dynamicObservations != null && 
                      config.dynamicObservations!.isNotEmpty;
    final hasStatic = config.staticObservations != null && 
                     config.staticObservations!.isNotEmpty;

    if (!hasDynamic && !hasStatic) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 1,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Key Observations',
              style: TextStyle(
                fontSize: _Typo.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (config.customHeader != null) ...[
              config.customHeader!,
              const SizedBox(height: 8),
            ],
            if (hasDynamic) ...[
              if (config.dynamicTitle != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    config.dynamicTitle!,
                    style: TextStyle(
                      fontSize: _Typo.sectionLabel,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              LatexBulletList(
                bullets: config.dynamicObservations!,
                style: TextStyle(fontSize: _Typo.body),
              ),
            ],
            if (hasDynamic && hasStatic) const SizedBox(height: 12),
            if (hasStatic) ...[
              if (config.staticTitle != null) ...[
                Text(
                  config.staticTitle!,
                  style: TextStyle(
                    fontSize: _Typo.sectionLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              LatexBulletList(
                bullets: config.staticObservations!,
                style: TextStyle(fontSize: _Typo.body),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
