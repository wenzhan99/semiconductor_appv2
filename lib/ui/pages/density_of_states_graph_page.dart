import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../widgets/latex_text.dart';

class DensityOfStatesGraphPage extends StatelessWidget {
  const DensityOfStatesGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Density of States g(E) vs Energy')),
      body: const DensityOfStatesGraphView(),
    );
  }
}

class DensityOfStatesGraphView extends StatefulWidget {
  const DensityOfStatesGraphView({super.key});

  @override
  State<DensityOfStatesGraphView> createState() => _DensityOfStatesGraphViewState();
}

class _DensityOfStatesGraphViewState extends State<DensityOfStatesGraphView> {
  // Parameters
  double _eg = 1.12; // eV
  double _meEff = 0.26; // m*_e / m0
  double _mhEff = 0.39; // m*_h / m0
  double _energyWindow = 1.0; // eV padding around band edges
  double _fermiOffset = 0.0; // eV relative to midgap

  static const double _hbar = 1.054571817e-34; // J*s
  static const double _m0 = 9.1093837015e-31; // kg

  static const int _samples = 220;

  @override
  Widget build(BuildContext context) {
    final ec = _eg / 2;
    final ev = -_eg / 2;
    final eMin = ev - _energyWindow;
    final eMax = ec + _energyWindow;
    final data = _buildData(ec: ec, ev: ev, eMin: eMin, eMax: eMax);

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
                      child: _buildChart(context, data, eMin, eMax, ec, ev),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildControls(context)),
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
          'Density of States g(E) vs Energy',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const LatexText(
          r'g_c(E)=\frac{1}{2\pi^{2}}\!\left(\frac{2m_e^{*}}{\hbar^{2}}\right)^{\frac{3}{2}}\!\sqrt{E-E_c},\quad'
          r'g_v(E)=\frac{1}{2\pi^{2}}\!\left(\frac{2m_h^{*}}{\hbar^{2}}\right)^{\frac{3}{2}}\!\sqrt{E_v-E}',
          displayMode: true,
          scale: 1.05,
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
          _Bullet(r'g(E) rises as \sqrt{|E-E_{c,v}|}; heavier m^{*} raises DOS.'),
          _Bullet(r'Conduction DOS starts at E_c; valence DOS starts at E_v.'),
          _Bullet(r'Fermi level (E_F) positioning + DOS shape explains carrier counts.'),
        ],
      ),
    );
  }

  Widget _buildChart(
    BuildContext context,
    _DosData data,
    double eMin,
    double eMax,
    double ec,
    double ev,
  ) {
    final conductionColor = Theme.of(context).colorScheme.primary;
    final valenceColor = Theme.of(context).colorScheme.tertiary;
    final efColor = Theme.of(context).colorScheme.error;

    final maxY = data.maxDos * 1.08;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: const [
            LatexText(r'\text{DOS axis: arbitrary units (scaled by }m^{*3/2}\text{)}'),
            LatexText(r'E\ \text{axis: eV relative to midgap}'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LineChart(
            LineChartData(
              minX: eMin,
              maxX: eMax,
              minY: 0,
              maxY: maxY == 0 ? 1 : maxY,
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 0,
                    color: Theme.of(context).dividerColor,
                    strokeWidth: 1,
                  ),
                ],
                verticalLines: [
                  VerticalLine(
                    x: ec,
                    color: conductionColor.withValues(alpha: 0.45),
                    dashArray: [6, 4],
                    label: VerticalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(bottom: 6, right: 4),
                      labelResolver: (_) => 'E_c',
                    ),
                  ),
                  VerticalLine(
                    x: ev,
                    color: valenceColor.withValues(alpha: 0.45),
                    dashArray: [6, 4],
                    label: VerticalLineLabel(
                      show: true,
                      alignment: Alignment.topLeft,
                      padding: const EdgeInsets.only(bottom: 6, left: 4),
                      labelResolver: (_) => 'E_v',
                    ),
                  ),
                  VerticalLine(
                    x: _fermiOffset,
                    color: efColor.withValues(alpha: 0.5),
                    strokeWidth: 2,
                    dashArray: [4, 4],
                    label: VerticalLineLabel(
                      show: true,
                      alignment: Alignment.bottomRight,
                      padding: const EdgeInsets.only(top: 4, right: 4),
                      labelResolver: (_) => 'E_F',
                    ),
                  ),
                ],
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: const Text('DOS (arb. units)'),
                  sideTitles: const SideTitles(showTitles: true, reservedSize: 46),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text('Energy (eV, midgap = 0)'),
                  sideTitles: const SideTitles(showTitles: true, reservedSize: 32),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: true),
              lineTouchData: LineTouchData(
                enabled: true,
                getTouchedSpotIndicator: (bar, indexes) {
                  return indexes
                      .map(
                        (_) => TouchedSpotIndicatorData(
                          FlLine(color: bar.color?.withValues(alpha: 0.4), dashArray: [4, 4], strokeWidth: 1),
                          FlDotData(show: false),
                        ),
                      )
                      .toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map(
                        (s) => LineTooltipItem(
                          'E = ${s.x.toStringAsFixed(3)} eV\nDOS = ${s.y.toStringAsPrecision(4)}',
                          TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                      )
                      .toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: data.conduction,
                  isCurved: false,
                  color: conductionColor,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: data.valence,
                  isCurved: false,
                  color: valenceColor,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
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
            _slider(
              label: 'Bandgap E_g (eV)',
              value: _eg,
              min: 0.4,
              max: 2.5,
              divisions: 210,
              onChanged: (v) => setState(() => _eg = double.parse(v.toStringAsFixed(3))),
            ),
            _slider(
              label: 'm* (electrons) / m0',
              value: _meEff,
              min: 0.05,
              max: 2.0,
              divisions: 195,
              onChanged: (v) => setState(() => _meEff = double.parse(v.toStringAsFixed(3))),
            ),
            _slider(
              label: 'm* (holes) / m0',
              value: _mhEff,
              min: 0.05,
              max: 2.0,
              divisions: 195,
              onChanged: (v) => setState(() => _mhEff = double.parse(v.toStringAsFixed(3))),
            ),
            _slider(
              label: 'Energy padding (eV)',
              value: _energyWindow,
              min: 0.2,
              max: 1.6,
              divisions: 140,
              onChanged: (v) => setState(() => _energyWindow = double.parse(v.toStringAsFixed(2))),
            ),
            _slider(
              label: 'E_F offset (eV, midgap = 0)',
              value: _fermiOffset,
              min: -1.5,
              max: 1.5,
              divisions: 300,
              onChanged: (v) => setState(() => _fermiOffset = double.parse(v.toStringAsFixed(3))),
            ),
          ],
        ),
      ),
    );
  }

  _DosData _buildData({required double ec, required double ev, required double eMin, required double eMax}) {
    final conduction = <FlSpot>[];
    final valence = <FlSpot>[];

    final coeffC = _dosCoeff(_meEff);
    final coeffV = _dosCoeff(_mhEff);
    double maxDos = 0;

    for (int i = 0; i < _samples; i++) {
      final e = eMin + (eMax - eMin) * (i / (_samples - 1));
      if (e >= ec) {
        final val = coeffC * math.sqrt((e - ec).clamp(0, double.infinity));
        maxDos = math.max(maxDos, val);
        conduction.add(FlSpot(e, val));
      }
      if (e <= ev) {
        final val = coeffV * math.sqrt((ev - e).clamp(0, double.infinity));
        maxDos = math.max(maxDos, val);
        valence.add(FlSpot(e, val));
      }
    }

    return _DosData(conduction: conduction, valence: valence, maxDos: maxDos);
  }

  double _dosCoeff(double mStarRatio) {
    // Use scaled coefficient to avoid huge magnitudes; retains m*^(3/2) scaling
    final coeff = math.pow(2 * mStarRatio * _m0 / (_hbar * _hbar), 1.5);
    // Normalize by an arbitrary factor so chart stays in a friendly range.
    return coeff / 1e56;
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
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _DosData {
  final List<FlSpot> conduction;
  final List<FlSpot> valence;
  final double maxDos;

  _DosData({required this.conduction, required this.valence, required this.maxDos});
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
