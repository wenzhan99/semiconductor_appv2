import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'latex_rich_text.dart';
import 'enhanced_animation_panel.dart';

typedef _Typo = GraphPanelTextStyles;

/// Card displaying numeric readouts with LaTeX labels.
/// 
/// Usage:
/// ```dart
/// ReadoutsCard(
///   title: 'Key Values',
///   readouts: [
///     ReadoutItem(label: r'$E_g$', value: '1.12 eV'),
///     ReadoutItem(label: r'$n_i$', value: '1.45x10^10 cm^-3'),
///   ],
/// )
/// ```
class ReadoutsCard extends StatelessWidget {
  final String title;
  final List<ReadoutItem> readouts;
  final bool collapsible;
  final bool initiallyExpanded;

  const ReadoutsCard({
    super.key,
    this.title = 'Readouts',
    required this.readouts,
    this.collapsible = false,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!collapsible) ...[
          Text(
            title,
            style: TextStyle(
              fontSize: _Typo.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ...readouts.map((item) => _ReadoutRow(item: item)),
      ],
    );

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: collapsible
          ? ExpansionTile(
              title: Text(
                title,
                style: TextStyle(
                    fontSize: _Typo.title, fontWeight: FontWeight.w700),
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

class ReadoutItem {
  /// Label (supports LaTeX: use $ delimiters for math)
  final String label;

  /// Value as string (can include units)
  final String value;

  /// Optional: Make value bold
  final bool boldValue;

  /// Optional: Color for value
  final Color? valueColor;

  /// Optional: Additional info/subtitle
  final String? subtitle;

  const ReadoutItem({
    required this.label,
    required this.value,
    this.boldValue = false,
    this.valueColor,
    this.subtitle,
  });
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child:               LatexRichText.parse(
                item.label,
                style: TextStyle(
                    fontSize: _Typo.body, fontWeight: FontWeight.w600),
              ),
              ),
              const SizedBox(width: 8),
              Text(
                item.value,
                style: TextStyle(
                  fontSize: _Typo.value,
                  fontWeight: item.boldValue ? FontWeight.w700 : FontWeight.normal,
                  color: item.valueColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
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
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


