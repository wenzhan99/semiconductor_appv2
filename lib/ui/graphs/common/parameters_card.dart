import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'latex_rich_text.dart';
import '../../widgets/latex_text.dart';
import 'enhanced_animation_panel.dart';

typedef _Typo = GraphPanelTextStyles;

String formatSciLatex(double x, {int sigFigs = 3}) {
  if (x.isNaN || x.isInfinite) return '--';
  if (x == 0) return '0';

  final absX = x.abs();
  if (absX >= 1e-3 && absX < 1e4) {
    final exponent = (math.log(absX) / math.ln10).floor();
    final decimals = math.max(0, sigFigs - exponent - 1).clamp(0, 12);
    return _trimTrailingZeros(x.toStringAsFixed(decimals));
  }

  var exponent = (math.log(absX) / math.ln10).floor();
  final decimals = math.max(0, sigFigs - 1);
  var mantissa = x / math.pow(10, exponent);
  mantissa = double.parse(mantissa.toStringAsFixed(decimals));
  if (mantissa.abs() >= 10) {
    mantissa /= 10;
    exponent += 1;
  }
  final mantissaStr = mantissa.toStringAsFixed(decimals);
  return '$mantissaStr\\times 10^{$exponent}';
}

String formatSciPlain(double x, {int sigFigs = 3}) {
  if (x.isNaN || x.isInfinite) return '--';
  if (x == 0) return '0';

  final absX = x.abs();
  if (absX >= 1e-3 && absX < 1e4) {
    return formatSciLatex(x, sigFigs: sigFigs);
  }

  var exponent = (math.log(absX) / math.ln10).floor();
  final decimals = math.max(0, sigFigs - 1);
  var mantissa = x / math.pow(10, exponent);
  mantissa = double.parse(mantissa.toStringAsFixed(decimals));
  if (mantissa.abs() >= 10) {
    mantissa /= 10;
    exponent += 1;
  }
  final mantissaStr = mantissa.toStringAsFixed(decimals);
  return '${mantissaStr}x10^$exponent';
}

String _trimTrailingZeros(String value) {
  if (!value.contains('.')) return value;
  final trimmed = value.replaceFirst(RegExp(r'\.?0+$'), '');
  return trimmed == '-0' ? '0' : trimmed;
}

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
            style: TextStyle(
              fontSize: _Typo.title,
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

/// Slider parameter with LaTeX label
class ParameterSlider extends StatelessWidget {
  final String label;
  final String? plainSuffix;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final String? subtitle;
  final bool showValue;
  final String Function(double)? valueFormatter;
  final String Function(double)? valueLatexFormatter;
  final bool showRangeLabels;
  final String Function(double)? rangeLatexFormatter;

  const ParameterSlider({
    super.key,
    required this.label,
    this.plainSuffix,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.onChanged,
    this.subtitle,
    this.showValue = true,
    this.valueFormatter,
    this.valueLatexFormatter,
    this.showRangeLabels = false,
    this.rangeLatexFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final valueLatex = valueLatexFormatter?.call(value);
    final sliderValueText = valueFormatter != null
        ? valueFormatter!(value)
        : (valueLatexFormatter != null
              ? formatSciPlain(value)
              : value.toStringAsFixed(3));
    final rangeFormatter =
        rangeLatexFormatter ?? valueLatexFormatter ?? ((double x) => formatSciLatex(x));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LatexText(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (plainSuffix != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        plainSuffix!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              if (showValue) ...[
                const SizedBox(width: 8),
                valueLatex != null
                    ? LatexText(
                        valueLatex,
                        style: TextStyle(
                          fontSize: _Typo.value,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Text(
                        sliderValueText,
                        style: TextStyle(
                          fontSize: _Typo.value,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
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
            label: sliderValueText,
          ),
          if (showRangeLabels)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: LatexText(
                        rangeFormatter(min),
                        style: TextStyle(
                          fontSize: _Typo.small,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: LatexText(
                        rangeFormatter(max),
                        style: TextStyle(
                          fontSize: _Typo.small,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
  final String? plainSuffix;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const ParameterSwitch({
    super.key,
    required this.label,
    this.plainSuffix,
    this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LatexText(label),
          if (plainSuffix != null) ...[
            const SizedBox(width: 4),
            Text(plainSuffix!),
          ],
        ],
      ),
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
  final String? plainSuffix;
  final Set<T> selected;
  final List<ButtonSegment<T>> segments;
  final ValueChanged<Set<T>>? onSelectionChanged;

  const ParameterSegmented({
    super.key,
    required this.label,
    this.plainSuffix,
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LatexText(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (plainSuffix != null) ...[
                const SizedBox(width: 4),
                Text(
                  plainSuffix!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
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
