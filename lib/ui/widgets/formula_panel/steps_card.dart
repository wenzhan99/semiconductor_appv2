import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/latex_symbols.dart';
import '../../../core/solver/step_items.dart';
import '../../../services/app_state.dart';
import '../../controllers/formula_panel_controller.dart';
import '../formula_ui_theme.dart';
import '../latex_text.dart';

/// **CANONICAL STEP-BY-STEP WIDGET** (Single Source of Truth)
/// 
/// This is the ONLY widget used to render step-by-step working across ALL formulas.
/// All formula panels must use this component via FormulaPanel widget.
/// 
/// Features:
/// - Optional animated playback with Play/Pause/Skip/Speed controls
/// - Discovery hint when animation disabled (one-click enable)
/// - Respects user preference from Settings > Appearance
/// - Respects reduced motion accessibility setting
/// - Persists animation state across app restarts
/// 
/// DO NOT create duplicate step rendering widgets. If you need to modify
/// step display behavior, modify this widget only.
class StepsCard extends StatefulWidget {
  const StepsCard({
    super.key,
    required this.controller,
    required this.latexMap,
  });

  final FormulaPanelController controller;
  final LatexSymbolMap latexMap;

  @override
  State<StepsCard> createState() => _StepsCardState();
}

enum AnimationSpeed { slow, normal, fast }

class _StepsCardState extends State<StepsCard> with TickerProviderStateMixin {
  // Animation state
  bool _isPlaying = false;
  bool _isPaused = false;
  int _revealedItemsCount = 0;
  AnimationSpeed _speed = AnimationSpeed.normal;
  Timer? _revealTimer;
  
  // Used to detect when steps change (new solve)
  int? _lastStepsHash;

  @override
  void initState() {
    super.initState();
    // Initialize hash without calling setState
    final steps = widget.controller.lastSteps;
    if (steps != null) {
      _lastStepsHash = steps.workingItems.length;
    }
  }

