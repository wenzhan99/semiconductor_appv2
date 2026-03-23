import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/latex_text.dart';

/// Standardized typography for graph panel cards (right-side panels).
class GraphPanelTextStyles {
  static const double title = 16.0; // Card titles
  static const double sectionLabel = 13.0; // Section headings
  static const double body = 13.0; // Normal text
  static const double value = 14.0; // Numeric values
  static const double hint = 12.0; // Helper text
  static const double small = 11.0; // Fine print

  // LaTeX should match body text for inline usage
  static const double latexInline = 13.0;
  static const double latexInlineScale =
      1.0; // scale multiplier for inline LaTeX

  GraphPanelTextStyles._();
}

/// Contract that graph pages implement to drive [EnhancedAnimationPanel].
abstract class EnhancedAnimationController<P> {
  List<P> get parameters;
  P get selectedParam;
  void selectParam(P param);

  /// LaTeX + descriptor label for dropdown, e.g. r'm_n^{*} (electron mass)'.
  String dropdownLabel(P param);

  /// Pure LaTeX symbol for current value line, e.g. r'm_n^{*}'.
  String valueLabel(P param);

  /// Unit latex, e.g. r'eV' or r'm_0'.
  String unitLabel(P param);

  /// Short physics note for the selected parameter.
  String physicsNote(P param);

  double get currentValue;
  void setCurrentValue(double value);

  double get rangeMin;
  double get rangeMax;
  double get absoluteMin;
  double get absoluteMax;
  void setRangeMin(double value);
  void setRangeMax(double value);
  void resetRangeToDefault();

  double get speed; // multiplier
  void setSpeed(double multiplier);

  bool get loopEnabled;
  void setLoopEnabled(bool value);

  bool get reverseDirection;
  void setReverseDirection(bool value);

  bool get holdSelectedK;
  void setHoldSelectedK(bool value);

  bool get lockYAxis;
  void setLockYAxis(bool value);

  bool get overlayPreviousCurve;
  void setOverlayPreviousCurve(bool value);

  bool get isAnimating;
  double? get progress; // 0-1 if available
  void play();
  void pause();
  void restart();
}

/// Shared animation panel used across graph pages with numeric inputs only.
class EnhancedAnimationPanel<P> extends StatefulWidget {
  final EnhancedAnimationController<P> controller;

  const EnhancedAnimationPanel({super.key, required this.controller});

  @override
  State<EnhancedAnimationPanel<P>> createState() =>
      _EnhancedAnimationPanelState<P>();
}

class _EnhancedAnimationPanelState<P> extends State<EnhancedAnimationPanel<P>> {
  static const _speedOptions = <double>[0.25, 0.5, 1.0, 2.0, 4.0];
  late final TextEditingController _currentCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;

  double _lastValidCurrent = 0;
  double _lastValidMin = 0;
  double _lastValidMax = 0;
  String? _currentError;
  String? _minError;
  String? _maxError;

  FocusNode? _currentFocus;
  FocusNode? _minFocus;
  FocusNode? _maxFocus;
  P? _lastAutoSelected;

  @override
  void initState() {
    super.initState();
    _currentCtrl = TextEditingController();
    _minCtrl = TextEditingController();
    _maxCtrl = TextEditingController();
    _currentFocus = FocusNode();
    _minFocus = FocusNode();
    _maxFocus = FocusNode();

    // Sync after frame to ensure controller is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncFromController(force: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant EnhancedAnimationPanel<P> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always sync when widget updates (animation tick, param change, etc.)
    _syncFromController(force: false);
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _currentFocus?.dispose();
    _minFocus?.dispose();
    _maxFocus?.dispose();
    super.dispose();
  }

  String _format(double v) {
    if (v.isNaN || v.isInfinite) return '--';
    // Use 3 decimals for Eg/masses, appropriate precision for others
    return v.toStringAsFixed(3);
  }

  double _clamp(double value, double min, double max) =>
      value.clamp(min, max).toDouble();

  double? _parse(String input) {
    final v = double.tryParse(input.trim());
    if (v == null || v.isNaN || v.isInfinite) return null;
    return v;
  }

  void _debugGuard(String message) {
    if (kDebugMode) debugPrint('EnhancedAnimationPanel: $message');
  }

  List<P> _safeParameters(EnhancedAnimationController<P> controller) {
    try {
      return controller.parameters;
    } catch (e) {
      _debugGuard('Failed to read parameters: $e');
      return <P>[];
    }
  }

  bool _containsParameter(List<P> parameters, P candidate) {
    return parameters
        .any((item) => identical(item, candidate) || item == candidate);
  }

