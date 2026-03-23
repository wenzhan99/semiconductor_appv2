import 'package:flutter/material.dart';

/// Selector for switching between multiple plots on multi-plot graph pages.
///
/// Used for pages like:
/// - Drift vs Diffusion (2 plots: n(x), J components)
/// - PN Depletion (3 plots: rho(x), E(x), V(x))
///
/// Usage:
/// ```dart
/// PlotSelector(
///   options: ['ρ(x)', 'E(x)', 'V(x)', 'All'],
///   selected: _selectedPlot,
///   onChanged: (plot) => setState(() => _selectedPlot = plot),
/// )
/// ```
class PlotSelector extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool showAllOnLargeScreen;

  const PlotSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.showAllOnLargeScreen = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Plot',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final isSelected = option == selected;
                return ChoiceChip(
                  label: Text(option),
                  selected: isSelected,
                  backgroundColor: Colors.white,
                  selectedColor: Colors.white,
                  onSelected: (_) => onChanged(option),
                );
              }).toList(),
            ),
            if (showAllOnLargeScreen && options.contains('All'))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '* "All" recommended for large screens',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tab-based plot selector (alternative style)
class PlotSelectorTabs extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const PlotSelectorTabs({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SegmentedButton<int>(
          segments: List.generate(
            options.length,
            (i) => ButtonSegment(
              value: i,
              label: Text(options[i]),
            ),
          ),
          selected: {selectedIndex},
          onSelectionChanged: (Set<int> selected) {
            onChanged(selected.first);
          },
        ),
      ),
    );
  }
}
