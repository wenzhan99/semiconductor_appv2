import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/chart_style.dart';
import '../widgets/latex_text.dart';

// New architecture imports
import '../graphs/core/standard_graph_page_scaffold.dart';
import '../graphs/core/graph_config.dart';
import '../graphs/core/animation_engine.dart';

// Standardized components
import '../graphs/common/enhanced_animation_panel.dart';
import '../graphs/utils/latex_number_formatter.dart';

// Typography standards
typedef _Typo = GraphPanelTextStyles;

class PnBandDiagramGraphPage extends StatelessWidget {
  const PnBandDiagramGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('✅ PN Band Diagram: USING STANDARD SCAFFOLD');
    return Scaffold(
      appBar: AppBar(title: const Text('PN Junction Band Diagram (E vs x)')),
      body: const PnBandDiagramView(),
    );
  }
}

class PnBandDiagramView extends StatefulWidget {
  const PnBandDiagramView({super.key});

  @override
  State<PnBandDiagramView> createState() => _PnBandDiagramViewState();
}

class _PnBandDiagramViewState extends State<PnBandDiagramView> {
  double _na = 1e16; // cm^-3
  double _nd = 1e16; // cm^-3
  double _temperature = 300; // K
  double _eg = 1.12; // eV
  double _bias = 0.0; // V (positive forward)
  double _epsRel = 11.7; // silicon default

  // Animation state
  late AnimationEngine _animationEngine;
  bool _biasAnimEnabled = false;
  bool _naAnimEnabled = false;
  bool _ndAnimEnabled = false;
  double _biasAnimMin = -1.0;
  double _biasAnimMax = 0.8;
  double _naAnimMin = 1e14;
  double _naAnimMax = 1e19;
  double _ndAnimMin = 1e14;
  double _ndAnimMax = 1e19;

  static const double _ni = 1e10; // cm^-3 (schematic, room temp)
  static const double _eps0 = 8.8541878128e-12; // F/m
  static const double _q = 1.602176634e-19; // C
  static const double _kB = 1.380649e-23; // J/K

  static const int _samples = 180;

  @override
  void initState() {
    super.initState();
    _animationEngine = AnimationEngine(
      getParameters: _getAnimatableParameters,
      onUpdate: () => setState(() {}),
    );
  }

  @override
  void dispose() {
    _animationEngine.dispose();
    super.dispose();
  }

  List<AnimatableParameter> _getAnimatableParameters() {
    // Default / normalized ranges
    final biasRange = _normalizeBiasRange(_biasAnimMin, _biasAnimMax);
    _biasAnimMin = biasRange.$1;
    _biasAnimMax = biasRange.$2;

    final naRange = _normalizeDopingRange(_na, _naAnimMin, _naAnimMax);
    _naAnimMin = naRange.$1;
    _naAnimMax = naRange.$2;

    final ndRange = _normalizeDopingRange(_nd, _ndAnimMin, _ndAnimMax);
    _ndAnimMin = ndRange.$1;
    _ndAnimMax = ndRange.$2;

    return [
      AnimatableParameter(
        id: 'bias',
        label: r'V_A (Applied Bias)',
        symbol: r'V_A',
        unit: 'V',
        currentValue: _bias,
        rangeMin: _biasAnimMin,
        rangeMax: _biasAnimMax,
        absoluteMin: -2.0,
        absoluteMax: 1.5,
        enabled: _biasAnimEnabled,
        onEnabledChanged: (enabled) => setState(() => _biasAnimEnabled = enabled),
        onValueChanged: (value) => setState(() => _bias = value),
        onRangeChanged: (min, max) => setState(() {
          final normalized = _normalizeBiasRange(min, max);
          _biasAnimMin = normalized.$1;
          _biasAnimMax = normalized.$2;
        }),
        physicsNote: 'Forward bias flattens bands; reverse bias increases band bending.',
      ),
      AnimatableParameter(
        id: 'na',
        label: r'N_A (Acceptor Concentration)',
        symbol: r'N_A',
        unit: 'cm^{-3}',
        currentValue: _na,
        rangeMin: _naAnimMin,
        rangeMax: _naAnimMax,
        absoluteMin: 1e12,
        absoluteMax: 1e21,
        enabled: _naAnimEnabled,
        onEnabledChanged: (enabled) => setState(() => _naAnimEnabled = enabled),
        onValueChanged: (value) => setState(() => _na = value),
        onRangeChanged: (min, max) => setState(() {
          final normalized = _normalizeDopingRange(_na, min, max);
          _naAnimMin = normalized.$1;
          _naAnimMax = normalized.$2;
        }),
        physicsNote: 'Higher NA increases built-in potential and steepens band bending.',
      ),
      AnimatableParameter(
        id: 'nd',
        label: r'N_D (Donor Concentration)',
        symbol: r'N_D',
        unit: 'cm^{-3}',
        currentValue: _nd,
        rangeMin: _ndAnimMin,
        rangeMax: _ndAnimMax,
        absoluteMin: 1e12,
        absoluteMax: 1e21,
        enabled: _ndAnimEnabled,
        onEnabledChanged: (enabled) => setState(() => _ndAnimEnabled = enabled),
        onValueChanged: (value) => setState(() => _nd = value),
        onRangeChanged: (min, max) => setState(() {
          final normalized = _normalizeDopingRange(_nd, min, max);
          _ndAnimMin = normalized.$1;
          _ndAnimMax = normalized.$2;
        }),
        physicsNote: 'Higher ND increases built-in potential and steepens band bending.',
      ),
    ];
  }

