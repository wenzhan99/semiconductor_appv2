import 'package:flutter/material.dart';
import 'latex_bullet_list.dart';

/// Card for displaying key observations with dynamic and static sections.
/// 
/// Dynamic observations are computed from current selection/pins/parameters.
/// Static observations are always shown.
/// 
/// Usage:
/// ```dart
/// KeyObservationsCard(
///   dynamicObservations: _pinnedSpots.length >= 2
///       ? [
///           r'Between your pins, $n_i$ changes by ${delta.toStringAsFixed(2)} decades.',
///           r'Your selected range: $\times 10^{3}$ to $\times 10^{12}$ vs 300K.',
///         ]
///       : null,
///   staticObservations: [
///     r'$n_i$ rises exponentially with T.',
///     r'Larger $E_g$ suppresses $n_i$.',
///   ],
/// )
/// ```
class KeyObservationsCard extends StatelessWidget {
  final String title;
  final List<String>? dynamicObservations;
  final List<String>? staticObservations;
  final String? dynamicTitle;
  final String? staticTitle;
  final Widget? customHeader;
  final bool collapsible;
  final bool initiallyExpanded;
  final Color? backgroundColor;

  const KeyObservationsCard({
    super.key,
    this.title = 'Key Observations',
    this.dynamicObservations,
    this.staticObservations,
    this.dynamicTitle = 'Dynamic Insight',
    this.staticTitle,
    this.customHeader,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasDynamic = dynamicObservations != null && dynamicObservations!.isNotEmpty;
    final hasStatic = staticObservations != null && staticObservations!.isNotEmpty;

    if (!hasDynamic && !hasStatic) {
      return const SizedBox.shrink();
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!collapsible) ...[
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
        ],
        if (customHeader != null) ...[
          customHeader!,
          const SizedBox(height: 8),
        ],
        if (hasDynamic) ...[
          if (dynamicTitle != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                dynamicTitle!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          LatexBulletList(
            bullets: dynamicObservations!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (hasDynamic && hasStatic) const SizedBox(height: 12),
        if (hasStatic) ...[
          if (staticTitle != null) ...[
            Text(
              staticTitle!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
          ],
          LatexBulletList(
            bullets: staticObservations!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );

    return Card(
      elevation: 1,
      color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: collapsible
          ? ExpansionTile(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              initiallyExpanded: initiallyExpanded,
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
