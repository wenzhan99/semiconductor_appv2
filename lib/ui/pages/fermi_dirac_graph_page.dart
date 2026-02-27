import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/solver/number_formatter.dart';
import '../graphs/common/enhanced_animation_panel.dart';
import '../graphs/common/latex_readout.dart';
import '../graphs/core/graph_config.dart';
import '../graphs/core/standard_graph_page_scaffold.dart';
import '../widgets/latex_text.dart';
import '../graphs/utils/safe_math.dart';

class FermiDiracGraphPage extends StatelessWidget {
  const FermiDiracGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fermi-Dirac Probability')),
      body: const FermiDiracGraphView(),
    );
  }
}

class FermiDiracGraphView extends StatefulWidget {
  const FermiDiracGraphView({super.key});

  @override
  State<FermiDiracGraphView> createState() => _FermiDiracGraphViewState();
}

enum _FDAnimParam { temperature, fermiLevel }

class _HoveredFDPoint {
  final FlSpot spot;
  const _HoveredFDPoint(this.spot);
}

class _FermiDiracGraphViewState extends State<FermiDiracGraphView> {
  int _chartVersion = 0;
  static const int _maxPins = 2;
  static const Color _pinBlue = Color(0xFF1E88E5);
  static const Color _pinRed = Color(0xFFE53935);

  // Parameters
  double _temperature = 300.0; // K
  double _fermiLevel = 0.0; // eV
  bool _relativeToFermi = true;

  // Animation state
  bool _isAnimating = false;
  double _animProgress = 0.0;
  double _animSpeed = 1.0;
  _FDAnimParam _animParam = _FDAnimParam.temperature;
  bool _loopEnabled = true;
  bool _reverseDirection = false;
  bool _holdSelectedK = false;
  bool _lockYAxis = true;
  bool _overlayPrevious = true;
  double _animDirection = 1.0;
  Timer? _animTimer;
  final Map<_FDAnimParam, RangeValues> _animRanges = {
    _FDAnimParam.temperature: const RangeValues(100, 900),
    _FDAnimParam.fermiLevel: const RangeValues(-0.5, 0.5),
  };

  // Interaction state
  _HoveredFDPoint? _hovered;
  final List<FlSpot> _pinnedSpots = [];
  List<FlSpot>? _overlayCurve;

  // Constants
  static const double _kBoltzmannEV = 8.617333262e-5; // eV/K
  static const double _inlineLatexScale = 1.12;
  static const double _inlineLatexScaleSmall = 1.05;

  final NumberFormatter _fmt = const NumberFormatter(significantFigures: 3);

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  Color _pinColorForIndex(int index) => index.isEven ? _pinBlue : _pinRed;

  Color _hoverMarkerColor() {
    if (_pinnedSpots.isEmpty) return _pinBlue;
    if (_pinnedSpots.length == 1) return _pinRed;
    return _pinBlue;
  }

  bool _sameSpot(FlSpot a, FlSpot b) =>
      (a.x - b.x).abs() < 1e-6 && (a.y - b.y).abs() < 1e-6;

  void _togglePinnedSpot(FlSpot spot) {
    final existing = _pinnedSpots.indexWhere((p) => _sameSpot(p, spot));
    if (existing >= 0) {
      _pinnedSpots.removeAt(existing);
      return;
    }
    _pinnedSpots.add(spot);
    if (_pinnedSpots.length > _maxPins) {
      _pinnedSpots.removeAt(0);
    }
  }

  List<FlSpot> _computeFermiDiracCurve() {
    const int numPoints = 400;
    final List<FlSpot> points = [];
    const double eMin = -0.5; // eV relative to EF
    const double eMax = 0.5; // eV relative to EF
    final kT = _kBoltzmannEV * _temperature; // eV

    for (int i = 0; i < numPoints; i++) {
      final double eRel = eMin + (eMax - eMin) * i / (numPoints - 1);
      final double eAbs = eRel + _fermiLevel;
      final double exponent = eRel / kT;
      final double f = 1.0 / (1.0 + SafeMath.safeExp(exponent));
      final double xValue = _relativeToFermi ? eRel : eAbs;
      points.add(FlSpot(xValue, f));
    }
    return points;
  }

