import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/constants_repository.dart';
import '../graphs/utils/text_number_formatter.dart';
import '../widgets/latex_text.dart';

class DriftDiffusionGraphPage extends StatelessWidget {
  const DriftDiffusionGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drift vs Diffusion Current (1D)')),
      body: const DriftDiffusionGraphView(),
    );
  }
}

class DriftDiffusionGraphView extends StatefulWidget {
  const DriftDiffusionGraphView({super.key});

  @override
  State<DriftDiffusionGraphView> createState() => _DriftDiffusionGraphViewState();
}

enum CarrierMode { electrons, holes, both }
enum ProfileType { linear, exponential }

class _DriftDiffusionGraphViewState extends State<DriftDiffusionGraphView> {
  int _chartVersion = 0;
  CarrierMode _carrierMode = CarrierMode.electrons;
  ProfileType _profileType = ProfileType.linear;

  double _temperature = 300;
  double _lengthUm = 10;
  double _electricField = 50000;
  double _n0Display = 1e16;
  double _gradientStrength = 0.5;
  double _mobilityCm2 = 1350;
  bool _useCmUnits = true;
  bool _useEinstein = true;
  bool _showComponents = true;
  double _manualD = 0.0035; // m^2/s (used when Einstein toggle is off)

  late Future<({double q, double kB})> _constants;

  static const int _samples = 180;
  static const double _densityFloor = 1e6; // m^-3 to avoid zeros

  void _updateChart(void Function() updater) {
    setState(() {
      updater();
      _chartVersion++;
    });
  }

  @override
  void initState() {
    super.initState();
    _constants = _loadConstants();
  }

  Future<({double q, double kB})> _loadConstants() async {
    final repo = ConstantsRepository();
    await repo.load();
    return (
      q: repo.getConstantValue('q')!,
      kB: repo.getConstantValue('k')!,
    );
  }

  double get _lengthMeters => _lengthUm * 1e-6;

  double _toSiDensity(double display) => _useCmUnits ? display * 1e6 : display;

  double _toDisplayDensity(double si) => _useCmUnits ? si / 1e6 : si;

  double _mobilitySi() => _mobilityCm2 * 1e-4; // cm^2/Vs -> m^2/Vs

  double _diffusivity(double kB, double q) {
    if (_useEinstein) {
      return _mobilitySi() * (kB * _temperature) / q;
    }
    return _manualD;
  }

