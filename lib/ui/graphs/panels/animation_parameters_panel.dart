import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/graph_config.dart';
import '../../widgets/latex_text.dart';
import '../common/enhanced_animation_panel.dart';

typedef _Typo = GraphPanelTextStyles;

/// Animation Parameters panel for StandardGraphPageScaffold.
/// 
/// Displays:
/// - List of animatable parameters with enable checkboxes
/// - Global animation controls (Play/Pause, Reverse, Loop, Speed)
/// - Current parameter values and ranges
class AnimationParametersPanel extends StatefulWidget {
  final AnimationConfig config;

  const AnimationParametersPanel({
    super.key,
    required this.config,
  });

  @override
  State<AnimationParametersPanel> createState() => _AnimationParametersPanelState();
}

class _AnimationParametersPanelState extends State<AnimationParametersPanel> {
  static const _speedOptions = <double>[0.5, 1.0, 2.0, 3.0, 4.0];
  String? _lastAutoSelectedId;

  String _formatSci(double v) {
    if (v.isNaN || v.isInfinite) return r'--';
    if (v == 0) return '0';
    final abs = v.abs();
    final exp = (math.log(abs) / math.ln10).floor();
    final mant = v / math.pow(10, exp);
    final mantStr = mant.abs() >= 100
        ? mant.toStringAsFixed(0)
        : mant
            .toStringAsFixed(3)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
    return '$mantStr\\times 10^{$exp}';
  }

  double _nearestSpeed(double current) {
    if (!_isValidNumber(current)) return _speedOptions.first;
    var nearest = _speedOptions.first;
    var bestDiff = (current - nearest).abs();
    for (final s in _speedOptions.skip(1)) {
      final diff = (current - s).abs();
      if (diff < bestDiff) {
        nearest = s;
        bestDiff = diff;
      }
    }
    return nearest;
  }