  void _toggleAnimation() {
    if (_isAnimating) {
      _stopAnimation();
    } else {
      _animDirection = _reverseDirection ? -1 : 1;
      _startAnimation();
    }
  }

  void _startAnimation() {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);
    _animTimer = Timer.periodic(const Duration(milliseconds: 36), (_) {
      if (!mounted) return;
      _stepAnimation();
    });
  }

  void _stopAnimation() {
    _animTimer?.cancel();
    setState(() => _isAnimating = false);
  }

  void _restartAnimation() {
    _animTimer?.cancel();
    setState(() {
      _animProgress = 0;
      _isAnimating = false;
    });
    _toggleAnimation();
  }

  void _stepAnimation() {
    setState(() {
      _animProgress += 0.01 * _animSpeed * _animDirection;
      if (_animProgress > 1.0 || _animProgress < 0.0) {
        if (_loopEnabled) {
          _animProgress = _animProgress < 0 ? 1.0 : 0.0;
        } else {
          _animProgress = _animProgress.clamp(0.0, 1.0);
          _stopAnimation();
        }
      }
      _applyAnimatedValue();
    });
  }

  void _applyAnimatedValue() {
    _captureOverlay();
    final range = _animRanges[_animParam]!;
    final value = range.start +
        (_animProgress.clamp(0.0, 1.0) * (range.end - range.start));
    switch (_animParam) {
      case _FDAnimParam.temperature:
        _temperature = value;
        break;
      case _FDAnimParam.fermiLevel:
        _fermiLevel = value;
        break;
    }
    _chartVersion++;
  }

  void _captureOverlay() {
    if (!_overlayPrevious) return;
    _overlayCurve = _computeFermiDiracCurve();
  }

  double _minX() => _relativeToFermi ? -0.5 : _fermiLevel - 0.5;
  double _maxX() => _relativeToFermi ? 0.5 : _fermiLevel + 0.5;

  // ignore: unused_element
  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fermi-Dirac Probability Distribution',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const LatexText(
          r'f(E) = \frac{1}{1 + \exp\left(\frac{E - E_{\mathrm{F}}}{k T}\right)}',
          displayMode: true,
          scale: 1.1,
        ),
      ],
    );
  }

  Widget _buildInfoPanel() {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text(
              'The Fermi-Dirac distribution describes the probability that an electron occupies an energy state E at thermal equilibrium.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    final curve = _computeFermiDiracCurve();
    final minX = _minX();
    final maxX = _maxX();
    final yMinCurve =
        curve.isEmpty ? 0.0 : curve.map((e) => e.y).reduce(math.min);
    final yMaxCurve =
        curve.isEmpty ? 1.0 : curve.map((e) => e.y).reduce(math.max);
    final minY = _lockYAxis ? -0.05 : math.min(-0.05, yMinCurve - 0.05);
    final maxY = _lockYAxis ? 1.05 : math.max(1.05, yMaxCurve + 0.05);
    final overlayLines = <LineChartBarData>[];
    if (_overlayPrevious && _overlayCurve != null) {
      overlayLines.add(LineChartBarData(
        spots: _overlayCurve!,
        isCurved: true,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }
    final mainCurveIndex = overlayLines.length;
    final hoveredSpot = _hovered?.spot;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return LineChart(
                key: ValueKey(
                    'fd-$_chartVersion-$_temperature-$_fermiLevel-$_relativeToFermi'),
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  gridData: const FlGridData(
                    show: true,
                    horizontalInterval: 0.2,
                    verticalInterval: 0.2,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: const LatexText(r'f(E)', scale: 1.0),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value > 1) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: LatexText(
                              value.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: LatexText(_relativeToFermi
                          ? r'E - E_{\mathrm{F}}\ \mathrm{(eV)}'
                          : r'E\ \mathrm{(eV)}'),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 0.2,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: LatexText(
                            value.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    ...overlayLines,
                    LineChartBarData(
                      spots: curve,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                      ),
                    ),
                    ..._pinnedSpots.asMap().entries.map(
                          (entry) => LineChartBarData(
                            spots: [entry.value],
                            isCurved: false,
                            color: Colors.transparent,
                            barWidth: 0,
                            dotData: FlDotData(
                              show: true,
                              checkToShowDot: (_, __) => true,
                              getDotPainter: (_, __, ___, ____) =>
                                  FlDotCirclePainter(
                                color: _pinColorForIndex(entry.key),
                                radius: 5.2,
                                strokeColor: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                    if (hoveredSpot != null &&
                        !_pinnedSpots.any((p) => _sameSpot(p, hoveredSpot)))
                      LineChartBarData(
                        spots: [hoveredSpot],
                        isCurved: false,
                        color: Colors.transparent,
                        barWidth: 0,
                        dotData: FlDotData(
                          show: true,
                          checkToShowDot: (_, __) => true,
                          getDotPainter: (_, __, ___, ____) =>
                              FlDotCirclePainter(
                            color: _hoverMarkerColor().withValues(alpha: 0.22),
                            radius: 6,
                            strokeColor: _hoverMarkerColor(),
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 0.5,
                        color: Colors.grey.withValues(alpha: 0.5),
                        strokeWidth: 1,
                        dashArray: const [5, 5],
                      ),
                    ],
                    verticalLines: _relativeToFermi
                        ? [
                            VerticalLine(
                              x: 0,
                              color: Colors.grey.withValues(alpha: 0.5),
                              strokeWidth: 1,
                              dashArray: const [5, 5],
                            ),
                          ]
                        : [],
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
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
                    touchSpotThreshold: 28,
                    touchCallback: (event, response) {
                      final spots = response?.lineBarSpots;
                      if (spots == null || spots.isEmpty) {
                        if (event is FlTapUpEvent && _pinnedSpots.isNotEmpty) {
                          setState(() {
                            _hovered = null;
                            _pinnedSpots.clear();
                          });
                          return;
                        }
                        if (event is FlPointerExitEvent) {
                          setState(() => _hovered = null);
                        }
                        return;
                      }
                      final mainSpot = spots.firstWhere(
                        (s) => s.barIndex == mainCurveIndex,
                        orElse: () => spots.first,
                      );
                      final normalized = FlSpot(mainSpot.x, mainSpot.y);
                      final next = _HoveredFDPoint(normalized);
                      if (_hovered != null &&
                          (_hovered!.spot.x - next.spot.x).abs() < 1e-6 &&
                          (_hovered!.spot.y - next.spot.y).abs() < 1e-6) {
                        if (event is FlTapUpEvent) {
                          setState(() => _togglePinnedSpot(normalized));
                        }
                        return;
                      }
                      if (event is FlTapUpEvent) {
                        setState(() {
                          _hovered = next;
                          _togglePinnedSpot(normalized);
                        });
                        return;
                      }
                      setState(() => _hovered = next);
                    },
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) =>
                          Colors.white.withValues(alpha: 0.98),
                      tooltipBorder: BorderSide(
                        color: Colors.black.withValues(alpha: 0.16),
                        width: 1,
                      ),
                      getTooltipItems: (spots) {
                        return spots
                            .where((s) => s.barIndex == mainCurveIndex)
                            .map(
                              (s) => LineTooltipItem(
                                '${_relativeToFermi ? 'E - E(Fermi)' : 'E'} = ${s.x.toStringAsFixed(3)} eV\nf(E) = ${s.y.toStringAsFixed(5)}',
                                const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                            .toList();
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final panelConfig = _buildPanelConfig();
    return StandardGraphPageScaffold(
      config: panelConfig.copyWith(
        title: 'Fermi-Dirac Probability Distribution',
        subtitle: 'DOS & Statistics',
        mainEquation:
            r'f(E) = \frac{1}{1 + \exp\left(\frac{E - E_{\mathrm{F}}}{k T}\right)}',
      ),
      aboutSection: _buildInfoPanel(),
      observeSection: _buildObserveCard(context),
      placeSectionsInWideLeftColumn: true,
      useTwoColumnRightPanelInWide: true,
      wideLeftColumnSectionIds: const ['point_inspector', 'animation'],
      wideRightColumnSectionIds: const ['notes', 'controls'],
      chartBuilder: (context) => _buildChartCard(),
    );
  }

  GraphConfig _buildPanelConfig() {
    final hovered = _hovered?.spot;
    final pinned = _pinnedSpots.isEmpty ? null : _pinnedSpots.last;
    final inspector = PointInspectorConfig(
      enabled: true,
      emptyMessage: 'Hover the curve to inspect values.',
      onClear: () => setState(() {
        _hovered = null;
        _pinnedSpots.clear();
      }),
      interactionHint:
          'Tap curve to pin (max $_maxPins); tap empty area to clear.',
      isPinned: pinned != null,
      builder: (hovered == null && pinned == null)
          ? null
          : () {
              final lines = <String>[];
              if (pinned != null) {
                lines.add(
                  'Pinned ${_relativeToFermi ? r'$E - E_{\mathrm{F}}$' : r'$E$'}: \$${pinned.x.toStringAsFixed(3)}\\,\\mathrm{eV}\$',
                );
                lines.add(
                    r'Pinned $f(E)$: ' '\$${pinned.y.toStringAsFixed(5)}\$');
              }
              if (hovered != null) {
                lines.add(
                  'Hover ${_relativeToFermi ? r'$E - E_{\mathrm{F}}$' : r'$E$'}: \$${hovered.x.toStringAsFixed(3)}\\,\\mathrm{eV}\$',
                );
                lines.add(r'$f(E)$: ' '\$${hovered.y.toStringAsFixed(5)}\$');
              }
              return lines;
            },
    );

    final animation = AnimationConfig(
      parameters: _FDAnimParam.values.map((param) {
        final range = _animRanges[param]!;
        final isSelected = _animParam == param;
        return AnimatableParameter(
          id: param == _FDAnimParam.temperature ? 'temperature' : 'fermi',
          label: param == _FDAnimParam.temperature
              ? r'T (temperature)'
              : r'E_{\mathrm{F}} (Fermi level)',
          symbol: param == _FDAnimParam.temperature ? r'T' : r'E_{\mathrm{F}}',
          unit: param == _FDAnimParam.temperature ? r'K' : r'eV',
          currentValue:
              param == _FDAnimParam.temperature ? _temperature : _fermiLevel,
          rangeMin: range.start,
          rangeMax: range.end,
          absoluteMin: param == _FDAnimParam.temperature ? 1 : -1.0,
          absoluteMax: param == _FDAnimParam.temperature ? 1200 : 1.0,
          enabled: isSelected,
          onEnabledChanged: (enabled) {
            if (!enabled) return;
            setState(() {
              _animParam = param;
              _animProgress = 0.0;
            });
          },
          onValueChanged: (value) {
            _stopAnimation();
            _captureOverlay();
            setState(() {
              if (param == _FDAnimParam.temperature) {
                _temperature = value;
              } else {
                _fermiLevel = value;
              }
              _chartVersion++;
            });
          },
          onRangeChanged: (min, max) {
            setState(() {
              _animRanges[param] = RangeValues(min, max);
            });
          },
          physicsNote: param == _FDAnimParam.temperature
              ? r'Higher temperature broadens the transition around $E_{\mathrm{F}}$.'
              : r'Changing $E_{\mathrm{F}}$ shifts the distribution along the energy axis.',
        );
      }).toList(),
      selectedParameterId:
          _animParam == _FDAnimParam.temperature ? 'temperature' : 'fermi',
      onParameterSelected: (id) {
        setState(() {
          _animParam = id == 'temperature'
              ? _FDAnimParam.temperature
              : _FDAnimParam.fermiLevel;
          _animProgress = 0.0;
        });
      },
      state: AnimationState(
        isPlaying: _isAnimating,
        speed: _animSpeed,
        reverse: _reverseDirection,
        loop: _loopEnabled,
        progress: _isAnimating ? _animProgress : null,
      ),
      callbacks: AnimationCallbacks(
        onPlay: _toggleAnimation,
        onPause: _stopAnimation,
        onRestart: _restartAnimation,
        onSpeedChanged: (speed) => setState(() => _animSpeed = speed),
        onReverseChanged: (reverse) =>
            setState(() => _reverseDirection = reverse),
        onLoopChanged: (loop) => setState(() => _loopEnabled = loop),
      ),
    );

    final staticObservations = <String>[
      r'At $E = E_{\mathrm{F}}$, $f(E) = 0.5$ for any temperature.',
      r'Increasing $T$ broadens occupation around $E_{\mathrm{F}}$.',
      r'Transition width scales approximately with $kT$.',
    ];
    final dynamicObservations = <String>[
      for (var i = 0; i < _pinnedSpots.length; i++) ...[
        'Pin ${i + 1}: ${_relativeToFermi ? r'$E - E_{\mathrm{F}}$' : r'$E$'} = \$${_pinnedSpots[i].x.toStringAsFixed(3)}\\,\\mathrm{eV}\$',
        r'$f(E)$ = ' '\$${_pinnedSpots[i].y.toStringAsFixed(5)}\$',
      ],
      if (hovered != null) ...[
        'Current hover: ${_relativeToFermi ? r'$E - E_{\mathrm{F}}$' : r'$E$'} = \$${hovered.x.toStringAsFixed(3)}\\,\\mathrm{eV}\$',
        r'$f(E)$ = ' '\$${hovered.y.toStringAsFixed(5)}\$',
      ],
    ];

    return GraphConfig(
      pointInspector: inspector,
      animation: animation,
      insights: InsightsConfig(
        dynamicObservations:
            dynamicObservations.isEmpty ? null : dynamicObservations,
        staticObservations: staticObservations,
        dynamicTitle: _pinnedSpots.isNotEmpty
            ? 'From Your Pins'
            : (hovered == null ? null : 'Current Hover'),
        pinnedCount: _pinnedSpots.length,
        maxPins: _maxPins,
        onClearPins: _pinnedSpots.isEmpty
            ? null
            : () => setState(() => _pinnedSpots.clear()),
      ),
      controls: ControlsConfig(
        children: [_buildControls()],
        collapsible: true,
        initiallyExpanded: true,
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
          _bulletLine(const [
            _InlinePiece.text('At '),
            _InlinePiece.latex(r'E = E_{\mathrm{F}}'),
            _InlinePiece.text(', '),
            _InlinePiece.latex(r'f(E)=0.5'),
            _InlinePiece.text(' for any temperature.'),
          ], latexScale: _inlineLatexScale),
          _bulletLine(const [
            _InlinePiece.text('Higher '),
            _InlinePiece.latex(r'T'),
            _InlinePiece.text(' broadens the transition around '),
            _InlinePiece.latex(r'E_{\mathrm{F}}'),
            _InlinePiece.text('.'),
          ], latexScale: _inlineLatexScale),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSidebar() {
    return Column(
      children: [
        _buildInspector(),
        const SizedBox(height: 12),
        _buildAnimationPanel(),
        const SizedBox(height: 12),
        _buildInsights(),
        const SizedBox(height: 12),
        _buildControls(),
      ],
    );
  }

  Widget _buildInspector() {
    final hovered = _hovered?.spot;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('Point Inspector',
            style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (hovered == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Hover the curve to inspect values.'),
            )
          else ...[
            LatexReadoutRow(
              labelLatex: _relativeToFermi ? r'E - E_{\mathrm{F}}' : r'E',
              valueLatex: LatexReadoutFormatter.valueWithUnitText(
                hovered.x,
                unit: 'eV',
                forceSci: false,
              ),
            ),
            LatexReadoutRow(
              labelLatex: r'f(E)',
              valueLatex: LatexReadoutFormatter.valueWithUnitText(
                hovered.y,
                unit: '',
                forceSci: false,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimationPanel() {
    return EnhancedAnimationPanel<_FDAnimParam>(
      controller: _FDAnimationController(this),
    );
  }

  Widget _buildInsights() {
    final hovered = _hovered?.spot;
    final kT = _kBoltzmannEV * _temperature;
    final widthApprox = 4 * kT; // ~4 kT transition width
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('Insights',
            style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dynamic insight',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                if (hovered == null)
                  _bulletLine(const [
                    _InlinePiece.text('Hover to see '),
                    _InlinePiece.latex(r'f(E)'),
                    _InlinePiece.text(' for the current energy value.'),
                  ], latexScale: _inlineLatexScale)
                else ...[
                  LatexText(
                    'kT \\approx ${_fmt.formatLatex(kT)}\\,\\mathrm{eV},\\quad \\mathrm{width} \\sim ${_fmt.formatLatex(widthApprox)}\\,\\mathrm{eV}',
                    scale: _inlineLatexScaleSmall,
                  ),
                  const SizedBox(height: 4),
                  LatexText(
                    LatexReadoutFormatter.equation(
                        labelLatex: r'f(E)',
                        valueLatex: _fmt.formatLatex(hovered.y)),
                    scale: _inlineLatexScaleSmall,
                  ),
                  if (_relativeToFermi)
                    const LatexText(
                      r'f(E_{\mathrm{F}})=0.5 \\mathrm{ when } E=E_{\mathrm{F}}',
                      scale: 1.0,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('Controls',
            style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _slider(
            labelLatex: r'T',
            min: 100,
            max: 900,
            value: _temperature,
            divisions: 800,
            unit: 'K',
            onChanged: (v) {
              _stopAnimation();
              _captureOverlay();
              setState(() {
                _temperature = v;
                _chartVersion++;
              });
            },
          ),
          const SizedBox(height: 12),
          _slider(
            labelLatex: r'E_{\mathrm{F}}',
            min: -0.5,
            max: 0.5,
            value: _fermiLevel,
            divisions: 100,
            unit: 'eV',
            onChanged: (v) {
              _stopAnimation();
              _captureOverlay();
              setState(() {
                _fermiLevel = v;
                _chartVersion++;
              });
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: const [
                Text('Relative to'),
                LatexText(r'E_{\mathrm{F}}', scale: 1.0),
              ],
            ),
            subtitle: _relativeToFermi
                ? Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: const [
                      Text('X-axis:'),
                      LatexText(r'E - E_{\mathrm{F}}', scale: 1.0),
                    ],
                  )
                : Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: const [
                      Text('X-axis:'),
                      LatexText(r'E', scale: 1.0),
                      Text('(absolute)'),
                    ],
                  ),
            value: _relativeToFermi,
            onChanged: (v) {
              setState(() {
                _relativeToFermi = v;
                _chartVersion++;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _slider({
    required String labelLatex,
    required double min,
    required double max,
    required double value,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            LatexText(labelLatex,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${_fmt.formatLatex(value)} $unit'),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _bulletLine(List<_InlinePiece> pieces, {double latexScale = 1.0}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 2,
        children: pieces
            .map((p) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: p.latex
                      ? LatexText(p.text, scale: latexScale)
                      : Text(p.text),
                ))
            .toList(),
      ),
    );
  }
}

class _InlinePiece {
  final String text;
  final bool latex;
  const _InlinePiece.text(this.text) : latex = false;
  const _InlinePiece.latex(this.text) : latex = true;
}

class _FDAnimationController
    implements EnhancedAnimationController<_FDAnimParam> {
  final _FermiDiracGraphViewState state;
  _FDAnimationController(this.state);

  void _update(VoidCallback fn) {
    // ignore: invalid_use_of_protected_member
    state.setState(fn);
  }

  @override
  List<_FDAnimParam> get parameters => _FDAnimParam.values;

  @override
  _FDAnimParam get selectedParam => state._animParam;

  @override
  void selectParam(_FDAnimParam param) {
    _update(() {
      state._animParam = param;
      state._animProgress = 0;
    });
  }

  String _latex(_FDAnimParam p) {
    switch (p) {
      case _FDAnimParam.temperature:
        return r'T';
      case _FDAnimParam.fermiLevel:
        return r'E_{\mathrm{F}}';
    }
  }

  String _descriptor(_FDAnimParam p) {
    switch (p) {
      case _FDAnimParam.temperature:
        return 'temperature';
      case _FDAnimParam.fermiLevel:
        return 'Fermi level';
    }
  }

  @override
  String dropdownLabel(_FDAnimParam param) =>
      '${_latex(param)} (${_descriptor(param)})';

  @override
  String valueLabel(_FDAnimParam param) => _latex(param);

  @override
  String unitLabel(_FDAnimParam param) {
    switch (param) {
      case _FDAnimParam.temperature:
        return r'K';
      case _FDAnimParam.fermiLevel:
        return r'eV';
    }
  }

  @override
  String physicsNote(_FDAnimParam param) {
    switch (param) {
      case _FDAnimParam.temperature:
        return r'Higher $T$ increases thermal smearing; slope at $E=E_{\mathrm{F}}$ decreases.';
      case _FDAnimParam.fermiLevel:
        return 'Shifts the distribution horizontally relative to the energy axis.';
    }
  }

  @override
  double get currentValue {
    switch (state._animParam) {
      case _FDAnimParam.temperature:
        return state._temperature;
      case _FDAnimParam.fermiLevel:
        return state._fermiLevel;
    }
  }

  @override
  void setCurrentValue(double value) {
    if (state._isAnimating) state._stopAnimation();
    _update(() {
      state._captureOverlay();
      switch (state._animParam) {
        case _FDAnimParam.temperature:
          state._temperature = value;
          break;
        case _FDAnimParam.fermiLevel:
          state._fermiLevel = value;
          break;
      }
      state._chartVersion++;
    });
  }

  @override
  double get rangeMin => state._animRanges[state._animParam]!.start;

  @override
  double get rangeMax => state._animRanges[state._animParam]!.end;

  @override
  double get absoluteMin => _boundsFor(state._animParam).$1;

  @override
  double get absoluteMax => _boundsFor(state._animParam).$2;

  (double, double) _boundsFor(_FDAnimParam param) {
    switch (param) {
      case _FDAnimParam.temperature:
        return (1, 1200);
      case _FDAnimParam.fermiLevel:
        return (-1.0, 1.0);
    }
  }

  @override
  void setRangeMin(double value) => _update(() {
        final current = state._animRanges[state._animParam]!;
        state._animRanges[state._animParam] =
            RangeValues(value, current.end.clamp(value, absoluteMax));
      });

  @override
  void setRangeMax(double value) => _update(() {
        final current = state._animRanges[state._animParam]!;
        state._animRanges[state._animParam] =
            RangeValues(current.start.clamp(absoluteMin, value), value);
      });

  @override
  void resetRangeToDefault() => _update(() {
        state._animRanges[state._animParam] =
            _defaultRangeFor(state._animParam);
      });

  RangeValues _defaultRangeFor(_FDAnimParam param) {
    switch (param) {
      case _FDAnimParam.temperature:
        return const RangeValues(100, 900);
      case _FDAnimParam.fermiLevel:
        return const RangeValues(-0.5, 0.5);
    }
  }

  @override
  double get speed => state._animSpeed;

  @override
  void setSpeed(double multiplier) =>
      _update(() => state._animSpeed = multiplier);

  @override
  bool get loopEnabled => state._loopEnabled;

  @override
  void setLoopEnabled(bool value) => _update(() => state._loopEnabled = value);

  @override
  bool get reverseDirection => state._reverseDirection;

  @override
  void setReverseDirection(bool value) =>
      _update(() => state._reverseDirection = value);

  @override
  bool get holdSelectedK => state._holdSelectedK;

  @override
  void setHoldSelectedK(bool value) =>
      _update(() => state._holdSelectedK = value);

  @override
  bool get lockYAxis => state._lockYAxis;

  @override
  void setLockYAxis(bool value) => _update(() => state._lockYAxis = value);

  @override
  bool get overlayPreviousCurve => state._overlayPrevious;

  @override
  void setOverlayPreviousCurve(bool value) =>
      _update(() => state._overlayPrevious = value);

  @override
  bool get isAnimating => state._isAnimating;

  @override
  double? get progress => state._isAnimating ? state._animProgress : null;

  @override
  void play() => state._toggleAnimation();

  @override
  void pause() => state._stopAnimation();

  @override
  void restart() => state._restartAnimation();
}