  _ProfileData _buildProfiles(double kB, double q) {
    final length = _lengthMeters;
    final baseDensity = _toSiDensity(_n0Display);
    final mu = _mobilitySi();
    final D = _diffusivity(kB, q);

    final List<FlSpot> densitySpotsN = [];
    final List<FlSpot> densitySpotsP = [];
    final List<FlSpot> driftSpotsN = [];
    final List<FlSpot> diffSpotsN = [];
    final List<FlSpot> totalSpotsN = [];
    final List<FlSpot> driftSpotsP = [];
    final List<FlSpot> diffSpotsP = [];
    final List<FlSpot> totalSpotsP = [];

    double maxDensity = _densityFloor;
    double minJ = 0;
    double maxJ = 0;

    for (int i = 0; i < _samples; i++) {
      final x = length * i / (_samples - 1);
      final profile = _densityAt(x, baseDensity, length);
      final n = math.max(profile.density, _densityFloor);
      final dnDx = profile.derivative;

      // Electrons
      final driftN = q * n * mu * _electricField;
      final diffN = q * D * dnDx;
      final totalN = driftN + diffN;

      final xUm = x * 1e6;

      if (_carrierMode != CarrierMode.holes) {
        final dispDensity = _toDisplayDensity(n);
        densitySpotsN.add(FlSpot(xUm, dispDensity));
        driftSpotsN.add(FlSpot(xUm, driftN));
        diffSpotsN.add(FlSpot(xUm, diffN));
        totalSpotsN.add(FlSpot(xUm, totalN));
        maxDensity = math.max(maxDensity, dispDensity);
        minJ = math.min(minJ, math.min(driftN, math.min(diffN, totalN)));
        maxJ = math.max(maxJ, math.max(driftN, math.max(diffN, totalN)));
      }

      // Holes (reuse density, sign change on diffusion term)
      if (_carrierMode != CarrierMode.electrons) {
        final p = n;
        final dpDx = dnDx;
        final driftP = q * p * mu * _electricField;
        final diffP = -q * D * dpDx; // sign flip
        final totalP = driftP + diffP;
        final dispDensity = _toDisplayDensity(p);
        densitySpotsP.add(FlSpot(xUm, dispDensity));
        driftSpotsP.add(FlSpot(xUm, driftP));
        diffSpotsP.add(FlSpot(xUm, diffP));
        totalSpotsP.add(FlSpot(xUm, totalP));
        maxDensity = math.max(maxDensity, dispDensity);
        minJ = math.min(minJ, math.min(driftP, math.min(diffP, totalP)));
        maxJ = math.max(maxJ, math.max(driftP, math.max(diffP, totalP)));
      }
    }

    final midX = length / 2;
    final midProfile = _densityAt(midX, baseDensity, length);
    final midN = math.max(midProfile.density, _densityFloor);
    final midDnDx = midProfile.derivative;
    final midDrift = q * midN * mu * _electricField;
    final midDiff = q * D * midDnDx;
    double midTotal = 0;
    if (_carrierMode != CarrierMode.holes) {
      midTotal += midDrift + midDiff;
    }
    if (_carrierMode != CarrierMode.electrons) {
      midTotal += midDrift - midDiff;
    }

    return _ProfileData(
      densityN: densitySpotsN,
      densityP: densitySpotsP,
      driftN: driftSpotsN,
      diffusionN: diffSpotsN,
      totalN: totalSpotsN,
      driftP: driftSpotsP,
      diffusionP: diffSpotsP,
      totalP: totalSpotsP,
      maxDensity: maxDensity,
      minJ: minJ,
      maxJ: maxJ,
      midTotal: midTotal,
      midXUm: midX * 1e6,
    );
  }

  _ProfileSample _densityAt(double x, double n0, double length) {
    final center = length / 2;
    switch (_profileType) {
      case ProfileType.linear:
        final slope = _gradientStrength * n0 / length;
        final density = n0 + slope * (x - center);
        return _ProfileSample(density: math.max(density, _densityFloor), derivative: slope);
      case ProfileType.exponential:
        final g = _gradientStrength / length;
        final density = n0 * math.exp(g * (x - center));
        final derivative = density * g;
        return _ProfileSample(density: math.max(density, _densityFloor), derivative: derivative);
    }
  }

  void _resetDefaults() {
    setState(() {
      _carrierMode = CarrierMode.electrons;
      _profileType = ProfileType.linear;
      _temperature = 300;
      _lengthUm = 10;
      _electricField = 50000;
      _n0Display = 1e16;
      _gradientStrength = 0.5;
      _mobilityCm2 = 1350;
      _useCmUnits = true;
      _useEinstein = true;
      _showComponents = true;
      _manualD = 0.0035;
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
        final profiles = _buildProfiles(constants.kB, constants.q);

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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildResultsStrip(constants.kB, constants.q, profiles.midTotal),
                              const SizedBox(height: 12),
                              Expanded(child: _buildCharts(context, profiles)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          _buildControls(context, constants.kB, constants.q),
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
        Text(
          'Drift vs Diffusion Current (1D)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 4),
        LatexText(
          r'J_n = q n \mu_n E + q D_n \frac{dn}{dx}, \quad J_p = q p \mu_p E - q D_p \frac{dp}{dx}',
          displayMode: true,
          scale: 1.0,
        ),
      ],
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('What to observe', style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: const [
          _InfoBullet('Drift scales with E-field and carrier density.'),
          _InfoBullet('Diffusion scales with concentration gradient dn/dx.'),
          _InfoBullet('Electron and hole diffusion terms have opposite signs.'),
        ],
      ),
    );
  }

  Widget _buildResultsStrip(double kB, double q, double midJ) {
    final mu = _mobilityCm2;
    final displayedD = _diffusivity(kB, q);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _resultChip('Carrier', _carrierMode.name),
        _resultChip('E (V/m)', _electricField.toStringAsFixed(0)),
        _resultChip('µ (cm²/V·s)', mu.toStringAsFixed(0)),
        _resultChip('D (m²/s)', displayedD.toStringAsExponential(3)),
        _resultChip('J_total @ x=L/2 (A/m²)', midJ.toStringAsExponential(3)),
      ],
    );
  }

