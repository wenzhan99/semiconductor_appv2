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

// Standardized components
import '../graphs/common/graph_controller.dart';
import '../graphs/common/readouts_card.dart';
import '../graphs/common/point_inspector_card.dart';
import '../graphs/common/animation_card.dart';
import '../graphs/common/parameters_card.dart';
import '../graphs/common/key_observations_card.dart';
import '../graphs/core/graph_config.dart' show GraphConfig, ControlsConfig;
import '../graphs/core/standard_graph_page_scaffold.dart';

enum ScalingMode { locked, auto, wide }

class IntrinsicCarrierGraphPage extends StatelessWidget {
  const IntrinsicCarrierGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Intrinsic Carrier Concentration vs T')),
      body: const _IntrinsicCarrierGraphView(),
    );
  }
}

class _IntrinsicCarrierGraphView extends StatefulWidget {
  const _IntrinsicCarrierGraphView();

  @override
  State<_IntrinsicCarrierGraphView> createState() => _IntrinsicCarrierGraphViewState();
}

class _IntrinsicCarrierGraphViewState extends State<_IntrinsicCarrierGraphView>
    with GraphController {
  final Debouncer _debouncer = Debouncer(milliseconds: 24);
  static const int _maxPins = 4;

  // Parameters
  double _bandgap = 1.12;
  double _mEffElectron = 1.08;
  double _mEffHole = 0.56;
  double _tMin = 200.0;
  double _tMax = 600.0;
  bool _useCmCubed = true;
  bool _show300KReference = true;
  bool _arrheniusMode = false;
  ScalingMode _scaleMode = ScalingMode.locked;

  // Animation
  bool _isAnimating = false;
  Timer? _animationTimer;
  double _animationProgress = 0.0;
  List<FlSpot>? _baselineCurveData;
  ScalingMode? _preAnimationScaleMode;

  // Interactive system
  FlSpot? _hoverSpot;
  final List<FlSpot> _pinnedSpots = [];

  static const _lockedRangeCm = (min: 4.0, max: 18.0);
  static const _lockedRangeM = (min: 10.0, max: 24.0);
  static const _wideRangeCm = (min: 0.0, max: 22.0);
  static const _wideRangeM = (min: 6.0, max: 28.0);

  late Future<_Constants> _constants;

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

  Future<_Constants> _loadConstants() async {
    final repo = ConstantsRepository();
    await repo.load();
    final latexMap = await ConstantsLoader.loadLatexSymbols();
    return _Constants(
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
      updateChart(() {
        _pinnedSpots.clear();
        _hoverSpot = null;
      });
    });
  }

  // === Physics computations ===
  double _computeNc(double T, double h, double kB, double m0) =>
      SemiconductorModels.computeNc(
        temperatureK: T,
        h: h,
        kB: kB,
        m0: m0,
        effectiveMassRatio: _mEffElectron,
      );

  double _computeNv(double T, double h, double kB, double m0) =>
      SemiconductorModels.computeNv(
        temperatureK: T,
        h: h,
        kB: kB,
        m0: m0,
        effectiveMassRatio: _mEffHole,
      );

  double _computeNi(double T, double h, double kB, double m0, double q) =>
      SemiconductorModels.computeNi(
        temperatureK: T,
        h: h,
        kB: kB,
        m0: m0,
        q: q,
        bandgapEv: _bandgap,
        mnEffRatio: _mEffElectron,
        mpEffRatio: _mEffHole,
      );

  List<FlSpot> _computeNiCurve(double h, double kB, double m0, double q) {
    const int numPoints = 300;
    final points = <FlSpot>[];

    for (int i = 0; i < numPoints; i++) {
      final T = _tMin + (_tMax - _tMin) * i / (numPoints - 1);
      final niSI = _computeNi(T, h, kB, m0, q);
      final ni = _useCmCubed ? niSI / 1e6 : niSI;
      final logNi = math.log(ni) / math.ln10;

      if (SafeMath.isValid(logNi)) {
        final x = _arrheniusMode ? (1.0 / T) : T;
        points.add(FlSpot(x, logNi));
      }
    }

    return _arrheniusMode ? points.reversed.toList() : points;
  }

  // === Animation ===
  void _startAnimation() async {
    if (_isAnimating) return;
    final constants = await _constants;

    setState(() {
      _baselineCurveData = _computeNiCurve(
        constants.h,
        constants.kB,
        constants.m0,
        constants.q,
      );
      _preAnimationScaleMode = _scaleMode;
      _scaleMode = ScalingMode.auto;
      _isAnimating = true;
      _animationProgress = 0.0;
    });

    const duration = Duration(milliseconds: 2500);
    const steps = 60;
    final stepDuration = Duration(milliseconds: duration.inMilliseconds ~/ steps);

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
          if (_preAnimationScaleMode != null) {
            _scaleMode = _preAnimationScaleMode!;
            _preAnimationScaleMode = null;
          }
          _baselineCurveData = null;
        }
        _bandgap = SafeMath.lerp(0.6, 1.6, _animationProgress);
        bumpChart();
      });
    });
  }

  void _stopAnimation() {
    _animationTimer?.cancel();
    setState(() {
      _isAnimating = false;
      if (_preAnimationScaleMode != null) {
        _scaleMode = _preAnimationScaleMode!;
        _preAnimationScaleMode = null;
      }
      _baselineCurveData = null;
      bumpChart();
    });
  }

  void _resetAnimation() {
    _stopAnimation();
    setState(() {
      _animationProgress = 0.0;
      _bandgap = 0.6;
      _baselineCurveData = null;
      bumpChart();
    });
  }

  void _resetToSilicon() {
    _stopAnimation();
    setState(() {
      _bandgap = 1.12;
      _mEffElectron = 1.08;
      _mEffHole = 0.56;
      _tMin = 200.0;
      _tMax = 600.0;
      _useCmCubed = true;
      _show300KReference = true;
      bumpChart();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Constants>(
      future: _constants,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final c = snapshot.data!;
        final curveData = _computeNiCurve(c.h, c.kB, c.m0, c.q);

        return StandardGraphPageScaffold(
          config: const GraphConfig(
            title: 'Intrinsic Carrier Concentration vs Temperature',
            subtitle: 'DOS & Statistics',
            mainEquation:
                r'n_i = \sqrt{N_c N_v}\,\exp\!\left(-\frac{E_g}{2\,k\,T}\right)',
            controls: ControlsConfig(children: []),
          ),
          aboutSection: _buildAboutCard(context),
          observeSection: _buildObserveCard(context),
          chartBuilder: (context) => _buildChartArea(context, c, curveData),
          rightPanelBuilder: (context, config) => _buildRightPanel(c),
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
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'DOS & Statistics',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                const LatexText(
                  r'n_i = \sqrt{N_c N_v}\,\exp\!\left(-\frac{E_g}{2\,k\,T}\right)',
                  displayMode: true,
                  scale: 1.2,
                ),
                const SizedBox(height: 8),
                Text(
                  'Equivalent form:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 4),
                const LatexText(
                  r'n_i^2 = N_c N_v \exp\!\left(-\frac{E_g}{k T}\right)',
                  displayMode: true,
                  scale: 1.0,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Shows how intrinsic carrier concentration increases exponentially with temperature. The bandgap ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const LatexText(r'E_g', scale: 1.0),
                Text(
                  ' has a strong (exponential) effect on ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const LatexText(r'n_i', scale: 1.0),
                Text('.', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObserveCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(
          'What you should observe',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _bullet(r'$n_i$ rises exponentially with T; slope â‰ˆ $-E_g/(2k)$ on Arrhenius plot.'),
          _bullet(r'Larger $E_g$ suppresses $n_i$; $N_c$, $N_v \propto T^{3/2}$ (weaker effect).'),
          _bullet(r'Log scale is essential because $n_i$ spans many decades over temperature range.'),
          const SizedBox(height: 8),
          Text('Try this:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          _bullet('Animate bandgap from 0.6 to 1.6 eV and watch curve shift dramatically.'),
          _bullet('Pin points at different temperatures to compare ratios vs 300K.'),
          _bullet('Switch to Arrhenius mode (1/T x-axis) to see linear log plot.'),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('â€¢ '),
          Expanded(
            child: _parseLatex(text, Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _parseLatex(String text, TextStyle? baseStyle) {
    // Simple inline LaTeX parser for $ delimiters
    final parts = <Widget>[];
    final buffer = StringBuffer();
    var inLatex = false;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == r'$') {
        if (buffer.isNotEmpty) {
          parts.add(inLatex
              ? LatexText(buffer.toString(), style: baseStyle, scale: 1.0)
              : Text(buffer.toString(), style: baseStyle));
          buffer.clear();
        }
        inLatex = !inLatex;
      } else {
        buffer.write(char);
      }
    }
    if (buffer.isNotEmpty) {
      parts.add(inLatex
          ? LatexText(buffer.toString(), style: baseStyle, scale: 1.0)
          : Text(buffer.toString(), style: baseStyle));
    }
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: parts);
  }

  Widget _buildRightPanel(_Constants c) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildReadoutsCard(c),
          const SizedBox(height: 12),
          _buildPointInspectorCard(c),
          const SizedBox(height: 12),
          _buildAnimationCard(),
          const SizedBox(height: 12),
          _buildKeyObservationsCard(c),
          const SizedBox(height: 12),
          _buildParametersCard(),
        ],
      ),
    );
  }

  Widget _buildReadoutsCard(_Constants c) {
    final ni300 = _computeNi(300, c.h, c.kB, c.m0, c.q);
    final ni300Display = _useCmCubed ? ni300 / 1e6 : ni300;
    final unit = _useCmCubed ? 'cmâ»Â³' : 'mâ»Â³';

    return ReadoutsCard(
      title: 'Readouts (at 300 K)',
      readouts: [
        ReadoutItem(
          label: r'$n_i$(300K)',
          value: '${LatexNumberFormatter.toUnicodeSci(ni300Display, sigFigs: 3)} $unit',
        ),
        ReadoutItem(
          label: r'$\log_{10}(n_i)$',
          value: (math.log(ni300Display) / math.ln10).toStringAsFixed(2),
        ),
        ReadoutItem(
          label: r'Current $E_g$',
          value: '${_bandgap.toStringAsFixed(3)} eV',
          boldValue: true,
        ),
      ],
    );
  }

  Widget _buildPointInspectorCard(_Constants c) {
    return PointInspectorCard<FlSpot>(
      selectedPoint: _hoverSpot,
      onClear: () => updateChart(() {
        _hoverSpot = null;
        _pinnedSpots.clear();
      }),
      builder: (spot) {
        final T = _arrheniusMode ? (1.0 / spot.x) : spot.x;
        final logNi = spot.y;
        final ni = math.pow(10, logNi).toDouble();
        final niFormatted = LatexNumberFormatter.toUnicodeSci(ni, sigFigs: 3);
        final unit = _useCmCubed ? 'cmâ»Â³' : 'mâ»Â³';

        return [
          'T = ${T.toStringAsFixed(1)} K',
          '$niFormatted $unit',
          r'$\log_{10}(n_i)$ = ${logNi.toStringAsFixed(2)}',
          'Tap curve to pin (max $_maxPins)',
        ];
      },
    );
  }

  Widget _buildAnimationCard() {
    return AnimationCard(
      description: r'Animate $E_g$: 0.6 â†’ 1.6 eV',
      currentValue: 'Current: \$E_g = ${_bandgap.toStringAsFixed(3)}\\,\\mathrm{eV}\$',
      isAnimating: _isAnimating,
      progress: _animationProgress,
      onPlay: _startAnimation,
      onPause: _stopAnimation,
      onReset: _resetAnimation,
    );
  }

  Widget _buildParametersCard() {
    return ParametersCard(
      title: 'Parameters',
      collapsible: true,
      initiallyExpanded: true,
      children: [
        ParameterSlider(
          label: r'$E_g$ (eV)',
          value: _bandgap,
          min: 0.2,
          max: 2.5,
          divisions: 230,
          onChanged: _isAnimating
              ? null
              : (v) {
                  setState(() => _bandgap = v);
                  _scheduleChartRefresh();
                },
          subtitle: 'Strong (exponential) effect on náµ¢',
        ),
        ParameterSlider(
          label: r'$m_n^*$ (Ã—$m_0$)',
          value: _mEffElectron,
          min: 0.05,
          max: 2.0,
          divisions: 195,
          onChanged: _isAnimating
              ? null
              : (v) {
                  setState(() => _mEffElectron = v);
                  _scheduleChartRefresh();
                },
          subtitle: 'Moderate effect via Nâ‚“ âˆ (m*T)^(3/2)',
        ),
        ParameterSlider(
          label: r'$m_p^*$ (Ã—$m_0$)',
          value: _mEffHole,
          min: 0.05,
          max: 2.0,
          divisions: 195,
          onChanged: _isAnimating
              ? null
              : (v) {
                  setState(() => _mEffHole = v);
                  _scheduleChartRefresh();
                },
          subtitle: 'Moderate effect via Náµ¥ âˆ (m*T)^(3/2)',
        ),
        ParameterSwitch(
          label: 'Units',
          subtitle: _useCmCubed ? 'cmâ»Â³' : 'mâ»Â³',
          value: _useCmCubed,
          onChanged: (v) {
            setState(() => _useCmCubed = v);
            _scheduleChartRefresh();
          },
        ),
        ParameterSwitch(
          label: r'Arrhenius plot ($1/T$ x-axis)',
          value: _arrheniusMode,
          onChanged: (v) {
            setState(() => _arrheniusMode = v);
            _scheduleChartRefresh();
          },
        ),
        ParameterSegmented<ScalingMode>(
          label: 'Y-axis scaling',
          selected: {_scaleMode},
          segments: const [
            ButtonSegment(value: ScalingMode.locked, label: Text('Locked')),
            ButtonSegment(value: ScalingMode.auto, label: Text('Auto')),
            ButtonSegment(value: ScalingMode.wide, label: Text('Wide')),
          ],
          onSelectionChanged: (s) {
            setState(() => _scaleMode = s.first);
            _scheduleChartRefresh();
          },
        ),
        ParameterSwitch(
          label: '300 K Reference',
          value: _show300KReference,
          onChanged: (v) {
            setState(() => _show300KReference = v);
            _scheduleChartRefresh();
          },
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _resetToSilicon,
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text('Reset to Silicon'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 36),
          ),
        ),
      ],
    );
  }

  Widget _buildKeyObservationsCard(_Constants c) {
    final dynamicObs = _buildDynamicObservations(c);
    final staticObs = _buildStaticObservations(c);

    return KeyObservationsCard(
      title: 'Key Observations & Pins',
      dynamicObservations: dynamicObs,
      staticObservations: staticObs,
      dynamicTitle: _pinnedSpots.length >= 2 ? 'From Your Pins' : null,
      customHeader: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _pinnedSpots.isEmpty
                ? null
                : () => updateChart(() => _pinnedSpots.clear()),
            icon: const Icon(Icons.clear_all, size: 18),
            label: Text('Clear ${_pinnedSpots.length} pins'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 32)),
          ),
          const SizedBox(width: 8),
          Text(
            '(Max $_maxPins)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  List<String> _buildDynamicObservations(_Constants c) {
    if (_pinnedSpots.length < 2) return [];

    final pins = List<FlSpot>.from(_pinnedSpots)..sort((a, b) => a.x.compareTo(b.x));
    final first = pins.first;
    final last = pins.last;
    final deltaLog = last.y - first.y;

    final obs = <String>[];
    obs.add(
        'Between ${_fmtT(first.x)} and ${_fmtT(last.x)}, \$n_i\$ changes â‰ˆ ${deltaLog.toStringAsFixed(2)} decades.');

    // Ratio range
    final ni300 = _computeNi(300, c.h, c.kB, c.m0, c.q);
    final ni300Display = _useCmCubed ? ni300 / 1e6 : ni300;
    final ratios = pins.map((p) {
      final ni = math.pow(10, p.y).toDouble();
      return ni / ni300Display;
    }).toList();
    final minR = ratios.reduce(math.min);
    final maxR = ratios.reduce(math.max);
    obs.add(
        'Pinned range: \$${LatexNumberFormatter.toScientific(minR, sigFigs: 2)}\\times\$ to \$${LatexNumberFormatter.toScientific(maxR, sigFigs: 2)}\\times\$ vs 300K.');

    return obs;
  }

  List<String> _buildStaticObservations(_Constants c) {
    return [
      r'$n_i$ âˆ $\sqrt{N_c N_v}\,\exp\!\left(-\frac{E_g}{2kT}\right)$; exponential term dominates.',
      r'Larger $E_g$ â†’ lower $n_i$; key parameter for device design.',
      r'Log scale needed: $n_i$ spans ~10 decades between 200K and 600K.',
    ];
  }

  String _fmtT(double x) {
    final T = _arrheniusMode ? (1.0 / x) : x;
    return '${T.toStringAsFixed(1)} K';
  }

  Widget _buildChartArea(BuildContext context, _Constants c, List<FlSpot> curveData) {
    if (curveData.isEmpty) return const Center(child: Text('No data'));

    final yValues = curveData.map((s) => s.y).toList();
    final minLogY = yValues.reduce(math.min);
    final maxLogY = yValues.reduce(math.max);
    final yPadding = (maxLogY - minLogY) * 0.1;

    double minY, maxY;
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

    final minX = _arrheniusMode ? (1.0 / _tMax) : _tMin;
    final maxX = _arrheniusMode ? (1.0 / _tMin) : _tMax;
    final unitLatex = _useCmCubed ? r'\mathrm{cm^{-3}}' : r'\mathrm{m^{-3}}';

    final lineBars = <LineChartBarData>[
      if (_baselineCurveData != null)
        LineChartBarData(
          spots: _baselineCurveData!,
          isCurved: true,
          color: Colors.grey.withOpacity(0.4),
          barWidth: 2.0,
          dotData: const FlDotData(show: false),
        ),
      LineChartBarData(
        spots: curveData,
        isCurved: true,
        color: Theme.of(context).colorScheme.primary,
        barWidth: 2.5,
        dotData: const FlDotData(show: false),
      ),
      if (_pinnedSpots.isNotEmpty)
        LineChartBarData(
          spots: _pinnedSpots,
          isCurved: false,
          color: Colors.orange,
          barWidth: 0,
          dotData: FlDotData(
            show: true,
            checkToShowDot: (_, __) => true,
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
              color: Colors.orange,
              radius: 5,
              strokeColor: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
      if (_hoverSpot != null && !_pinnedSpots.contains(_hoverSpot))
        LineChartBarData(
          spots: [_hoverSpot!],
          isCurved: false,
          color: Colors.teal,
          barWidth: 0,
          dotData: FlDotData(
            show: true,
            checkToShowDot: (_, __) => true,
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
              color: Colors.transparent,
              radius: 6,
              strokeColor: Colors.teal,
              strokeWidth: 2.5,
            ),
          ),
        ),
    ];

    return LineChart(
      key: ValueKey('intrinsic-$chartVersion'),
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(show: true, horizontalInterval: 2),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LatexText(r'n_i', scale: 1.0),
                const SizedBox(width: 4),
                LatexText('($unitLatex, log scale)', scale: 0.85),
              ],
            ),
            axisNameSize: 50,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: context.chartStyle.leftReservedSize + 4,
              getTitlesWidget: (value, meta) {
                final exp = value.round();
                return Padding(
                  padding: context.chartStyle.tickPadding,
                  child: LatexText('10^{$exp}', scale: 0.8),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: _arrheniusMode
                ? const LatexText(r'\frac{1}{T}\ (\mathrm{K^{-1}})', scale: 0.95)
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LatexText(r'T', scale: 1.0),
                      SizedBox(width: 4),
                      LatexText(r'(\mathrm{K})', scale: 0.85),
                    ],
                  ),
            axisNameSize: 40,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: context.chartStyle.bottomReservedSize,
              getTitlesWidget: (value, meta) {
                final label = _arrheniusMode ? value.toStringAsFixed(4) : value.toStringAsFixed(0);
                return Padding(
                  padding: context.chartStyle.tickPadding,
                  child: Text(label, style: context.chartStyle.tickTextStyle),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
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
                      labelResolver: (_) => '300 K',
                    ),
                  ),
                ],
              )
            : null,
        lineBarsData: lineBars,
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (event, response) {
            final spots = response?.lineBarSpots;
            if (spots == null || spots.isEmpty) {
              if (event is FlTapUpEvent) {
                updateChart(() {
                  _pinnedSpots.clear();
                  _hoverSpot = null;
                });
              }
              return;
            }
            final spot = FlSpot(spots.first.x, spots.first.y);
            if (event is FlTapUpEvent) {
              setState(() {
                _pinnedSpots.removeWhere((p) => (p.x - spot.x).abs() < 1e-6);
                _pinnedSpots.add(spot);
                if (_pinnedSpots.length > _maxPins) _pinnedSpots.removeAt(0);
                _hoverSpot = spot;
              });
            } else if (event is FlPointerHoverEvent || event is FlPanUpdateEvent) {
              setState(() => _hoverSpot = spot);
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((s) {
                final T = _arrheniusMode ? (1.0 / s.x) : s.x;
                final logNi = s.y;
                final ni = math.pow(10, logNi).toDouble();
                final niStr = LatexNumberFormatter.toUnicodeSci(ni, sigFigs: 3);
                final unit = _useCmCubed ? 'cmâ»Â³' : 'mâ»Â³';
                return LineTooltipItem(
                  'T: ${T.toStringAsFixed(1)} K\n',
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(text: 'náµ¢: $niStr $unit\n', style: const TextStyle(fontSize: 11)),
                    TextSpan(
                      text: 'Tap to pin; tap empty to clear',
                      style: TextStyle(fontSize: 9, color: Colors.grey[400]),
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
}

class _Constants {
  final double h, kB, m0, q;
  final LatexSymbolMap latexMap;
  _Constants({
    required this.h,
    required this.kB,
    required this.m0,
    required this.q,
    required this.latexMap,
  });
}

