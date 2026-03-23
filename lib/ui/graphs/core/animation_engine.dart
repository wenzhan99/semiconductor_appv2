import 'package:flutter/scheduler.dart';
import 'graph_config.dart';

/// Animation engine that supports multi-parameter simultaneous animation.
/// 
/// Features:
/// - Animates all enabled parameters simultaneously under same clock
/// - Speed control: at 1.0x, animates 10% of (max-min) per second
/// - Reverse direction support
/// - Loop behavior: WRAP only (no ping-pong)
///   - Loop OFF: clamp to boundary and stop
///   - Loop ON: wrap (if value > max => value = min; if value < min => value = max)
/// 
/// Usage:
/// ```dart
/// final engine = AnimationEngine(
///   parameters: _animatableParameters,
///   onUpdate: () => setState(() {}),
/// );
/// 
/// // Start animation
/// engine.play();
/// 
/// // Stop animation
/// engine.pause();
/// ```
class AnimationEngine {
  /// List of animatable parameters (should be kept in sync with page state)
  final List<AnimatableParameter> Function() getParameters;
  
  /// Callback when animation updates parameters
  final VoidCallback onUpdate;
  
  /// Current animation state
  AnimationState _state = const AnimationState();
  
  /// Ticker for animation
  Ticker? _ticker;
  
  /// Last frame time
  Duration? _lastFrameTime;

  AnimationEngine({
    required this.getParameters,
    required this.onUpdate,
  });

  /// Get current animation state
  AnimationState get state => _state;

  /// Whether animation is currently playing
  bool get isPlaying => _state.isPlaying;

  /// Current speed multiplier
  double get speed => _state.speed;

  /// Whether reverse direction is enabled
  bool get reverse => _state.reverse;

  /// Whether loop (wrap) is enabled
  bool get loop => _state.loop;

  /// Start or resume animation
  void play() {
    if (_state.isPlaying) return;
    
    _state = _state.copyWith(isPlaying: true);
    _lastFrameTime = null;
    
    _ticker ??= Ticker(_onTick);
    _ticker!.start();
    onUpdate();
  }

  /// Pause animation
  void pause() {
    if (!_state.isPlaying) return;
    
    _state = _state.copyWith(isPlaying: false);
    _ticker?.stop();
    _lastFrameTime = null;
    onUpdate();
  }

  /// Restart animation (reset all enabled parameters to their range min)
  void restart() {
    final params = getParameters();
    for (final param in params) {
      if (param.enabled) {
        param.onValueChanged(param.rangeMin);
      }
    }
    _lastFrameTime = null;
    onUpdate();
  }

  /// Set speed multiplier
  void setSpeed(double speed) {
    _state = _state.copyWith(speed: speed);
    onUpdate();
  }

  /// Set reverse direction
  void setReverse(bool reverse) {
    _state = _state.copyWith(reverse: reverse);
    onUpdate();
  }

  /// Set loop (wrap) mode
  void setLoop(bool loop) {
    _state = _state.copyWith(loop: loop);
    onUpdate();
  }

  /// Dispose resources
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
  }

  /// Animation tick callback
  void _onTick(Duration elapsed) {
    if (_lastFrameTime == null) {
      _lastFrameTime = elapsed;
      return;
    }

    final deltaTime = (elapsed - _lastFrameTime!).inMicroseconds / 1e6; // seconds
    _lastFrameTime = elapsed;

    final params = getParameters();
    final enabledParams = params.where((p) => p.enabled).toList();
    
    if (enabledParams.isEmpty) {
      // No parameters to animate, pause
      pause();
      return;
    }

    bool anyActive = false;

    for (final param in enabledParams) {
      final range = param.rangeMax - param.rangeMin;
      if (range <= 0) continue;

      // At 1.0x speed: animate 10% of range per second
      // delta = speedMultiplier * 0.1 * (max - min) * deltaTimeSeconds
      final delta = _state.speed * 0.1 * range * deltaTime;
      
      double newValue;
      if (_state.reverse) {
        newValue = param.currentValue - delta;
      } else {
        newValue = param.currentValue + delta;
      }

      // Apply loop or clamp behavior
      if (_state.loop) {
        // Wrap behavior
        if (newValue > param.rangeMax) {
          newValue = param.rangeMin + (newValue - param.rangeMax);
          anyActive = true;
        } else if (newValue < param.rangeMin) {
          newValue = param.rangeMax - (param.rangeMin - newValue);
          anyActive = true;
        } else {
          anyActive = true;
        }
      } else {
        // Clamp behavior - stop at boundaries
        if (newValue > param.rangeMax) {
          newValue = param.rangeMax;
          // Don't set anyActive for this param (reached boundary)
        } else if (newValue < param.rangeMin) {
          newValue = param.rangeMin;
          // Don't set anyActive for this param (reached boundary)
        } else {
          anyActive = true;
        }
      }

      // Update parameter value
      param.onValueChanged(newValue);
    }

    // If no parameters are actively animating (all clamped), pause
    if (!anyActive && !_state.loop) {
      pause();
    } else {
      onUpdate();
    }
  }
}
