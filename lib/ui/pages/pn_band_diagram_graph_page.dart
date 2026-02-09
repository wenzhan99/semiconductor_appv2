import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/chart_style.dart';
import '../widgets/latex_text.dart';

class PnBandDiagramGraphPage extends StatelessWidget {
  const PnBandDiagramGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
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

  static const double _ni = 1e10; // cm^-3 (schematic, room temp)
  static const double _eps0 = 8.8541878128e-12; // F/m
  static const double _q = 1.602176634e-19; // C
  static const double _kB = 1.380649e-23; // J/K

  static const int _samples = 180;

  @override
  Widget build(BuildContext context) {
    final profile = _buildBandProfile();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          _buildInfoPanel(),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _buildChart(context, profile),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ListView(
                    children: [
                      _buildReadout(profile),
                      const SizedBox(height: 12),
                      _buildControls(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PN Junction Band Diagram (E vs x)',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Shows E_c(x), E_v(x), E_i(x) and quasi-Fermi levels under bias.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildInfoPanel() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('What you should observe', style: TextStyle(fontWeight: FontWeight.w700)),
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
        const LatexText(r'E_c, E_v, E_i, E_{Fn}, E_{Fp}\ \text{(eV)}'),
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
                  axisNameWidget: Text('Energy (eV)', style: context.chartStyle.axisTitleTextStyle),
                  axisNameSize: 44,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: context.chartStyle.leftReservedSize,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: context.chartStyle.tickPadding,
                        child: Text(
                          value.toStringAsFixed(1),
                          style: context.chartStyle.tickTextStyle,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: Text('Position (µm)', style: context.chartStyle.axisTitleTextStyle),
                  axisNameSize: 40,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: context.chartStyle.bottomReservedSize,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: context.chartStyle.tickPadding,
                        child: Text(
                          value.toStringAsFixed(2),
                          style: context.chartStyle.tickTextStyle,
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
                            context.chartStyle.tooltipTextStyle,
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

  Widget _buildReadout(_BandProfile profile) {
    final format = (double v) => v.toStringAsPrecision(3);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Key values', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Built-in potential V_bi ≈ ${format(profile.vbi)} V'),
            Text('Applied bias V_A = ${format(_bias)} V'),
            Text('Barrier height V_bi - V_A ≈ ${format(profile.barrier)} V'),
            Text('Depletion width ≈ ${format(profile.totalWidthUm)} µm'),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Parameters', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _logSlider(
              label: 'N_A (cm⁻³)',
              value: _na,
              min: 1e14,
              max: 1e19,
              onChanged: (v) => setState(() => _na = v),
            ),
            _logSlider(
              label: 'N_D (cm⁻³)',
              value: _nd,
              min: 1e14,
              max: 1e19,
              onChanged: (v) => setState(() => _nd = v),
            ),
            _slider(
              label: 'Temperature (K)',
              value: _temperature,
              min: 200,
              max: 450,
              divisions: 250,
              onChanged: (v) => setState(() => _temperature = v),
            ),
            _slider(
              label: 'Bandgap E_g (eV)',
              value: _eg,
              min: 0.7,
              max: 1.6,
              divisions: 180,
              onChanged: (v) => setState(() => _eg = double.parse(v.toStringAsFixed(3))),
            ),
            _slider(
              label: 'Applied bias V_A (V)',
              value: _bias,
              min: -1.0,
              max: 0.8,
              divisions: 90,
              onChanged: (v) => setState(() => _bias = double.parse(v.toStringAsFixed(3))),
            ),
            _slider(
              label: 'Permittivity ε_r',
              value: _epsRel,
              min: 8,
              max: 15,
              divisions: 70,
              onChanged: (v) => setState(() => _epsRel = double.parse(v.toStringAsFixed(2))),
            ),
          ],
        ),
      ),
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
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(value.toStringAsPrecision(4)),
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
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(value.toStringAsPrecision(3)),
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
          const Text('• '),
          Expanded(child: LatexText(latex)),
        ],
      ),
    );
  }
}
