import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/constants_loader.dart';
import '../../core/constants/constants_repository.dart';
import '../../core/constants/latex_symbols.dart';
import '../theme/chart_style.dart';
import '../graphs/utils/latex_number_formatter.dart';
import '../graphs/utils/safe_math.dart';
import '../graphs/utils/semiconductor_models.dart';
import '../widgets/latex_text.dart';

class CarrierConcentrationGraphPage extends StatelessWidget {
  const CarrierConcentrationGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carrier Concentration vs Fermi Level')),
      body: const CarrierConcentrationGraphView(),
    );
  }
}

class CarrierConcentrationGraphView extends StatefulWidget {
  const CarrierConcentrationGraphView({super.key});

  @override
  State<CarrierConcentrationGraphView> createState() =>
      _CarrierConcentrationGraphViewState();
}

enum SeriesMode { nOnly, pOnly, both }

class _CarrierConcentrationGraphViewState
    extends State<CarrierConcentrationGraphView> {
  int _chartVersion = 0;
  // Controls
  double _temperature = 300; // K
  double _bandgap = 1.12; // eV
  double _mnStar = 1.08; // x m0
  double _mpStar = 0.56; // x m0
  double _fermiLevel = 0.56; // eV
  bool _useCmUnits = true;
  bool _showBandEdges = true;
  bool _showNiLine = true;
  bool _autoScaleY = false;
  bool _showIntrinsicMarker = true;
  SeriesMode _seriesMode = SeriesMode.both;

  static const double _efMin = -0.5;
  static const double _efMaxBase = 2.0;
  static const int _samples = 240;

  static const _fixedRangeCm = (min: 0.0, max: 22.0);
  static const _fixedRangeM = (min: 6.0, max: 28.0);

  void _update(VoidCallback fn) {
    setState(() {
      fn();
      _chartVersion++;
    });
  }

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

  double get _densityDisplayFactor =>
      _useCmUnits ? 1e-6 : 1.0; // m^-3 to cm^-3 or m^-3

  double _calcN(double efEv, double Nc, double q, double kB) {
    final deltaEc = (_bandgap - efEv) * q;
    final exponent = -deltaEc / (kB * _temperature);
    final safeExp =
        SafeMath.safeExp(SafeMath.clamp(exponent, -200, 200), maxExp: 200);
    return Nc * safeExp;
  }

  double _calcP(double efEv, double Nv, double q, double kB) {
    final deltaEv = efEv * q;
    final exponent = -deltaEv / (kB * _temperature);
    final safeExp =
        SafeMath.safeExp(SafeMath.clamp(exponent, -200, 200), maxExp: 200);
    return Nv * safeExp;
  }

  _CarrierCurves _buildCurves(
      ({double h, double kB, double m0, double q, LatexSymbolMap latexMap}) c) {
    final Nc = SemiconductorModels.computeNc(
      temperatureK: _temperature,
      h: c.h,
      kB: c.kB,
      m0: c.m0,
      effectiveMassRatio: _mnStar,
    );
    final Nv = SemiconductorModels.computeNv(
      temperatureK: _temperature,
      h: c.h,
      kB: c.kB,
      m0: c.m0,
      effectiveMassRatio: _mpStar,
    );

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

    final List<FlSpot> nSpots = [];
    final List<FlSpot> pSpots = [];
    final List<double> yVals = [];

    final efMax = _efMax();

    for (int i = 0; i < _samples; i++) {
      final ef = _efMin + (efMax - _efMin) * i / (_samples - 1);
      final nSi = _calcN(ef, Nc, c.q, c.kB);
      final pSi = _calcP(ef, Nv, c.q, c.kB);

      final nDisplay = nSi * _densityDisplayFactor;
      final pDisplay = pSi * _densityDisplayFactor;

      if (nDisplay > 0) {
        final logN = math.log(nDisplay) / math.ln10;
        if (SafeMath.isValid(logN)) {
          nSpots.add(FlSpot(ef, logN));
          yVals.add(logN);
        }
      }

      if (pDisplay > 0) {
        final logP = math.log(pDisplay) / math.ln10;
        if (SafeMath.isValid(logP)) {
          pSpots.add(FlSpot(ef, logP));
          yVals.add(logP);
        }
      }
    }

    double? niLog;
    if (_showNiLine && ni > 0) {
      final niDisplay = ni * _densityDisplayFactor;
      niLog = math.log(niDisplay) / math.ln10;
      if (SafeMath.isValid(niLog)) {
        yVals.add(niLog);
      }
    }

    if (yVals.isEmpty) {
      yVals.addAll([-1, 1]);
    }

    final minY = yVals.reduce(math.min);
    final maxY = yVals.reduce(math.max);
    final pad = (maxY - minY).abs() * 0.12 + 0.2;

    return _CarrierCurves(
      nSpots: nSpots,
      pSpots: pSpots,
      niLog: niLog,
      minY: minY - pad,
      maxY: maxY + pad,
      Nc: Nc,
      Nv: Nv,
      ni: ni,
    );
  }

  double _efMax() => math.max(_efMaxBase, _bandgap + 0.5);

  void _resetSilicon() {
    setState(() {
      _temperature = 300;
      _bandgap = 1.12;
      _mnStar = 1.08;
      _mpStar = 0.56;
      _fermiLevel = _bandgap / 2;
      _useCmUnits = true;
      _showBandEdges = true;
      _showNiLine = true;
      _showIntrinsicMarker = true;
      _autoScaleY = false;
      _seriesMode = SeriesMode.both;
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
        final curves = _buildCurves(constants);

        final currentN =
            _calcN(_fermiLevel, curves.Nc, constants.q, constants.kB) *
                _densityDisplayFactor;
        final currentP =
            _calcP(_fermiLevel, curves.Nv, constants.q, constants.kB) *
                _densityDisplayFactor;
        final currentNi = curves.ni * _densityDisplayFactor;

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
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildResultsStrip(currentN, currentP, currentNi),
                              const SizedBox(height: 12),
                              Expanded(child: _buildChart(context, curves)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildControls(context),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 300,
                              child: _buildObservations(context),
                            ),
                          ],
                        ),
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
          'Carrier Concentration vs Fermi Level',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const LatexText(
          r'n = N_c e^{-\frac{E_c - E_F}{kT}},\quad p = N_v e^{-\frac{E_F - E_v}{kT}}',
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
        title: const Text('What to observe',
            style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: const [
          _InfoBullet(
              r'n \text{ rises exponentially as } E_F \text{ moves toward } E_c',
              useLatex: true),
          _InfoBullet(
              r'p \text{ rises exponentially as } E_F \text{ moves toward } E_v',
              useLatex: true),
          _InfoBullet(
              r'\text{At intrinsic conditions, } n \approx p \approx n_i \text{ (log-scale helps)}',
              useLatex: true),
        ],
      ),
    );
  }

  Widget _buildResultsStrip(double n, double p, double ni) {
    final unitLatex = _useCmUnits ? r'\mathrm{cm^{-3}}' : r'\mathrm{m^{-3}}';
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _resultChip(r'T', '${_temperature.toStringAsFixed(0)} K'),
        _resultChip(r'E_F', '${_fermiLevel.toStringAsFixed(3)} eV'),
        if (_seriesMode != SeriesMode.pOnly)
          _resultChipLatex(
              r'n(E_F)',
              LatexNumberFormatter.valueWithUnit(n,
                  unitLatex: unitLatex, sigFigs: 3)),
        if (_seriesMode != SeriesMode.nOnly)
          _resultChipLatex(
              r'p(E_F)',
              LatexNumberFormatter.valueWithUnit(p,
                  unitLatex: unitLatex, sigFigs: 3)),
        if (_showNiLine)
          _resultChipLatex(
              r'n_i(T)',
              LatexNumberFormatter.valueWithUnit(ni,
                  unitLatex: unitLatex, sigFigs: 3)),
      ],
    );
  }

  Widget _buildChart(BuildContext context, _CarrierCurves curves) {
    final unitLatex = _useCmUnits ? r'\mathrm{cm^{-3}}' : r'\mathrm{m^{-3}}';
    final unitUnicode = _useCmUnits ? 'cm⁻³' : 'm⁻³';
    final legendColorN = Theme.of(context).colorScheme.primary;
    final legendColorP = Theme.of(context).colorScheme.tertiary;
    final intrinsicMarker = _computeIntrinsicMarker(curves);
    final yRange = _computeYRange(curves);

    final extraLines = <HorizontalLine>[];
    if (_showNiLine && curves.niLog != null) {
      extraLines.add(
        HorizontalLine(
          y: curves.niLog!,
          color: Colors.grey.withValues(alpha: 0.55),
          strokeWidth: 1.2,
          dashArray: const [6, 6],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 6),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            labelResolver: (_) => 'nᵢ',
          ),
        ),
      );
    }

    final verticals = <VerticalLine>[
      VerticalLine(
        x: _fermiLevel,
        color: Colors.grey.withValues(alpha: 0.6),
        strokeWidth: 1.4,
        dashArray: const [5, 5],
        label: VerticalLineLabel(
          show: true,
          alignment: Alignment.bottomRight,
          padding: const EdgeInsets.only(right: 4, bottom: 4),
          style: const TextStyle(fontSize: 11),
          labelResolver: (_) => 'E_F',
        ),
      ),
    ];

    if (_showBandEdges) {
      verticals.addAll([
        VerticalLine(
          x: 0,
          color: legendColorP.withValues(alpha: 0.35),
          strokeWidth: 1.2,
          dashArray: const [4, 6],
          label: VerticalLineLabel(
            show: true,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 4),
            style: TextStyle(fontSize: 11, color: legendColorP),
            labelResolver: (_) => 'Eᵥ',
          ),
        ),
        VerticalLine(
          x: _bandgap,
          color: legendColorN.withValues(alpha: 0.35),
          strokeWidth: 1.2,
          dashArray: const [4, 6],
          label: VerticalLineLabel(
            show: true,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 4),
            style: TextStyle(fontSize: 11, color: legendColorN),
            labelResolver: (_) => 'Eᴄ',
          ),
        ),
      ]);
    }

    if (intrinsicMarker != null) {
      extraLines.add(
        HorizontalLine(
          y: intrinsicMarker.y,
          color: Colors.orange.withValues(alpha: 0.6),
          strokeWidth: 0.8,
          dashArray: const [4, 6],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 4),
            style: const TextStyle(fontSize: 11, color: Colors.orange),
            labelResolver: (_) => 'n = p',
          ),
        ),
      );
    }

    final bars =
        _buildSeries(curves, legendColorN, legendColorP, intrinsicMarker);
    final barLabels = <String>[];
    if (_seriesMode != SeriesMode.pOnly) barLabels.add('n');
    if (_seriesMode != SeriesMode.nOnly) barLabels.add('p');
    if (intrinsicMarker != null &&
        _showIntrinsicMarker &&
        _seriesMode == SeriesMode.both) {
      barLabels.add('n=p');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_seriesMode != SeriesMode.pOnly)
              _legend(legendColorN, r'n(E_F)'),
            if (_seriesMode != SeriesMode.nOnly)
              _legend(legendColorP, r'p(E_F)'),
            if (_showNiLine) _legend(Colors.grey, r'n_i(T)', dashed: true),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LineChart(
            key: ValueKey('carrier-$_chartVersion'),
            LineChartData(
              minX: _efMin,
              maxX: _efMax(),
              minY: yRange.min,
              maxY: yRange.max,
              clipData: FlClipData.all(),
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
                      const LatexText(r'n,\, p', scale: 0.95),
                      const SizedBox(width: 6),
                      LatexText("($unitLatex,\\ \\log_{10})", scale: 0.85),
                    ],
                  ),
                  axisNameSize: 44,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: context.chartStyle.leftReservedSize,
                    getTitlesWidget: (value, _) {
                      final exp = value.round();
                      if (exp % 2 != 0) return const SizedBox.shrink();
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
                  axisNameWidget:
                      const LatexText(r'E_F\ (\mathrm{eV})', scale: 0.95),
                  axisNameSize: 40,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: context.chartStyle.bottomReservedSize,
                    getTitlesWidget: (value, _) {
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
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: extraLines,
                verticalLines: verticals,
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: bars,
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (touched) {
                    if (touched.isEmpty) return [];

                    // Show E_F once at the top
                    final efValue = touched.first.x;
                    final items = <LineTooltipItem>[];

                    for (int i = 0; i < touched.length; i++) {
                      final spot = touched[i];
                      final yVal = spot.y;
                      final conc = math.pow(10, yVal).toDouble();
                      final label = spot.barIndex < barLabels.length
                          ? barLabels[spot.barIndex]
                          : '';

                      if (i == 0) {
                        // First item: show E_F
                        items.add(LineTooltipItem(
                          '',
                          const TextStyle(),
                          children: [
                            TextSpan(
                                text: 'E_F: ${efValue.toStringAsFixed(3)} eV\n',
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                            TextSpan(
                              text:
                                  '$label: ${LatexNumberFormatter.toUnicodeSci(conc, sigFigs: 3)} $unitUnicode\n',
                              style: const TextStyle(fontSize: 11),
                            ),
                            TextSpan(
                              text:
                                  'log₁₀($label) = ${yVal.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[300]),
                            ),
                          ],
                        ));
                      } else {
                        // Subsequent items: show only concentration
                        items.add(LineTooltipItem(
                          '',
                          const TextStyle(),
                          children: [
                            TextSpan(
                              text:
                                  '$label: ${LatexNumberFormatter.toUnicodeSci(conc, sigFigs: 3)} $unitUnicode\n',
                              style: const TextStyle(fontSize: 11),
                            ),
                            TextSpan(
                              text:
                                  'log₁₀($label) = ${yVal.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[300]),
                            ),
                          ],
                        ));
                      }
                    }

                    return items;
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  _Range _computeYRange(_CarrierCurves curves) {
    if (!_autoScaleY) {
      final fixed = _useCmUnits ? _fixedRangeCm : _fixedRangeM;
      return _Range(fixed.min, fixed.max);
    }

    final ys = <double>[];
    if (_seriesMode != SeriesMode.pOnly) {
      ys.addAll(curves.nSpots.map((e) => e.y));
    }
    if (_seriesMode != SeriesMode.nOnly) {
      ys.addAll(curves.pSpots.map((e) => e.y));
    }
    if (_showNiLine && curves.niLog != null) {
      ys.add(curves.niLog!);
    }
    if (ys.isEmpty) return _Range(curves.minY, curves.maxY);
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);
    final pad = (maxY - minY).abs() * 0.12 + 0.2;
    return _Range(minY - pad, maxY + pad);
  }

  List<LineChartBarData> _buildSeries(
    _CarrierCurves curves,
    Color colorN,
    Color colorP,
    FlSpot? intrinsicMarker,
  ) {
    final bars = <LineChartBarData>[];
    if (_seriesMode != SeriesMode.pOnly) {
      bars.add(
        LineChartBarData(
          spots: curves.nSpots,
          isCurved: true,
          color: colorN,
          barWidth: 2.2,
          dotData: const FlDotData(show: false),
        ),
      );
    }
    if (_seriesMode != SeriesMode.nOnly) {
      bars.add(
        LineChartBarData(
          spots: curves.pSpots,
          isCurved: true,
          color: colorP,
          barWidth: 2.2,
          dotData: const FlDotData(show: false),
        ),
      );
    }

    if (intrinsicMarker != null &&
        _showIntrinsicMarker &&
        _seriesMode == SeriesMode.both) {
      bars.add(
        LineChartBarData(
          spots: [intrinsicMarker],
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
      );
    }

    return bars;
  }

  FlSpot? _computeIntrinsicMarker(_CarrierCurves curves) {
    if (!_showIntrinsicMarker || _seriesMode != SeriesMode.both) return null;
    if (curves.nSpots.isEmpty || curves.pSpots.isEmpty) return null;
    final len = math.min(curves.nSpots.length, curves.pSpots.length);
    double bestDiff = double.infinity;
    FlSpot? best;
    for (int i = 0; i < len; i++) {
      final diff = (curves.nSpots[i].y - curves.pSpots[i].y).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = FlSpot(
            curves.nSpots[i].x, (curves.nSpots[i].y + curves.pSpots[i].y) / 2);
      }
    }
    return best;
  }

  Widget _buildControls(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title:
            Text('Parameters', style: Theme.of(context).textTheme.titleSmall),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _slider(
                label: const LatexText(r'T\ (\mathrm{K})', scale: 1.0),
                value: _temperature,
                min: 100,
                max: 800,
                divisions: 700,
                onChanged: (v) => _update(() => _temperature = v),
                valueText: _temperature.toStringAsFixed(0),
              ),
              _slider(
                label: const LatexText(r'E_g\ (\mathrm{eV})', scale: 1.0),
                value: _bandgap,
                min: 0.5,
                max: 1.6,
                divisions: 1100,
                onChanged: (v) => _update(() {
                  _bandgap = double.parse(v.toStringAsFixed(3));
                  _fermiLevel = _fermiLevel.clamp(_efMin, _efMax());
                }),
                valueText: _bandgap.toStringAsFixed(3),
              ),
              _slider(
                label: const LatexText(r'm_n^*\ (\times m_0)', scale: 1.0),
                value: _mnStar,
                min: 0.1,
                max: 2.0,
                divisions: 190,
                onChanged: (v) => _update(() {
                  _mnStar = double.parse(v.toStringAsFixed(3));
                }),
                valueText: _mnStar.toStringAsFixed(2),
              ),
              _slider(
                label: const LatexText(r'm_p^*\ (\times m_0)', scale: 1.0),
                value: _mpStar,
                min: 0.1,
                max: 2.0,
                divisions: 190,
                onChanged: (v) => _update(() {
                  _mpStar = double.parse(v.toStringAsFixed(3));
                }),
                valueText: _mpStar.toStringAsFixed(2),
              ),
              _slider(
                label: const LatexText(r'E_F\ (\mathrm{eV})', scale: 1.0),
                value: _fermiLevel,
                min: _efMin,
                max: _efMax(),
                divisions: 250,
                onChanged: (v) => _update(() {
                  _fermiLevel = double.parse(v.toStringAsFixed(3));
                }),
                valueText: _fermiLevel.toStringAsFixed(3),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: true, label: LatexText(r'\mathrm{cm^{-3}}')),
                  ButtonSegment(
                      value: false, label: LatexText(r'\mathrm{m^{-3}}')),
                ],
                selected: {_useCmUnits},
                onSelectionChanged: (s) => _update(() => _useCmUnits = s.first),
              ),
              const SizedBox(height: 8),
              SegmentedButton<SeriesMode>(
                segments: const [
                  ButtonSegment(
                      value: SeriesMode.nOnly,
                      label: LatexText(r'n\ \text{only}', scale: 0.95)),
                  ButtonSegment(
                      value: SeriesMode.pOnly,
                      label: LatexText(r'p\ \text{only}', scale: 0.95)),
                  ButtonSegment(value: SeriesMode.both, label: Text('n & p')),
                ],
                selected: {_seriesMode},
                onSelectionChanged: (s) => _update(() => _seriesMode = s.first),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const LatexText(r'Show\ E_v / E_c\ markers'),
                value: _showBandEdges,
                onChanged: (v) => _update(() => _showBandEdges = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const LatexText(r'Show\ n_i(T)\ reference'),
                value: _showNiLine,
                onChanged: (v) => _update(() => _showNiLine = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const LatexText(r'Show\ intrinsic\ point'),
                value: _showIntrinsicMarker,
                onChanged: (v) => _update(() => _showIntrinsicMarker = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const LatexText(r'Auto\text{-}scale\ Y'),
                subtitle: const Text(
                    'If off, fixed log range so curves visibly shift'),
                value: _autoScaleY,
                onChanged: (v) => _update(() => _autoScaleY = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Log scale (locked)'),
                subtitle: const Text('Log scale is required for this view'),
                value: true,
                onChanged: null,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _resetSilicon,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset to Silicon'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40)),
              ),
            ],
          ),
        ],
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
            Text('Key Observations',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: const [
                  _InfoBullet(
                      r'n \text{ increases exponentially as } E_F \text{ approaches } E_c',
                      useLatex: true),
                  _InfoBullet(
                      r'p \text{ increases exponentially as } E_F \text{ approaches } E_v',
                      useLatex: true),
                  _InfoBullet(r'n_i \text{ marks the intrinsic point } (n = p)',
                      useLatex: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider({
    required Widget label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String valueText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: label),
              Text(valueText,
                  style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueText,
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
          LatexText(label,
              scale: 0.9,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _resultChipLatex(String labelLatex, String valueLatex) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LatexText(labelLatex,
              scale: 0.9,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          LatexText(valueLatex,
              scale: 0.95, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _legend(Color color, String latex, {bool dashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 3,
          decoration: BoxDecoration(
            color: dashed ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(2),
            border: dashed
                ? Border.all(color: color, width: 2, style: BorderStyle.solid)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        LatexText(latex, scale: 0.95),
      ],
    );
  }
}

class _CarrierCurves {
  final List<FlSpot> nSpots;
  final List<FlSpot> pSpots;
  final double? niLog;
  final double minY;
  final double maxY;
  final double Nc;
  final double Nv;
  final double ni;

  _CarrierCurves({
    required this.nSpots,
    required this.pSpots,
    required this.niLog,
    required this.minY,
    required this.maxY,
    required this.Nc,
    required this.Nv,
    required this.ni,
  });
}

class _Range {
  final double min;
  final double max;
  const _Range(this.min, this.max);
}

class _InfoBullet extends StatelessWidget {
  final String text;
  final bool useLatex;
  const _InfoBullet(this.text, {this.useLatex = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(
            child: useLatex ? LatexText(text, scale: 0.95) : Text(text),
          ),
        ],
      ),
    );
  }
}