  (double, double) _normalizeDopingRange(double n0, double minIn, double maxIn) {
    const boundsMin = 1e14;
    const boundsMax = 1e19;
    double min = minIn;
    double max = maxIn;

    if (min <= 0 || max <= 0 || min >= max || (min == boundsMin && max >= boundsMax * 0.99)) {
      min = n0 / 10;
      max = n0 * 10;
    }

    min = min.clamp(boundsMin, boundsMax);
    max = max.clamp(boundsMin, boundsMax);

    if (min >= max) {
      min = boundsMin;
      max = math.min(boundsMax, min * 10);
    }

    return (min, max);
  }

  (double, double) _normalizeBiasRange(double minIn, double maxIn) {
    const defaultMin = -1.0;
    const defaultMax = 0.8;
    double min = minIn;
    double max = maxIn;

    if (min >= max || (min == 0 && max == 0)) {
      min = defaultMin;
      max = defaultMax;
    }

    min = min.clamp(-2.0, 1.5);
    max = max.clamp(-2.0, 1.5);

    if (min >= max) {
      min = defaultMin;
      max = defaultMax;
    }

    return (min, max);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _buildBandProfile();
    final config = _buildGraphConfig(profile);

    return StandardGraphPageScaffold(
      config: config,
      chartBuilder: (context) => _buildChart(context, profile),
      showDebugBadge: true,
      debugBadgeText: 'PN USING STANDARD SCAFFOLD',
      headerWidgets: [
        _buildInfoPanel(),
      ],
    );
  }

  GraphConfig _buildGraphConfig(_BandProfile profile) {
    return GraphConfig(
      title: 'PN Junction Band Diagram (E vs x)',
      subtitle: 'Shows Ec(x), Ev(x), Ei(x) and quasi-Fermi levels under bias',
      animation: AnimationConfig(
        parameters: _getAnimatableParameters(),
        selectedParameterId: 'bias',
        onParameterSelected: (id) => setState(() {}),
        state: AnimationState(
          isPlaying: _animationEngine.isPlaying,
          speed: _animationEngine.speed,
          reverse: _animationEngine.reverse,
          loop: _animationEngine.loop,
        ),
        callbacks: AnimationCallbacks(
          onPlay: () => _animationEngine.play(),
          onPause: () => _animationEngine.pause(),
          onRestart: () => _animationEngine.restart(),
          onSpeedChanged: (speed) => _animationEngine.setSpeed(speed),
          onReverseChanged: (reverse) => _animationEngine.setReverse(reverse),
          onLoopChanged: (loop) => _animationEngine.setLoop(loop),
        ),
      ),
      insights: InsightsConfig(
        dynamicObservations: _buildDynamicObservations(profile),
        staticObservations: _buildStaticObservations(),
      ),
      readouts: _buildReadouts(profile),
      controls: ControlsConfig(
        children: _buildControlsChildren(profile),
        collapsible: true,
        initiallyExpanded: true,
      ),
    );
  }

