import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/graph_config.dart';
import '../common/graph_panels.dart';
import '../common/graph_scaffold_tokens.dart';
import '../../widgets/latex_text.dart';

/// Animation Parameters panel for StandardGraphPageScaffold.
///
/// Displays:
/// - List of animatable parameters with enable checkboxes
/// - Global animation controls (Play/Pause, Reverse, Loop, Speed)
/// - Current parameter values and ranges
class AnimationParametersPanel extends StatefulWidget {
  final AnimationConfig config;
  final GraphScaffoldTokens? tokensOverride;

  const AnimationParametersPanel({
    super.key,
    required this.config,
    this.tokensOverride,
  });

  @override
  State<AnimationParametersPanel> createState() =>
      _AnimationParametersPanelState();
}

class _AnimationParametersPanelState extends State<AnimationParametersPanel> {
  static const _speedOptions = <double>[0.5, 1.0, 2.0, 3.0, 4.0];
  String? _lastAutoSelectedId;
  static const Map<String, String> _superscripts = {
    '-': '\u207B',
    '+': '\u207A',
    '0': '\u2070',
    '1': '\u00B9',
    '2': '\u00B2',
    '3': '\u00B3',
    '4': '\u2074',
    '5': '\u2075',
    '6': '\u2076',
    '7': '\u2077',
    '8': '\u2078',
    '9': '\u2079',
  };