  @override
  void didUpdateWidget(StepsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkForNewSteps();
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _checkForNewSteps() {
    final steps = widget.controller.lastSteps;
    if (steps == null) return;
    
    final newHash = steps.workingItems.length;
    if (_lastStepsHash != newHash) {
      // New steps detected - reset animation state
      _lastStepsHash = newHash;
      _revealTimer?.cancel();
      
      // Use post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _isPaused = false;
          _revealedItemsCount = 0;
        });
      });
    }
  }

  Duration _getRevealInterval() {
    switch (_speed) {
      case AnimationSpeed.slow:
        return const Duration(milliseconds: 1000);
      case AnimationSpeed.normal:
        return const Duration(milliseconds: 600);
      case AnimationSpeed.fast:
        return const Duration(milliseconds: 300);
    }
  }

  void _play() {
    final steps = widget.controller.lastSteps;
    if (steps == null || steps.workingItems.isEmpty) return;

    // Check for reduced motion preference
    final reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion) {
      // Skip animation and show all steps immediately
      setState(() {
        _revealedItemsCount = steps.workingItems.length;
        _isPlaying = false;
        _isPaused = false;
      });
      return;
    }

    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });

    _revealTimer?.cancel();
    _revealTimer = Timer.periodic(_getRevealInterval(), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _revealedItemsCount++;
        if (_revealedItemsCount >= steps.workingItems.length) {
          _isPlaying = false;
          timer.cancel();
        }
      });
    });
  }

  void _pause() {
    _revealTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _isPaused = true;
    });
  }

  void _resume() {
    _play();
  }

  void _skip() {
    final steps = widget.controller.lastSteps;
    if (steps == null) return;

    _revealTimer?.cancel();
    setState(() {
      _revealedItemsCount = steps.workingItems.length;
      _isPlaying = false;
      _isPaused = false;
    });
  }

  void _repeat() {
    _revealTimer?.cancel();
    setState(() {
      _revealedItemsCount = 0;
      _isPlaying = false;
      _isPaused = false;
    });
    // Auto-play after reset
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _play();
      }
    });
  }

  void _changeSpeed(AnimationSpeed newSpeed) {
    final wasPlaying = _isPlaying;
    setState(() {
      _speed = newSpeed;
    });
    
    if (wasPlaying) {
      // Restart timer with new speed
      _revealTimer?.cancel();
      _play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.controller.lastSteps;
    if (steps == null || steps.workingItems.isEmpty) return const SizedBox.shrink();
    
    final appState = context.watch<AppState>();
    final animationEnabled = appState.animateSteps;
    final reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    
    // DEBUG: Print animation state
    debugPrint('🎬 StepsCard build: animationEnabled=$animationEnabled, reducedMotion=$reducedMotion, stepsCount=${steps.workingItems.length}, isPlaying=$_isPlaying, revealed=$_revealedItemsCount');
    
    // If animation is disabled globally, show all steps
    final displayItemsCount = animationEnabled 
        ? (_revealedItemsCount > 0 ? _revealedItemsCount : steps.workingItems.length)
        : steps.workingItems.length;

    final sectionTitleStyle = FormulaUiTheme.stepSectionTitleStyle(context);
    final headerStyle = FormulaUiTheme.stepHeaderTextStyle(context);
    final mathStyle = FormulaUiTheme.stepMathTextStyle(context);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Step-by-step working', style: sectionTitleStyle),
                ),
              ],
            ),
            // Always show animation controls for discoverability
            const SizedBox(height: 8),
            animationEnabled
                ? _buildAnimationControls(context, steps.workingItems.length)
                : _buildEnableAnimationHint(context),
            const SizedBox(height: 8),
            ...steps.workingItems.take(displayItemsCount).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isMathHeader =
                  item.type == StepItemType.math && item.latex.trim().startsWith(r'\textbf{Step');
              if (item.type == StepItemType.text) {
                return Padding(
                  key: ValueKey('step_item_${index}_text'),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildStepHeaderText(item.value, headerStyle),
                );
              } else if (isMathHeader) {
                return Padding(
                  key: ValueKey('step_item_${index}_math_header'),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildStepHeaderLatex(item.latex, headerStyle),
                );
              }
              return Padding(
                key: ValueKey('step_item_${index}_math'),
                padding: const EdgeInsets.only(bottom: 6),
                child: _StepMathLine(
                  latex: item.latex,
                  style: mathStyle,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEnableAnimationHint(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.animation_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Enable animation to watch steps unfold line-by-line',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              final appState = context.read<AppState>();
              appState.setAnimateSteps(true);
              // Optionally auto-play after enabling
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  _play();
                }
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationControls(BuildContext context, int totalItems) {
    final canPlay = _revealedItemsCount < totalItems && !_isPlaying;
    final canPause = _isPlaying;
    final canResume = _isPaused && _revealedItemsCount < totalItems;
    final canRepeat = _revealedItemsCount >= totalItems && !_isPlaying;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play button
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 20),
            tooltip: 'Play',
            onPressed: canPlay ? _play : null,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),
          // Pause/Resume button
          IconButton(
            icon: Icon(
              canResume ? Icons.play_arrow : Icons.pause,
              size: 20,
            ),
            tooltip: canResume ? 'Resume' : 'Pause',
            onPressed: canPause ? _pause : (canResume ? _resume : null),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),
          // Skip button
          IconButton(
            icon: const Icon(Icons.skip_next, size: 20),
            tooltip: 'Skip to end',
            onPressed: _revealedItemsCount < totalItems ? _skip : null,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),
          // Repeat button
          IconButton(
            icon: const Icon(Icons.replay, size: 20),
            tooltip: 'Replay from start',
            onPressed: canRepeat ? _repeat : null,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 24,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(width: 12),
          // Speed selector
          Text(
            'Speed:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          _buildSpeedButton(context, AnimationSpeed.slow, '0.5x'),
          const SizedBox(width: 4),
          _buildSpeedButton(context, AnimationSpeed.normal, '1x'),
          const SizedBox(width: 4),
          _buildSpeedButton(context, AnimationSpeed.fast, '2x'),
        ],
      ),
    );
  }

  Widget _buildSpeedButton(BuildContext context, AnimationSpeed speed, String label) {
    final isSelected = _speed == speed;
    return InkWell(
      onTap: () => _changeSpeed(speed),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeaderText(String text, TextStyle style) {
    return Text(text, style: style);
  }

  Widget _buildStepHeaderLatex(String latex, TextStyle style) {
    return LatexText(
      latex,
      style: style,
      displayMode: false,
      scale: 1.0,
    );
  }
}

class _StepMathLine extends StatefulWidget {
  const _StepMathLine({
    required this.latex,
    required this.style,
  });

  final String latex;
  final TextStyle style;

  @override
  State<_StepMathLine> createState() => _StepMathLineState();
}

class _StepMathLineState extends State<_StepMathLine> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      notificationPredicate: (notif) => notif.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: LatexText(
          widget.latex,
          style: widget.style,
          displayMode: true,
          scale: FormulaUiTheme.stepMathScale,
        ),
      ),
    );
  }
}
