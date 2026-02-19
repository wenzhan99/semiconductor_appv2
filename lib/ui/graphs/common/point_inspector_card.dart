import 'package:flutter/material.dart';
import 'latex_rich_text.dart';
import 'enhanced_animation_panel.dart';

typedef _Typo = GraphPanelTextStyles;

/// Card for inspecting selected/hovered points on the graph.
/// 
/// Usage:
/// ```dart
/// PointInspectorCard(
///   selectedPoint: _selectedPoint,
///   onClear: () => setState(() => _selectedPoint = null),
///   builder: (point) => [
///     'Band: ${point.band}',
///     'k = ${point.k.toStringAsFixed(3)} x10^10 m^-1',
///     'E = ${point.energy.toStringAsFixed(4)} eV',
///   ],
/// )
/// ```
class PointInspectorCard<T> extends StatelessWidget {
  final T? selectedPoint;
  final VoidCallback? onClear;
  final List<String> Function(T point)? builder;
  final Widget Function(T point)? customBuilder;
  final String emptyMessage;
  final bool collapsible;
  final bool initiallyExpanded;

  const PointInspectorCard({
    super.key,
    required this.selectedPoint,
    this.onClear,
    this.builder,
    this.customBuilder,
    this.emptyMessage = 'Tap the curve to inspect a point.',
    this.collapsible = false,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasPoint = selectedPoint != null;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!collapsible)
          Row(
            children: [
              Text(
                'Point Inspector',
                style: TextStyle(
                  fontSize: _Typo.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (hasPoint && onClear != null)
                TextButton(
                  onPressed: onClear,
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
        if (!hasPoint)
          Text(
            emptyMessage,
            style: TextStyle(fontSize: _Typo.hint),
          )
        else if (customBuilder != null)
          customBuilder!(selectedPoint as T)
        else if (builder != null)
          ...builder!(selectedPoint as T).map((line) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: LatexRichText.parse(
                line,
                style: TextStyle(fontSize: _Typo.value),
              ),
            );
          }),
      ],
    );

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: collapsible
          ? ExpansionTile(
              title: Row(
                children: [
                  Text(
                    'Point Inspector',
                    style: TextStyle(
                        fontSize: _Typo.title, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (hasPoint && onClear != null)
                    TextButton(
                      onPressed: onClear,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Clear'),
                    ),
                ],
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


