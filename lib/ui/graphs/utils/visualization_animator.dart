import 'package:flutter/animation.dart';

/// Lightweight animation helper for visualization parameter auto-play.
class VisualizationAnimator {
  final TickerProvider vsync;
  final double min;
  final double max;
  final bool pingPong;
  Duration baseDuration;
  void Function(double value)? onValue;

  late AnimationController _controller;
  late Animation<double> _animation;
  bool loop = true;
  double speed = 1.0; // 0.5x, 1x, 2x etc.

  VisualizationAnimator({
    required this.vsync,
    required this.min,
    required this.max,
    required this.baseDuration,
    this.pingPong = true,
    this.onValue,
  }) {
    _controller = AnimationController(vsync: vsync, duration: baseDuration);
    _buildAnimation();
  }

  void _buildAnimation() {
    _animation = Tween<double>(begin: min, end: max).animate(_controller)
      ..addListener(() {
        onValue?.call(_animation.value);
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (pingPong) {
            _controller.reverse();
          } else if (loop) {
            _controller.forward(from: 0);
          }
        } else if (status == AnimationStatus.dismissed && loop && pingPong) {
          _controller.forward(from: 0);
        }
      });
  }

  void setSpeed(double multiplier) {
    speed = multiplier;
    final newDuration = Duration(
      milliseconds: (baseDuration.inMilliseconds / speed).clamp(200, 20000).round(),
    );
    _controller.duration = newDuration;
  }

  void start() {
    _controller.forward(from: _controller.value);
  }

  void pause() {
    _controller.stop();
  }

  void reset() {
    _controller.stop();
    _controller.value = 0;
    onValue?.call(min);
  }

  bool get isAnimating => _controller.isAnimating;

  void dispose() {
    _controller.dispose();
  }
}
