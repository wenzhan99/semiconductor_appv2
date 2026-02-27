import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/constants_loader.dart';
import '../../core/constants/constants_repository.dart';
import '../../core/constants/latex_symbols.dart';
import '../graphs/utils/semiconductor_models.dart';
import '../widgets/latex_text.dart';

// New architecture imports
import '../graphs/common/standard_graph_page_scaffold.dart';
import '../graphs/core/graph_config.dart';
import '../graphs/core/animation_engine.dart';

// Standardized components
import '../graphs/common/graph_controller.dart';
import '../graphs/common/parameters_card.dart';
import '../graphs/utils/latex_number_formatter.dart';
import '../graphs/utils/pn_latex.dart';
import '../graphs/common/enhanced_animation_panel.dart';

// Typography standards
typedef _Typo = GraphPanelTextStyles;

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
  String _selectedPlot = 'rho(x)';
  static const List<String> _plotOptions = ['rho(x)', 'E(x)', 'V(x)', 'All'];

  // Interactive
  FlSpot? _selectedPoint;
  String? _selectedPointPlot;
  int? _selectedPointIndex;
  Offset? _selectedPointLocalPosition;
  FlSpot? _hoverPoint;
  String? _hoverPointPlot;
  int? _hoverPointIndex;
  Offset? _hoverPointLocalPosition;
  double _lastComputedVbi = 0.8;
  bool _pendingVaClamp = false;

  static const double _hoverThresholdPx = 14.0;
  static const double _biasSafetyMargin = 1e-4;

  // Animation state
  late AnimationEngine _animationEngine;
  bool _vaAnimEnabled = false;
  bool _naAnimEnabled = false;
  bool _ndAnimEnabled = false;
  String _selectedAnimParamId = 'va';
  double _vaAnimMin = -5.0;
  double _vaAnimMax = 1.0;
  double _naAnimMin = 1e14;
  double _naAnimMax = 1e20;
  double _ndAnimMin = 1e14;
  double _ndAnimMax = 1e20;

  static const double _bandgap = 1.12; // eV for Si
  static const double _mnStar = 1.08;
  static const double _mpStar = 0.56;
  static const int _samples = 240;

  late Future<_Constants> _constants;

  @override
  void initState() {
    super.initState();
    _constants = _loadConstants();
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
      _selectedPlot = 'rho(x)';
      _selectedPoint = null;
      _selectedPointPlot = null;
      _selectedPointIndex = null;
      _selectedPointLocalPosition = null;
      _hoverPoint = null;
      _hoverPointPlot = null;
      _hoverPointIndex = null;
      _hoverPointLocalPosition = null;
      _selectedAnimParamId = 'va';
      _animationEngine.pause();
    });
  }

  List<AnimatableParameter> _getAnimatableParameters() {
    final dopingUnit = _useCmUnits ? PnLatex.unitCmNeg3 : PnLatex.unitMNeg3;
    // Ensure ranges are valid and non-degenerate before building parameter specs
    final vaRange = _normalizeVaRange(_vaAnimMin, _vaAnimMax);
    _vaAnimMin = vaRange.$1;
    _vaAnimMax = vaRange.$2;

    final naRange = _normalizeDopingRange(_naDisplay, _naAnimMin, _naAnimMax);
    _naAnimMin = naRange.$1;
    _naAnimMax = naRange.$2;

    final ndRange = _normalizeDopingRange(_ndDisplay, _ndAnimMin, _ndAnimMax);
    _ndAnimMin = ndRange.$1;
    _ndAnimMax = ndRange.$2;

    return [
      AnimatableParameter(
        id: 'va',
        label: r'V_a (applied bias)',
        symbol: r'V_a',
        unit: PnLatex.unitV,
        currentValue: _va,
        rangeMin: _vaAnimMin,
        rangeMax: _vaAnimMax,
        absoluteMin: -10.0,
        absoluteMax: 2.0,
        enabled: _vaAnimEnabled,
        onEnabledChanged: (enabled) => setState(() => _vaAnimEnabled = enabled),
        onValueChanged: (value) {
          final clamped = _clampVaToSafeBarrier(value, _lastComputedVbi);
          setState(() => _va = clamped);
        },
        onRangeChanged: (min, max) => setState(() {
          final clamped = _normalizeVaRange(min, max);
          _vaAnimMin = clamped.$1;
          _vaAnimMax = clamped.$2;
          _va = _clampVaToSafeBarrier(_va, _lastComputedVbi);
        }),
        physicsNote:
            'Forward bias (Va > 0) shrinks depletion width; reverse bias (Va < 0) widens it.',
      ),
      AnimatableParameter(
        id: 'na',
        label: r'N_A (acceptor concentration)',
        symbol: r'N_A',
        unit: dopingUnit,
        currentValue: _naDisplay,
        rangeMin: _naAnimMin,
        rangeMax: _naAnimMax,
        absoluteMin: 1e12,
        absoluteMax: 1e22,
        enabled: _naAnimEnabled,
        onEnabledChanged: (enabled) => setState(() => _naAnimEnabled = enabled),
        onValueChanged: (value) => setState(() => _naDisplay = value),
        onRangeChanged: (min, max) => setState(() {
          final normalized = _normalizeDopingRange(_naDisplay, min, max);
          _naAnimMin = normalized.$1;
          _naAnimMax = normalized.$2;
        }),
        physicsNote: 'Higher NA narrows depletion on p-side, shifts junction.',
      ),
      AnimatableParameter(
        id: 'nd',
        label: r'N_D (donor concentration)',
        symbol: r'N_D',
        unit: dopingUnit,
        currentValue: _ndDisplay,
        rangeMin: _ndAnimMin,
        rangeMax: _ndAnimMax,
        absoluteMin: 1e12,
        absoluteMax: 1e22,
        enabled: _ndAnimEnabled,
        onEnabledChanged: (enabled) => setState(() => _ndAnimEnabled = enabled),
        onValueChanged: (value) => setState(() => _ndDisplay = value),
        onRangeChanged: (min, max) => setState(() {
          final normalized = _normalizeDopingRange(_ndDisplay, min, max);
          _ndAnimMin = normalized.$1;
          _ndAnimMax = normalized.$2;
        }),
        physicsNote: 'Higher ND narrows depletion on n-side, shifts junction.',
      ),
    ];
  }

  /// Option 3 around-current sweep with clamping to safe bounds.
  (double, double) _normalizeDopingRange(
      double n0Display, double minIn, double maxIn) {
    final boundsMin = _useCmUnits ? 1e14 : 1e20;
    final boundsMax = _useCmUnits ? 1e19 : 1e25;

    double min = minIn;
    double max = maxIn;

    // If degenerate or uninitialized, derive from current value.
    if (min <= 0 ||
        max <= 0 ||
        min >= max ||
        (min == boundsMin && max >= boundsMax * 0.99)) {
      min = n0Display / 10;
      max = n0Display * 10;
    }

    // Clamp to absolute bounds
    min = min.clamp(boundsMin, boundsMax);
    max = max.clamp(boundsMin, boundsMax);

    if (min >= max) {
      // force a small spread inside bounds
      min = boundsMin;
      max = math.min(boundsMax, min * 10);
      if (min >= max) {
        max = min * 1.1;
      }
    }

    return (min, max);
  }

  (double, double) _normalizeVaRange(double minIn, double maxIn) {
    const defaultMin = -1.0;
    const defaultMax = 0.8;
    double min = minIn;
    double max = maxIn;

    // Replace legacy defaults with the desired teaching range.
    if ((min == -5.0 && max == 1.0) || (min >= max) || (min == 0 && max == 0)) {
      min = defaultMin;
      max = defaultMax;
    }

    // clamp to absolute safety bounds from AnimatableParameter
    min = min.clamp(-10.0, 2.0);
    max = max.clamp(-10.0, 2.0);

    // Keep animation range in physically valid depletion regime when Vbi is known.
    final safeMax = _safeVaUpperBound(_lastComputedVbi);
    if (safeMax > min) {
      max = math.min(max, safeMax);
    }

    if (min >= max) {
      min = defaultMin;
      max = math.min(defaultMax, _safeVaUpperBound(_lastComputedVbi));
      if (min >= max) {
        max = min + 0.1;
      }
    }

    return (min, max);
  }

  double _safeVaUpperBound(double vbi) {
    final capped = (vbi - _biasSafetyMargin).clamp(-10.0, 2.0);
    return capped.toDouble();
  }

  double _clampVaToSafeBarrier(double va, double vbi) {
    final upper = _safeVaUpperBound(vbi);
    if (upper <= -10.0) return -10.0;
    return va.clamp(-10.0, upper).toDouble();
  }

  void _scheduleVaClamp(double clampedVa) {
    if (_pendingVaClamp) return;
    _pendingVaClamp = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingVaClamp = false;
      if (!mounted) return;
      if ((_va - clampedVa).abs() < 1e-9) return;
      setState(() {
        _va = double.parse(clampedVa.toStringAsFixed(3));
      });
      if (_animationEngine.isPlaying) {
        _animationEngine.pause();
      }
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

    final vbi =
        (c.kB * _temperature / c.q) * math.log((naSi * ndSi) / (ni * ni));
    _lastComputedVbi = vbi;

    final rawBiasTerm = vbi - _va;
    final invalid = rawBiasTerm <= 0;
    final safeVa = _clampVaToSafeBarrier(_va, vbi);
    if ((safeVa - _va).abs() > 1e-9) {
      _scheduleVaClamp(safeVa);
    }

    final biasTerm = vbi - safeVa;
    final effectiveBias = biasTerm <= 0 ? _biasSafetyMargin : biasTerm;

    final epsS = _epsR * c.eps0;
    final W =
        math.sqrt((2 * epsS / c.q) * (1 / naSi + 1 / ndSi) * effectiveBias);
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

        final config = _buildGraphConfig(curves);

        return StandardGraphPageScaffold(
          config: config,
          chartBuilder: (context) => _buildChartArea(context, curves),
          aboutSection: _buildAboutCard(context),
          observeSection: _buildObserveCard(context),
          placeSectionsInWideLeftColumn: true,
          useTwoColumnRightPanelInWide: true,
          wideLeftColumnSectionIds: const ['point_inspector', 'animation'],
          wideRightColumnSectionIds: const ['notes', 'controls'],
        );
      },
    );
  }

  GraphConfig _buildGraphConfig(_PnCurves curves) {
    return GraphConfig(
      title: 'PN Junction Depletion Profiles',
      subtitle: 'PN Junction',
      mainEquation:
          r'W = \sqrt{\frac{2 \varepsilon_s}{q}\left(\frac{1}{N_A} + \frac{1}{N_D}\right)(V_{bi}-V_a)}',
      pointInspector: PointInspectorConfig(
        enabled: true,
        builder:
            _activeInspectorPoint != null ? _buildPointInspectorLines : null,
        interactionHint: 'Tap curve to pin; tap empty area to clear.',
        onClear: () => updateChart(() {
          _selectedPoint = null;
          _selectedPointPlot = null;
          _selectedPointIndex = null;
          _selectedPointLocalPosition = null;
          _hoverPoint = null;
          _hoverPointPlot = null;
          _hoverPointIndex = null;
          _hoverPointLocalPosition = null;
        }),
        isPinned: _selectedPoint != null,
      ),
      animation: AnimationConfig(
        parameters: _getAnimatableParameters(),
        selectedParameterId: _selectedAnimParamId,
        onParameterSelected: (id) => setState(() {
          _selectedAnimParamId = id;
          if (id == 'va') {
            _vaAnimEnabled = true;
          } else if (id == 'na') {
            _naAnimEnabled = true;
          } else if (id == 'nd') {
            _ndAnimEnabled = true;
          }
        }),
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
        dynamicObservations: _buildDynamicObservations(curves),
        staticObservations: _buildStaticObservations(),
        dynamicTitle: 'Current Configuration',
        pinnedCount: _selectedPoint != null ? 1 : 0,
        onClearPins: _selectedPoint == null
            ? null
            : () => updateChart(() {
                  _selectedPoint = null;
                  _selectedPointPlot = null;
                  _selectedPointIndex = null;
                  _selectedPointLocalPosition = null;
                }),
      ),
      controls: ControlsConfig(
        children: _buildControlsChildren(curves),
        collapsible: true,
        initiallyExpanded: true,
      ),
    );
  }

  FlSpot? get _activeInspectorPoint => _selectedPoint ?? _hoverPoint;

  String get _activeInspectorPlotId {
    if (_selectedPoint != null) {
      return _selectedPointPlot ?? _selectedPlot;
    }
    return _hoverPointPlot ?? _selectedPlot;
  }

  int? _activeSpotIndexForPlot(String plotId) {
    if (_selectedPoint != null && _selectedPointPlot == plotId) {
      return _selectedPointIndex;
    }
    if (_hoverPoint != null && _hoverPointPlot == plotId) {
      return _hoverPointIndex;
    }
    return null;
  }

  Offset? _activeLocalPositionForPlot(String plotId) {
    if (_selectedPoint != null && _selectedPointPlot == plotId) {
      return _selectedPointLocalPosition;
    }
    if (_hoverPoint != null && _hoverPointPlot == plotId) {
      return _hoverPointLocalPosition;
    }
    return null;
  }

  List<String> _buildPointInspectorLines() {
    final point = _activeInspectorPoint;
    if (point == null) return [];

    final x = point.x; // in micrometers
    final y = point.y;
    final plotId = _activeInspectorPlotId;
    final xLine = r'x = ' + x.toStringAsFixed(3) + r'\,' + PnLatex.unitUm;

    String yLine;
    if (plotId == 'rho(x)') {
      final val = LatexNumberFormatter.valueWithUnit(y,
          unitLatex: PnLatex.unitCPerM3, sigFigs: 3);
      yLine = '${PnLatex.rhoPlot} = $val';
    } else if (plotId == 'E(x)') {
      final val = LatexNumberFormatter.valueWithUnit(y,
          unitLatex: PnLatex.unitVPerM, sigFigs: 3);
      yLine = '${PnLatex.ePlot} = $val';
    } else {
      yLine =
          '${PnLatex.vPlot} = ${LatexNumberFormatter.valueWithUnit(y, unitLatex: PnLatex.unitV, sigFigs: 3)}';
    }

    return [
      r'Plot:\ ' + PnLatex.depletionPlotTex(plotId),
      xLine,
      yLine,
    ];
  }

  List<String> _buildHoverTooltipLines(String plotId, FlSpot point) {
    final xLine = r'x = ' + point.x.toStringAsFixed(3) + r'\,' + PnLatex.unitUm;

    if (plotId == 'rho(x)') {
      return [
        xLine,
        '${PnLatex.rhoPlot} = ${LatexNumberFormatter.valueWithUnit(point.y, unitLatex: PnLatex.unitCPerM3, sigFigs: 3)}',
      ];
    }
    if (plotId == 'E(x)') {
      return [
        xLine,
        '${PnLatex.ePlot} = ${LatexNumberFormatter.valueWithUnit(point.y, unitLatex: PnLatex.unitVPerM, sigFigs: 3)}',
      ];
    }
    return [
      xLine,
      '${PnLatex.vPlot} = ${LatexNumberFormatter.valueWithUnit(point.y, unitLatex: PnLatex.unitV, sigFigs: 3)}',
    ];
  }

  Widget _buildHoverTooltip(
    BuildContext context, {
    required String plotId,
    required double maxWidth,
  }) {
    final point = (_selectedPoint != null && _selectedPointPlot == plotId)
        ? _selectedPoint
        : (_hoverPoint != null && _hoverPointPlot == plotId
            ? _hoverPoint
            : null);
    final local = _activeLocalPositionForPlot(plotId);
    if (point == null || local == null) {
      return const SizedBox.shrink();
    }

    const estimatedHeight = 78.0;
    const tooltipWidth = 210.0;
    final width = math.min(tooltipWidth, maxWidth - 8);
    final left = (local.dx + 12)
        .clamp(4.0, math.max(4.0, maxWidth - width - 4))
        .toDouble();
    final top = (local.dy - estimatedHeight - 12).clamp(4.0, 160.0).toDouble();
    final lines = _buildHoverTooltipLines(plotId, point);

    return Positioned(
      left: left,
      top: top,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surface,
        child: Container(
          width: width,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: lines
                .map((line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: LatexText(
                        line,
                        style: TextStyle(fontSize: _Typo.hint),
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
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
          r'Highly asymmetric doping: $N_A \gg N_D$ -> depletion extends mostly into n-side ($x_n \gg x_p$).');
    } else if (ratio < 0.1) {
      obs.add(
          r'Highly asymmetric doping: $N_D \gg N_A$ -> depletion extends mostly into p-side ($x_p \gg x_n$).');
    } else {
      obs.add(r'Moderate doping asymmetry: depletion regions fairly balanced.');
    }

    return obs;
  }

  List<String> _buildStaticObservations() {
    return [
      r'Depletion width $W \propto \sqrt{V_{bi} - V_a}$; sensitive to bias.',
      r'Peak field $E_{max} = -q N_A x_p / \varepsilon_s = q N_D x_n / \varepsilon_s$ at junction.',
      r'Charge neutrality: $N_A x_p = N_D x_n$ (equal charge on both sides).',
      r'Higher doping -> narrower depletion on that side (one-sided junction approximation).',
    ];
  }

  String _formatWithUnit(double value, String unitTex, {int sigFigs = 3}) {
    return '${formatSciLatex(value, sigFigs: sigFigs)}\\,$unitTex';
  }

  // ignore: unused_element
  List<ReadoutItem> _buildReadouts(_PnCurves curves) {
    const lengthUnit = PnLatex.unitUm;
    const voltageUnit = PnLatex.unitV;
    const eFieldUnit = PnLatex.unitVPerM;

    return [
      ReadoutItem(
        label: r'W (depletion width)',
        value: _formatWithUnit(curves.wUm, lengthUnit, sigFigs: 3),
        boldValue: true,
      ),
      ReadoutItem(
        label: r'x_{p} (p-side)',
        value: _formatWithUnit(curves.xpUm, lengthUnit, sigFigs: 3),
      ),
      ReadoutItem(
        label: r'x_{n} (n-side)',
        value: _formatWithUnit(curves.xnUm, lengthUnit, sigFigs: 3),
      ),
      ReadoutItem(
        label: r'E_{max} (peak field)',
        value: _formatWithUnit(curves.eMax.abs(), eFieldUnit, sigFigs: 3),
      ),
      ReadoutItem(
        label: r'V_{bi} (built-in)',
        value: _formatWithUnit(curves.vbi, voltageUnit, sigFigs: 3),
      ),
    ];
  }

  List<Widget> _buildControlsChildren(_PnCurves curves) {
    final dopingUnitTex = _useCmUnits ? PnLatex.unitCmNeg3 : PnLatex.unitMNeg3;
    final safeVaMax = _safeVaUpperBound(curves.vbi);

    return [
      Text(
        'Parameters',
        style: TextStyle(
          fontSize: _Typo.title,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      ParameterSlider(
        label: PnLatex.withUnit(r'T', PnLatex.unitK),
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
        label: PnLatex.withUnit(r'N_A', dopingUnitTex),
        value: _naDisplay,
        min: 1e14,
        max: 1e20,
        divisions: null,
        valueFormatter: (v) => formatSciPlain(v, sigFigs: 3),
        valueLatexFormatter: (v) => formatSciLatex(v, sigFigs: 3),
        showRangeLabels: true,
        rangeLatexFormatter: (v) => formatSciLatex(v, sigFigs: 3),
        onChanged: (v) {
          setState(() => _naDisplay = v);
          bumpChart();
        },
        subtitle: 'Acceptor concentration',
      ),
      ParameterSlider(
        label: PnLatex.withUnit(r'N_D', dopingUnitTex),
        value: _ndDisplay,
        min: 1e14,
        max: 1e20,
        divisions: null,
        valueFormatter: (v) => formatSciPlain(v, sigFigs: 3),
        valueLatexFormatter: (v) => formatSciLatex(v, sigFigs: 3),
        showRangeLabels: true,
        rangeLatexFormatter: (v) => formatSciLatex(v, sigFigs: 3),
        onChanged: (v) {
          setState(() => _ndDisplay = v);
          bumpChart();
        },
        subtitle: 'Donor concentration',
      ),
      ParameterSlider(
        label: PnLatex.withUnit(r'V_a', PnLatex.unitV),
        value: _va,
        min: -5.0,
        max: safeVaMax > -5.0 ? safeVaMax : -4.9,
        divisions: 600,
        onChanged: (v) {
          final clamped = _clampVaToSafeBarrier(v, curves.vbi);
          setState(() => _va = double.parse(clamped.toStringAsFixed(3)));
          bumpChart();
        },
        subtitle: 'Applied bias',
      ),
      ParameterSlider(
        label: r'\varepsilon_r',
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
        label: r'N',
        plainSuffix: '(doping units)',
        selected: {_useCmUnits},
        segments: [
          ButtonSegment(
              value: true,
              label: LatexText(PnLatex.unitCmNeg3,
                  style: TextStyle(fontSize: _Typo.body))),
          ButtonSegment(
              value: false,
              label: LatexText(PnLatex.unitMNeg3,
                  style: TextStyle(fontSize: _Typo.body))),
        ],
        onSelectionChanged: (s) {
          final naSi = _dopingToSi(_naDisplay);
          final ndSi = _dopingToSi(_ndDisplay);
          updateChart(() {
            _useCmUnits = s.first;
            _naDisplay = _dopingToDisplay(naSi);
            _ndDisplay = _dopingToDisplay(ndSi);
            final naRange = _normalizeDopingRange(_naDisplay, 0, 0);
            _naAnimMin = naRange.$1;
            _naAnimMax = naRange.$2;
            final ndRange = _normalizeDopingRange(_ndDisplay, 0, 0);
            _ndAnimMin = ndRange.$1;
            _ndAnimMax = ndRange.$2;
          });
        },
      ),
      ParameterSwitch(
        label: r'x_{p},\,x_{n}',
        plainSuffix: '(markers)',
        subtitle: 'Show junction marker',
        value: _showMarkers,
        onChanged: (v) {
          setState(() => _showMarkers = v);
          bumpChart();
        },
      ),
      ParameterSwitch(
        label: r'\rho = 0',
        plainSuffix: '(outside depletion)',
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
    ];
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
              style: TextStyle(
                fontSize: _Typo.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Shows spatial profiles of charge density ',
                  style: TextStyle(fontSize: _Typo.body),
                ),
                LatexText(r'\rho(x)', style: TextStyle(fontSize: _Typo.body)),
                Text(
                  ', electric field ',
                  style: TextStyle(fontSize: _Typo.body),
                ),
                LatexText(r'E(x)', style: TextStyle(fontSize: _Typo.body)),
                Text(
                  ', and potential ',
                  style: TextStyle(fontSize: _Typo.body),
                ),
                LatexText(r'V(x)', style: TextStyle(fontSize: _Typo.body)),
                Text(
                  ' in the depletion region of a PN junction under bias.',
                  style: TextStyle(fontSize: _Typo.body),
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
          style: TextStyle(
            fontSize: _Typo.title,
            fontWeight: FontWeight.w700,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _bullet(
              r'Charge density $\rho(x)$ is piecewise constant inside depletion region.'),
          _bullet(
              r'Electric field $E(x)$ is triangular and peaks at junction.'),
          _bullet(
              r'Potential $V(x)$ is parabolic; rises from 0 to $V_{bi}$ across depletion width.'),
          _bullet(
              r'Depletion width $W$ widens under reverse bias ($V_a < 0$).'),
          const SizedBox(height: 8),
          Text('Try this:',
              style: TextStyle(
                  fontSize: _Typo.sectionLabel, fontWeight: FontWeight.w700)),
          _bullet(
              r'Change $N_A$ and $N_D$ to see asymmetric depletion (higher doping -> narrower side).'),
          _bullet(
              r'Apply forward bias ($V_a > 0$) to shrink $W$; reverse bias to widen.'),
          _bullet(
              'Use plot selector to view one profile at a time or all together.'),
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
          const Text('- '),
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
              : Text(buffer.toString(),
                  style: Theme.of(context).textTheme.bodyMedium));
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
          : Text(buffer.toString(),
              style: Theme.of(context).textTheme.bodyMedium));
    }
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: parts);
  }

  Widget _buildPlotSelectorLabel(String option) {
    if (option == 'All') {
      return Text(
        'All',
        style: TextStyle(fontSize: _Typo.body),
      );
    }
    return LatexText(
      PnLatex.depletionPlotTex(option),
      style: TextStyle(fontSize: _Typo.body),
    );
  }

  Widget _buildPlotSelectorCard() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Plot',
              style: TextStyle(
                fontSize: _Typo.sectionLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _plotOptions.map((option) {
                final isSelected = option == _selectedPlot;
                return ChoiceChip(
                  label: _buildPlotSelectorLabel(option),
                  selected: isSelected,
                  onSelected: (_) => updateChart(() {
                    _selectedPlot = option;
                    _selectedPoint = null;
                    _selectedPointPlot = null;
                    _selectedPointIndex = null;
                    _selectedPointLocalPosition = null;
                    _hoverPoint = null;
                    _hoverPointPlot = null;
                    _hoverPointIndex = null;
                    _hoverPointLocalPosition = null;
                  }),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartArea(BuildContext context, _PnCurves curves) {
    return Column(
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
            child: LatexText(
              r'V_{bi} - V_a > 0\ \mathrm{required\ for\ depletion\ approximation}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        _buildPlotSelectorCard(),
        const SizedBox(height: 12),
        Expanded(child: _buildChart(context, curves)),
      ],
    );
  }

  Widget _buildChart(BuildContext context, _PnCurves curves) {
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
            style: TextStyle(fontSize: _Typo.small),
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
            style: TextStyle(fontSize: _Typo.small),
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
            style: TextStyle(fontSize: _Typo.small),
            labelResolver: (_) => 'xₙ',
          ),
        ),
      ]);
    }

    if (_selectedPlot == 'All') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: _buildRhoChart(context, curves, xMin, xMax, markerLines)),
          const SizedBox(height: 8),
          Expanded(
              child: _buildEChart(context, curves, xMin, xMax, markerLines)),
          const SizedBox(height: 8),
          Expanded(
              child: _buildVChart(context, curves, xMin, xMax, markerLines)),
        ],
      );
    } else if (_selectedPlot == 'rho(x)') {
      return _buildRhoChart(context, curves, xMin, xMax, markerLines);
    } else if (_selectedPlot == 'E(x)') {
      return _buildEChart(context, curves, xMin, xMax, markerLines);
    } else {
      return _buildVChart(context, curves, xMin, xMax, markerLines);
    }
  }

  void _handleSingleSeriesTouch(
    String plotId,
    FlTouchEvent event,
    LineTouchResponse? response,
  ) {
    if (event is FlPointerExitEvent ||
        response == null ||
        (response.lineBarSpots?.isEmpty ?? true)) {
      if (_hoverPoint != null || _hoverPointPlot != null) {
        setState(() {
          _hoverPoint = null;
          _hoverPointPlot = null;
          _hoverPointIndex = null;
          _hoverPointLocalPosition = null;
        });
      }
      return;
    }

    final spots = response.lineBarSpots!;
    final nearest = spots.length == 1
        ? spots.first
        : spots.cast<TouchLineBarSpot>().reduce(
              (a, b) => a.distance <= b.distance ? a : b,
            );

    if (nearest.distance > _hoverThresholdPx && event is! FlTapUpEvent) {
      if (_hoverPoint != null || _hoverPointPlot != null) {
        setState(() {
          _hoverPoint = null;
          _hoverPointPlot = null;
          _hoverPointIndex = null;
          _hoverPointLocalPosition = null;
        });
      }
      return;
    }

    if (event is FlTapUpEvent) {
      setState(() {
        _selectedPoint = FlSpot(nearest.x, nearest.y);
        _selectedPointPlot = plotId;
        _selectedPointIndex = nearest.spotIndex;
        _selectedPointLocalPosition = event.localPosition;
      });
      return;
    }

    setState(() {
      _hoverPoint = FlSpot(nearest.x, nearest.y);
      _hoverPointPlot = plotId;
      _hoverPointIndex = nearest.spotIndex;
      if (event.localPosition != null) {
        _hoverPointLocalPosition = event.localPosition!;
      }
    });
  }

  List<TouchedSpotIndicatorData> _singleSpotIndicator(
    String plotId,
    List<int> spotIndexes,
    Color color,
  ) {
    final activeIndex = _activeSpotIndexForPlot(plotId);
    return spotIndexes
        .map(
          (index) => index == activeIndex
              ? TouchedSpotIndicatorData(
                  FlLine(
                    color: color.withValues(alpha: 0.4),
                    strokeWidth: 1.5,
                    dashArray: [4, 4],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3.5,
                      color: color,
                      strokeWidth: 1,
                      strokeColor: Colors.white,
                    ),
                  ),
                )
              : const TouchedSpotIndicatorData(
                  FlLine(color: Colors.transparent, strokeWidth: 0),
                  FlDotData(show: false),
                ),
        )
        .toList();
  }

  LineTouchTooltipData _hiddenTooltipData() {
    return LineTouchTooltipData(
      getTooltipItems: (spots) =>
          List<LineTooltipItem?>.filled(spots.length, null),
    );
  }

  Widget _buildRhoChart(BuildContext context, _PnCurves curves, double xMin,
      double xMax, List<VerticalLine> markers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            LineChart(
              key: ValueKey('pn-rho-$chartVersion'),
              LineChartData(
                minX: xMin,
                maxX: xMax,
                minY: curves.minRho,
                maxY: curves.maxRho,
                gridData: const FlGridData(show: true, drawVerticalLine: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: LatexText(
                      PnLatex.withUnit(PnLatex.rhoPlot, PnLatex.unitCPerM3),
                      style: TextStyle(
                          fontSize: _Typo.sectionLabel,
                          fontWeight: FontWeight.w600),
                    ),
                    axisNameSize: 32,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 70,
                      getTitlesWidget: (v, _) => Text(
                        PnLatex.unicodeScientific(v, sigFigs: 2),
                        style: TextStyle(fontSize: _Typo.small),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget:
                        LatexText(PnLatex.withUnit(r'x', PnLatex.unitUm)),
                    axisNameSize: 32,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(v.toStringAsFixed(2),
                          style: TextStyle(fontSize: _Typo.small)),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
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
                  touchSpotThreshold: _hoverThresholdPx,
                  getTouchedSpotIndicator: (barData, spotIndexes) =>
                      _singleSpotIndicator('rho(x)', spotIndexes,
                          Theme.of(context).colorScheme.primary),
                  touchCallback: (event, response) =>
                      _handleSingleSeriesTouch('rho(x)', event, response),
                  touchTooltipData: _hiddenTooltipData(),
                ),
              ),
            ),
            _buildHoverTooltip(
              context,
              plotId: 'rho(x)',
              maxWidth: constraints.maxWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildEChart(BuildContext context, _PnCurves curves, double xMin,
      double xMax, List<VerticalLine> markers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            LineChart(
              key: ValueKey('pn-e-$chartVersion'),
              LineChartData(
                minX: xMin,
                maxX: xMax,
                minY: curves.minE,
                maxY: curves.maxE,
                gridData: const FlGridData(show: true, drawVerticalLine: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: LatexText(
                      PnLatex.withUnit(PnLatex.ePlot, PnLatex.unitVPerM),
                      style: TextStyle(
                          fontSize: _Typo.sectionLabel,
                          fontWeight: FontWeight.w600),
                    ),
                    axisNameSize: 32,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (v, _) => Text(
                        PnLatex.unicodeScientific(v, sigFigs: 2),
                        style: TextStyle(fontSize: _Typo.small),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget:
                        LatexText(PnLatex.withUnit(r'x', PnLatex.unitUm)),
                    axisNameSize: 32,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(v.toStringAsFixed(2),
                          style: TextStyle(fontSize: _Typo.small)),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
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
                  touchSpotThreshold: _hoverThresholdPx,
                  getTouchedSpotIndicator: (barData, spotIndexes) =>
                      _singleSpotIndicator('E(x)', spotIndexes,
                          Theme.of(context).colorScheme.secondary),
                  touchCallback: (event, response) =>
                      _handleSingleSeriesTouch('E(x)', event, response),
                  touchTooltipData: _hiddenTooltipData(),
                ),
              ),
            ),
            _buildHoverTooltip(
              context,
              plotId: 'E(x)',
              maxWidth: constraints.maxWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildVChart(BuildContext context, _PnCurves curves, double xMin,
      double xMax, List<VerticalLine> markers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            LineChart(
              key: ValueKey('pn-v-$chartVersion'),
              LineChartData(
                minX: xMin,
                maxX: xMax,
                minY: curves.minV,
                maxY: curves.maxV,
                gridData: const FlGridData(show: true, drawVerticalLine: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: LatexText(
                      PnLatex.withUnit(PnLatex.vPlot, PnLatex.unitV),
                      style: TextStyle(
                          fontSize: _Typo.sectionLabel,
                          fontWeight: FontWeight.w600),
                    ),
                    axisNameSize: 32,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (v, _) => Text(v.toStringAsFixed(2),
                          style: TextStyle(fontSize: _Typo.small)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget:
                        LatexText(PnLatex.withUnit(r'x', PnLatex.unitUm)),
                    axisNameSize: 32,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(v.toStringAsFixed(2),
                          style: TextStyle(fontSize: _Typo.small)),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
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
                  touchSpotThreshold: _hoverThresholdPx,
                  getTouchedSpotIndicator: (barData, spotIndexes) =>
                      _singleSpotIndicator('V(x)', spotIndexes,
                          Theme.of(context).colorScheme.tertiary),
                  touchCallback: (event, response) =>
                      _handleSingleSeriesTouch('V(x)', event, response),
                  touchTooltipData: _hiddenTooltipData(),
                ),
              ),
            ),
            _buildHoverTooltip(
              context,
              plotId: 'V(x)',
              maxWidth: constraints.maxWidth,
            ),
          ],
        );
      },
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
