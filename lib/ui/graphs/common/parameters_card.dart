import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'latex_rich_text.dart';
import '../../widgets/latex_text.dart';

/// Card for parameter controls with LaTeX labels.
/// 
/// Supports sliders, switches, dropdowns, and segmented buttons.
/// 
/// Usage:
/// ```dart
/// ParametersCard(
///   title: 'Parameters',
///   children: [
///     ParameterSlider(
///       label: r'$E_g$ (eV)',
///       value: _bandgap,
///       min: 0.2,
///       max: 2.5,
///       divisions: 230,
///       onChanged: (v) => setState(() => _bandgap = v),
///     ),
///     ParameterSwitch(
///       label: r'Show $N_c$ and $N_v$',
///       value: _showNcNv,
///       onChanged: (v) => setState(() => _showNcNv = v),
///     ),
///   ],
/// )
/// ```
class ParametersCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool collapsible;
  final bool initiallyExpanded;

  const ParametersCard({
    super.key,
    this.title = 'Parameters',
    required this.children,
    this.collapsible = true,
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
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
        ],
        ...children,
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

/// Slider parameter with LaTeX label
class ParameterSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final String? subtitle;
  final bool showValue;
  final String Function(double)? valueFormatter;

  const ParameterSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.onChanged,
    this.subtitle,
    this.showValue = true,
    this.valueFormatter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: LatexRichText.parse(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (showValue) ...[
                const SizedBox(width: 8),
                Text(
                  valueFormatter != null ? valueFormatter!(value) : value.toStringAsFixed(3),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            label: valueFormatter != null ? valueFormatter!(value) : value.toStringAsFixed(3),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Switch parameter with LaTeX label
class ParameterSwitch extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const ParameterSwitch({
    super.key,
    required this.label,
    this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: LatexRichText.parse(label),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// Dropdown parameter with LaTeX label
class ParameterDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const ParameterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LatexRichText.parse(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          DropdownButton<T>(
            value: value,
            isExpanded: true,
            onChanged: onChanged,
            items: items,
          ),
        ],
      ),
    );
  }
}

/// Segmented button parameter with LaTeX label
class ParameterSegmented<T> extends StatelessWidget {
  final String label;
  final Set<T> selected;
  final List<ButtonSegment<T>> segments;
  final ValueChanged<Set<T>>? onSelectionChanged;

  const ParameterSegmented({
    super.key,
    required this.label,
    required this.selected,
    required this.segments,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LatexRichText.parse(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<T>(
            segments: segments,
            selected: selected,
            onSelectionChanged: onSelectionChanged,
          ),
        ],
      ),
    );
  }
}
