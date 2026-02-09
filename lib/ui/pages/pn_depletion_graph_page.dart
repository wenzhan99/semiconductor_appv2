import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/constants_loader.dart';
import '../../core/constants/constants_repository.dart';
import '../../core/constants/latex_symbols.dart';
import '../graphs/utils/semiconductor_models.dart';
import '../graphs/utils/text_number_formatter.dart';
import '../widgets/latex_text.dart';

class PnDepletionGraphPage extends StatelessWidget {
  const PnDepletionGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PN Junction Depletion Profiles')),
      body: const PnDepletionGraphView(),
    );
  }
}

class PnDepletionGraphView extends StatefulWidget {
  const PnDepletionGraphView({super.key});

  @override
  State<PnDepletionGraphView> createState() => _PnDepletionGraphViewState();
}

class _PnDepletionGraphViewState extends State<PnDepletionGraphView> {
  int _chartVersion = 0;
  double _temperature = 300;
  double _naDisplay = 1e16;
  double _ndDisplay = 1e16;
  double _va = 0.0;
  double _epsR = 11.7;
  bool _useCmUnits = true;
  bool _showMarkers = true;
  bool _showOutside = true;

  static const double _bandgap = 1.12; // eV for Si
  static const double _mnStar = 1.08;
  static const double _mpStar = 0.56;
  static const int _samples = 240;

  late Future<({
    double h,
    double kB,
    double m0,
    double q,
    double eps0,
    LatexSymbolMap latexMap,
  })> _constants;

  @override
  void initState() {
    super.initState();
    _constants = _loadConstants();
  }

  Future<({
    double h,
    double kB,
    double m0,
    double q,
    double eps0,
    LatexSymbolMap latexMap,
  })> _loadConstants() async {
    final repo = ConstantsRepository();
    await repo.load();
    final latex = await ConstantsLoader.loadLatexSymbols();
    return (
      h: repo.getConstantValue('h')!,
      kB: repo.getConstantValue('k')!,
      m0: repo.getConstantValue('m_0')!,
      q: repo.getConstantValue('q')!,
      eps0: repo.getConstantValue('eps_0')!,
      latexMap: latex,
    );
  }

  double _dopingToSi(double value) => _useCmUnits ? value * 1e6 : value;
  double _dopingToDisplay(double si) => _useCmUnits ? si / 1e6 : si;

  void _updateChart(void Function() updater) {
    setState(() {
      updater();
      _chartVersion++;
    });
  }

  void _resetDefaults() {
    setState(() {
      _temperature = 300;
      _naDisplay = 1e16;
      _ndDisplay = 1e16;
      _va = 0.0;
      _epsR = 11.7;
      _useCmUnits = true;
      _showMarkers = true;
      _showOutside = true;
      _chartVersion++;
    });
  }

