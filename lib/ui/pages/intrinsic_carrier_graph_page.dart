import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/latex_symbols.dart';
import '../../core/constants/constants_loader.dart';
import '../../core/constants/constants_repository.dart';
import '../theme/chart_style.dart';
import '../widgets/latex_text.dart';
import '../graphs/utils/latex_number_formatter.dart';
import '../graphs/utils/safe_math.dart';
import '../graphs/utils/semiconductor_models.dart';
import '../graphs/utils/debouncer.dart';

enum ScalingMode { locked, auto, wide }

class IntrinsicCarrierGraphPage extends StatelessWidget {
  const IntrinsicCarrierGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Intrinsic Carrier Concentration vs T')),
      body: const IntrinsicCarrierGraphView(),
    );
  }
}

class IntrinsicCarrierGraphView extends StatefulWidget {
  const IntrinsicCarrierGraphView({super.key});

  @override
  State<IntrinsicCarrierGraphView> createState() =>
      _IntrinsicCarrierGraphViewState();
}

class _IntrinsicCarrierGraphViewState extends State<IntrinsicCarrierGraphView> {
  int _chartVersion = 0;
  final Debouncer _debouncer = Debouncer(milliseconds: 24);
  static const int _maxPins = 4;
  // Parameters
  double _bandgap = 1.12; // eV (Silicon)
  double _mEffElectron = 1.08; // m0
  double _mEffHole = 0.56; // m0
  double _tMin = 200.0; // K
  double _tMax = 600.0; // K
  bool _useCmCubed = true; // true: cm^-3, false: m^-3
  bool _show300KReference = true; // Show 300K reference line
  bool _showNcNvOverlay = false; // Show Nc and Nv curves
  bool _arrheniusMode = false; // x-axis as 1/T
  ScalingMode _scaleMode = ScalingMode.locked;

  // Animation
  bool _isAnimating = false;
  Timer? _animationTimer;
  double _animationProgress = 0.0;
  List<FlSpot>?
      _baselineCurveData; // Baseline curve captured at animation start
  ScalingMode? _preAnimationScaleMode; // Store scale mode before animation

  // Interactive insight system
  FlSpot? _hoverSpot;
  final List<FlSpot> _pinnedSpots = [];

  static const _lockedRangeCm = (min: 4.0, max: 18.0);
  static const _lockedRangeM = (min: 10.0, max: 24.0);
  static const _wideRangeCm = (min: 0.0, max: 22.0);
  static const _wideRangeM = (min: 6.0, max: 28.0);

  // Physical constants (will load from repository)
  late Future<
      ({
        double h,
        double kB,
        double m0,
        double q,
        LatexSymbolMap latexMap,
      })> _constants;

  @override
  void initState() {
    super.initState();
    _constants = _loadConstants();
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _debouncer.dispose();
    super.dispose();
  }

  Future<
      ({
        double h,
        double kB,
        double m0,
        double q,
        LatexSymbolMap latexMap,
      })> _loadConstants() async {
    final repo = ConstantsRepository();
    await repo.load();
    final latexMap = await ConstantsLoader.loadLatexSymbols();

    return (
      h: repo.getConstantValue('h')!,
      kB: repo.getConstantValue('k')!,
      m0: repo.getConstantValue('m_0')!,
      q: repo.getConstantValue('q')!,
      latexMap: latexMap,
    );
  }

  void _scheduleChartRefresh() {
    _debouncer.run(() {
      if (!mounted) return;
      setState(() {
        _chartVersion++;
        // Clear selections when parameters change to avoid stale explanations
        _pinnedSpots.clear();
        _hoverSpot = null;
      });
    });
  }

  double _computeNc(double T, double h, double kB, double m0) {
    return SemiconductorModels.computeNc(
      temperatureK: T,
      h: h,
      kB: kB,
      m0: m0,
      effectiveMassRatio: _mEffElectron,
    );
  }

  double _computeNv(double T, double h, double kB, double m0) {
    return SemiconductorModels.computeNv(
      temperatureK: T,
      h: h,
      kB: kB,
      m0: m0,
      effectiveMassRatio: _mEffHole,
    );
  }

