import 'package:flutter/material.dart';
import 'latex_rich_text.dart';
import '../../widgets/latex_text.dart';

/// Card for animation controls with LaTeX support.
/// 
/// Usage:
/// ```dart
/// AnimationCard(
///   title: 'Animation',
///   description: r'Animate $E_g$: 0.6 -> 1.6 eV',
///   currentValue: r'Current: $E_g = ${_bandgap.toStringAsFixed(3)}\,\mathrm{eV}$',
///   isAnimating: _isAnimating,
///   progress: _animationProgress,
///   onPlay: _startAnimation,
///   onPause: _stopAnimation,
///   onReset: _resetAnimation,
/// )
/// ```
class AnimationCard extends StatelessWidget {
  final String title;
  final String? description;
  final String? currentValue;
  final bool isAnimating;
  final double? progress; // 0.0 to 1.0
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final VoidCallback? onReset;
  final bool collapsible;
  final bool initiallyExpanded;
  final Widget? customControls;

  const AnimationCard({
    super.key,
    this.title = 'Animation',
    this.description,
    this.currentValue,
    required this.isAnimating,
    this.progress,
    this.onPlay,
    this.onPause,
    this.onReset,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.customControls,
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
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
        ],
        if (description != null) ...[
          LatexRichText.parse(
            description!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
        ],
        if (currentValue != null) ...[
          LatexRichText.parse(
            currentValue!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        if (customControls != null)
          customControls!
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(isAnimating ? Icons.pause : Icons.play_arrow),
                onPressed: isAnimating ? onPause : onPlay,
                tooltip: isAnimating ? 'Pause' : 'Play',
              ),
              IconButton(
                icon: const Icon(Icons.replay),
                onPressed: onReset,
                tooltip: 'Reset',
              ),
            ],
          ),
        if (isAnimating && progress != null) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress),
        ],
      ],
    );

    return Card(
      elevation: 1,
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