  _PnCurves _buildCurves(({double h, double kB, double m0, double q, double eps0, LatexSymbolMap latexMap}) c) {
    final naSi = _dopingToSi(_naDisplay);
    final ndSi = _dopingToSi(_ndDisplay);

    final ni = SemiconductorModels.computeNi(
      temperatureK: _temperature,
      h: c.h,
      kB: c.kB,
      m0: c.m0,
      q: c.q,
      bandgapEv: _bandgap,
      mnEffRatio: _mnStar,
      mpEffRatio: _mpStar,
    );

    final vbi = (c.kB * _temperature / c.q) * math.log((naSi * ndSi) / (ni * ni));
    final biasTerm = vbi - _va;
    final invalid = biasTerm <= 0;
    final effectiveBias = invalid ? 1e-6 : biasTerm;

    final epsS = _epsR * c.eps0;
    final W = math.sqrt((2 * epsS / c.q) * (1 / naSi + 1 / ndSi) * effectiveBias);
    final xn = (naSi / (naSi + ndSi)) * W;
    final xp = (ndSi / (naSi + ndSi)) * W;

    final xMin = -xp * 1.5;
    final xMax = xn * 1.5;

    final List<FlSpot> rhoSpots = [];
    final List<FlSpot> eSpots = [];
    final List<FlSpot> vSpots = [];

    double minRho = 0;
    double maxRho = 0;
    double minE = 0;
    double maxE = 0;
    double minV = 0;
    double maxV = effectiveBias;

    for (int i = 0; i < _samples; i++) {
      final x = xMin + (xMax - xMin) * i / (_samples - 1);
      final positionUm = x * 1e6;

      double rho = 0;
      double eField = 0;
      double potential = 0;

      if (x >= -xp && x <= 0) {
        rho = -c.q * naSi;
        eField = -(c.q * naSi / epsS) * (x + xp);
        potential = (c.q * naSi / (2 * epsS)) * math.pow(x + xp, 2);
      } else if (x >= 0 && x <= xn) {
        rho = c.q * ndSi;
        eField = (c.q * ndSi / epsS) * (x - xn);
        final v0 = (c.q * naSi / (2 * epsS)) * math.pow(xp, 2);
        potential = v0 + (c.q * ndSi / epsS) * (xn * x - 0.5 * x * x);
      } else {
        rho = 0;
        eField = 0;
        potential = x < -xp ? 0 : effectiveBias;
      }

      if (_showOutside || (x >= -xp && x <= xn)) {
        rhoSpots.add(FlSpot(positionUm, rho));
        eSpots.add(FlSpot(positionUm, eField));
        vSpots.add(FlSpot(positionUm, potential));

        minRho = math.min(minRho, rho);
        maxRho = math.max(maxRho, rho);
        minE = math.min(minE, eField);
        maxE = math.max(maxE, eField);
        minV = math.min(minV, potential);
        maxV = math.max(maxV, potential);
      }
    }

    // Padding for nicer axes
    final rhoPad = (maxRho - minRho).abs() * 0.1 + 1e-3;
    final ePad = (maxE - minE).abs() * 0.1 + 1e3;
    final vPad = (maxV - minV).abs() * 0.08 + 0.05;

    return _PnCurves(
      rho: rhoSpots,
      eField: eSpots,
      potential: vSpots,
      xpUm: xp * 1e6,
      xnUm: xn * 1e6,
      wUm: W * 1e6,
      vbi: vbi,
      biasTerm: biasTerm,
      invalid: invalid,
      minRho: minRho - rhoPad,
      maxRho: maxRho + rhoPad,
      minE: minE - ePad,
      maxE: maxE + ePad,
      minV: minV - vPad,
      maxV: maxV + vPad,
    );
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
        final curves = _buildCurves(constants);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 12),
              _buildInfoPanel(context, curves),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildResultsStrip(curves),
                              const SizedBox(height: 12),
                              if (curves.invalid)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Invalid: V_bi - V_a must be positive for depletion approximation.',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              if (curves.invalid) const SizedBox(height: 8),
                              Expanded(child: _buildCharts(context, curves)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          _buildControls(context),
                          const SizedBox(height: 12),
                          Expanded(child: _buildObservations(context)),
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
      children: const [
        Text('PN Junction Depletion Profiles', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        SizedBox(height: 6),
        LatexText(
          r'W = \sqrt{\frac{2 \varepsilon_s}{q}\left(\frac{1}{N_A} + \frac{1}{N_D}\right)(V_{bi}-V_a)}',
          displayMode: true,
          scale: 1.0,
        ),
      ],
    );
  }

