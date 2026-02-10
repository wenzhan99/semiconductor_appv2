import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/constants_loader.dart';
import '../../core/constants/constants_repository.dart';
import '../../core/constants/latex_symbols.dart';
import '../graphs/utils/semiconductor_models.dart';
import '../widgets/latex_text.dart';

// Standardized components
import '../graphs/common/graph_controller.dart';
import '../graphs/common/readouts_card.dart';
import '../graphs/common/point_inspector_card.dart';
import '../graphs/common/parameters_card.dart';
import '../graphs/common/key_observations_card.dart';
import '../graphs/common/plot_selector.dart';
import '../graphs/utils/latex_number_formatter.dart';

class PnDepletionGraphPage extends StatelessWidget {
  const PnDepletionGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PN Junction Depletion Profiles')),
      body: const _PnDepletionGraphView(),
    );
  }
}

class _PnDepletionGraphView extends StatefulWidget {
  const _PnDepletionGraphView();

  @override
  State<_PnDepletionGraphView> createState() => _PnDepletionGraphViewState();
}

class _PnDepletionGraphViewState extends State<_PnDepletionGraphView>
    with GraphController {
  // Parameters
  double _temperature = 300;
  double _naDisplay = 1e16;
  double _ndDisplay = 1e16;
  double _va = 0.0;
  double _epsR = 11.7;
  bool _useCmUnits = true;
  bool _showMarkers = true;
  bool _showOutside = true;

  // Plot selection
  String _selectedPlot = 'ρ(x)';

  // Interactive
  FlSpot? _selectedPoint;

  static const double _bandgap = 1.12; // eV for Si
  static const double _mnStar = 1.08;
  static const double _mpStar = 0.56;
  static const int _samples = 240;

  late Future<_Constants> _constants;

  @override
  void initState() {
    super.initState();
    _constants = _loadConstants();
  }

  Future<_Constants> _loadConstants() async {
    final repo = ConstantsRepository();
    await repo.load();
    final latex = await ConstantsLoader.loadLatexSymbols();
    return _Constants(
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

  void _resetDefaults() {
    updateChart(() {
      _temperature = 300;
      _naDisplay = 1e16;
      _ndDisplay = 1e16;
      _va = 0.0;
      _epsR = 11.7;
      _useCmUnits = true;
      _showMarkers = true;
      _showOutside = true;
      _selectedPlot = 'ρ(x)';
      _selectedPoint = null;
    });
  }

  _PnCurves _buildCurves(_Constants c) {
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

    final eMax = -(c.q * naSi / epsS) * xp;
    
    return _PnCurves(
      rho: rhoSpots,
      eField: eSpots,
      potential: vSpots,
      xpUm: xp * 1e6,
      xnUm: xn * 1e6,
      wUm: W * 1e6,
      vbi: vbi,
      eMax: eMax,
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
    return FutureBuilder<_Constants>(
      future: _constants,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final constants = snapshot.data!;
        final curves = _buildCurves(constants);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1100;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 12),
                  _buildAboutCard(context),
                  const SizedBox(height: 12),
                  _buildObserveCard(context),
                  const SizedBox(height: 12),
                  Expanded(
                    child: isWide
                        ? _buildWideLayout(context, curves)
                        : _buildNarrowLayout(context, curves),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PN Junction Depletion Profiles',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'PN Junction',
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
              r'W = \sqrt{\frac{2 \varepsilon_s}{q}\left(\frac{1}{N_A} + \frac{1}{N_D}\right)(V_{bi}-V_a)}',
              displayMode: true,
              scale: 1.1,
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
                  'Shows spatial profiles of charge density ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const LatexText(r'\rho(x)', scale: 1.0),
                Text(
                  ', electric field ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const LatexText(r'E(x)', scale: 1.0),
                Text(
                  ', and potential ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const LatexText(r'V(x)', scale: 1.0),
                Text(
                  ' in the depletion region of a PN junction under bias.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
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
          _bullet(r'Charge density $\rho(x)$ is piecewise constant inside depletion region.'),
          _bullet(r'Electric field $E(x)$ is triangular and peaks at junction.'),
          _bullet(r'Potential $V(x)$ is parabolic; rises from 0 to $V_{bi}$ across depletion width.'),
          _bullet(r'Depletion width $W$ widens under reverse bias ($V_a < 0$).'),
          const SizedBox(height: 8),
          Text('Try this:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          _bullet(r'Change $N_A$ and $N_D$ to see asymmetric depletion (higher doping → narrower side).'),
          _bullet(r'Apply forward bias ($V_a > 0$) to shrink $W$; reverse bias to widen.'),
          _bullet('Use plot selector to view one profile at a time or all together.'),
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

  Widget _buildWideLayout(BuildContext context, _PnCurves curves) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildChartCard(context, curves),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildReadoutsCard(curves),
                const SizedBox(height: 12),
                _buildPointInspectorCard(curves),
                const SizedBox(height: 12),
                _buildParametersCard(),
                const SizedBox(height: 12),
                _buildKeyObservationsCard(curves),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, _PnCurves curves) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 300, maxHeight: 450),
            child: _buildChartCard(context, curves),
          ),
          const SizedBox(height: 12),
          _buildReadoutsCard(curves),
          const SizedBox(height: 12),
          _buildPointInspectorCard(curves),
          const SizedBox(height: 12),
          _buildParametersCard(),
          const SizedBox(height: 12),
          _buildKeyObservationsCard(curves),
        ],
      ),
    );
  }

  Widget _buildReadoutsCard(_PnCurves curves) {
    final unitLabel = _useCmUnits ? 'cm⁻³' : 'm⁻³';
    return ReadoutsCard(
      title: 'Readouts',
      readouts: [
        ReadoutItem(
          label: r'$W$ (depletion width)',
          value: '${curves.wUm.toStringAsFixed(3)} µm',
          boldValue: true,
        ),
        ReadoutItem(
          label: r'$x_p$ (p-side)',
          value: '${curves.xpUm.toStringAsFixed(3)} µm',
        ),
        ReadoutItem(
          label: r'$x_n$ (n-side)',
          value: '${curves.xnUm.toStringAsFixed(3)} µm',
        ),
        ReadoutItem(
          label: r'$E_{max}$ (peak field)',
          value: '${LatexNumberFormatter.toUnicodeSci(curves.eMax.abs(), sigFigs: 3)} V/m',
        ),
        ReadoutItem(
          label: r'$V_{bi}$ (built-in)',
          value: '${curves.vbi.toStringAsFixed(3)} V',
        ),
        ReadoutItem(
          label: r'$N_A$',
          value: '${LatexNumberFormatter.toUnicodeSci(_naDisplay, sigFigs: 3)} $unitLabel',
        ),
        ReadoutItem(
          label: r'$N_D$',
          value: '${LatexNumberFormatter.toUnicodeSci(_ndDisplay, sigFigs: 3)} $unitLabel',
        ),
        ReadoutItem(
          label: r'$T$',
          value: '${_temperature.toStringAsFixed(0)} K',
        ),
        ReadoutItem(
          label: r'$V_a$ (applied)',
          value: '${_va.toStringAsFixed(2)} V',
        ),
      ],
    );
  }

  Widget _buildPointInspectorCard(_PnCurves curves) {
    return PointInspectorCard<FlSpot>(
      selectedPoint: _selectedPoint,
      onClear: () => updateChart(() => _selectedPoint = null),
      builder: (spot) {
        final x = spot.x;
        final y = spot.y;
        
        String yLabel;
        String yValue;
        if (_selectedPlot == 'ρ(x)') {
          yLabel = 'ρ';
          yValue = '${LatexNumberFormatter.toUnicodeSci(y, sigFigs: 3)} C/m³';
        } else if (_selectedPlot == 'E(x)') {
          yLabel = 'E';
          yValue = '${LatexNumberFormatter.toUnicodeSci(y, sigFigs: 3)} V/m';
        } else {
          yLabel = 'V';
          yValue = '${y.toStringAsFixed(3)} V';
        }

        return [
          'Plot: $_selectedPlot',
          'x = ${x.toStringAsFixed(3)} µm',
          '$yLabel = $yValue',
          'Tap chart to select point',
        ];
      },
    );
  }

  Widget _buildParametersCard() {
    return ParametersCard(
      title: 'Parameters',
      collapsible: true,
      initiallyExpanded: true,
      children: [
        ParameterSlider(
          label: r'$T$ (K)',
          value: _temperature,
          min: 200,
          max: 500,
          divisions: 300,
          onChanged: (v) {
            setState(() => _temperature = v);
            bumpChart();
          },
        ),
        ParameterSlider(
          label: r'$N_A$ (${_useCmUnits ? "cm⁻³" : "m⁻³"})',
          value: _naDisplay,
          min: 1e14,
          max: 1e20,
          divisions: null,
          onChanged: (v) {
            setState(() => _naDisplay = v);
            bumpChart();
          },
          subtitle: LatexNumberFormatter.toUnicodeSci(_naDisplay, sigFigs: 3),
        ),
        ParameterSlider(
          label: r'$N_D$ (${_useCmUnits ? "cm⁻³" : "m⁻³"})',
          value: _ndDisplay,
          min: 1e14,
          max: 1e20,
          divisions: null,
          onChanged: (v) {
            setState(() => _ndDisplay = v);
            bumpChart();
          },
          subtitle: LatexNumberFormatter.toUnicodeSci(_ndDisplay, sigFigs: 3),
        ),
        ParameterSlider(
          label: r'$V_a$ (V)',
          value: _va,
          min: -5.0,
          max: 1.0,
          divisions: 600,
          onChanged: (v) {
            setState(() => _va = double.parse(v.toStringAsFixed(2)));
            bumpChart();
          },
          subtitle: 'Applied bias',
        ),
        ParameterSlider(
          label: r'$\varepsilon_r$',
          value: _epsR,
          min: 1.0,
          max: 15.0,
          divisions: 140,
          onChanged: (v) {
            setState(() => _epsR = double.parse(v.toStringAsFixed(2)));
            bumpChart();
          },
          subtitle: 'Relative permittivity',
        ),
        const SizedBox(height: 8),
        ParameterSegmented<bool>(
          label: 'Doping units',
          selected: {_useCmUnits},
          segments: const [
            ButtonSegment(value: true, label: Text('cm⁻³')),
            ButtonSegment(value: false, label: Text('m⁻³')),
          ],
          onSelectionChanged: (s) {
            final naSi = _dopingToSi(_naDisplay);
            final ndSi = _dopingToSi(_ndDisplay);
            updateChart(() {
              _useCmUnits = s.first;
              _naDisplay = _dopingToDisplay(naSi);
              _ndDisplay = _dopingToDisplay(ndSi);
            });
          },
        ),
        ParameterSwitch(
          label: r'Show markers ($x_p$, $x_n$, junction)',
          value: _showMarkers,
          onChanged: (v) {
            setState(() => _showMarkers = v);
            bumpChart();
          },
        ),
        ParameterSwitch(
          label: r'Show outside depletion ($\rho=0$)',
          value: _showOutside,
          onChanged: (v) {
            setState(() => _showOutside = v);
            bumpChart();
          },
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _resetDefaults,
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text('Reset to Defaults'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 36),
          ),
        ),
      ],
    );
  }

  Widget _buildKeyObservationsCard(_PnCurves curves) {
    final dynamicObs = _buildDynamicObservations(curves);
    final staticObs = _buildStaticObservations();

    return KeyObservationsCard(
      title: 'Key Observations',
      dynamicObservations: dynamicObs.isNotEmpty ? dynamicObs : null,
      staticObservations: staticObs,
      dynamicTitle: 'Current Configuration',
    );
  }

  List<String> _buildDynamicObservations(_PnCurves curves) {
    final obs = <String>[];

    // Bias regime
    if (_va < -0.1) {
      obs.add(
          r'Reverse bias ($V_a < 0$): depletion width increases, peak field rises.');
    } else if (_va > 0.1 && _va < curves.vbi) {
      obs.add(
          r'Forward bias ($V_a > 0$): depletion width shrinks, field decreases.');
    } else if (_va >= curves.vbi) {
      obs.add(
          r'Warning: $V_a \geq V_{bi}$ violates depletion approximation (diffusion dominates).');
    } else {
      obs.add(r'Zero bias ($V_a \approx 0$): equilibrium depletion width.');
    }

    // Doping asymmetry
    final naSi = _dopingToSi(_naDisplay);
    final ndSi = _dopingToSi(_ndDisplay);
    final ratio = naSi / ndSi;
    if (ratio > 10) {
      obs.add(
          r'Highly asymmetric doping: $N_A \gg N_D$ → depletion extends mostly into n-side ($x_n \gg x_p$).');
    } else if (ratio < 0.1) {
      obs.add(
          r'Highly asymmetric doping: $N_D \gg N_A$ → depletion extends mostly into p-side ($x_p \gg x_n$).');
    } else {
      obs.add(r'Moderate doping asymmetry: depletion regions fairly balanced.');
    }

    // Field and bias relationship
    if (_selectedPlot == 'E(x)') {
      obs.add(
          r'Electric field $E(x)$ profile: triangular, peaks at junction ($x=0$), zero at depletion edges.');
    }

    // Potential shape
    if (_selectedPlot == 'V(x)') {
      obs.add(
          r'Potential $V(x)$ is parabolic in each region; total drop equals $V_{bi} - V_a$.');
    }

    return obs;
  }

  List<String> _buildStaticObservations() {
    return [
      r'Depletion width $W \propto \sqrt{V_{bi} - V_a}$; sensitive to bias.',
      r'Peak field $E_{max} = -q N_A x_p / \varepsilon_s = q N_D x_n / \varepsilon_s$ at junction.',
      r'Charge neutrality: $N_A x_p = N_D x_n$ (equal charge on both sides).',
      r'Higher doping → narrower depletion on that side (one-sided junction approximation).',
    ];
  }

  Widget _buildChartCard(BuildContext context, _PnCurves curves) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (curves.invalid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r'Invalid: $V_{bi} - V_a$ must be positive for depletion approximation.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            PlotSelector(
              options: const ['ρ(x)', 'E(x)', 'V(x)', 'All'],
              selected: _selectedPlot,
              onChanged: (value) {
                updateChart(() {
                  _selectedPlot = value;
                  _selectedPoint = null;
                });
              },
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildChartArea(context, curves)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartArea(BuildContext context, _PnCurves curves) {
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
            labelResolver: (_) => '-xₚ',
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
            labelResolver: (_) => 'xₙ',
          ),
        ),
      ]);
    }

    if (_selectedPlot == 'All') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildRhoChart(context, curves, xMin, xMax, markerLines)),
          const SizedBox(height: 8),
          Expanded(child: _buildEChart(context, curves, xMin, xMax, markerLines)),
          const SizedBox(height: 8),
          Expanded(child: _buildVChart(context, curves, xMin, xMax, markerLines)),
        ],
      );
    } else if (_selectedPlot == 'ρ(x)') {
      return _buildRhoChart(context, curves, xMin, xMax, markerLines);
    } else if (_selectedPlot == 'E(x)') {
      return _buildEChart(context, curves, xMin, xMax, markerLines);
    } else {
      return _buildVChart(context, curves, xMin, xMax, markerLines);
    }
  }

  Widget _buildRhoChart(BuildContext context, _PnCurves curves, double xMin, double xMax, List<VerticalLine> markers) {
    return LineChart(
      key: ValueKey('pn-rho-$chartVersion'),
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
              getTitlesWidget: (v, _) => Text(
                LatexNumberFormatter.toUnicodeSci(v, sigFigs: 2),
                style: const TextStyle(fontSize: 10),
              ),
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
        extraLinesData: ExtraLinesData(verticalLines: markers),
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
          enabled: true,
          touchCallback: (event, response) {
            if (event is FlTapUpEvent && response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
              final spot = response.lineBarSpots!.first;
              setState(() => _selectedPoint = FlSpot(spot.x, spot.y));
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      'x=${s.x.toStringAsFixed(3)} µm\nρ=${LatexNumberFormatter.toUnicodeSci(s.y, sigFigs: 3)} C/m³',
                      const TextStyle(fontSize: 11),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEChart(BuildContext context, _PnCurves curves, double xMin, double xMax, List<VerticalLine> markers) {
    return LineChart(
      key: ValueKey('pn-e-$chartVersion'),
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
              getTitlesWidget: (v, _) => Text(
                LatexNumberFormatter.toUnicodeSci(v, sigFigs: 2),
                style: const TextStyle(fontSize: 10),
              ),
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
        extraLinesData: ExtraLinesData(verticalLines: markers),
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
          enabled: true,
          touchCallback: (event, response) {
            if (event is FlTapUpEvent && response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
              final spot = response.lineBarSpots!.first;
              setState(() => _selectedPoint = FlSpot(spot.x, spot.y));
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      'x=${s.x.toStringAsFixed(3)} µm\nE=${LatexNumberFormatter.toUnicodeSci(s.y, sigFigs: 3)} V/m',
                      const TextStyle(fontSize: 11),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildVChart(BuildContext context, _PnCurves curves, double xMin, double xMax, List<VerticalLine> markers) {
    return LineChart(
      key: ValueKey('pn-v-$chartVersion'),
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
        extraLinesData: ExtraLinesData(verticalLines: markers),
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
          enabled: true,
          touchCallback: (event, response) {
            if (event is FlTapUpEvent && response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
              final spot = response.lineBarSpots!.first;
              setState(() => _selectedPoint = FlSpot(spot.x, spot.y));
            }
          },
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
  final double eMax;
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
    required this.eMax,
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

class _Constants {
  final double h, kB, m0, q, eps0;
  final LatexSymbolMap latexMap;

  _Constants({
    required this.h,
    required this.kB,
    required this.m0,
    required this.q,
    required this.eps0,
    required this.latexMap,
  });
}
