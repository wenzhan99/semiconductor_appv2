import 'dart:async';
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
import '../graphs/core/graph_config.dart';
import '../graphs/core/standard_graph_page_scaffold.dart';

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
  static const int _maxPins = 2;
  static const Color _pinBlue = Color(0xFF1E88E5);
  static const Color _pinRed = Color(0xFFE53935);

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

  _CarrierPointRef? _hoverPoint;
  final List<_CarrierPointRef> _pinnedPoints = [];

  // Animation panel state
  Timer? _animationTimer;
  bool _animationPlaying = false;
  double _animationSpeed = 1.0;
  bool _animationReverse = false;
  bool _animationLoop = true;
  double _animationProgress = 0.0;
  String _selectedAnimationParam = 'ef';
  final Map<String, bool> _animationEnabled = <String, bool>{
    'temperature': false,
    'bandgap': false,
    'mn': false,
    'mp': false,
    'ef': false,
  };
  final Map<String, _AnimRange> _animationRanges = <String, _AnimRange>{
    'temperature': const _AnimRange(100, 800),
    'bandgap': const _AnimRange(0.5, 1.6),
    'mn': const _AnimRange(0.1, 2.0),
    'mp': const _AnimRange(0.1, 2.0),
    'ef': const _AnimRange(_efMin, _efMaxBase),
  };

  String get _densityUnitLatex =>
      _useCmUnits ? r'\mathrm{cm^{-3}}' : r'\mathrm{m^{-3}}';

  Color _pinColorForIndex(int index) => index.isEven ? _pinBlue : _pinRed;

  Color _hoverColorForSeries(String series) =>
      series == 'n' ? _pinBlue : _pinRed;

  String _seriesLatex(String series) =>
      series == 'n' ? r'n(E_{F})' : r'p(E_{F})';

  String _seriesTitle(String series) =>
      series == 'n' ? 'Electrons (n)' : 'Holes (p)';

  String _inlineMath(String tex) => '\$$tex\$';

  bool _samePointRef(_CarrierPointRef a, _CarrierPointRef b) =>
      a.series == b.series &&
      (a.spot.x - b.spot.x).abs() < 1e-6 &&
      (a.spot.y - b.spot.y).abs() < 1e-6;

  void _togglePinnedPoint(_CarrierPointRef point) {
    final existing = _pinnedPoints.indexWhere((p) => _samePointRef(p, point));
    if (existing >= 0) {
      _pinnedPoints.removeAt(existing);
      return;
    }
    _pinnedPoints.add(point);
    if (_pinnedPoints.length > _maxPins) {
      _pinnedPoints.removeAt(0);
    }
  }

  void _update(VoidCallback fn) {
    setState(() {
      fn();
      _hoverPoint = null;
      _pinnedPoints.clear();
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

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
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
    _animationTimer?.cancel();
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
      _animationPlaying = false;
      _animationProgress = 0.0;
      _chartVersion++;
    });
  }

  void _setAnimationRange(String id, double min, double max) {
    final bounds = _absoluteBoundsForParam(id);
    final safeMin = min.clamp(bounds.min, bounds.max).toDouble();
    final safeMax = max.clamp(bounds.min, bounds.max).toDouble();
    final normalizedMin = math.min(safeMin, safeMax);
    final normalizedMax = math.max(safeMin, safeMax);
    setState(() {
      _animationRanges[id] = _AnimRange(normalizedMin, normalizedMax);
      _chartVersion++;
    });
  }

  _AnimRange _absoluteBoundsForParam(String id) {
    switch (id) {
      case 'temperature':
        return const _AnimRange(100, 800);
      case 'bandgap':
        return const _AnimRange(0.5, 1.6);
      case 'mn':
      case 'mp':
        return const _AnimRange(0.1, 2.0);
      case 'ef':
        return _AnimRange(_efMin, _efMax());
      default:
        return const _AnimRange(0, 1);
    }
  }

  void _setAnimatedParamValue(String id, double value) {
    switch (id) {
      case 'temperature':
        _temperature = value.clamp(100, 800).toDouble();
        break;
      case 'bandgap':
        _bandgap = value.clamp(0.5, 1.6).toDouble();
        _fermiLevel = _fermiLevel.clamp(_efMin, _efMax()).toDouble();
        break;
      case 'mn':
        _mnStar = value.clamp(0.1, 2.0).toDouble();
        break;
      case 'mp':
        _mpStar = value.clamp(0.1, 2.0).toDouble();
        break;
      case 'ef':
        _fermiLevel = value.clamp(_efMin, _efMax()).toDouble();
        break;
    }
  }

  void _applyAnimationFrame(double progress) {
    for (final entry in _animationEnabled.entries) {
      if (!entry.value) continue;
      final id = entry.key;
      final range = _animationRanges[id] ?? _absoluteBoundsForParam(id);
      final value = range.min + (range.max - range.min) * progress;
      _setAnimatedParamValue(id, value);
    }
  }

  void _playAnimation() {
    final hasEnabled = _animationEnabled.values.any((v) => v);
    if (!hasEnabled) return;
    if (_animationPlaying) return;
    _animationTimer?.cancel();
    setState(() {
      _animationPlaying = true;
      _hoverPoint = null;
      _pinnedPoints.clear();
    });
    _animationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        final signedStep =
            0.004 * _animationSpeed * (_animationReverse ? -1 : 1);
        var next = _animationProgress + signedStep;
        if (_animationLoop) {
          while (next > 1.0) next -= 1.0;
          while (next < 0.0) next += 1.0;
        } else {
          if (next >= 1.0 || next <= 0.0) {
            next = next.clamp(0.0, 1.0);
            _animationPlaying = false;
            timer.cancel();
          }
        }
        _animationProgress = next;
        _applyAnimationFrame(_animationProgress);
        _chartVersion++;
      });
    });
  }

  void _pauseAnimation() {
    _animationTimer?.cancel();
    setState(() {
      _animationPlaying = false;
    });
  }

  void _restartAnimation() {
    _animationTimer?.cancel();
    setState(() {
      _animationProgress = _animationReverse ? 1.0 : 0.0;
      _hoverPoint = null;
      _pinnedPoints.clear();
      _applyAnimationFrame(_animationProgress);
      _chartVersion++;
    });
    _playAnimation();
  }

  AnimationConfig _buildAnimationConfig() {
    AnimatableParameter param({
      required String id,
      required String label,
      required String symbol,
      required String unit,
      required double value,
      required _AnimRange absolute,
      String? physicsNote,
    }) {
      final range = _animationRanges[id] ?? absolute;
      return AnimatableParameter(
        id: id,
        label: label,
        symbol: symbol,
        unit: unit,
        currentValue: value,
        rangeMin: range.min,
        rangeMax: range.max,
        absoluteMin: absolute.min,
        absoluteMax: absolute.max,
        enabled: _animationEnabled[id] ?? false,
        onEnabledChanged: (enabled) {
          setState(() {
            _animationEnabled[id] = enabled;
            if (!enabled &&
                !_animationEnabled.values.any((v) => v) &&
                _animationPlaying) {
              _pauseAnimation();
            }
          });
        },
        onValueChanged: (v) {
          setState(() {
            _setAnimatedParamValue(id, v);
            _hoverPoint = null;
            _pinnedPoints.clear();
            _chartVersion++;
          });
        },
        onRangeChanged: (min, max) => _setAnimationRange(id, min, max),
        physicsNote: physicsNote,
      );
    }

    return AnimationConfig(
      parameters: [
        param(
          id: 'temperature',
          label: r'T (temperature)',
          symbol: r'T',
          unit: r'\mathrm{K}',
          value: _temperature,
          absolute: const _AnimRange(100, 800),
          physicsNote: r'Sets thermal energy scale $kT$.',
        ),
        param(
          id: 'bandgap',
          label: r'E_g (bandgap)',
          symbol: r'E_g',
          unit: r'\mathrm{eV}',
          value: _bandgap,
          absolute: const _AnimRange(0.5, 1.6),
          physicsNote: r'Controls separation between $E_c$ and $E_v$.',
        ),
        param(
          id: 'mn',
          label: r'm_n^{*} (electron mass)',
          symbol: r'm_n^{*}',
          unit: r'm_0',
          value: _mnStar,
          absolute: const _AnimRange(0.1, 2.0),
          physicsNote: r'Affects $N_c$ and therefore $n(E_F)$.',
        ),
        param(
          id: 'mp',
          label: r'm_p^{*} (hole mass)',
          symbol: r'm_p^{*}',
          unit: r'm_0',
          value: _mpStar,
          absolute: const _AnimRange(0.1, 2.0),
          physicsNote: r'Affects $N_v$ and therefore $p(E_F)$.',
        ),
        param(
          id: 'ef',
          label: r'E_F (Fermi level)',
          symbol: r'E_F',
          unit: r'\mathrm{eV}',
          value: _fermiLevel,
          absolute: _AnimRange(_efMin, _efMax()),
          physicsNote:
              r'Sweeps occupancy between valence and conduction sides.',
        ),
      ],
      selectedParameterId: _selectedAnimationParam,
      onParameterSelected: (id) {
        setState(() => _selectedAnimationParam = id);
      },
      state: AnimationState(
        isPlaying: _animationPlaying,
        speed: _animationSpeed,
        reverse: _animationReverse,
        loop: _animationLoop,
        progress: _animationProgress,
      ),
      callbacks: AnimationCallbacks(
        onPlay: _playAnimation,
        onPause: _pauseAnimation,
        onRestart: _restartAnimation,
        onSpeedChanged: (speed) => setState(() => _animationSpeed = speed),
        onReverseChanged: (reverse) =>
            setState(() => _animationReverse = reverse),
        onLoopChanged: (loop) => setState(() => _animationLoop = loop),
      ),
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

        final currentN =
            _calcN(_fermiLevel, curves.Nc, constants.q, constants.kB) *
                _densityDisplayFactor;
        final currentP =
            _calcP(_fermiLevel, curves.Nv, constants.q, constants.kB) *
                _densityDisplayFactor;
        final currentNi = curves.ni * _densityDisplayFactor;
        final panelConfig = _buildPanelConfig(context, curves);

        return StandardGraphPageScaffold(
          config: panelConfig.copyWith(
            title: 'Carrier Concentration vs Fermi Level',
            subtitle: 'Carrier Concentration',
            mainEquation:
                r'n = N_c e^{-\frac{E_c - E_F}{kT}},\quad p = N_v e^{-\frac{E_F - E_v}{kT}}',
          ),
          aboutSection: _buildAboutCard(context),
          observeSection: _buildInfoPanel(context),
          placeSectionsInWideLeftColumn: true,
          useTwoColumnRightPanelInWide: true,
          wideLeftColumnSectionIds: const ['point_inspector', 'animation'],
          wideRightColumnSectionIds: const ['notes', 'controls'],
          chartBuilder: (context) => _buildChartContent(
              context, curves, currentN, currentP, currentNi),
        );
      },
    );
  }

  GraphConfig _buildPanelConfig(BuildContext context, _CarrierCurves curves) {
    final dynamicObs = _buildDynamicObservations();
    return GraphConfig(
      pointInspector: _buildPointInspectorConfig(),
      animation: _buildAnimationConfig(),
      insights: InsightsConfig(
        dynamicObservations: dynamicObs.isEmpty ? null : dynamicObs,
        staticObservations: const [
          r'n increases as $E_F$ approaches $E_c$.',
          r'p increases as $E_F$ approaches $E_v$.',
          r'$n_i$ marks intrinsic condition where $n$ and $p$ are comparable.',
        ],
        dynamicTitle: _pinnedPoints.isNotEmpty
            ? 'From Your Pins'
            : (_hoverPoint == null ? 'Current Configuration' : 'Current Hover'),
        pinnedCount: _pinnedPoints.length,
        maxPins: _maxPins,
        onClearPins: _pinnedPoints.isEmpty
            ? null
            : () => _update(() {
                  _pinnedPoints.clear();
                  _hoverPoint = null;
                }),
      ),
      controls: ControlsConfig(
        children: [_buildControls(context)],
        collapsible: true,
        initiallyExpanded: true,
      ),
    );
  }

  PointInspectorConfig _buildPointInspectorConfig() {
    final pinned = _pinnedPoints.isNotEmpty ? _pinnedPoints.last : null;
    final hover = _hoverPoint;
    return PointInspectorConfig(
      enabled: true,
      emptyMessage:
          'Hover the chart to inspect n(E_F), p(E_F); tap curve to pin.',
      isPinned: pinned != null,
      interactionHint:
          'Tap curve to pin/unpin (max $_maxPins); tap empty area to clear.',
      onClear: () => _update(() {
        _hoverPoint = null;
        _pinnedPoints.clear();
      }),
      builder: (pinned == null && hover == null)
          ? null
          : () {
              final lines = <String>[];
              if (pinned != null) {
                final conc = math.pow(10, pinned.spot.y).toDouble();
                lines.add('Pinned: ${_seriesTitle(pinned.series)}');
                lines.add(
                    'E_{F} = ${pinned.spot.x.toStringAsFixed(3)}\\,\\mathrm{eV}');
                lines.add(
                    '${_seriesLatex(pinned.series)} = ${LatexNumberFormatter.valueWithUnit(conc, unitLatex: _densityUnitLatex, sigFigs: 3)}');
                lines.add(
                    '\\log_{10}(${_seriesLatex(pinned.series)}) = ${pinned.spot.y.toStringAsFixed(2)}');
              }
              if (hover != null) {
                final conc = math.pow(10, hover.spot.y).toDouble();
                lines.add('Hover: ${_seriesTitle(hover.series)}');
                lines.add(
                    'E_{F} = ${hover.spot.x.toStringAsFixed(3)}\\,\\mathrm{eV}');
                lines.add(
                    '${_seriesLatex(hover.series)} = ${LatexNumberFormatter.valueWithUnit(conc, unitLatex: _densityUnitLatex, sigFigs: 3)}');
                lines.add(
                    '\\log_{10}(${_seriesLatex(hover.series)}) = ${hover.spot.y.toStringAsFixed(2)}');
              }
              return lines;
            },
    );
  }

  List<String> _buildDynamicObservations() {
    final obs = <String>[];
    for (var i = 0; i < _pinnedPoints.length; i++) {
      final pin = _pinnedPoints[i];
      final conc = math.pow(10, pin.spot.y).toDouble();
      final efLatex = r'E_{F}';
      final pointLatex = _seriesLatex(pin.series);
      final concLatex = LatexNumberFormatter.valueWithUnit(
        conc,
        unitLatex: _densityUnitLatex,
        sigFigs: 3,
      );
      obs.add(
        'Pin ${i + 1}: ${_inlineMath(pointLatex)} at '
        '${_inlineMath('$efLatex = ${pin.spot.x.toStringAsFixed(3)}\\,\\mathrm{eV}')}, '
        '${_inlineMath(concLatex)}.',
      );
    }
    if (_pinnedPoints.length >= 2) {
      final a = _pinnedPoints[_pinnedPoints.length - 2];
      final b = _pinnedPoints.last;
      final deltaEf = (b.spot.x - a.spot.x).abs();
      final deltaDecades = (b.spot.y - a.spot.y).abs();
      obs.add(
        'Between latest pins: '
        '${_inlineMath(r'\Delta E_{F} = ' + deltaEf.toStringAsFixed(3) + r'\,\mathrm{eV}')}, '
        '${_inlineMath(r'\Delta\log_{10}(n,p) = ' + deltaDecades.toStringAsFixed(2))} decades.',
      );
    }
    return obs;
  }

  // ignore: unused_element
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
              'Shows how electron and hole concentrations change with Fermi-level position at fixed temperature and band parameters.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
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
          _InfoBullet(r'$n$ rises as $E_F$ moves toward $E_c$.'),
          _InfoBullet(r'$p$ rises as $E_F$ moves toward $E_v$.'),
          _InfoBullet(r'At intrinsic conditions, $n \approx p \approx n_i$.'),
        ],
      ),
    );
  }

  Widget _buildChartContent(
    BuildContext context,
    _CarrierCurves curves,
    double n,
    double p,
    double ni,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResultsStrip(n, p, ni),
        const SizedBox(height: 12),
        Expanded(child: _buildChart(context, curves)),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildRightPanel(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildObservations(context),
          const SizedBox(height: 12),
          _buildControls(context),
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
    final unitUnicode = _useCmUnits ? 'cm\u207b\u00b3' : 'm\u207b\u00b3';
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
            labelResolver: (_) => 'ni',
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
            labelResolver: (_) => 'Ev',
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
            labelResolver: (_) => 'Ec',
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

    final int? nBarIndex = _seriesMode != SeriesMode.pOnly ? 0 : null;
    final int? pBarIndex = switch (_seriesMode) {
      SeriesMode.nOnly => null,
      SeriesMode.pOnly => 0,
      SeriesMode.both => 1,
    };
    final baseBars =
        _buildSeries(curves, legendColorN, legendColorP, intrinsicMarker);
    final hoverPoint = _hoverPoint;
    final bars = <LineChartBarData>[
      ...baseBars,
      ..._pinnedPoints.asMap().entries.map(
            (entry) => LineChartBarData(
              spots: [entry.value.spot],
              isCurved: false,
              color: Colors.transparent,
              barWidth: 0,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (_, __) => true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  color: _pinColorForIndex(entry.key),
                  radius: 4.9,
                  strokeColor: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
      if (hoverPoint != null &&
          !_pinnedPoints.any((pin) => _samePointRef(pin, hoverPoint)))
        LineChartBarData(
          spots: [hoverPoint.spot],
          isCurved: false,
          color: Colors.transparent,
          barWidth: 0,
          dotData: FlDotData(
            show: true,
            checkToShowDot: (_, __) => true,
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
              color: _hoverColorForSeries(hoverPoint.series)
                  .withValues(alpha: 0.22),
              radius: 5.8,
              strokeColor: _hoverColorForSeries(hoverPoint.series),
              strokeWidth: 2.4,
            ),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_seriesMode != SeriesMode.pOnly)
              _legend(legendColorN, r'n(E_{F})'),
            if (_seriesMode != SeriesMode.nOnly)
              _legend(legendColorP, r'p(E_{F})'),
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
                enabled: true,
                touchSpotThreshold: 28,
                handleBuiltInTouches: true,
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes
                      .map(
                        (_) => const TouchedSpotIndicatorData(
                          FlLine(color: Colors.transparent, strokeWidth: 0),
                          FlDotData(show: false),
                        ),
                      )
                      .toList();
                },
                touchCallback: (event, response) {
                  final spots = response?.lineBarSpots;
                  if (spots == null || spots.isEmpty) {
                    if (event is FlTapUpEvent) {
                      if (_hoverPoint != null || _pinnedPoints.isNotEmpty) {
                        setState(() {
                          _hoverPoint = null;
                          _pinnedPoints.clear();
                        });
                      }
                      return;
                    }
                    if (event is FlPointerExitEvent && _hoverPoint != null) {
                      setState(() => _hoverPoint = null);
                    }
                    return;
                  }

                  final candidates = spots
                      .where(
                        (s) =>
                            s.barIndex == nBarIndex || s.barIndex == pBarIndex,
                      )
                      .toList();
                  if (candidates.isEmpty) return;

                  final chosen = candidates.first;
                  final series = chosen.barIndex == nBarIndex ? 'n' : 'p';
                  final nextHover = _CarrierPointRef(
                    series: series,
                    spot: FlSpot(chosen.x, chosen.y),
                  );

                  if (event is FlTapUpEvent) {
                    setState(() {
                      _hoverPoint = nextHover;
                      _togglePinnedPoint(nextHover);
                    });
                    return;
                  }

                  if (_hoverPoint != null &&
                      _samePointRef(_hoverPoint!, nextHover)) {
                    return;
                  }
                  setState(() => _hoverPoint = nextHover);
                },
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => Colors.white.withValues(alpha: 0.98),
                  tooltipBorder: BorderSide(
                    color: Colors.black.withValues(alpha: 0.16),
                    width: 1,
                  ),
                  getTooltipItems: (touched) {
                    final candidates = touched
                        .where(
                          (spot) =>
                              spot.barIndex == nBarIndex ||
                              spot.barIndex == pBarIndex,
                        )
                        .toList();
                    if (candidates.isEmpty) return [];
                    final efValue = candidates.first.x;
                    final items = <LineTooltipItem>[];
                    for (int i = 0; i < candidates.length; i++) {
                      final spot = candidates[i];
                      final yVal = spot.y;
                      final conc = math.pow(10, yVal).toDouble();
                      final label =
                          spot.barIndex == nBarIndex ? r'n(E_F)' : r'p(E_F)';

                      if (i == 0) {
                        items.add(LineTooltipItem(
                          '',
                          const TextStyle(),
                          children: [
                            TextSpan(
                                text: 'E_F: ${efValue.toStringAsFixed(3)} eV\n',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                )),
                            TextSpan(
                              text:
                                  '$label: ${LatexNumberFormatter.toUnicodeSci(conc, sigFigs: 3)} $unitUnicode\n',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                            TextSpan(
                              text:
                                  'log10($label) = ${yVal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ));
                      } else {
                        items.add(LineTooltipItem(
                          '',
                          const TextStyle(),
                          children: [
                            TextSpan(
                              text:
                                  '$label: ${LatexNumberFormatter.toUnicodeSci(conc, sigFigs: 3)} $unitUnicode\n',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                            TextSpan(
                              text:
                                  'log10($label) = ${yVal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[700],
                              ),
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
                      value: SeriesMode.nOnly, label: const Text('n only')),
                  ButtonSegment(
                      value: SeriesMode.pOnly, label: const Text('p only')),
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
                title: const Text('Auto-scale Y'),
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
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                _InfoBullet(r'$n$ increases as $E_F$ approaches $E_c$.'),
                _InfoBullet(r'$p$ increases as $E_F$ approaches $E_v$.'),
                _InfoBullet(
                    r'$n_i$ marks the intrinsic point where $n \approx p$.'),
              ],
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

class _CarrierPointRef {
  final String series; // 'n' or 'p'
  final FlSpot spot;

  const _CarrierPointRef({
    required this.series,
    required this.spot,
  });
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

class _AnimRange {
  final double min;
  final double max;
  const _AnimRange(this.min, this.max);
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
          const Text('- '),
          Expanded(
            child: _buildLatexAwareText(text),
          ),
        ],
      ),
    );
  }

  Widget _buildLatexAwareText(String line) {
    if (line.contains(r'$')) {
      return _InlineLatexText(line);
    }
    return _looksLikeStandaloneLatex(line)
        ? LatexText(line, scale: 0.95)
        : Text(line);
  }

  bool _looksLikeStandaloneLatex(String line) {
    return line.contains(r'\') ||
        (!line.contains(' ') && (line.contains('^') || line.contains('_')));
  }
}

class _InlineLatexText extends StatelessWidget {
  final String text;
  const _InlineLatexText(this.text);

  @override
  Widget build(BuildContext context) {
    final parts = <_InlinePart>[];
    final buffer = StringBuffer();
    var inLatex = false;

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == r'$') {
        if (buffer.isNotEmpty) {
          parts.add(_InlinePart(buffer.toString(), inLatex));
          buffer.clear();
        }
        inLatex = !inLatex;
      } else {
        buffer.write(ch);
      }
    }
    if (buffer.isNotEmpty) {
      parts.add(_InlinePart(buffer.toString(), inLatex));
    }

    if (parts.length == 1 && !parts.first.isLatex) {
      return Text(parts.first.text);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts
          .map((p) => p.isLatex ? LatexText(p.text, scale: 0.95) : Text(p.text))
          .toList(growable: false),
    );
  }
}

class _InlinePart {
  final String text;
  final bool isLatex;
  const _InlinePart(this.text, this.isLatex);
}
