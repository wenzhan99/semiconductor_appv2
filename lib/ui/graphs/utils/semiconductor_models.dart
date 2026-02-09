import 'dart:math' as math;

/// Shared semiconductor helper models for density of states and n_i.
class SemiconductorModels {
  /// Effective density of states in the conduction band.
  static double computeNc({
    required double temperatureK,
    required double h,
    required double kB,
    required double m0,
    required double effectiveMassRatio,
  }) {
    final mEff = effectiveMassRatio * m0;
    final base = (2 * math.pi * mEff * kB * temperatureK) / (h * h);
    return (2 * math.pow(base, 1.5)).toDouble();
  }

  /// Effective density of states in the valence band.
  static double computeNv({
    required double temperatureK,
    required double h,
    required double kB,
    required double m0,
    required double effectiveMassRatio,
  }) {
    final mEff = effectiveMassRatio * m0;
    final base = (2 * math.pi * mEff * kB * temperatureK) / (h * h);
    return (2 * math.pow(base, 1.5)).toDouble();
  }

  /// Intrinsic carrier concentration using Maxwell-Boltzmann (non-degenerate).
  static double computeNi({
    required double temperatureK,
    required double h,
    required double kB,
    required double m0,
    required double q,
    required double bandgapEv,
    required double mnEffRatio,
    required double mpEffRatio,
  }) {
    final nc = computeNc(
      temperatureK: temperatureK,
      h: h,
      kB: kB,
      m0: m0,
      effectiveMassRatio: mnEffRatio,
    );
    final nv = computeNv(
      temperatureK: temperatureK,
      h: h,
      kB: kB,
      m0: m0,
      effectiveMassRatio: mpEffRatio,
    );

    final egJoules = bandgapEv * q;
    final exponent = -egJoules / (2 * kB * temperatureK);
    final lnNi = 0.5 * (math.log(nc) + math.log(nv)) + exponent;
    return math.exp(lnNi);
  }
}
