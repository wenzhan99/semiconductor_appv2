import 'package:flutter/material.dart';

import '../../../core/solver/number_formatter.dart';
import '../../widgets/latex_text.dart';
import 'parameters_card.dart';

/// Loop behaviour for animations.
enum LoopMode { off, loop, pingPong }

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

  LoopMode get loopMode;
  void setLoopMode(LoopMode mode);

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

/// Shared animation panel used across graph pages.
class EnhancedAnimationPanel<P> extends StatelessWidget {
  final EnhancedAnimationController<P> controller;
  final NumberFormatter _fmt =
      const NumberFormatter(significantFigures: 3, sciThresholdExp: -1000);

  EnhancedAnimationPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedParam;
    final current = controller.currentValue;
    final min = controller.rangeMin;
    final max = controller.rangeMax;
    final absMin = controller.absoluteMin;
    final absMax = controller.absoluteMax;

    String currentLatex() {
      final unit = controller.unitLabel(selected);
      final num = _fmt.formatLatex(current);
      return '${controller.valueLabel(selected)} = $num\\,\\mathrm{$unit}';
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('Animation Parameter',
            style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ParameterDropdown<P>(
                label: 'Animation Parameter',
                value: selected,
                items: controller.parameters
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: LatexText(
                            controller.dropdownLabel(p),
                            scale: 1.05,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  controller.selectParam(v);
                },
              ),
              const SizedBox(height: 8),
              const Text('Current value:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              LatexText(currentLatex(), scale: 1.05),
              const SizedBox(height: 8),
              Text('Manual control:',
                  style: Theme.of(context).textTheme.labelMedium),
              Slider(
                value: current,
                min: min,
                max: max,
                divisions: 200,
                label: current.toStringAsFixed(3),
                onChanged: (v) => controller.setCurrentValue(v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Range Min',
                            style: Theme.of(context).textTheme.labelSmall),
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: min,
                                min: absMin,
                                max: max,
                                divisions: 100,
                                label: min.toStringAsFixed(3),
                                onChanged: (v) => controller.setRangeMin(v),
                              ),
                            ),
                            SizedBox(
                              width: 56,
                              child: Text(min.toStringAsFixed(2),
                                  style: const TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Range Max',
                            style: Theme.of(context).textTheme.labelSmall),
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: max,
                                min: min,
                                max: absMax,
                                divisions: 100,
                                label: max.toStringAsFixed(3),
                                onChanged: (v) => controller.setRangeMax(v),
                              ),
                            ),
                            SizedBox(
                              width: 56,
                              child: Text(max.toStringAsFixed(2),
                                  style: const TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ParameterSlider(
                label: 'Speed',
                value: controller.speed,
                min: 0.25,
                max: 3.0,
                divisions: 11,
                onChanged: (v) => controller.setSpeed(v),
                valueFormatter: (v) => '${v.toStringAsFixed(2)}×',
              ),
              ParameterSegmented<LoopMode>(
                label: 'Loop mode',
                selected: {controller.loopMode},
                segments: const [
                  ButtonSegment(value: LoopMode.off, label: Text('Off')),
                  ButtonSegment(value: LoopMode.loop, label: Text('Loop')),
                  ButtonSegment(value: LoopMode.pingPong, label: Text('PingPong')),
                ],
                onSelectionChanged: (s) => controller.setLoopMode(s.first),
              ),
              ParameterSwitch(
                label: 'Reverse direction',
                value: controller.reverseDirection,
                onChanged: (v) => controller.setReverseDirection(v),
              ),
              ParameterSwitch(
                label: 'Hold selected k',
                value: controller.holdSelectedK,
                onChanged: (v) => controller.setHoldSelectedK(v),
              ),
              ParameterSwitch(
                label: 'Lock y-axis (no auto-scale)',
                value: controller.lockYAxis,
                onChanged: (v) => controller.setLockYAxis(v),
              ),
              ParameterSwitch(
                label: 'Overlay previous curve',
                value: controller.overlayPreviousCurve,
                onChanged: (v) => controller.setOverlayPreviousCurve(v),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        controller.isAnimating ? controller.pause : controller.play,
                    icon: Icon(
                        controller.isAnimating ? Icons.pause : Icons.play_arrow),
                    label: Text(controller.isAnimating ? 'Pause' : 'Play'),
                  ),
                  ElevatedButton.icon(
                    onPressed: controller.restart,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Restart'),
                  ),
                  ElevatedButton.icon(
                    onPressed: controller.resetRangeToDefault,
                    icon: const Icon(Icons.settings_backup_restore),
                    label: const Text('Reset Range'),
                  ),
                ],
              ),
              if (controller.isAnimating && controller.progress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: controller.progress),
              ],
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.9)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.physicsNote(selected),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