  P? _resolveSelectedParameter(
    EnhancedAnimationController<P> controller,
    List<P> parameters,
  ) {
    if (parameters.isEmpty) return null;

    P? selected;
    try {
      selected = controller.selectedParam;
    } catch (e) {
      _debugGuard('Failed to read selected parameter: $e');
    }

    if (selected != null && _containsParameter(parameters, selected)) {
      _lastAutoSelected = null;
      return selected;
    }

    final fallback = parameters.first;
    if (_lastAutoSelected != null &&
        (_lastAutoSelected == fallback ||
            identical(_lastAutoSelected, fallback))) {
      return fallback;
    }

    _lastAutoSelected = fallback;
    _debugGuard('Selected parameter missing; defaulting to first option.');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        controller.selectParam(fallback);
        _syncFromController(force: true);
      } catch (e) {
        _debugGuard('Failed to apply fallback selected parameter: $e');
      }
    });
    return fallback;
  }

  String _safeLabel({
    required String Function() getter,
    required String fieldName,
    String fallback = '',
  }) {
    try {
      return getter();
    } catch (e) {
      _debugGuard('Failed to read $fieldName: $e');
      return fallback;
    }
  }

  double? _safeNumber({
    required double Function() getter,
    required String fieldName,
  }) {
    try {
      final value = getter();
      if (value.isNaN || value.isInfinite) {
        _debugGuard('Invalid $fieldName: $value');
        return null;
      }
      return value;
    } catch (e) {
      _debugGuard('Failed to read $fieldName: $e');
      return null;
    }
  }

  bool _hasValidNumericInputs(EnhancedAnimationController<P> controller) {
    final current = _safeNumber(
        getter: () => controller.currentValue, fieldName: 'currentValue');
    final min =
        _safeNumber(getter: () => controller.rangeMin, fieldName: 'rangeMin');
    final max =
        _safeNumber(getter: () => controller.rangeMax, fieldName: 'rangeMax');
    final absMin = _safeNumber(
        getter: () => controller.absoluteMin, fieldName: 'absoluteMin');
    final absMax = _safeNumber(
        getter: () => controller.absoluteMax, fieldName: 'absoluteMax');
    if (current == null ||
        min == null ||
        max == null ||
        absMin == null ||
        absMax == null) {
      return false;
    }
    return min <= max && absMin <= absMax;
  }

  void _syncFromController({bool force = false}) {
    if (!mounted) return;

    final c = widget.controller;
    try {
      final newCurrent = c.currentValue;
      final newMin = c.rangeMin;
      final newMax = c.rangeMax;

      // Only update if values changed or force is true
      final currentChanged = (newCurrent - _lastValidCurrent).abs() > 1e-6;
      final minChanged = (newMin - _lastValidMin).abs() > 1e-6;
      final maxChanged = (newMax - _lastValidMax).abs() > 1e-6;

      if (force || currentChanged || minChanged || maxChanged) {
        setState(() {
          _lastValidCurrent = newCurrent;
          _lastValidMin = newMin;
          _lastValidMax = newMax;

          // Don't overwrite focused field unless force=true
          if (force || !(_currentFocus?.hasFocus ?? false)) {
            _currentCtrl.text = _format(_lastValidCurrent);
          }
          if (force || !(_minFocus?.hasFocus ?? false)) {
            _minCtrl.text = _format(_lastValidMin);
          }
          if (force || !(_maxFocus?.hasFocus ?? false)) {
            _maxCtrl.text = _format(_lastValidMax);
          }

          _currentError = null;
          _minError = null;
          _maxError = null;
        });
      }
    } catch (e) {
      _debugGuard('Failed to sync values from controller: $e');
      // Fallback to safe defaults
      setState(() {
        _currentCtrl.text = '--';
        _minCtrl.text = '--';
        _maxCtrl.text = '--';
        _currentError = 'Error reading values';
      });
    }
  }

  void _sanitizeAndApply() {
    final c = widget.controller;
    final absMin =
        _safeNumber(getter: () => c.absoluteMin, fieldName: 'absoluteMin');
    final absMax =
        _safeNumber(getter: () => c.absoluteMax, fieldName: 'absoluteMax');
    if (absMin == null || absMax == null) {
      _currentError = 'Unavailable';
      _minError = 'Unavailable';
      _maxError = 'Unavailable';
      setState(() {});
      return;
    }

    final parsedMin = _parse(_minCtrl.text);
    final parsedMax = _parse(_maxCtrl.text);
    final parsedCurrent = _parse(_currentCtrl.text);

    var hasError = false;
    if (parsedMin == null) {
      _minError = 'Enter a number';
      _minCtrl.text = _format(_lastValidMin);
      hasError = true;
    } else {
      _minError = null;
    }
    if (parsedMax == null) {
      _maxError = 'Enter a number';
      _maxCtrl.text = _format(_lastValidMax);
      hasError = true;
    } else {
      _maxError = null;
    }
    if (parsedCurrent == null) {
      _currentError = 'Enter a number';
      _currentCtrl.text = _format(_lastValidCurrent);
      hasError = true;
    } else {
      _currentError = null;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    var minVal = _clamp(parsedMin!, absMin, absMax);
    var maxVal = _clamp(parsedMax!, absMin, absMax);
    if (minVal > maxVal) {
      final tmp = minVal;
      minVal = maxVal;
      maxVal = tmp;
    }
    final currentVal = _clamp(parsedCurrent!, minVal, maxVal);

    try {
      c.setRangeMin(minVal);
      c.setRangeMax(maxVal);
      c.setCurrentValue(currentVal);
    } catch (e) {
      _debugGuard('Failed to apply numeric values: $e');
      _currentError = 'Unavailable';
      setState(() {});
      return;
    }

    // Re-sync to ensure consistency after apply
    _syncFromController(force: true);
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required FocusNode? focusNode,
    required String unitLatex,
    required String symbolLatex,
    required String? errorText,
  }) {
    final symbol = symbolLatex.trim().isEmpty ? '--' : symbolLatex.trim();
    final unit = unitLatex.trim();
    final suffixTex = unit.isEmpty ? symbol : '$symbol\\,$unit';

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(
        fontSize: GraphPanelTextStyles.value,
        fontStyle: FontStyle.normal,
      ),
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[-0-9eE+.]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: GraphPanelTextStyles.body,
          fontStyle: FontStyle.normal,
        ),
        errorStyle: const TextStyle(
          fontSize: GraphPanelTextStyles.small,
          fontStyle: FontStyle.normal,
        ),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Center(
            widthFactor: 1.0,
            child: LatexText(
              suffixTex,
              style: const TextStyle(
                fontSize: GraphPanelTextStyles.small,
                fontStyle: FontStyle.normal,
              ),
            ),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        errorText: errorText,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onEditingComplete: _sanitizeAndApply,
      onFieldSubmitted: (_) => _sanitizeAndApply(),
      onTapOutside: (_) {
        focusNode?.unfocus();
        _sanitizeAndApply();
      },
    );
  }

  Widget _buildParameterSelector({
    required P? selected,
    required List<P> parameters,
    required ValueChanged<P?> onChanged,
    required String Function(P) labelBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Parameter',
          style: TextStyle(
            fontSize: GraphPanelTextStyles.body,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.normal,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButton<P>(
          value: selected,
          isExpanded: true,
          hint: const Text(
            'Select a parameter',
            style: TextStyle(
              fontSize: GraphPanelTextStyles.hint,
              fontStyle: FontStyle.normal,
            ),
          ),
          style: const TextStyle(
            fontSize: GraphPanelTextStyles.body,
            fontStyle: FontStyle.normal,
          ),
          items: parameters
              .map(
                (p) => DropdownMenuItem<P>(
                  value: p,
                  child: LatexText(
                    labelBuilder(p),
                    style: const TextStyle(
                      fontSize: GraphPanelTextStyles.body,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: parameters.isEmpty ? null : onChanged,
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: GraphPanelTextStyles.body,
          fontStyle: FontStyle.normal,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: const TextStyle(
                fontSize: GraphPanelTextStyles.hint,
                fontStyle: FontStyle.normal,
              ),
            ),
      value: value,
      onChanged: onChanged,
      dense: false,
      visualDensity: VisualDensity.standard,
      contentPadding: EdgeInsets.zero,
    );
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
    final controller = widget.controller;
    final parameters = _safeParameters(controller);
    final selected = _resolveSelectedParameter(controller, parameters);
    final selectedParam = selected;
    final hasSelection = selectedParam != null;
    final hasNumericInputs = hasSelection && _hasValidNumericInputs(controller);
    final unit = hasSelection
        ? _safeLabel(
            getter: () => controller.unitLabel(selectedParam as P),
            fieldName: 'unitLabel',
          )
        : '';
    final symbol = hasSelection
        ? _safeLabel(
            getter: () => controller.valueLabel(selectedParam as P),
            fieldName: 'valueLabel',
            fallback: '--',
          )
        : '--';
    final speed =
        _safeNumber(getter: () => controller.speed, fieldName: 'speed') ?? 1.0;
    final speedValue = _nearestSpeed(speed);
    final physicsNote = hasSelection
        ? _safeLabel(
            getter: () => controller.physicsNote(selectedParam as P),
            fieldName: 'physicsNote',
            fallback: 'Select a parameter.',
          )
        : 'Select a parameter.';
    final canAnimate = hasSelection;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text(
          'Animation Parameters',
          style: TextStyle(
            fontSize: GraphPanelTextStyles.title,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.normal,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildParameterSelector(
                selected: selected,
                parameters: parameters,
                labelBuilder: controller.dropdownLabel,
                onChanged: (v) {
                  if (v == null) return;
                  controller.selectParam(v);
                  // Force sync after parameter change
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _syncFromController(force: true);
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              if (hasNumericInputs)
                _numberField(
                  label: 'Current value',
                  controller: _currentCtrl,
                  focusNode: _currentFocus,
                  unitLatex: unit,
                  symbolLatex: symbol,
                  errorText: _currentError,
                )
              else
                Text(
                  'Select a parameter',
                  style: TextStyle(
                    fontSize: GraphPanelTextStyles.hint,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.normal,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: hasNumericInputs
                        ? _numberField(
                            label: 'Range Min',
                            controller: _minCtrl,
                            focusNode: _minFocus,
                            unitLatex: unit,
                            symbolLatex: symbol,
                            errorText: _minError,
                          )
                        : Text(
                            '--',
                            style: TextStyle(
                              fontSize: GraphPanelTextStyles.hint,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: hasNumericInputs
                        ? _numberField(
                            label: 'Range Max',
                            controller: _maxCtrl,
                            focusNode: _maxFocus,
                            unitLatex: unit,
                            symbolLatex: symbol,
                            errorText: _maxError,
                          )
                        : Text(
                            '--',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: GraphPanelTextStyles.hint,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Speed',
                    style: TextStyle(
                      fontSize: GraphPanelTextStyles.sectionLabel,
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
                                  '${s.toStringAsFixed(2)}x',
                                  style: const TextStyle(
                                    fontSize: GraphPanelTextStyles.body,
                                    fontStyle: FontStyle.normal,
                                  ),
                                ),
                              ))
                          .toList(),
                      selected: {speedValue},
                      onSelectionChanged: (Set<double> selected) {
                        if (selected.isNotEmpty) {
                          controller.setSpeed(selected.first);
                          setState(() {});
                        }
                      },
                      showSelectedIcon: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSwitchTile(
                title: 'Loop',
                value: controller.loopEnabled,
                onChanged: (v) {
                  controller.setLoopEnabled(v);
                  setState(() {});
                },
              ),
              _buildSwitchTile(
                title: 'Reverse direction',
                value: controller.reverseDirection,
                onChanged: (v) {
                  controller.setReverseDirection(v);
                  setState(() {});
                },
              ),
              _buildSwitchTile(
                title: 'Hold selected k',
                value: controller.holdSelectedK,
                onChanged: (v) {
                  controller.setHoldSelectedK(v);
                  setState(() {});
                },
              ),
              _buildSwitchTile(
                title: 'Lock y-axis (no auto-scale)',
                value: controller.lockYAxis,
                onChanged: (v) {
                  controller.setLockYAxis(v);
                  setState(() {});
                },
              ),
              _buildSwitchTile(
                title: 'Overlay previous curve',
                value: controller.overlayPreviousCurve,
                onChanged: (v) {
                  controller.setOverlayPreviousCurve(v);
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: !canAnimate
                        ? null
                        : (controller.isAnimating
                            ? controller.pause
                            : controller.play),
                    icon: Icon(controller.isAnimating
                        ? Icons.pause
                        : Icons.play_arrow),
                    label: Text(
                      controller.isAnimating ? 'Pause' : 'Play',
                      style: const TextStyle(
                        fontSize: GraphPanelTextStyles.body,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: !canAnimate
                        ? null
                        : () {
                            controller.restart();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _syncFromController(force: true);
                            });
                          },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text(
                      'Restart',
                      style: TextStyle(
                        fontSize: GraphPanelTextStyles.body,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: !canAnimate
                        ? null
                        : () {
                            controller.resetRangeToDefault();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _syncFromController(force: true);
                            });
                          },
                    icon: const Icon(Icons.settings_backup_restore),
                    label: const Text(
                      'Reset Range',
                      style: TextStyle(
                        fontSize: GraphPanelTextStyles.body,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
              if (controller.isAnimating && controller.progress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: controller.progress),
              ],
              const SizedBox(height: 12),
              const Text(
                'Note',
                style: TextStyle(
                  fontSize: GraphPanelTextStyles.sectionLabel,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.normal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                physicsNote,
                style: const TextStyle(
                  fontSize: GraphPanelTextStyles.hint,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