  List<String> _buildDynamicObservations(_BandProfile profile) {
    final obs = <String>[];
    
    if (_bias > 0.1) {
      obs.add(r'Forward bias: bands flatten, quasi-Fermi splitting increases carrier injection.');
    } else if (_bias < -0.1) {
      obs.add(r'Reverse bias: bands steepen, depletion widens, minimal carrier flow.');
    } else {
      obs.add(r'Zero bias: equilibrium band bending determined by $V_{bi}$.');
    }
    
    final ratio = _na / _nd;
    if (ratio > 5) {
      obs.add(r'$N_A \gg N_D$: depletion extends mostly into n-side.');
    } else if (ratio < 0.2) {
      obs.add(r'$N_D \gg N_A$: depletion extends mostly into p-side.');
    }
    
    return obs;
  }

  List<String> _buildStaticObservations() {
    return [
      r'Built-in potential $V_{bi} = V_T \ln(N_A N_D / n_i^2)$ sets equilibrium band bending.',
      r'Quasi-Fermi levels split under bias: $E_{Fn} - E_{Fp} = q V_A$.',
      r'Band edges $E_c$, $E_v$ are continuous; intrinsic level $E_i$ follows mid-gap.',
    ];
  }

  List<ReadoutItem> _buildReadouts(_BandProfile profile) {
    const voltageUnit = r'\mathrm{V}';
    const lengthUnit = r'\mu\mathrm{m}';

    return [
      ReadoutItem(
        label: r'\(V_{bi}\) (built-in)',
        value: LatexNumberFormatter.valueWithUnit(profile.vbi, unitLatex: voltageUnit, sigFigs: 3),
        boldValue: true,
      ),
      ReadoutItem(
        label: r'\(V_A\) (applied)',
        value: LatexNumberFormatter.valueWithUnit(_bias, unitLatex: voltageUnit, sigFigs: 3),
      ),
      ReadoutItem(
        label: r'Barrier $V_{bi} - V_A$',
        value: LatexNumberFormatter.valueWithUnit(profile.barrier, unitLatex: voltageUnit, sigFigs: 3),
      ),
      ReadoutItem(
        label: r'Depletion width $W$',
        value: LatexNumberFormatter.valueWithUnit(profile.totalWidthUm, unitLatex: lengthUnit, sigFigs: 3),
      ),
    ];
  }

  List<Widget> _buildControlsChildren(_BandProfile profile) {
    const dopingUnit = r'\mathrm{cm^{-3}}';
    const tempLabel = r'\(T\,(\mathrm{K})\)';
    const naLabel = r'\(N_A\,(' + dopingUnit + r')\)';
    const ndLabel = r'\(N_D\,(' + dopingUnit + r')\)';
    const egLabel = r'\(E_g\,(\mathrm{eV})\)';
    const biasLabel = r'\(V_A\,(\mathrm{V})\)';
    const epsLabel = r'\(\varepsilon_r\)';
    
    return [
      Text(
        'Parameters',
        style: TextStyle(
          fontSize: _Typo.title,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      _logSlider(
        label: naLabel,
        value: _na,
        min: 1e14,
        max: 1e19,
        onChanged: (v) => setState(() => _na = v),
      ),
      _logSlider(
        label: ndLabel,
        value: _nd,
        min: 1e14,
        max: 1e19,
        onChanged: (v) => setState(() => _nd = v),
      ),
      _slider(
        label: tempLabel,
        value: _temperature,
        min: 200,
        max: 450,
        divisions: 250,
        onChanged: (v) => setState(() => _temperature = v),
      ),
      _slider(
        label: egLabel,
        value: _eg,
        min: 0.7,
        max: 1.6,
        divisions: 180,
        onChanged: (v) => setState(() => _eg = double.parse(v.toStringAsFixed(3))),
      ),
      _slider(
        label: biasLabel,
        value: _bias,
        min: -1.0,
        max: 0.8,
        divisions: 90,
        onChanged: (v) => setState(() => _bias = double.parse(v.toStringAsFixed(3))),
      ),
      _slider(
        label: epsLabel,
        value: _epsRel,
        min: 8,
        max: 15,
        divisions: 70,
        onChanged: (v) => setState(() => _epsRel = double.parse(v.toStringAsFixed(2))),
      ),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        onPressed: () => setState(() {
          _na = 1e16;
          _nd = 1e16;
          _temperature = 300;
          _eg = 1.12;
          _bias = 0.0;
          _epsRel = 11.7;
          _animationEngine.pause();
        }),
        icon: const Icon(Icons.restart_alt, size: 18),
        label: const Text('Reset to Defaults'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 36),
        ),
      ),
    ];
  }