  String _formatSciLatex(double v) {
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

  String _formatSciPlain(double v) {
    if (v.isNaN || v.isInfinite) return '--';
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
    if (exp == 0) return mantStr;
    return '$mantStr\u00D710${_toSuperscript(exp)}';
  }

  String _toSuperscript(int exponent) {
    final chars = exponent.toString().split('');
    final out = StringBuffer();
    for (final ch in chars) {
      out.write(_superscripts[ch] ?? ch);
    }
    return out.toString();
  }

  String _formatFixed(double v) {
    if (v.isNaN || v.isInfinite) return '--';
    if (v == 0) return '0';
    final decimals = v.abs() >= 100 ? 1 : 3;
    return v
        .toStringAsFixed(decimals)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _formatNumber(double v, {required bool useLatex}) {
    final abs = v.abs();
    final useScientific = abs >= 1e4 || (abs > 0 && abs < 1e-3);
    if (!useScientific) return _formatFixed(v);
    return useLatex ? _formatSciLatex(v) : _formatSciPlain(v);
  }

  bool _looksLikeLatex(String text) {
    return text.contains(r'\') ||
        text.contains('^') ||
        text.contains('_') ||
        text.contains('{') ||
        text.contains('}');
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
    final useLatex = _looksLikeLatex(unit);
    final formatted = _formatNumber(value, useLatex: useLatex);
    if (unit.isEmpty) return formatted;
    return useLatex ? '$formatted\\,$unit' : '$formatted $unit';
  }

  List<AnimatableParameter> _enabledParams(List<AnimatableParameter> params) {
    return params.where((p) => p.enabled).toList();
  }

  String _summaryItem(AnimatableParameter param, {required bool useLatex}) {
    final symbol = param.symbol.trim().isEmpty ? param.label : param.symbol;
    final unit = param.unit.trim();
    if (unit.isEmpty) return symbol;
    return useLatex ? '$symbol\\,($unit)' : '$symbol ($unit)';
  }

  Widget _buildAnimationSummary(
    BuildContext context,
    List<AnimatableParameter> params,
    GraphScaffoldTokens tokens,
  ) {
    final enabled = _enabledParams(params);
    final baseStyle = tokens.hint.copyWith(fontWeight: FontWeight.w600);

    if (enabled.isEmpty) {
      return Text('Animating: none', style: baseStyle);
    }

    final useLatex = enabled.any(
      (param) =>
          _looksLikeLatex(
              param.symbol.trim().isEmpty ? param.label : param.symbol) ||
          _looksLikeLatex(param.unit),
    );
    final summaryText = enabled
        .map((param) => _summaryItem(param, useLatex: useLatex))
        .join(useLatex ? r',\ ' : ', ');
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Animating: ', style: baseStyle),
        useLatex
            ? LatexText(summaryText, style: baseStyle)
            : Text(summaryText, style: baseStyle),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        GraphScaffoldTokens.of(context, override: widget.tokensOverride);
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

    return GraphCard(
      title: 'Animation Parameters',
      tokens: tokens,
      collapsible: true,
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasParameters) ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: selectedParameterId,
              decoration: InputDecoration(
                labelText: 'Active parameter',
                labelStyle: tokens.label,
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
                      child: _ParamLabelRow(param: param, tokens: tokens),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                widget.config.onParameterSelected(value);
                AnimatableParameter? selected;
                for (final param in parameters) {
                  if (param.id == value) {
                    selected = param;
                    break;
                  }
                }
                if (selected != null &&
                    !selected.enabled &&
                    selected.onEnabledChanged != null) {
                  selected.onEnabledChanged!(true);
                }
              },
            ),
            SizedBox(height: tokens.rowGap),
            Text(
              'Only checked parameters animate. Dropdown sets the focused parameter.',
              style: tokens.hint.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: tokens.rowGap * 0.5),
            _buildAnimationSummary(context, parameters, tokens),
            SizedBox(height: tokens.rowGap + 2),
            ...parameters
                .map((param) => _buildParameterRow(context, param, tokens)),
          ] else
            Text(
              'No animatable parameters available for this graph.',
              style: tokens.hint.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const Divider(height: 24),
          Text(
            'Speed',
            style: tokens.label.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: tokens.rowGap),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<double>(
              segments: _speedOptions
                  .map((s) => ButtonSegment(
                        value: s,
                        label: Text(
                          '${s.toStringAsFixed(1)}x',
                          style: tokens.label,
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
          SizedBox(height: tokens.cardGap),
          SwitchListTile(
            title: Text('Loop (Wrap)', style: tokens.label),
            subtitle: Text(
              'Wraps to min at max (forward) and to max at min (reverse)',
              style: tokens.hint,
            ),
            value: state.loop,
            onChanged: hasParameters ? callbacks.onLoopChanged : null,
            dense: false,
            visualDensity: VisualDensity.standard,
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: Text('Reverse Direction', style: tokens.label),
            value: state.reverse,
            onChanged: hasParameters ? callbacks.onReverseChanged : null,
            dense: false,
            visualDensity: VisualDensity.standard,
            contentPadding: EdgeInsets.zero,
          ),
          SizedBox(height: tokens.cardGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: !hasParameters
                      ? null
                      : (state.isPlaying
                          ? callbacks.onPause
                          : callbacks.onPlay),
                  icon: Icon(
                    state.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(
                    state.isPlaying ? 'Pause' : 'Play',
                    style: tokens.label,
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
                  label: Text('Restart', style: tokens.label),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ),
            ],
          ),
          if (state.isPlaying && state.progress != null) ...[
            SizedBox(height: tokens.rowGap),
            Builder(
              builder: (_) {
                final progress = state.progress;
                final safeProgress =
                    (progress == null) ? null : progress.clamp(0.0, 1.0);
                return LinearProgressIndicator(value: safeProgress);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParameterRow(
    BuildContext context,
    AnimatableParameter param,
    GraphScaffoldTokens tokens,
  ) {
    final unit = param.unit.trim();
    final useLatex = _looksLikeLatex(unit);
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
                ? (value) {
                    final enabled = value ?? false;
                    onEnabledChanged(enabled);
                    if (enabled) {
                      widget.config.onParameterSelected(param.id);
                    }
                  }
                : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ParamLabelRow(param: param, tokens: tokens),
                const SizedBox(height: 4),
                _buildValueLine(
                  context: context,
                  tokens: tokens,
                  label: 'Current:',
                  valueTex: _formatWithOptionalUnit(param.currentValue, unit),
                ),
                const SizedBox(height: 4),
                _buildValueLine(
                  context: context,
                  tokens: tokens,
                  label: 'Range:',
                  valueTex: (_isValidNumber(param.rangeMin) &&
                          _isValidNumber(param.rangeMax))
                      ? '${_formatWithOptionalUnit(param.rangeMin, unit)} ${useLatex ? r'\to' : '\u2192'} ${_formatWithOptionalUnit(param.rangeMax, unit)}'
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
    required BuildContext context,
    required GraphScaffoldTokens tokens,
    required String label,
    required String valueTex,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: tokens.label.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: _looksLikeLatex(valueTex)
                  ? LatexText(
                      valueTex,
                      style: tokens.value.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Text(
                      valueTex,
                      style: tokens.value.copyWith(
                        fontWeight: FontWeight.w600,
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
  final GraphScaffoldTokens tokens;

  const _ParamLabelRow({required this.param, required this.tokens});

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
        _looksLikeMath(symbolTex)
            ? LatexText(
                symbolTex,
                style: tokens.label.copyWith(fontWeight: FontWeight.w600),
              )
            : Text(
                symbolTex,
                style: tokens.label.copyWith(fontWeight: FontWeight.w600),
              ),
        if (desc != null) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              desc,
              style: tokens.label.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

bool _looksLikeMath(String line) {
  return line.contains(r'\') ||
      line.contains('^') ||
      line.contains('_') ||
      line.contains('{') ||
      line.contains('}');
}