  Widget _buildCharts(BuildContext context, _ProfileData data) {
    final densityUnit = _useCmUnits ? 'cm^-3' : 'm^-3';
    final colorN = Theme.of(context).colorScheme.primary;
    final colorP = Theme.of(context).colorScheme.tertiary;
    final xMax = _lengthUm;

    final densityLines = <LineChartBarData>[];
    if (_carrierMode != CarrierMode.holes) {
      densityLines.add(LineChartBarData(
        spots: data.densityN,
        isCurved: false,
        color: colorN,
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }
    if (_carrierMode != CarrierMode.electrons) {
      densityLines.add(LineChartBarData(
        spots: data.densityP,
        isCurved: false,
        color: colorP,
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }

    final componentLines = <LineChartBarData>[];
    void addSeries(List<FlSpot> spots, Color c) {
      componentLines.add(LineChartBarData(
        spots: spots,
        isCurved: false,
        color: c,
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }

    final driftColor = Theme.of(context).colorScheme.primary;
    final diffColor = Theme.of(context).colorScheme.secondary;
    final totalColor = Theme.of(context).colorScheme.error;

    if (_carrierMode != CarrierMode.holes) {
      if (_showComponents) {
        addSeries(data.driftN, driftColor.withValues(alpha: 0.8));
        addSeries(data.diffusionN, diffColor.withValues(alpha: 0.8));
      }
      addSeries(data.totalN, totalColor.withValues(alpha: 0.9));
    }
    if (_carrierMode != CarrierMode.electrons) {
      if (_showComponents) {
        addSeries(data.driftP, driftColor.withValues(alpha: 0.5));
        addSeries(data.diffusionP, diffColor.withValues(alpha: 0.5));
      }
      addSeries(data.totalP, totalColor.withValues(alpha: 0.6));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LineChart(
            key: ValueKey('drift-density-$_chartVersion'),
            LineChartData(
              minX: 0,
              maxX: xMax,
              minY: 0,
              maxY: data.maxDensity * 1.1,
              gridData: const FlGridData(show: true, drawVerticalLine: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: Text('n/p ($densityUnit)', style: const TextStyle(fontSize: 12)),
                  axisNameSize: 36,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (value, _) => Text(TextNumberFormatter.sci(value, sigFigs: 2), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text('x (µm)'),
                  axisNameSize: 32,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: densityLines,
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    return LineTooltipItem(
                      'x=${s.x.toStringAsFixed(2)} µm\nn/p=${TextNumberFormatter.sci(s.y)} $densityUnit',
                      const TextStyle(fontSize: 11),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LineChart(
            key: ValueKey('drift-current-$_chartVersion'),
            LineChartData(
              minX: 0,
              maxX: xMax,
              minY: data.minJ * 1.1,
              maxY: data.maxJ * 1.1,
              gridData: const FlGridData(show: true, drawVerticalLine: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: const Text('J (A/m²)', style: TextStyle(fontSize: 12)),
                  axisNameSize: 32,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (value, _) => Text(TextNumberFormatter.sci(value, sigFigs: 2), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text('x (µm)'),
                  axisNameSize: 32,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true),
              extraLinesData: ExtraLinesData(
                verticalLines: [
                  VerticalLine(
                    x: _lengthUm / 2,
                    color: Colors.grey.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: const [4, 4],
                    label: VerticalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, top: 4),
                      style: const TextStyle(fontSize: 10),
                      labelResolver: (_) => 'x=L/2',
                    ),
                  ),
                ],
              ),
              lineBarsData: componentLines,
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    return LineTooltipItem(
                      'x=${s.x.toStringAsFixed(2)} µm\nJ=${TextNumberFormatter.sci(s.y)} A/m²',
                      const TextStyle(fontSize: 11),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context, double kB, double q) {
    final D = _diffusivity(kB, q);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Parameters', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              DropdownButton<CarrierMode>(
                value: _carrierMode,
                isExpanded: true,
                onChanged: (v) => _updateChart(() => _carrierMode = v ?? CarrierMode.electrons),
                items: const [
                  DropdownMenuItem(value: CarrierMode.electrons, child: Text('Electrons')),
                  DropdownMenuItem(value: CarrierMode.holes, child: Text('Holes')),
                  DropdownMenuItem(value: CarrierMode.both, child: Text('Both')),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButton<ProfileType>(
                value: _profileType,
                isExpanded: true,
                onChanged: (v) => _updateChart(() => _profileType = v ?? ProfileType.linear),
                items: const [
                  DropdownMenuItem(value: ProfileType.linear, child: Text('Linear')),
                  DropdownMenuItem(value: ProfileType.exponential, child: Text('Exponential')),
                ],
              ),
              const SizedBox(height: 12),
              _slider('T (K)', _temperature, 200, 500, (v) => _updateChart(() => _temperature = v), step: 1, labelText: '${_temperature.toStringAsFixed(0)} K'),
              _slider('Length L (µm)', _lengthUm, 1, 50, (v) => _updateChart(() => _lengthUm = v), step: 0.5, labelText: _lengthUm.toStringAsFixed(1)),
              _slider('E (V/m)', _electricField, -200000, 200000, (v) => _updateChart(() => _electricField = v), step: 1000, labelText: _electricField.toStringAsFixed(0)),
              _slider('n0 (units)', _n0Display, 1e14, 1e22, (v) => _updateChart(() => _n0Display = v), step: 1e14, labelText: TextNumberFormatter.sci(_n0Display)),
              _slider('Gradient strength', _gradientStrength, -2, 2, (v) => _updateChart(() => _gradientStrength = v), step: 0.01, labelText: _gradientStrength.toStringAsFixed(2)),
              _slider('µ (cm²/V·s)', _mobilityCm2, 50, 2000, (v) => _updateChart(() => _mobilityCm2 = v), step: 10, labelText: _mobilityCm2.toStringAsFixed(0)),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('cm^-3')),
                  ButtonSegment(value: false, label: Text('m^-3')),
                ],
                selected: {_useCmUnits},
                onSelectionChanged: (s) {
                  final siDensity = _toSiDensity(_n0Display);
                  _updateChart(() {
                    _useCmUnits = s.first;
                    _n0Display = _useCmUnits ? siDensity / 1e6 : siDensity;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use Einstein relation (D = µkT/q)'),
                value: _useEinstein,
                onChanged: (v) => _updateChart(() => _useEinstein = v),
              ),
              if (!_useEinstein)
                _slider('D override (m²/s)', _manualD, 1e-4, 0.05, (v) => _updateChart(() => _manualD = v), step: 1e-4, labelText: _manualD.toStringAsExponential(2)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show drift & diffusion components'),
                value: _showComponents,
                onChanged: (v) => _updateChart(() => _showComponents = v),
              ),
              const SizedBox(height: 4),
              Text('D (current): ${D.toStringAsExponential(3)} m²/s', style: const TextStyle(fontSize: 12)),
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
                  _InfoBullet('Drift term follows E-field sign and carrier density.'),
                  _InfoBullet('Diffusion term follows density slope dn/dx.'),
                  _InfoBullet('Reversing E flips drift without changing diffusion.'),
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

class _ProfileSample {
  final double density;
  final double derivative;

  _ProfileSample({required this.density, required this.derivative});
}

class _ProfileData {
  final List<FlSpot> densityN;
  final List<FlSpot> densityP;
  final List<FlSpot> driftN;
  final List<FlSpot> diffusionN;
  final List<FlSpot> totalN;
  final List<FlSpot> driftP;
  final List<FlSpot> diffusionP;
  final List<FlSpot> totalP;
  final double maxDensity;
  final double minJ;
  final double maxJ;
  final double midTotal;
  final double midXUm;

  _ProfileData({
    required this.densityN,
    required this.densityP,
    required this.driftN,
    required this.diffusionN,
    required this.totalN,
    required this.driftP,
    required this.diffusionP,
    required this.totalP,
    required this.maxDensity,
    required this.minJ,
    required this.maxJ,
    required this.midTotal,
    required this.midXUm,
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