  Widget _buildInfoPanel() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text('What you should observe',
            style:
                TextStyle(fontSize: _Typo.title, fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: const [
          _Bullet(r'E_c, E_v bend through the depletion region; forward bias flattens the bands.'),
          _Bullet(r'Quasi-Fermi splitting (E_{Fn}, E_{Fp}) grows with applied bias.'),
          _Bullet(r'Heavier doping shrinks depletion widths and steepens the band bending.'),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, _BandProfile profile) {
    final ecColor = Theme.of(context).colorScheme.primary;
    final evColor = Theme.of(context).colorScheme.tertiary;
    final eiColor = Theme.of(context).colorScheme.outline;
    final fermiColor = Theme.of(context).colorScheme.secondary;
    final biasColor = Theme.of(context).colorScheme.error;

    final minY = (profile.ev.map((e) => e.y).reduce(math.min)) - 0.25;
    final maxY = (profile.ec.map((e) => e.y).reduce(math.max)) + 0.25;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LatexText(r'E_c, E_v, E_i, E_{Fn}, E_{Fp}\ \text{(eV)}',
            style: TextStyle(fontSize: _Typo.sectionLabel)),
        const SizedBox(height: 8),
        Expanded(
          child: LineChart(
            LineChartData(
              minX: profile.xMin,
              maxX: profile.xMax,
              minY: minY,
              maxY: maxY,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: Text('Energy (eV)',
                      style: TextStyle(
                          fontSize: _Typo.sectionLabel,
                          fontWeight: FontWeight.w600)),
                  axisNameSize: 44,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: context.chartStyle.leftReservedSize,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: context.chartStyle.tickPadding,
                        child: Text(
                          value.toStringAsFixed(1),
                          style: TextStyle(fontSize: _Typo.hint),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: Text('Position (µm)',
                      style: TextStyle(
                          fontSize: _Typo.sectionLabel,
                          fontWeight: FontWeight.w600)),
                  axisNameSize: 40,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: context.chartStyle.bottomReservedSize,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: context.chartStyle.tickPadding,
                        child: Text(
                          value.toStringAsFixed(2),
                          style: TextStyle(fontSize: _Typo.hint),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: true),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) {
                    return spots
                        .map(
                          (s) => LineTooltipItem(
                            'x=${s.x.toStringAsFixed(3)} µm\nE=${s.y.toStringAsFixed(3)} eV',
                            TextStyle(
                              fontSize: _Typo.hint,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                        .toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(spots: profile.ec, color: ecColor, barWidth: 2, isCurved: false, dotData: const FlDotData(show: false)),
                LineChartBarData(spots: profile.ev, color: evColor, barWidth: 2, isCurved: false, dotData: const FlDotData(show: false)),
                LineChartBarData(spots: profile.ei, color: eiColor, barWidth: 1.5, isCurved: false, dashArray: [6, 4], dotData: const FlDotData(show: false)),
                LineChartBarData(spots: profile.efn, color: biasColor, barWidth: 1.8, isCurved: false, dashArray: [4, 4], dotData: const FlDotData(show: false)),
                LineChartBarData(spots: profile.efp, color: fermiColor, barWidth: 1.8, isCurved: false, dashArray: [4, 4], dotData: const FlDotData(show: false)),
              ],
              extraLinesData: ExtraLinesData(
                verticalLines: [
                  VerticalLine(
                    x: 0,
                    color: Theme.of(context).dividerColor,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                    label: VerticalLineLabel(
                      show: true,
                      alignment: Alignment.topCenter,
                      labelResolver: (_) => 'Junction',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  _BandProfile _buildBandProfile() {
    final naSi = _na * 1e6; // cm^-3 -> m^-3
    final ndSi = _nd * 1e6;
    final niSi = _ni * 1e6;
    final vt = (_kB * _temperature) / _q;
    final vbi = vt * math.log((naSi * ndSi) / (niSi * niSi));
    final barrier = (vbi - _bias).clamp(0.01, 2.5);

    // Depletion widths (1D abrupt junction approximation)
    final eps = _epsRel * _eps0;
    final wd = math.sqrt(2 * eps * barrier / _q * (1 / naSi + 1 / ndSi));
    final wp = wd * ndSi / (naSi + ndSi);
    final wn = wd * naSi / (naSi + ndSi);
    final xMin = -wp;
    final xMax = wn;

    final ec0 = _eg / 2;
    final ev0 = -_eg / 2;

    List<FlSpot> ec = [];
    List<FlSpot> ev = [];
    List<FlSpot> ei = [];
    List<FlSpot> efn = [];
    List<FlSpot> efp = [];

    for (int i = 0; i < _samples; i++) {
      final x = xMin + (xMax - xMin) * i / (_samples - 1);
      final phi = _potentialAt(x, xMin, xMax, barrier);
      final ecVal = ec0 - phi;
      final evVal = ev0 - phi;
      final eiVal = (ecVal + evVal) / 2;
      final efnVal = ecVal - 0.5 * _bias; // schematic: n-side quasi-Fermi moves with bias
      final efpVal = evVal + 0.5 * _bias;
      final xUm = x * 1e6;
      ec.add(FlSpot(xUm, ecVal));
      ev.add(FlSpot(xUm, evVal));
      ei.add(FlSpot(xUm, eiVal));
      efn.add(FlSpot(xUm, efnVal));
      efp.add(FlSpot(xUm, efpVal));
    }

    return _BandProfile(
      ec: ec,
      ev: ev,
      ei: ei,
      efn: efn,
      efp: efp,
      xMin: xMin * 1e6,
      xMax: xMax * 1e6,
      vbi: vbi,
      barrier: barrier,
      totalWidthUm: (xMax - xMin) * 1e6,
    );
  }

  double _potentialAt(double x, double xMin, double xMax, double barrier) {
    // Simple linear potential across depletion region with small rounding at edges
    final t = ((x - xMin) / (xMax - xMin)).clamp(0.0, 1.0);
    final smoothT = 0.5 - 0.5 * math.cos(math.pi * t); // smoothen edges
    return barrier * (smoothT - 0.5); // centered around 0 to keep mid-gap near 0
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LatexText(label,
                  style: TextStyle(
                      fontSize: _Typo.sectionLabel,
                      fontWeight: FontWeight.w600)),
              Text(value.toStringAsPrecision(4),
                  style: TextStyle(fontSize: _Typo.value)),
            ],
          ),
          Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _logSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final logMin = _log10(min);
    final logMax = _log10(max);
    final logVal = _log10(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LatexText(label,
                  style: TextStyle(
                      fontSize: _Typo.sectionLabel,
                      fontWeight: FontWeight.w600)),
              Text(value.toStringAsPrecision(3),
                  style: TextStyle(fontSize: _Typo.value)),
            ],
          ),
          Slider(
            value: logVal,
            min: logMin,
            max: logMax,
            divisions: 50,
            onChanged: (v) => onChanged(math.pow(10, v).toDouble()),
          ),
        ],
      ),
    );
  }

  double _log10(double v) => math.log(v) / math.ln10;
}

class _BandProfile {
  final List<FlSpot> ec;
  final List<FlSpot> ev;
  final List<FlSpot> ei;
  final List<FlSpot> efn;
  final List<FlSpot> efp;
  final double xMin;
  final double xMax;
  final double vbi;
  final double barrier;
  final double totalWidthUm;

  _BandProfile({
    required this.ec,
    required this.ev,
    required this.ei,
    required this.efn,
    required this.efp,
    required this.xMin,
    required this.xMax,
    required this.vbi,
    required this.barrier,
    required this.totalWidthUm,
  });
}

class _Bullet extends StatelessWidget {
  final String latex;
  const _Bullet(this.latex);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: _Typo.body)),
          Expanded(
              child: LatexText(latex,
                  style: TextStyle(fontSize: _Typo.body))),
        ],
      ),
    );
  }
}
