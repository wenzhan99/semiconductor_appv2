import 'package:flutter/material.dart';

import '../common/graph_panels.dart';
import '../common/graph_scaffold_tokens.dart';
import '../common/latex_bullet_list.dart';
import '../core/graph_config.dart';

/// Insights & Pins panel for StandardGraphPageScaffold.
///
/// Displays dynamic and static observations based on current configuration.
class InsightsAndPinsPanel extends StatelessWidget {
  final InsightsConfig config;
  final GraphScaffoldTokens? tokensOverride;

  const InsightsAndPinsPanel({
    super.key,
    required this.config,
    this.tokensOverride,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = GraphScaffoldTokens.of(context, override: tokensOverride);
    final hasDynamic = config.dynamicObservations != null &&
        config.dynamicObservations!.isNotEmpty;
    final hasStatic = config.staticObservations != null &&
        config.staticObservations!.isNotEmpty;
    final showPinRow = config.pinnedCount >= 0;

    if (!hasDynamic && !hasStatic && !showPinRow) {
      return const SizedBox.shrink();
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.customHeader != null) ...[
          config.customHeader!,
          SizedBox(height: tokens.rowGap),
        ],
        if (showPinRow) ...[
          _PinsHeaderRow(config: config, tokens: tokens),
          SizedBox(height: tokens.rowGap),
        ],
        if (hasDynamic) ...[
          if (config.dynamicTitle != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                config.dynamicTitle!,
                style: tokens.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            SizedBox(height: tokens.rowGap),
          ],
          LatexBulletList(
            bullets: config.dynamicObservations!,
            style: tokens.label,
          ),
        ],
        if (hasDynamic && hasStatic) SizedBox(height: tokens.cardGap),
        if (hasStatic) ...[
          if (config.staticTitle != null) ...[
            Text(
              config.staticTitle!,
              style: tokens.label.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: tokens.rowGap),
          ],
          LatexBulletList(
            bullets: config.staticObservations!,
            style: tokens.label,
          ),
        ],
      ],
    );

    return GraphCard(
      title: 'Key Observations',
      tokens: tokens,
      child: body,
    );
  }
}

class _PinsHeaderRow extends StatelessWidget {
  final InsightsConfig config;
  final GraphScaffoldTokens tokens;

  const _PinsHeaderRow({required this.config, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final canClear = config.pinnedCount > 0 && config.onClearPins != null;
    return Row(
      children: [
        Text(
          'Pinned points',
          style: tokens.label.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (canClear)
          TextButton.icon(
            onPressed: config.onClearPins,
            icon: const Icon(Icons.clear_all, size: 18),
            label: Text(
              'Clear ${config.pinnedCount} pins',
              style: tokens.label,
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        if (config.maxPins != null) ...[
          const SizedBox(width: 8),
          Text(
            '(Max ${config.maxPins})',
            style: tokens.hint.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
