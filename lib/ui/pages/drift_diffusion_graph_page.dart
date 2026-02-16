import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/constants_repository.dart';
import '../theme/chart_style.dart';
import '../widgets/latex_text.dart';

// Standardized components
import '../graphs/common/graph_controller.dart';
import '../graphs/common/parameters_card.dart';
import '../graphs/common/plot_selector.dart';
import '../graphs/utils/latex_number_formatter.dart';
import '../graphs/core/graph_config.dart';
import '../graphs/core/standard_graph_page_scaffold.dart';
import '../graphs/core/standard_panel_stack.dart';

class DriftDiffusionGraphPage extends StatelessWidget {
  const DriftDiffusionGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drift vs Diffusion Current (1D)')),
      body: const _DriftDiffusionGraphView(),
    );
  }
}

class _DriftDiffusionGraphView extends StatefulWidget {
  const _DriftDiffusionGraphView();

  @override
  State<_DriftDiffusionGraphView> createState() => _DriftDiffusionGraphViewState();
}

enum CarrierMode { electrons, holes, both }
enum ProfileType { linear, exponential }

class _DriftDiffusionGraphViewState extends State<_DriftDiffusionGraphView>
    with GraphController {
  // Plot selection (fix overflow)
  String _selectedPlot = 'n(x)';

  // Parameters
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

  // Interactive system
  FlSpot? _hoverSpot;
  String? _hoverPlotId; // 'density' or 'current'

  late Future<({double q, double kB})> _constants;

  static const int _samples = 180;
  static const double _densityFloor = 1e6; // m^-3 to avoid zeros

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
      midDrift: midDrift,
      midDiff: midDiff,
      mu: mu,
      D: D,
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
    updateChart(() {
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
      _hoverSpot = null;
      _hoverPlotId = null;
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
        final panelConfig = _buildPanelConfig(constants, profiles);

        return StandardGraphPageScaffold(
          config: const GraphConfig(
            title: 'Drift vs Diffusion Current (1D)',
            subtitle: 'Carrier Transport Fundamentals',
            mainEquation:
                r'J_n = q n \mu_n E + q D_n \frac{dn}{dx},\quad J_p = q p \mu_p E - q D_p \frac{dp}{dx}',
            controls: ControlsConfig(children: []),
          ),
          aboutSection: _buildAboutCard(context),
          observeSection: _buildObserveCard(context),
          chartBuilder: (context) => _buildChartContent(context, profiles),
          rightPanelBuilder: (context, config) =>
              StandardPanelStack(config: panelConfig),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Drift vs Diffusion Current (1D)',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Carrier Transport Fundamentals',
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
            child: const Column(
              children: [
                LatexText(
                  r'J_n = q n \mu_n E + q D_n \frac{dn}{dx}',
                  displayMode: true,
                  scale: 1.1,
                ),
                SizedBox(height: 8),
                LatexText(
                  r'J_p = q p \mu_p E - q D_p \frac{dp}{dx}',
                  displayMode: true,
                  scale: 1.1,
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
                  'Visualizes drift and diffusion current components in a 1D semiconductor. Drift current arises from electric field ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const LatexText(r'E', scale: 1.0),
                Text(
                  ' acting on carriers, while diffusion current results from concentration gradients ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const LatexText(r'dn/dx', scale: 1.0),
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
          _bullet(r'Drift term follows electric field: $J_{\mathrm{drift}} \propto n\mu E$.'),
          _bullet(r'Diffusion term follows concentration gradient: $J_{\mathrm{diff}} \propto D\,dn/dx$.'),
          _bullet('Net current is the sum of drift and diffusion components.'),
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
          const Text('• '),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartContent(BuildContext context, _ProfileData profiles) {
    return Column(
      children: [
        PlotSelector(
          options: const ['n(x)', 'J components', 'All'],
          selected: _selectedPlot,
          onChanged: (plot) => updateChart(() {
            _selectedPlot = plot;
            _hoverSpot = null;
            _hoverPlotId = null;
          }),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildChartArea(context, profiles)),
      ],
    );
  }

  GraphConfig _buildPanelConfig(
    ({double q, double kB}) constants,
    _ProfileData profiles,
  ) {
    return GraphConfig(
      readouts: _buildReadouts(profiles),
      pointInspector: _buildPointInspectorConfig(),
      insights: InsightsConfig(
        dynamicObservations: _buildDynamicObservations(profiles),
        staticObservations: _buildStaticObservations(),
      ),
      controls: ControlsConfig(
        children: _buildControlsChildren(constants),
        collapsible: true,
        initiallyExpanded: true,
      ),
    );
  }

  List<ReadoutItem> _buildReadouts(_ProfileData profiles) {
    final densityUnit = _useCmUnits ? 'cm^-3' : 'm^-3';
    final mu = profiles.mu * 1e4; // back to cm^2/Vs for display
    final d = profiles.D;

    return [
      ReadoutItem(
        label: r'Carrier',
        value: _carrierMode.name,
      ),
      ReadoutItem(
        label: r'E (V/m)',
        value: LatexNumberFormatter.toUnicodeSci(_electricField, sigFigs: 3),
      ),
      ReadoutItem(
        label: r'mu (cm^2/Vs)',
        value: mu.toStringAsFixed(0),
      ),
      ReadoutItem(
        label: r'D (m^2/s)',
        value: LatexNumberFormatter.toUnicodeSci(d, sigFigs: 3),
      ),
      ReadoutItem(
        label: r'J_drift (A/m^2)',
        value: LatexNumberFormatter.toUnicodeSci(profiles.midDrift, sigFigs: 3),
      ),
      ReadoutItem(
        label: r'J_diff (A/m^2)',
        value: LatexNumberFormatter.toUnicodeSci(profiles.midDiff, sigFigs: 3),
      ),
      ReadoutItem(
        label: r'J_total (A/m^2)',
        value: LatexNumberFormatter.toUnicodeSci(profiles.midTotal, sigFigs: 3),
        boldValue: true,
      ),
      ReadoutItem(
        label: r'Units',
        value: densityUnit,
      ),
    ];
  }

  PointInspectorConfig _buildPointInspectorConfig() {
    return PointInspectorConfig(
      enabled: true,
      emptyMessage: 'Hover over any plot to inspect local values.',
      onClear: () => updateChart(() {
        _hoverSpot = null;
        _hoverPlotId = null;
      }),
      builder: _hoverSpot == null
          ? null
          : () {
              final spot = _hoverSpot!;
              final densityUnit = _useCmUnits ? 'cm^-3' : 'm^-3';
              final x = spot.x;
              final y = spot.y;

              if (_hoverPlotId == 'density') {
                return [
                  'x = ${x.toStringAsFixed(2)} um',
                  'n/p = ${LatexNumberFormatter.toUnicodeSci(y, sigFigs: 3)} $densityUnit',
                ];
              }
              if (_hoverPlotId == 'current') {
                return [
                  'x = ${x.toStringAsFixed(2)} um',
                  'J = ${LatexNumberFormatter.toUnicodeSci(y, sigFigs: 3)} A/m^2',
                ];
              }
              return [
                'Hover over any plot',
                'to inspect values',
              ];
            },
    );
  }

  List<Widget> _buildControlsChildren(({double q, double kB}) constants) {
    final d = _diffusivity(constants.kB, constants.q);

    return [
        // Carrier mode dropdown
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Carrier Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              DropdownButton<CarrierMode>(
                value: _carrierMode,
                isExpanded: true,
                onChanged: (v) => updateChart(() => _carrierMode = v ?? CarrierMode.electrons),
                items: const [
                  DropdownMenuItem(value: CarrierMode.electrons, child: Text('Electrons (n)')),
                  DropdownMenuItem(value: CarrierMode.holes, child: Text('Holes (p)')),
                  DropdownMenuItem(value: CarrierMode.both, child: Text('Both')),
                ],
              ),
            ],
          ),
        ),
        // Profile type dropdown
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Profile Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              DropdownButton<ProfileType>(
                value: _profileType,
                isExpanded: true,
                onChanged: (v) => updateChart(() => _profileType = v ?? ProfileType.linear),
                items: const [
                  DropdownMenuItem(value: ProfileType.linear, child: Text('Linear gradient')),
                  DropdownMenuItem(value: ProfileType.exponential, child: Text('Exponential gradient')),
                ],
              ),
            ],
          ),
        ),
        ParameterSlider(
          label: r'$T$ (K)',
          value: _temperature,
          min: 200,
          max: 500,
          divisions: 300,
          onChanged: (v) {
            setState(() => _temperature = v);
            updateChart(() {});
          },
        ),
        ParameterSlider(
          label: r'Length $L$ (um)',
          value: _lengthUm,
          min: 1,
          max: 50,
          divisions: 98,
          onChanged: (v) {
            setState(() => _lengthUm = v);
            updateChart(() {});
          },
        ),
        ParameterSlider(
          label: r'$E$ (V/m)',
          value: _electricField,
          min: -200000,
          max: 200000,
          divisions: 400,
          onChanged: (v) {
            setState(() => _electricField = v);
            updateChart(() {});
          },
          subtitle: 'Electric field strength',
        ),
        ParameterSlider(
          label: r'$n_0$ (base density)',
          value: _n0Display,
          min: 1e14,
          max: 1e22,
          onChanged: (v) {
            setState(() => _n0Display = v);
            updateChart(() {});
          },
          subtitle: _useCmUnits ? 'cm^-3' : 'm^-3',
        ),
        ParameterSlider(
          label: r'Gradient strength',
          value: _gradientStrength,
          min: -2,
          max: 2,
          divisions: 400,
          onChanged: (v) {
            setState(() => _gradientStrength = v);
            updateChart(() {});
          },
          subtitle: 'Controls dn/dx magnitude',
        ),
        ParameterSlider(
          label: r'$\mu$ (cm^2/Vs)',
          value: _mobilityCm2,
          min: 50,
          max: 2000,
          divisions: 195,
          onChanged: (v) {
            setState(() => _mobilityCm2 = v);
            updateChart(() {});
          },
          subtitle: 'Carrier mobility',
        ),
        const SizedBox(height: 8),
        ParameterSegmented<bool>(
          label: 'Density units',
          selected: {_useCmUnits},
          segments: const [
            ButtonSegment(value: true, label: Text('cm^-3')),
            ButtonSegment(value: false, label: Text('m^-3')),
          ],
          onSelectionChanged: (s) {
            final siDensity = _toSiDensity(_n0Display);
            updateChart(() {
              _useCmUnits = s.first;
              _n0Display = _useCmUnits ? siDensity / 1e6 : siDensity;
            });
          },
        ),
        ParameterSwitch(
          label: r'Use Einstein relation ($D = \mu kT/q$)',
          value: _useEinstein,
          onChanged: (v) => updateChart(() => _useEinstein = v),
        ),
        if (!_useEinstein)
          ParameterSlider(
            label: r'$D$ override (m^2/s)',
            value: _manualD,
            min: 1e-4,
            max: 0.05,
            onChanged: (v) {
              setState(() => _manualD = v);
              updateChart(() {});
            },
            subtitle: 'Manual diffusion coefficient',
          ),
        ParameterSwitch(
          label: 'Show drift & diffusion components',
          value: _showComponents,
          onChanged: (v) => updateChart(() => _showComponents = v),
        ),
        const SizedBox(height: 4),
        Text(
          'Current D: ${d.toStringAsExponential(3)} m^2/s',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _resetDefaults,
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text('Reset to Defaults'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 36),
          ),
        ),
    ];
  }

  List<String> _buildDynamicObservations(_ProfileData profiles) {
    final obs = <String>[];
    
    final driftRatio = (profiles.midDrift / profiles.midTotal).abs();
    final diffRatio = (profiles.midDiff / profiles.midTotal).abs();
    
    if (driftRatio > 0.9) {
      obs.add('Drift dominates: \$|J_{\\mathrm{drift}}/J_{\\mathrm{total}}| ~= ${(driftRatio * 100).toStringAsFixed(0)}\\%\$');
    } else if (diffRatio > 0.9) {
      obs.add('Diffusion dominates: \$|J_{\\mathrm{diff}}/J_{\\mathrm{total}}| ~= ${(diffRatio * 100).toStringAsFixed(0)}\\%\$');
    } else {
      obs.add('Drift and diffusion are comparable: drift ${(driftRatio * 100).toStringAsFixed(0)}%, diff ${(diffRatio * 100).toStringAsFixed(0)}%');
    }

    if (_electricField.abs() < 1000) {
      obs.add(r'Very low $E$-field -> diffusion term more important.');
    } else if (_electricField.abs() > 100000) {
      obs.add(r'Large $E$-field -> drift term dominates.');
    }

    if (_gradientStrength.abs() < 0.1) {
      obs.add(r'Nearly flat profile -> small $dn/dx$, minimal diffusion.');
    } else if (_gradientStrength.abs() > 1.5) {
      obs.add(r'Steep gradient -> large $dn/dx$, strong diffusion.');
    }

    if (_profileType == ProfileType.exponential && _gradientStrength.abs() > 0.5) {
      obs.add(r'Exponential profile creates non-constant $dn/dx$ across device.');
    }

    return obs;
  }

  List<String> _buildStaticObservations() {
    return [
      r'Drift current: $J_{\\mathrm{drift}} = q n \mu E$, scales with field and density.',
      r'Diffusion current: $J_{\\mathrm{diff}} = q D \frac{dn}{dx}$, scales with gradient.',
      r'Electron and hole diffusion have opposite signs due to charge polarity.',
      r'Einstein relation: $D = \mu kT/q$ connects mobility and diffusivity.',
    ];
  }

  Widget _buildChartArea(BuildContext context, _ProfileData profiles) {
    final showDensity = _selectedPlot == 'n(x)' || _selectedPlot == 'All';
    final showCurrent = _selectedPlot == 'J components' || _selectedPlot == 'All';

    if (_selectedPlot == 'All') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildDensityChart(context, profiles)),
          const SizedBox(height: 12),
          Expanded(child: _buildCurrentChart(context, profiles)),
        ],
      );
    } else if (showDensity) {
      return _buildDensityChart(context, profiles);
    } else {
      return _buildCurrentChart(context, profiles);
    }
  }

  Widget _buildDensityChart(BuildContext context, _ProfileData profiles) {
    final densityUnit = _useCmUnits ? 'cm^-3' : 'm^-3';
    final colorN = Theme.of(context).colorScheme.primary;
    final colorP = Theme.of(context).colorScheme.tertiary;
    final xMax = _lengthUm;

    final densityLines = <LineChartBarData>[];
    if (_carrierMode != CarrierMode.holes) {
      densityLines.add(LineChartBarData(
        spots: profiles.densityN,
        isCurved: false,
        color: colorN,
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }
    if (_carrierMode != CarrierMode.electrons) {
      densityLines.add(LineChartBarData(
        spots: profiles.densityP,
        isCurved: false,
        color: colorP,
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }

    return LineChart(
      key: ValueKey('drift-n-$chartVersion'),
      LineChartData(
        minX: 0,
        maxX: xMax,
        minY: 0,
        maxY: profiles.maxDensity * 1.1,
        gridData: const FlGridData(show: true, drawVerticalLine: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LatexText(r'n/p', scale: 1.0),
                const SizedBox(width: 4),
                Text('($densityUnit)', style: const TextStyle(fontSize: 12)),
              ],
            ),
            axisNameSize: 50,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: context.chartStyle.leftReservedSize,
              getTitlesWidget: (value, meta) => Padding(
                padding: context.chartStyle.tickPadding,
                child: Text(
                  LatexNumberFormatter.toUnicodeSci(value, sigFigs: 2),
                  style: context.chartStyle.tickTextStyle,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LatexText(r'x', scale: 1.0),
                SizedBox(width: 4),
                Text('(um)', style: TextStyle(fontSize: 12)),
              ],
            ),
            axisNameSize: 40,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: context.chartStyle.bottomReservedSize,
              getTitlesWidget: (v, meta) => Padding(
                padding: context.chartStyle.tickPadding,
                child: Text(
                  v.toStringAsFixed(1),
                  style: context.chartStyle.tickTextStyle,
                ),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: densityLines,
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (event, response) {
            final spots = response?.lineBarSpots;
            if (spots == null || spots.isEmpty) {
              setState(() {
                _hoverSpot = null;
                _hoverPlotId = null;
              });
              return;
            }
            setState(() {
              _hoverSpot = FlSpot(spots.first.x, spots.first.y);
              _hoverPlotId = 'density';
            });
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              return LineTooltipItem(
                'x=${s.x.toStringAsFixed(2)} um\nn/p=${LatexNumberFormatter.toUnicodeSci(s.y, sigFigs: 3)} $densityUnit',
                const TextStyle(fontSize: 11),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentChart(BuildContext context, _ProfileData profiles) {
    final xMax = _lengthUm;

    final componentLines = <LineChartBarData>[];
    void addSeries(List<FlSpot> spots, Color c, String label) {
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
        addSeries(profiles.driftN, driftColor.withValues(alpha: 0.8), 'J_drift(n)');
        addSeries(profiles.diffusionN, diffColor.withValues(alpha: 0.8), 'J_diff(n)');
      }
      addSeries(profiles.totalN, totalColor.withValues(alpha: 0.9), 'J_total(n)');
    }
    if (_carrierMode != CarrierMode.electrons) {
      if (_showComponents) {
        addSeries(profiles.driftP, driftColor.withValues(alpha: 0.5), 'J_drift(p)');
        addSeries(profiles.diffusionP, diffColor.withValues(alpha: 0.5), 'J_diff(p)');
      }
      addSeries(profiles.totalP, totalColor.withValues(alpha: 0.6), 'J_total(p)');
    }

    return LineChart(
      key: ValueKey('drift-j-$chartVersion'),
      LineChartData(
        minX: 0,
        maxX: xMax,
        minY: profiles.minJ * 1.1,
        maxY: profiles.maxJ * 1.1,
        gridData: const FlGridData(show: true, drawVerticalLine: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LatexText(r'J', scale: 1.0),
                SizedBox(width: 4),
                Text('(A/m^2)', style: TextStyle(fontSize: 12)),
              ],
            ),
            axisNameSize: 40,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: context.chartStyle.leftReservedSize,
              getTitlesWidget: (value, meta) => Padding(
                padding: context.chartStyle.tickPadding,
                child: Text(
                  LatexNumberFormatter.toUnicodeSci(value, sigFigs: 2),
                  style: context.chartStyle.tickTextStyle,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LatexText(r'x', scale: 1.0),
                SizedBox(width: 4),
                Text('(um)', style: TextStyle(fontSize: 12)),
              ],
            ),
            axisNameSize: 40,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: context.chartStyle.bottomReservedSize,
              getTitlesWidget: (v, meta) => Padding(
                padding: context.chartStyle.tickPadding,
                child: Text(
                  v.toStringAsFixed(1),
                  style: context.chartStyle.tickTextStyle,
                ),
              ),
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
          enabled: true,
          touchCallback: (event, response) {
            final spots = response?.lineBarSpots;
            if (spots == null || spots.isEmpty) {
              setState(() {
                _hoverSpot = null;
                _hoverPlotId = null;
              });
              return;
            }
            setState(() {
              _hoverSpot = FlSpot(spots.first.x, spots.first.y);
              _hoverPlotId = 'current';
            });
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              return LineTooltipItem(
                'x=${s.x.toStringAsFixed(2)} um\nJ=${LatexNumberFormatter.toUnicodeSci(s.y, sigFigs: 3)} A/m^2',
                const TextStyle(fontSize: 11),
              );
            }).toList(),
          ),
        ),
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
  final double midDrift;
  final double midDiff;
  final double mu;
  final double D;

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
    required this.midDrift,
    required this.midDiff,
    required this.mu,
    required this.D,
  });
}







