import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../widgets/latex_text.dart';
import '../graphs/common/graph_controller.dart';
import '../graphs/common/readouts_card.dart';
import '../graphs/common/point_inspector_card.dart';
import '../graphs/common/parameters_card.dart';
import '../graphs/common/key_observations_card.dart';
import '../graphs/common/chart_toolbar.dart';
import '../graphs/common/viewport_state.dart';
import '../graphs/core/graph_config.dart' show GraphConfig, ControlsConfig;
import '../graphs/core/standard_graph_page_scaffold.dart';

class DensityOfStatesGraphPage extends StatelessWidget {
  const DensityOfStatesGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Density of States g(E) vs Energy')),
      body: const _DensityOfStatesGraphView(),
    );
  }
}

class _DensityOfStatesGraphView extends StatefulWidget {
  const _DensityOfStatesGraphView();

  @override
  State<_DensityOfStatesGraphView> createState() => _DensityOfStatesGraphViewState();
}

class _DensityOfStatesGraphViewState extends State<_DensityOfStatesGraphView>
    with GraphController {
  // Parameters
  double _eg = 1.12;
  double _meEff = 0.26;
  double _mhEff = 0.39;
  double _energyWindow = 1.0;
  double _fermiOffset = 0.0;

  // Selection
  FlSpot? _selectedPoint;
  String? _selectedBand;

  // Viewport
  late ViewportState _viewport;

  static const double _hbar = 1.054571817e-34; // J*s
  static const double _m0 = 9.1093837015e-31; // kg
  static const int _samples = 220;

  @override
  void initState() {
    super.initState();
    final ec = _eg / 2;
    final ev = -_eg / 2;
    final eMin = ev - _energyWindow;
    final eMax = ec + _energyWindow;
    _viewport = ViewportState(
      defaultMinX: eMin,
      defaultMaxX: eMax,
      defaultMinY: 0,
      defaultMaxY: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ec = _eg / 2;
    final ev = -_eg / 2;
    final eMin = ev - _energyWindow;
    final eMax = ec + _energyWindow;
    final data = _buildData(ec: ec, ev: ev, eMin: eMin, eMax: eMax);

    // Update viewport defaults when parameters change
    _viewport = ViewportState(
      defaultMinX: eMin,
      defaultMaxX: eMax,
      defaultMinY: 0,
      defaultMaxY: (data.maxDos * 1.08).clamp(0.1, double.infinity),
    );

    return StandardGraphPageScaffold(
      config: const GraphConfig(
        title: 'Density of States g(E) vs Energy',
        subtitle: 'DOS & Statistics',
        mainEquation:
            r'g_c(E)=\frac{1}{2\pi^{2}}\!\left(\frac{2m_e^{*}}{\hbar^{2}}\right)^{\frac{3}{2}}\!\sqrt{E-E_c},\quad'
            r'g_v(E)=\frac{1}{2\pi^{2}}\!\left(\frac{2m_h^{*}}{\hbar^{2}}\right)^{\frac{3}{2}}\!\sqrt{E_v-E}',
        controls: ControlsConfig(children: []),
      ),
      aboutSection: _buildAboutCard(context),
      observeSection: _buildObserveCard(context),
      chartBuilder: (context) => _buildChartCard(context, data, ec, ev),
      rightPanelBuilder: (context, config) => _buildRightPanel(ec, ev),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Density of States g(E) vs Energy',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
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
            child: const LatexText(
              r'g_c(E)=\frac{1}{2\pi^{2}}\!\left(\frac{2m_e^{*}}{\hbar^{2}}\right)^{\frac{3}{2}}\!\sqrt{E-E_c},\quad'
              r'g_v(E)=\frac{1}{2\pi^{2}}\!\left(\frac{2m_h^{*}}{\hbar^{2}}\right)^{\frac{3}{2}}\!\sqrt{E_v-E}',
              displayMode: true,
              scale: 1.05,
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
            Text(
              'Shows the available quantum states per unit energy. The square-root dependence arises from parabolic bands. Heavier effective mass increases DOS.',
              style: Theme.of(context).textTheme.bodyMedium,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bullet(r'$g(E)$ rises as $\sqrt{|E-E_{c,v}|}$; heavier $m^*$ raises DOS.'),
              _bullet(r'Conduction DOS starts at $E_c$; valence DOS starts at $E_v$.'),
              _bullet(r'Fermi level ($E_F$) positioning + DOS shape explains carrier counts.'),
              const SizedBox(height: 8),
              Text('Try this:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              _bullet(r'Change $m_e^*$ and $m_h^*$ to see asymmetric DOS.'),
              _bullet(r'Move $E_F$ and observe overlap with conduction/valence DOS.'),
              _bullet('Adjust bandgap to see how the DOS gap changes.'),
            ],
          ),
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
          Expanded(child: _parseLatex(text)),
        ],
      ),
    );
  }

  Widget _parseLatex(String text) {
    final parts = <Widget>[];
    final buffer = StringBuffer();
    var inLatex = false;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == r'$') {
        if (buffer.isNotEmpty) {
          parts.add(inLatex
              ? LatexText(buffer.toString(), scale: 1.0)
              : Text(buffer.toString(), style: Theme.of(context).textTheme.bodyMedium));
          buffer.clear();
        }
        inLatex = !inLatex;
      } else {
        buffer.write(char);
      }
    }
    if (buffer.isNotEmpty) {
      parts.add(inLatex
          ? LatexText(buffer.toString(), scale: 1.0)
          : Text(buffer.toString(), style: Theme.of(context).textTheme.bodyMedium));
    }
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: parts);
  }

  Widget _buildRightPanel(double ec, double ev) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildReadoutsCard(ec, ev),
          const SizedBox(height: 12),
          _buildPointInspectorCard(),
          const SizedBox(height: 12),
          _buildKeyObservationsCard(ec, ev),
          const SizedBox(height: 12),
          _buildParametersCard(),
        ],
      ),
    );
  }

  Widget _buildReadoutsCard(double ec, double ev) {
    final dosAtEc = _dosCoeff(_meEff) * math.sqrt(0.1);
    final dosAtEv = _dosCoeff(_mhEff) * math.sqrt(0.1);

    return ReadoutsCard(
      title: 'Band Edges & DOS',
      readouts: [
        ReadoutItem(
          label: r'$E_c$ (conduction edge)',
          value: '${ec.toStringAsFixed(3)} eV',
        ),
        ReadoutItem(
          label: r'$E_v$ (valence edge)',
          value: '${ev.toStringAsFixed(3)} eV',
        ),
        ReadoutItem(
          label: r'$E_g$ (bandgap)',
          value: '${_eg.toStringAsFixed(3)} eV',
          boldValue: true,
        ),
        ReadoutItem(
          label: r'$E_F$ (Fermi level)',
          value: '${_fermiOffset.toStringAsFixed(3)} eV',
        ),
        ReadoutItem(
          label: r'$g_c$ at $E_c$+0.1eV',
          value: dosAtEc.toStringAsPrecision(3),
          subtitle: 'Arbitrary units',
        ),
        ReadoutItem(
          label: r'$g_v$ at $E_v$âˆ’0.1eV',
          value: dosAtEv.toStringAsPrecision(3),
          subtitle: 'Arbitrary units',
        ),
      ],
    );
  }

  Widget _buildPointInspectorCard() {
    return PointInspectorCard<FlSpot>(
      selectedPoint: _selectedPoint,
      onClear: () => updateChart(() {
        _selectedPoint = null;
        _selectedBand = null;
      }),
      builder: (spot) {
        return [
          'Band: ${_selectedBand ?? "Unknown"}',
          'Energy: ${spot.x.toStringAsFixed(3)} eV',
          'DOS: ${spot.y.toStringAsPrecision(4)}',
          'Distance to band edge: ${_distanceToBandEdge(spot.x).toStringAsFixed(3)} eV',
        ];
      },
    );
  }

  double _distanceToBandEdge(double e) {
    final ec = _eg / 2;
    final ev = -_eg / 2;
    if (_selectedBand == 'Conduction') {
      return (e - ec).abs();
    } else {
      return (ev - e).abs();
    }
  }

  Widget _buildParametersCard() {
    return ParametersCard(
      title: 'Parameters',
      collapsible: true,
      initiallyExpanded: true,
      children: [
        ParameterSlider(
          label: r'Bandgap $E_g$ (eV)',
          value: _eg,
          min: 0.4,
          max: 2.5,
          divisions: 210,
          onChanged: (v) {
            setState(() => _eg = double.parse(v.toStringAsFixed(3)));
            bumpChart();
          },
        ),
        ParameterSlider(
          label: r'$m_e^*$ / $m_0$ (electrons)',
          value: _meEff,
          min: 0.05,
          max: 2.0,
          divisions: 195,
          onChanged: (v) {
            setState(() => _meEff = double.parse(v.toStringAsFixed(3)));
            bumpChart();
          },
          subtitle: 'Affects conduction DOS',
        ),
        ParameterSlider(
          label: r'$m_h^*$ / $m_0$ (holes)',
          value: _mhEff,
          min: 0.05,
          max: 2.0,
          divisions: 195,
          onChanged: (v) {
            setState(() => _mhEff = double.parse(v.toStringAsFixed(3)));
            bumpChart();
          },
          subtitle: 'Affects valence DOS',
        ),
        ParameterSlider(
          label: 'Energy padding (eV)',
          value: _energyWindow,
          min: 0.2,
          max: 1.6,
          divisions: 140,
          onChanged: (v) {
            setState(() => _energyWindow = double.parse(v.toStringAsFixed(2)));
            bumpChart();
          },
          subtitle: 'Viewing range around band edges',
        ),
        ParameterSlider(
          label: r'$E_F$ offset (eV, midgap = 0)',
          value: _fermiOffset,
          min: -1.5,
          max: 1.5,
          divisions: 300,
          onChanged: (v) {
            setState(() => _fermiOffset = double.parse(v.toStringAsFixed(3)));
            bumpChart();
          },
          subtitle: 'Fermi level position',
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () {
            updateChart(() {
              _eg = 1.12;
              _meEff = 0.26;
              _mhEff = 0.39;
              _energyWindow = 1.0;
              _fermiOffset = 0.0;
            });
          },
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text('Reset to Silicon'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 36),
          ),
        ),
      ],
    );
  }

  Widget _buildKeyObservationsCard(double ec, double ev) {
    final dynamicObs = _buildDynamicObservations(ec, ev);
    final staticObs = _buildStaticObservations();

    return KeyObservationsCard(
      title: 'Key Observations',
      dynamicObservations: dynamicObs.isNotEmpty ? dynamicObs : null,
      staticObservations: staticObs,
      dynamicTitle: _selectedPoint != null ? 'Selected Point' : null,
    );
  }

  List<String> _buildDynamicObservations(double ec, double ev) {
    if (_selectedPoint == null) return [];

    final e = _selectedPoint!.x;
    final dos = _selectedPoint!.y;
    final obs = <String>[];

    if (_selectedBand == 'Conduction') {
      final deltaE = e - ec;
      obs.add(
          'Selected conduction DOS at \$E = ${e.toStringAsFixed(3)}\$ eV, \$\\Delta E = ${deltaE.toStringAsFixed(3)}\$ eV above \$E_c\$.');
      obs.add('DOS value: ${dos.toStringAsPrecision(4)} (arb. units).');
      obs.add(
          r'DOS $\propto \sqrt{\Delta E}$; doubling $\Delta E$ increases DOS by $\times\sqrt{2} \approx 1.41$.');
    } else if (_selectedBand == 'Valence') {
      final deltaE = ev - e;
      obs.add(
          'Selected valence DOS at \$E = ${e.toStringAsFixed(3)}\$ eV, \$\\Delta E = ${deltaE.toStringAsFixed(3)}\$ eV below \$E_v\$.');
      obs.add('DOS value: ${dos.toStringAsPrecision(4)} (arb. units).');
      obs.add(
          r'DOS $\propto \sqrt{\Delta E}$; doubling $\Delta E$ increases DOS by $\times\sqrt{2} \approx 1.41$.');
    }

    // Fermi level context
    final deltaEf = (_fermiOffset - e).abs();
    if (deltaEf < 0.2) {
      obs.add(
          r'Selected point is near $E_F$ ($\Delta E_F < 0.2$ eV) â†’ high occupation/depletion probability.');
    }

    return obs;
  }

  List<String> _buildStaticObservations() {
    return [
      r'DOS $\propto (m^*)^{3/2}$; heavier effective mass â†’ more available states.',
      r'Conduction DOS: $g_c(E) \propto \sqrt{E - E_c}$ (parabolic band).',
      r'Valence DOS: $g_v(E) \propto \sqrt{E_v - E}$ (parabolic band).',
      r'Carrier concentration $\propto$ DOS $\times$ Fermi-Dirac distribution.',
    ];
  }

  Widget _buildChartCard(BuildContext context, _DosData data, double ec, double ev) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _legendSwatch(Theme.of(context).colorScheme.primary, 'Conduction'),
                      _legendSwatch(Theme.of(context).colorScheme.tertiary, 'Valence'),
                      _legendLine(Theme.of(context).colorScheme.error, r'$E_F$'),
                    ],
                  ),
                ),
                ChartToolbar(
                  onZoomIn: () => updateChart(() => _viewport.zoom(0.2)),
                  onZoomOut: () => updateChart(() => _viewport.zoom(-0.2)),
                  onReset: () => updateChart(() => _viewport.reset()),
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildChart(context, data, ec, ev)),
          ],
        ),
      ),
    );
  }

  Widget _legendSwatch(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 10,
          width: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _legendLine(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(width: 6, height: 2, color: color),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildChart(BuildContext context, _DosData data, double ec, double ev) {
    final conductionColor = Theme.of(context).colorScheme.primary;
    final valenceColor = Theme.of(context).colorScheme.tertiary;
    final efColor = Theme.of(context).colorScheme.error;

    return LineChart(
      key: ValueKey('dos-$chartVersion'),
      LineChartData(
        minX: _viewport.minX,
        maxX: _viewport.maxX,
        minY: _viewport.minY,
        maxY: _viewport.maxY,
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
              color: conductionColor.withOpacity(0.45),
              dashArray: [6, 4],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(bottom: 6, right: 4),
                labelResolver: (_) => 'Eá´„',
              ),
            ),
            VerticalLine(
              x: ev,
              color: valenceColor.withOpacity(0.45),
              dashArray: [6, 4],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                labelResolver: (_) => 'Eá´ ',
              ),
            ),
            VerticalLine(
              x: _fermiOffset,
              color: efColor.withOpacity(0.5),
              strokeWidth: 2,
              dashArray: [4, 4],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.only(top: 4, right: 4),
                labelResolver: (_) => 'Eêœ°',
              ),
            ),
          ],
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            axisNameWidget: Text('DOS (arb. units)'),
            sideTitles: SideTitles(showTitles: true, reservedSize: 46),
          ),
          bottomTitles: const AxisTitles(
            axisNameWidget: Text('Energy (eV, midgap = 0)'),
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
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
                    FlLine(color: bar.color?.withOpacity(0.4), dashArray: [4, 4], strokeWidth: 1),
                    FlDotData(show: false),
                  ),
                )
                .toList();
          },
          touchCallback: (event, response) {
            if (event is FlTapUpEvent && response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
              final spot = response.lineBarSpots!.first;
              setState(() {
                _selectedPoint = FlSpot(spot.x, spot.y);
                _selectedBand = spot.barIndex == 0 ? 'Conduction' : 'Valence';
              });
            }
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
    final coeff = math.pow(2 * mStarRatio * _m0 / (_hbar * _hbar), 1.5);
    return coeff / 1e56;
  }
}

class _DosData {
  final List<FlSpot> conduction;
  final List<FlSpot> valence;
  final double maxDos;

  _DosData({required this.conduction, required this.valence, required this.maxDos});
}

