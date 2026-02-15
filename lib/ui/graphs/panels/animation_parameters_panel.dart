import 'dart:math' as math;

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

  @override
  Widget build(BuildContext context) {
    final state = widget.config.state;
    final callbacks = widget.config.callbacks;
    final speedValue = _nearestSpeed(state.speed);

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
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // List of animatable parameters
              Text(
                'Animation Parameters',
                style: TextStyle(
                  fontSize: _Typo.sectionLabel,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.config.parameters.map((param) => _buildParameterRow(param)),
              const Divider(height: 24),
              
              // Speed control
              Text(
                'Speed',
                style: TextStyle(
                  fontSize: _Typo.sectionLabel,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<double>(
                  segments: _speedOptions
                      .map((s) => ButtonSegment(
                            value: s,
                            label: Text('${s.toStringAsFixed(1)}×',
                                style: TextStyle(fontSize: _Typo.body)),
                          ))
                      .toList(),
                  selected: {speedValue},
                  onSelectionChanged: (Set<double> selected) {
                    if (selected.isNotEmpty) {
                      callbacks.onSpeedChanged(selected.first);
                    }
                  },
                  showSelectedIcon: false,
                ),
              ),
              const SizedBox(height: 12),
              
              // Global animation switches
              SwitchListTile(
                title: Text('Loop (Wrap)', style: TextStyle(fontSize: _Typo.body)),
                subtitle: Text('Wraps to min at max (forward) and to max at min (reverse)',
                    style: TextStyle(fontSize: _Typo.hint)),
                value: state.loop,
                onChanged: callbacks.onLoopChanged,
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: Text('Reverse Direction', style: TextStyle(fontSize: _Typo.body)),
                value: state.reverse,
                onChanged: callbacks.onReverseChanged,
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              
              // Animation control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: state.isPlaying ? callbacks.onPause : callbacks.onPlay,
                      icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow, size: 18),
                      label: Text(state.isPlaying ? 'Pause' : 'Play'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: callbacks.onRestart,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('Restart'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ),
                ],
              ),
              if (state.isPlaying && state.progress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: state.progress),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParameterRow(AnimatableParameter param) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: param.enabled,
            onChanged: param.onEnabledChanged != null
                ? (value) => param.onEnabledChanged!(value ?? false)
                : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ParamLabelRow(param: param),
                Row(
                  children: [
                    Expanded(
                      child: LatexText(
                        r'\(Current: ' +
                            _formatSci(param.currentValue) +
                            r'\,\mathrm{' +
                            param.unit +
                            r'}\)',
                        style: TextStyle(fontSize: _Typo.body),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LatexText(
                        r'\(Range: ' +
                            _formatSci(param.rangeMin) +
                            r'\,\mathrm{' +
                            param.unit +
                            r'} \to ' +
                            _formatSci(param.rangeMax) +
                            r'\,\mathrm{' +
                            param.unit +
                            r'}\)',
                        style: TextStyle(fontSize: _Typo.body),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
          r'\(' + symbolTex + r'\)',
          style: TextStyle(
            fontSize: _Typo.body,
            fontWeight: FontWeight.w600,
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
              ),
            ),
          ),
        ],
      ],
    );
  }
}