  List<AnimatableParameter> _safeParameters() {
    try {
      return widget.config.parameters;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AnimationParametersPanel: failed to read parameters: $e');
      }
      return const <AnimatableParameter>[];
    }
  }

  String? _ensureSelectedParameter(List<AnimatableParameter> parameters) {
    if (parameters.isEmpty) return null;
    final selectedId = widget.config.selectedParameterId;
    final exists = parameters.any((p) => p.id == selectedId);
    if (exists) {
      _lastAutoSelectedId = null;
      return selectedId;
    }

    final fallbackId = parameters.first.id;
    if (_lastAutoSelectedId != fallbackId) {
      _lastAutoSelectedId = fallbackId;
      if (kDebugMode) {
        debugPrint(
            'AnimationParametersPanel: selected id "$selectedId" missing; defaulting to "$fallbackId".');
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.config.onParameterSelected(fallbackId);
      });
    }
    return fallbackId;
  }

  bool _isValidNumber(double value) => !value.isNaN && !value.isInfinite;

  String _formatWithOptionalUnit(double? value, String? unitTex) {
    if (value == null || !_isValidNumber(value)) return '--';
    final unit = (unitTex ?? '').trim();
    final formatted = _formatSci(value);
    return unit.isEmpty ? formatted : '$formatted\\,$unit';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.config.state;
    final callbacks = widget.config.callbacks;
    final speedValue = _nearestSpeed(state.speed);
    final parameters = _safeParameters();
    final hasParameters = parameters.isNotEmpty;
    final selectedParameterId = _ensureSelectedParameter(parameters);

    if (!hasParameters && kDebugMode) {
      debugPrint(
          'AnimationParametersPanel: no animatable parameters provided. Showing empty state.');
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          'Animation Parameters',
          style: TextStyle(
            fontSize: _Typo.title,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.normal,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // List of animatable parameters
              if (hasParameters)
                ...[
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedParameterId,
                    decoration: InputDecoration(
                      labelText: 'Active parameter',
                      labelStyle: TextStyle(
                        fontSize: _Typo.body,
                        fontStyle: FontStyle.normal,
                      ),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: parameters
                        .map(
                          (param) => DropdownMenuItem<String>(
                            value: param.id,
                            child: _ParamLabelRow(param: param),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      widget.config.onParameterSelected(value);
                    },
                  ),
                  const SizedBox(height: 10),
                  ...parameters.map((param) => _buildParameterRow(param)),
                ]
              else
                Text(
                  'No animatable parameters available for this graph.',
                  style: TextStyle(
                    fontSize: _Typo.hint,
                    fontStyle: FontStyle.normal,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              const Divider(height: 24),
              
              // Speed control
              Text(
                'Speed',
                style: TextStyle(
                  fontSize: _Typo.sectionLabel,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.normal,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<double>(
                  segments: _speedOptions
                      .map((s) => ButtonSegment(
                            value: s,
                            label: Text(
                              '${s.toStringAsFixed(1)}x',
                              style: TextStyle(
                                fontSize: _Typo.body,
                                fontStyle: FontStyle.normal,
                              ),
                            ),
                          ))
                      .toList(),
                  selected: {speedValue},
                  onSelectionChanged: hasParameters
                      ? (Set<double> selected) {
                          if (selected.isNotEmpty) {
                            callbacks.onSpeedChanged(selected.first);
                          }
                        }
                      : null,
                  showSelectedIcon: false,
                ),
              ),
              const SizedBox(height: 12),
              
              // Global animation switches
              SwitchListTile(
                title: Text(
                  'Loop (Wrap)',
                  style: TextStyle(
                    fontSize: _Typo.body,
                    fontStyle: FontStyle.normal,
                  ),
                ),
                subtitle: Text(
                  'Wraps to min at max (forward) and to max at min (reverse)',
                  style: TextStyle(
                    fontSize: _Typo.hint,
                    fontStyle: FontStyle.normal,
                  ),
                ),
                value: state.loop,
                onChanged: hasParameters ? callbacks.onLoopChanged : null,
                dense: false,
                visualDensity: VisualDensity.standard,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: Text(
                  'Reverse Direction',
                  style: TextStyle(
                    fontSize: _Typo.body,
                    fontStyle: FontStyle.normal,
                  ),
                ),
                value: state.reverse,
                onChanged: hasParameters ? callbacks.onReverseChanged : null,
                dense: false,
                visualDensity: VisualDensity.standard,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              
              // Animation control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: !hasParameters
                          ? null
                          : (state.isPlaying ? callbacks.onPause : callbacks.onPlay),
                      icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow, size: 18),
                      label: Text(
                        state.isPlaying ? 'Pause' : 'Play',
                        style: TextStyle(
                          fontSize: _Typo.body,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: hasParameters ? callbacks.onRestart : null,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: Text(
                        'Restart',
                        style: TextStyle(
                          fontSize: _Typo.body,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ),
                ],
              ),
              if (state.isPlaying && state.progress != null) ...[
                const SizedBox(height: 8),
                Builder(
                  builder: (_) {
                    final progress = state.progress;
                    final safeProgress = (progress == null)
                        ? null
                        : progress.clamp(0.0, 1.0);
                    return LinearProgressIndicator(value: safeProgress);
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParameterRow(AnimatableParameter param) {
    final unit = param.unit.trim();
    final onEnabledChanged = param.onEnabledChanged;
    if (kDebugMode && param.symbol.trim().isEmpty) {
      debugPrint(
          'AnimationParametersPanel: parameter "${param.id}" has empty symbol.');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: param.enabled,
            onChanged: onEnabledChanged != null
                ? (value) => onEnabledChanged(value ?? false)
                : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ParamLabelRow(param: param),
                const SizedBox(height: 4),
                _buildValueLine(
                  label: 'Current:',
                  valueTex: _formatWithOptionalUnit(param.currentValue, unit),
                ),
                const SizedBox(height: 4),
                _buildValueLine(
                  label: 'Range:',
                  valueTex: (_isValidNumber(param.rangeMin) &&
                          _isValidNumber(param.rangeMax))
                      ? '${_formatWithOptionalUnit(param.rangeMin, unit)} \\to ${_formatWithOptionalUnit(param.rangeMax, unit)}'
                      : '--',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueLine({
    required String label,
    required String valueTex,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: _Typo.body,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.normal,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: LatexText(
                valueTex,
                style: TextStyle(
                  fontSize: _Typo.value,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ParamLabelRow extends StatelessWidget {
  final AnimatableParameter param;

  const _ParamLabelRow({required this.param});

  @override
  Widget build(BuildContext context) {
    // Use pure symbol as LaTeX, keep human-readable label as plain text.
    final symbolTex = param.symbol;
    // Derive description: everything in param.label after the symbol, if present.
    String? desc;
    if (param.label.length > symbolTex.length) {
      // Try to strip leading symbol from label
      final lower = param.label.toLowerCase();
      final symLower = symbolTex.toLowerCase();
      if (lower.startsWith(symLower)) {
        desc = param.label.substring(symbolTex.length).trim();
      } else {
        desc = param.label.trim();
      }
      if (desc.isEmpty) desc = null;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LatexText(
          symbolTex,
          style: TextStyle(
            fontSize: _Typo.body,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.normal,
          ),
        ),
        if (desc != null) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              desc,
              style: TextStyle(
                fontSize: _Typo.body,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.normal,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