  double _computeNi(double T, double h, double kB, double m0, double q) {
    return SemiconductorModels.computeNi(
      temperatureK: T,
      h: h,
      kB: kB,
      m0: m0,
      q: q,
      bandgapEv: _bandgap,
      mnEffRatio: _mEffElectron,
      mpEffRatio: _mEffHole,
    );
  }

  List<FlSpot> _computeNiCurve(double h, double kB, double m0, double q) {
    const int numPoints = 300;
    final List<FlSpot> points = [];

    for (int i = 0; i < numPoints; i++) {
      final T = _tMin + (_tMax - _tMin) * i / (numPoints - 1);
      final niSI = _computeNi(T, h, kB, m0, q); // m^-3

      // Convert to cm^-3 if needed
      final ni = _useCmCubed ? niSI / 1e6 : niSI;

      // Use log10 for y-axis
      final logNi = math.log(ni) / math.ln10;

      if (SafeMath.isValid(logNi)) {
        final x = _arrheniusMode ? (1.0 / T) : T;
        points.add(FlSpot(x, logNi));
      }
    }

    if (_arrheniusMode) {
      final reversed = points.reversed.toList();
      return reversed;
    }
    return points;
  }

  void _startAnimation() async {
    if (_isAnimating) return;

    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Animation disabled due to reduced motion preference'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Load constants to capture baseline curve
    final constants = await _constants;

    setState(() {
      // Capture baseline curve at current E_g
      _baselineCurveData =
          _computeNiCurve(constants.h, constants.kB, constants.m0, constants.q);

      // Store current scale mode and switch to Auto for better animation visibility
      _preAnimationScaleMode = _scaleMode;
      _scaleMode = ScalingMode.auto;

      _isAnimating = true;
      _animationProgress = 0.0;
    });

    const duration = Duration(milliseconds: 2500);
    const steps = 60;
    final stepDuration =
        Duration(milliseconds: duration.inMilliseconds ~/ steps);

    _animationTimer = Timer.periodic(stepDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _animationProgress += 1.0 / steps;

        if (_animationProgress >= 1.0) {
          _animationProgress = 1.0;
          _isAnimating = false;
          timer.cancel();
          // Restore previous scale mode
          if (_preAnimationScaleMode != null) {
            _scaleMode = _preAnimationScaleMode!;
            _preAnimationScaleMode = null;
          }
          // Clear baseline curve after animation
          _baselineCurveData = null;
        }

        // Animate bandgap from 0.6 to 1.6 eV
        _bandgap = SafeMath.lerp(0.6, 1.6, _animationProgress);

        // Force chart rebuild on every tick
        _chartVersion++;
      });
    });
  }

  void _stopAnimation() {
    _animationTimer?.cancel();
    setState(() {
      _isAnimating = false;
      // Restore previous scale mode if stored
      if (_preAnimationScaleMode != null) {
        _scaleMode = _preAnimationScaleMode!;
        _preAnimationScaleMode = null;
      }
      // Clear baseline curve
      _baselineCurveData = null;
      _chartVersion++;
    });
  }

  void _resetAnimation() {
    _stopAnimation();
    setState(() {
      _animationProgress = 0.0;
      _bandgap = 0.6;
      _baselineCurveData = null;
      _chartVersion++;
    });
  }

  void _resetToSilicon() {
    _stopAnimation();
    setState(() {
      _bandgap = 1.12; // Silicon bandgap at 300K
      _mEffElectron = 1.08; // Silicon electron effective mass
      _mEffHole = 0.56; // Silicon hole effective mass
      _tMin = 200.0;
      _tMax = 600.0;
      _useCmCubed = true;
      _show300KReference = true;
      _showNcNvOverlay = false;
      _chartVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _constants,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final constants = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 12),
              _buildInfoPanel(context),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildChartArea(context, constants),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _buildControls(context),
                          const SizedBox(height: 12),
                          _buildAnimationControls(context),
                          const SizedBox(height: 12),
                          _buildInsights(context, constants),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Intrinsic Carrier Concentration vs Temperature',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const LatexText(
          r'n_i = \sqrt{N_c N_v}\,\exp\!\left(-\frac{E_g}{2\,k\,T}\right)',
          displayMode: true,
          scale: 1.2,
        ),
        const SizedBox(height: 4),
        const Text('Equivalent form:', style: TextStyle(fontSize: 12)),
        const LatexText(
          r'n_i^2 = N_c N_v \exp\!\left(-\frac{E_g}{k T}\right)',
          displayMode: true,
          scale: 1.0,
        ),
      ],
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Shows how intrinsic carrier concentration increases exponentially with temperature. The bandgap ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const LatexText(r'E_g', scale: 0.9),
                Text(
                  ' has a strong (exponential) effect on ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const LatexText(r'n_i', scale: 0.9),
                Text(
                  '.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartArea(
      BuildContext context,
      ({
        double h,
        double kB,
        double m0,
        double q,
        LatexSymbolMap latexMap
      }) constants) {
    final curveData =
        _computeNiCurve(constants.h, constants.kB, constants.m0, constants.q);

    if (curveData.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final yValues = curveData.map((spot) => spot.y).toList();
    final minLogY = yValues.reduce(math.min);
    final maxLogY = yValues.reduce(math.max);
    final yPadding = (maxLogY - minLogY) * 0.1;
    final unitLatex = _useCmCubed ? r'\mathrm{cm^{-3}}' : r'\mathrm{m^{-3}}';
    final unitUnicode = _useCmCubed ? 'cm⁻³' : 'm⁻³';

    double minY;
    double maxY;
    if (_scaleMode == ScalingMode.auto) {
      minY = minLogY - yPadding;
      maxY = maxLogY + yPadding;
    } else if (_scaleMode == ScalingMode.wide) {
      final range = _useCmCubed ? _wideRangeCm : _wideRangeM;
      minY = range.min;
      maxY = range.max;
    } else {
      final range = _useCmCubed ? _lockedRangeCm : _lockedRangeM;
      minY = range.min;
      maxY = range.max;
    }
    final double minX = _arrheniusMode ? (1.0 / _tMax) : _tMin;
    final double maxX = _arrheniusMode ? (1.0 / _tMin) : _tMax;

    final pinnedDots = List<FlSpot>.from(_pinnedSpots);
    final FlSpot? hoverDot =
        (_hoverSpot != null && !_pinnedSpots.contains(_hoverSpot))
            ? _hoverSpot
            : null;

    return LineChart(
      key: ValueKey('intrinsic-$_chartVersion'),
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 2,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LatexText(r'n_i', scale: 1.0),
                const SizedBox(width: 4),
                LatexText(r'(' + unitLatex + r',\ \text{log scale})',
                    scale: 0.85),
              ],
            ),
            axisNameSize: 50,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: context.chartStyle.leftReservedSize + 4,
              getTitlesWidget: (value, meta) {
                // Show as 10^n in LaTeX
                final exp = value.round();
                return Padding(
                  padding: context.chartStyle.tickPadding,
                  child: LatexText(
                    '10^{$exp}',
                    scale: 0.8,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: _arrheniusMode
                ? const LatexText(r'\frac{1}{T}\ (\mathrm{K^{-1}})',
                    scale: 0.95)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LatexText(r'T', scale: 1.0),
                      const SizedBox(width: 4),
                      const LatexText(r'(\mathrm{K})', scale: 0.85),
                    ],
                  ),
            axisNameSize: 40,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: context.chartStyle.bottomReservedSize,
              getTitlesWidget: (value, meta) {
                final label = _arrheniusMode
                    ? value.toStringAsFixed(4)
                    : value.toStringAsFixed(0);
                return Padding(
                  padding: context.chartStyle.tickPadding,
                  child: LatexText(
                    label,
                    style: context.chartStyle.tickTextStyle,
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        extraLinesData: _show300KReference
            ? ExtraLinesData(
                verticalLines: [
                  VerticalLine(
                    x: 300,
                    color: Colors.grey.withOpacity(0.5),
                    strokeWidth: 1.5,
                    dashArray: [5, 5],
                    label: VerticalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, top: 4),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      labelResolver: (line) => '300 K',
                    ),
                  ),
                ],
              )
            : null,
        lineBarsData: [
          // Baseline ghost curve (shown during animation)
          if (_baselineCurveData != null && _baselineCurveData!.isNotEmpty)
            LineChartBarData(
              spots: _baselineCurveData!,
              isCurved: true,
              color: Colors.grey.withOpacity(0.4),
              barWidth: 2.0,
              dotData: const FlDotData(show: false),
            ),
          // Main animated curve
          LineChartBarData(
            spots: curveData,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
          ),
          if (pinnedDots.isNotEmpty)
            LineChartBarData(
              spots: pinnedDots,
              isCurved: false,
              color: Colors.orange,
              barWidth: 0,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (_, __) => true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  color: Colors.orange,
                  radius: 4,
                  strokeColor: Colors.white,
                  strokeWidth: 1.5,
                ),
              ),
            ),
          if (hoverDot != null)
            LineChartBarData(
              spots: [hoverDot],
              isCurved: false,
              color: Colors.teal,
              barWidth: 0,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (_, __) => true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  color: Colors.transparent,
                  radius: 5,
                  strokeColor: Colors.teal,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchSpotThreshold: 28,
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            final spots = response?.lineBarSpots;
            final hasSpot = spots != null && spots.isNotEmpty;

            if (!hasSpot) {
              if (event is FlTapUpEvent) {
                setState(() {
                  _pinnedSpots.clear();
                  _hoverSpot = null;
                });
              } else if (event is FlPanEndEvent) {
                setState(() {
                  _hoverSpot = null;
                });
              }
              return;
            }

            final s = spots!.first;
            final spot = FlSpot(s.x, s.y);

            // Tap to pin (multi-pin, max 4 with FIFO replace)
            if (event is FlTapUpEvent) {
              debugPrint(
                  '🔵 Dynamic Insight: Pinning spot at x=${spot.x.toStringAsFixed(4)}');
              setState(() {
                // Avoid near-duplicate pins
                _pinnedSpots.removeWhere((p) => (p.x - spot.x).abs() < 1e-6);
                _pinnedSpots.add(spot);
                if (_pinnedSpots.length > _maxPins) {
                  _pinnedSpots.removeAt(0);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Replaced oldest pin (max 4)'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
                _hoverSpot = spot;
              });
              return;
            }

            // Hover/drag
            if (event is FlPointerHoverEvent ||
                event is FlPanUpdateEvent ||
                event is FlPanStartEvent) {
              setState(() {
                _hoverSpot = spot;
              });
              return;
            }

            // Pan end - clear hover
            if (event is FlPanEndEvent) {
              setState(() {
                _hoverSpot = null;
              });
            }
          },
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final T = _arrheniusMode ? (1.0 / spot.x) : spot.x;
                final invT = 1.0 / T;
                final logNi = spot.y;
                final ni = math.pow(10, logNi).toDouble();

                final niFormatted =
                    LatexNumberFormatter.toUnicodeSci(ni, sigFigs: 3);

                return LineTooltipItem(
                  'T: ${T.toStringAsFixed(1)} K${_arrheniusMode ? ' • 1/T=${invT.toStringAsFixed(4)} K⁻¹' : ''}\n',
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: 'nᵢ: $niFormatted $unitUnicode\n',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.normal),
                    ),
                    TextSpan(
                      text: 'log₁₀(nᵢ) = ${logNi.toStringAsFixed(2)}\n',
                      style: TextStyle(fontSize: 10, color: Colors.grey[300]),
                    ),
                    TextSpan(
                      text: '(Tap curve to pin; tap empty to clear)',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parameters', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),

            // Bandgap slider
            Row(
              children: [
                const SizedBox(
                  width: 60,
                  child: LatexText(r'E_g', scale: 1.0),
                ),
                Expanded(
                  child: Slider(
                    value: _bandgap,
                    min: 0.2,
                    max: 2.5,
                    divisions: 230,
                    label: '${_bandgap.toStringAsFixed(2)} eV',
                    onChanged: _isAnimating
                        ? null
                        : (value) {
                            setState(() {
                              _bandgap = value;
                            });
                            _scheduleChartRefresh();
                          },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_bandgap.toStringAsFixed(3)} eV',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Strong (exponential) effect on nᵢ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Electron effective mass
            Row(
              children: [
                const SizedBox(
                  width: 60,
                  child: LatexText(r'm_n^*', scale: 1.0),
                ),
                Expanded(
                  child: Slider(
                    value: _mEffElectron,
                    min: 0.05,
                    max: 2.0,
                    divisions: 195,
                    label: '${_mEffElectron.toStringAsFixed(2)} m₀',
                    onChanged: _isAnimating
                        ? null
                        : (value) {
                            setState(() {
                              _mEffElectron = value;
                            });
                            _scheduleChartRefresh();
                          },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_mEffElectron.toStringAsFixed(2)} m₀',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Moderate effect via Nₓ ∝ (m*T)^(3/2)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Hole effective mass
            Row(
              children: [
                const SizedBox(
                  width: 60,
                  child: LatexText(r'm_p^*', scale: 1.0),
                ),
                Expanded(
                  child: Slider(
                    value: _mEffHole,
                    min: 0.05,
                    max: 2.0,
                    divisions: 195,
                    label: '${_mEffHole.toStringAsFixed(2)} m₀',
                    onChanged: _isAnimating
                        ? null
                        : (value) {
                            setState(() {
                              _mEffHole = value;
                            });
                            _scheduleChartRefresh();
                          },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_mEffHole.toStringAsFixed(2)} m₀',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Moderate effect via Nᵥ ∝ (m*T)^(3/2)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Unit toggle
            SwitchListTile(
              title: const LatexText(r'Units'),
              subtitle: LatexText(
                  _useCmCubed ? r'\mathrm{cm^{-3}}' : r'\mathrm{m^{-3}}'),
              value: _useCmCubed,
              onChanged: (value) {
                setState(() {
                  _useCmCubed = value;
                });
                _scheduleChartRefresh();
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const LatexText(r'\text{Arrhenius plot }(1/T)'),
              subtitle: const LatexText(
                  r'x\text{-axis becomes }\frac{1}{T}\ (\mathrm{K^{-1}})'),
              value: _arrheniusMode,
              onChanged: (value) {
                setState(() {
                  _arrheniusMode = value;
                });
                _scheduleChartRefresh();
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 4),
            Text('Y-axis scaling',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            SegmentedButton<ScalingMode>(
              segments: const [
                ButtonSegment(value: ScalingMode.locked, label: Text('Locked')),
                ButtonSegment(value: ScalingMode.auto, label: Text('Auto')),
                ButtonSegment(value: ScalingMode.wide, label: Text('Wide')),
              ],
              selected: {_scaleMode},
              onSelectionChanged: (s) {
                setState(() {
                  _scaleMode = s.first;
                });
                _scheduleChartRefresh();
              },
            ),

            const SizedBox(height: 8),

            // 300K Reference toggle
            SwitchListTile(
              title: const Text('300 K Reference'),
              subtitle: const Text('Show marker line'),
              value: _show300KReference,
              onChanged: (value) {
                setState(() {
                  _show300KReference = value;
                });
                _scheduleChartRefresh();
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 16),

            // Reset to Silicon button
            ElevatedButton.icon(
              onPressed: _resetToSilicon,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Reset to Silicon'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimationControls(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Animation', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            const LatexText(
              r'\text{Animate }E_g: 0.6\ \to\ 1.6\ \mathrm{eV}',
              scale: 0.95,
            ),
            const SizedBox(height: 8),

            // Live E_g readout during animation
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Current: ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                LatexText(
                  'E_g = ${_bandgap.toStringAsFixed(3)}\\,\\mathrm{eV}',
                  scale: 0.95,
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(_isAnimating ? Icons.pause : Icons.play_arrow),
                  onPressed: _isAnimating ? _stopAnimation : _startAnimation,
                  tooltip: _isAnimating ? 'Pause' : 'Play',
                ),
                IconButton(
                  icon: const Icon(Icons.replay),
                  onPressed: _resetAnimation,
                  tooltip: 'Reset',
                ),
              ],
            ),

            if (_isAnimating)
              LinearProgressIndicator(value: _animationProgress),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights(BuildContext context,
      ({double h, double kB, double m0, double q, LatexSymbolMap latexMap}) c) {
    final ni300Si = _computeNi(300, c.h, c.kB, c.m0, c.q);
    final ni300Disp = _toDisplayDensity(ni300Si);
    final FlSpot? focusSpot =
        _pinnedSpots.isNotEmpty ? _pinnedSpots.last : _hoverSpot;

    // Compute curve to get log span for key observations
    final curveData = _computeNiCurve(c.h, c.kB, c.m0, c.q);
    double? decadesSpan;
    double? minLog;
    double? maxLog;
    if (curveData.isNotEmpty) {
      final yValues = curveData.map((spot) => spot.y).toList();
      minLog = yValues.reduce(math.min);
      maxLog = yValues.reduce(math.max);
      decadesSpan = maxLog - minLog;
    }

    _SpotBreakdown? breakdown;
    if (focusSpot != null) breakdown = _spotBreakdown(focusSpot, c, ni300Disp);
    final unitLatex = _useCmCubed ? r'\mathrm{cm^{-3}}' : r'\mathrm{m^{-3}}';

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Insights & Pins',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pinnedSpots.isEmpty
                      ? null
                      : () => setState(() {
                            _pinnedSpots.clear();
                            _chartVersion++;
                          }),
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear pins'),
                  style:
                      ElevatedButton.styleFrom(minimumSize: const Size(0, 34)),
                ),
                const SizedBox(width: 8),
                LatexText(
                  r'\text{Pinned: }' +
                      _pinnedSpots.length.toString() +
                      r'\text{ (max 4) }\cdot\ \text{Baseline }300\,\mathrm{K}',
                  scale: 0.95,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (breakdown != null) ...[
              _detailRow(
                  r'T', '${breakdown.tempK.toStringAsFixed(1)}\\,\\mathrm{K}',
                  latex: true),
              if (_arrheniusMode)
                _detailRow(r'\\frac{1}{T}',
                    '${breakdown.invTemp.toStringAsFixed(4)}\\,\\mathrm{K^{-1}}',
                    latex: true),
              _detailRow(
                  r'n_i',
                  LatexNumberFormatter.valueWithUnit(breakdown.niDisplay,
                      unitLatex: unitLatex),
                  latex: true),
              _detailRow(r'\\log_{10}(n_i)', breakdown.logNi.toStringAsFixed(3),
                  latex: true),
              _detailRow(r'\\frac{n_i}{n_i(300\\,\\mathrm{K})}',
                  '${LatexNumberFormatter.toScientific(breakdown.ratioTo300, sigFigs: 3)}\\ (\\approx ${breakdown.decadesVs300.toStringAsFixed(2)}\\ \\text{dec})',
                  latex: true),
              const SizedBox(height: 6),
              Text('Breakdown', style: Theme.of(context).textTheme.bodyMedium),
              _detailRow(
                  r'kT\\ (\\mathrm{eV})', breakdown.kT.toStringAsFixed(4),
                  latex: true),
              _detailRow(
                  r'\\frac{E_g}{kT}', breakdown.egOverkT.toStringAsFixed(2),
                  latex: true),
              _detailRow(
                  r'N_c',
                  LatexNumberFormatter.valueWithUnit(breakdown.NcDisp,
                      unitLatex: unitLatex),
                  latex: true),
              _detailRow(
                  r'N_v',
                  LatexNumberFormatter.valueWithUnit(breakdown.NvDisp,
                      unitLatex: unitLatex),
                  latex: true),
              _detailRow(
                  r'\\sqrt{N_c N_v}',
                  LatexNumberFormatter.valueWithUnit(breakdown.sqrtNcNvDisp,
                      unitLatex: unitLatex),
                  latex: true),
              _detailRow(
                r'\\exp\\!\\left(-\\frac{E_g}{2kT}\\right)',
                LatexNumberFormatter.toScientific(breakdown.expFactor,
                    sigFigs: 3),
                latex: true,
              ),
            ] else
              Text(
                  'Tap the curve to pin points; drag to preview. Pins compare against 300 K.',
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            if (_pinnedSpots.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pinned points',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  ..._pinnedSpots.map((p) {
                    final b = _spotBreakdown(p, c, ni300Disp);
                    final niLatex = LatexNumberFormatter.valueWithUnit(
                        b.niDisplay,
                        unitLatex: unitLatex);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: LatexText(
                              r'T=' +
                                  b.tempK.toStringAsFixed(1) +
                                  r'\,\mathrm{K},\ n_i=' +
                                  niLatex,
                              scale: 0.95,
                            ),
                          ),
                          LatexText(r'\times ' +
                              LatexNumberFormatter.toScientific(b.ratioTo300,
                                  sigFigs: 3)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            const SizedBox(height: 10),
            Text(
              _pinnedSpots.length >= 2
                  ? 'Key observations (from your pins)'
                  : 'Key observations',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_pinnedSpots.length >= 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: LatexText(
                  r'n_i \propto \sqrt{N_c N_v}\,\exp\!\left(-\frac{E_g}{2kT}\right)',
                  displayMode: true,
                  scale: 1.0,
                ),
              ),
            ..._buildObservationBullets(c, ni300Disp,
                    decadesSpan: decadesSpan, minLog: minLog, maxLog: maxLog)
                .map((b) => _bullet(b.text, latex: b.latex)),
          ],
        ),
      ),
    );
  }

  _SpotBreakdown _spotBreakdown(
      FlSpot spot,
      ({double h, double kB, double m0, double q, LatexSymbolMap latexMap}) c,
      double ni300Disp) {
    final tempK = _arrheniusMode ? (1.0 / spot.x) : spot.x;
    final invTemp = 1.0 / tempK;
    final logNi = spot.y;
    final niDisp = math.pow(10, logNi).toDouble();

    final NcSi = _computeNc(tempK, c.h, c.kB, c.m0);
    final NvSi = _computeNv(tempK, c.h, c.kB, c.m0);
    final NcDisp = _toDisplayDensity(NcSi);
    final NvDisp = _toDisplayDensity(NvSi);
    final sqrtNcNvDisp = _toDisplayDensity(math.sqrt(NcSi * NvSi));

    final kT = c.kB * tempK / c.q; // eV
    final egOverkT = _bandgap / kT;
    final expFactor = math.exp(-_bandgap / (2 * kT));

    final ratioTo300 = niDisp / ni300Disp;
    final decades = logNi -
        (SafeMath.isValid(ni300Disp) ? math.log(ni300Disp) / math.ln10 : 0);

    return _SpotBreakdown(
      tempK: tempK,
      invTemp: invTemp,
      niDisplay: niDisp,
      logNi: logNi,
      NcDisp: NcDisp,
      NvDisp: NvDisp,
      sqrtNcNvDisp: sqrtNcNvDisp,
      kT: kT,
      egOverkT: egOverkT,
      expFactor: expFactor,
      ratioTo300: ratioTo300,
      decadesVs300: decades,
    );
  }

  double _toDisplayDensity(double si) => _useCmCubed ? si / 1e6 : si;
  String _unitUnicode() => _useCmCubed ? 'cm⁻³' : 'm⁻³';

  List<_BulletEntry> _buildObservationBullets(
    ({double h, double kB, double m0, double q, LatexSymbolMap latexMap}) c,
    double ni300Disp, {
    double? decadesSpan,
    double? minLog,
    double? maxLog,
  }) {
    if (_pinnedSpots.length < 2) {
      // Build the log-scale explanation with quantified decades
      String logScaleBullet;
      if (decadesSpan != null && minLog != null && maxLog != null) {
        final minExp = minLog.round();
        final maxExp = maxLog.round();
        logScaleBullet = r'\text{Log scale needed: }n_i\text{ spans }' +
            decadesSpan.toStringAsFixed(1) +
            r'\text{ decades (}\approx 10^{' +
            minExp.toString() +
            r'}\text{ to }10^{' +
            maxExp.toString() +
            r'})';
      } else {
        logScaleBullet =
            r'\text{Log scaling is essential because }n_i\text{ spans many decades}';
      }

      return [
        const _BulletEntry(
            r'n_i \text{ rises exponentially with }T;\ \text{slope}\approx -E_g/(2k)',
            true),
        const _BulletEntry(
            r'\text{Larger }E_g\text{ suppresses }n_i;\ N_c,N_v\propto T^{3/2}',
            true),
        _BulletEntry(logScaleBullet, true),
      ];
    }

    final pins = List<FlSpot>.from(_pinnedSpots);
    pins.sort((a, b) => a.x.compareTo(b.x));

    final first = pins.first;
    final last = pins.last;
    final deltaLog = last.y - first.y;
    final deltaX = (_arrheniusMode ? (last.x - first.x) : (last.x - first.x));
    final slope = deltaX.abs() > 0 ? deltaLog / deltaX : 0;

    final ratios = pins
        .map((p) => math.pow(10, p.y).toDouble() / ni300Disp)
        .where((v) => v.isFinite && v > 0)
        .toList();
    double? minR = ratios.isNotEmpty ? ratios.reduce(math.min) : null;
    double? maxR = ratios.isNotEmpty ? ratios.reduce(math.max) : null;

    _BulletEntry slopeDesc;
    if (_arrheniusMode) {
      // simple least squares slope for log10 vs x
      final n = pins.length.toDouble();
      final sumX = pins.fold<double>(0, (s, p) => s + p.x);
      final sumY = pins.fold<double>(0, (s, p) => s + p.y);
      final sumXY = pins.fold<double>(0, (s, p) => s + p.x * p.y);
      final sumXX = pins.fold<double>(0, (s, p) => s + p.x * p.x);
      final denom = n * sumXX - sumX * sumX;
      final fitSlope =
          denom.abs() > 1e-12 ? (n * sumXY - sumX * sumY) / denom : slope;
      slopeDesc = _BulletEntry(
          r'\text{Arrhenius slope}\approx ' +
              fitSlope.toStringAsFixed(2) +
              r'\ \text{(}\log_{10} n_i \text{ vs }1/T\text{)}',
          true);
    } else {
      slopeDesc = _BulletEntry(
        r'\text{Between }' +
            _formatTempLatex(first.x) +
            r'\text{ and }' +
            _formatTempLatex(last.x) +
            r',\ n_i\ \text{changes }\approx ' +
            deltaLog.toStringAsFixed(2) +
            r'\ \text{decades}',
        true,
      );
    }

    final ratioDesc = (minR != null && maxR != null)
        ? _BulletEntry(
            r'\text{Pinned range: }' +
                LatexNumberFormatter.toScientific(minR, sigFigs: 2) +
                r'\times \text{ to }' +
                LatexNumberFormatter.toScientific(maxR, sigFigs: 2) +
                r'\times\ n_i(300\,\mathrm{K})',
            true,
          )
        : const _BulletEntry(
            r'\text{Pinned range compared to 300 K unavailable}', true);

    return [
      slopeDesc,
      ratioDesc,
      const _BulletEntry(
          r'\text{Theory: }n_i \propto \sqrt{N_c N_v}\,\exp\!\left(-\frac{E_g}{2kT}\right)\ \text{(exp term dominates)}',
          true),
    ];
  }

  String _formatTemp(double t) => '${t.toStringAsFixed(1)}K';
  String _formatTempLatex(double t) => t.toStringAsFixed(1) + r'\,\mathrm{K}';

  Widget _detailRow(String label, String value, {bool latex = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: latex
                ? LatexText(label,
                    style: const TextStyle(fontWeight: FontWeight.w600))
                : Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: latex ? LatexText(value) : Text(value),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text, {bool latex = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: latex ? LatexText(text) : Text(text)),
        ],
      ),
    );
  }
}

class _BulletEntry {
  final String text;
  final bool latex;
  const _BulletEntry(this.text, this.latex);
}

class _SpotBreakdown {
  final double tempK;
  final double invTemp;
  final double niDisplay;
  final double logNi;
  final double NcDisp;
  final double NvDisp;
  final double sqrtNcNvDisp;
  final double kT;
  final double egOverkT;
  final double expFactor;
  final double ratioTo300;
  final double decadesVs300;

  _SpotBreakdown({
    required this.tempK,
    required this.invTemp,
    required this.niDisplay,
    required this.logNi,
    required this.NcDisp,
    required this.NvDisp,
    required this.sqrtNcNvDisp,
    required this.kT,
    required this.egOverkT,
    required this.expFactor,
    required this.ratioTo300,
    required this.decadesVs300,
  });
}