  Widget _buildInfoPanel(BuildContext context, _PnCurves curves) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('What to observe', style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: const [
          _InfoBullet('Charge density is piecewise constant inside the depletion region.'),
          _InfoBullet('E(x) is triangular and peaks at the junction.'),
          _InfoBullet('W widens under reverse bias and shrinks under forward bias.'),
        ],
      ),
    );
  }

  Widget _buildResultsStrip(_PnCurves curves) {
    final unitLabel = _useCmUnits ? 'cm^-3' : 'm^-3';
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _resultChip('N_A', TextNumberFormatter.withUnit(_naDisplay, unitLabel)),
        _resultChip('N_D', TextNumberFormatter.withUnit(_ndDisplay, unitLabel)),
        _resultChip('T', '${_temperature.toStringAsFixed(0)} K'),
        _resultChip('V_a', '${_va.toStringAsFixed(2)} V'),
        _resultChip('V_bi', '${curves.vbi.toStringAsFixed(3)} V'),
        _resultChip('x_p', '${curves.xpUm.toStringAsFixed(3)} µm'),
        _resultChip('x_n', '${curves.xnUm.toStringAsFixed(3)} µm'),
        _resultChip('W', '${curves.wUm.toStringAsFixed(3)} µm'),
      ],
    );
  }

  Widget _buildCharts(BuildContext context, _PnCurves curves) {
    final xMin = -curves.xpUm * 1.5;
    final xMax = curves.xnUm * 1.5;

    final markerLines = <VerticalLine>[];
    if (_showMarkers) {
      markerLines.addAll([
        VerticalLine(
          x: -curves.xpUm,
          color: Colors.grey.withValues(alpha: 0.5),
          strokeWidth: 1,
          dashArray: const [4, 4],
          label: VerticalLineLabel(
            show: true,
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            style: const TextStyle(fontSize: 10),
            labelResolver: (_) => '-x_p',
          ),
        ),
        VerticalLine(
          x: 0,
          color: Colors.grey.withValues(alpha: 0.7),
          strokeWidth: 1.2,
          dashArray: const [4, 4],
          label: VerticalLineLabel(
            show: true,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 4),
            style: const TextStyle(fontSize: 10),
            labelResolver: (_) => 'junction',
          ),
        ),
        VerticalLine(
          x: curves.xnUm,
          color: Colors.grey.withValues(alpha: 0.5),
          strokeWidth: 1,
          dashArray: const [4, 4],
          label: VerticalLineLabel(
            show: true,
            alignment: Alignment.bottomRight,
            padding: const EdgeInsets.only(right: 4, bottom: 4),
            style: const TextStyle(fontSize: 10),
            labelResolver: (_) => 'x_n',
          ),
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LineChart(
            key: ValueKey('pn-rho-$_chartVersion'),
            LineChartData(
              minX: xMin,
              maxX: xMax,
              minY: curves.minRho,
              maxY: curves.maxRho,
              gridData: const FlGridData(show: true, drawVerticalLine: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: const Text('ρ (C/m³)', style: TextStyle(fontSize: 12)),
                  axisNameSize: 32,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 70,
                    getTitlesWidget: (v, _) => Text(TextNumberFormatter.sci(v, sigFigs: 2), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text('x (µm)'),
                  axisNameSize: 32,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text(v.toStringAsFixed(2), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              extraLinesData: ExtraLinesData(verticalLines: markerLines),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: curves.rho,
                  isCurved: false,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem(
                            'x=${s.x.toStringAsFixed(3)} µm\nρ=${TextNumberFormatter.sci(s.y)} C/m³',
                            const TextStyle(fontSize: 11),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LineChart(
            key: ValueKey('pn-e-$_chartVersion'),
            LineChartData(
              minX: xMin,
              maxX: xMax,
              minY: curves.minE,
              maxY: curves.maxE,
              gridData: const FlGridData(show: true, drawVerticalLine: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: const Text('E (V/m)', style: TextStyle(fontSize: 12)),
                  axisNameSize: 32,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (v, _) => Text(TextNumberFormatter.sci(v, sigFigs: 2), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text('x (µm)'),
                  axisNameSize: 32,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text(v.toStringAsFixed(2), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              extraLinesData: ExtraLinesData(verticalLines: markerLines),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: curves.eField,
                  isCurved: false,
                  color: Theme.of(context).colorScheme.secondary,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem(
                            'x=${s.x.toStringAsFixed(3)} µm\nE=${TextNumberFormatter.sci(s.y)} V/m',
                            const TextStyle(fontSize: 11),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LineChart(
            key: ValueKey('pn-v-$_chartVersion'),
            LineChartData(
              minX: xMin,
              maxX: xMax,
              minY: curves.minV,
              maxY: curves.maxV,
              gridData: const FlGridData(show: true, drawVerticalLine: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: const Text('V (V)', style: TextStyle(fontSize: 12)),
                  axisNameSize: 32,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (v, _) => Text(v.toStringAsFixed(2), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text('x (µm)'),
                  axisNameSize: 32,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text(v.toStringAsFixed(2), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              extraLinesData: ExtraLinesData(verticalLines: markerLines),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: curves.potential,
                  isCurved: false,
                  color: Theme.of(context).colorScheme.tertiary,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem(
                            'x=${s.x.toStringAsFixed(3)} µm\nV=${s.y.toStringAsFixed(3)} V',
                            const TextStyle(fontSize: 11),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Parameters', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              _slider('T (K)', _temperature, 200, 500, (v) => _updateChart(() => _temperature = v), step: 1, labelText: '${_temperature.toStringAsFixed(0)} K'),
              _slider('N_A', _naDisplay, 1e14, 1e20, (v) => _updateChart(() => _naDisplay = v), step: 1e14, labelText: TextNumberFormatter.sci(_naDisplay)),
              _slider('N_D', _ndDisplay, 1e14, 1e20, (v) => _updateChart(() => _ndDisplay = v), step: 1e14, labelText: TextNumberFormatter.sci(_ndDisplay)),
              _slider('V_a (V)', _va, -5.0, 1.0, (v) => _updateChart(() => _va = double.parse(v.toStringAsFixed(2))), step: 0.01, labelText: _va.toStringAsFixed(2)),
              _slider('ε_r', _epsR, 1.0, 15.0, (v) => _updateChart(() => _epsR = double.parse(v.toStringAsFixed(2))), step: 0.1, labelText: _epsR.toStringAsFixed(2)),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('cm^-3')),
                  ButtonSegment(value: false, label: Text('m^-3')),
                ],
                selected: {_useCmUnits},
                onSelectionChanged: (s) {
                  final naSi = _dopingToSi(_naDisplay);
                  final ndSi = _dopingToSi(_ndDisplay);
                  _updateChart(() {
                    _useCmUnits = s.first;
                    _naDisplay = _dopingToDisplay(naSi);
                    _ndDisplay = _dopingToDisplay(ndSi);
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show x_p, x_n, W markers'),
                value: _showMarkers,
                onChanged: (v) => _updateChart(() => _showMarkers = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show outside depletion (ρ=0)'),
                value: _showOutside,
                onChanged: (v) => _updateChart(() => _showOutside = v),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _resetDefaults,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildObservations(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key Observations', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: const [
                  _InfoBullet('Higher doping narrows depletion width W.'),
                  _InfoBullet('Reverse bias increases W; forward bias decreases W.'),
                  _InfoBullet('E(x) peaks at the junction and goes to zero at depletion edges.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged,
      {required double step, required String labelText}) {
    final divisions = ((max - min) / step).round();
    final int? safeDivisions = divisions > 2000 ? null : (divisions > 0 ? divisions : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(labelText, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: safeDivisions,
            label: labelText,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _resultChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PnCurves {
  final List<FlSpot> rho;
  final List<FlSpot> eField;
  final List<FlSpot> potential;
  final double xpUm;
  final double xnUm;
  final double wUm;
  final double vbi;
  final double biasTerm;
  final bool invalid;
  final double minRho;
  final double maxRho;
  final double minE;
  final double maxE;
  final double minV;
  final double maxV;

  _PnCurves({
    required this.rho,
    required this.eField,
    required this.potential,
    required this.xpUm,
    required this.xnUm,
    required this.wUm,
    required this.vbi,
    required this.biasTerm,
    required this.invalid,
    required this.minRho,
    required this.maxRho,
    required this.minE,
    required this.maxE,
    required this.minV,
    required this.maxV,
  });
}

class _InfoBullet extends StatelessWidget {
  final String text;
  const _InfoBullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
