import 'dart:math' as math;

/// Safe mathematical operations to prevent overflow/underflow
class SafeMath {
  /// Safe exponential function with clamping
  static double safeExp(double x, {double maxExp = 80.0}) {
    if (x > maxExp) return math.exp(maxExp);
    if (x < -maxExp) return math.exp(-maxExp);
    return math.exp(x);
  }
  
  /// Compute exp in log-space for numerical stability
  /// Returns ln(exp(a) + exp(b)) without computing exp directly
  static double logSumExp(double logA, double logB) {
    if (logA > logB) {
      return logA + math.log(1 + math.exp(logB - logA));
    } else {
      return logB + math.log(1 + math.exp(logA - logB));
    }
  }
  
  /// Compute sqrt of product in log-space: sqrt(a * b) = exp(0.5 * (ln(a) + ln(b)))
  static double sqrtProduct(double a, double b) {
    if (a <= 0 || b <= 0) return 0.0;
    return math.exp(0.5 * (math.log(a) + math.log(b)));
  }
  
  /// Clamp a value between min and max
  static double clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
  
  /// Check if value is valid (not NaN, not infinite)
  static bool isValid(double value) {
    return !value.isNaN && !value.isInfinite;
  }
  
  /// Linear interpolation
  static double lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }
}



