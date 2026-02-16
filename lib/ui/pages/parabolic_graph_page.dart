import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/constants_loader.dart';
import '../../core/constants/latex_symbols.dart';
import '../../core/solver/number_formatter.dart';
import '../graphs/common/enhanced_animation_panel.dart';
import '../graphs/core/graph_config.dart' show GraphConfig, ControlsConfig;
import '../graphs/core/standard_graph_page_scaffold.dart';
import '../graphs/utils/latex_number_formatter.dart';
import '../graphs/common/latex_readout.dart';
import '../widgets/latex_text.dart';

// Import typography standards
typedef _Typo = GraphPanelTextStyles;

enum PlotMode { absolute, delta }

enum _AnimTarget { eg, mn, mp, kmax }

class ParabolicGraphPage extends StatelessWidget {
  const ParabolicGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parabolic Band Dispersion (E\u2013k)')),
      body: const ParabolicGraphView(),
    );
  }
}

class ParabolicGraphView extends StatefulWidget {
  const ParabolicGraphView({super.key});

  @override
  State<ParabolicGraphView> createState() => _ParabolicGraphViewState();
}

class _ParabolicGraphViewState extends State<ParabolicGraphView> {
  // Toggles
  bool _showConduction = true;
  bool _showValence = true;

  // Modes
  PlotMode _plotMode = PlotMode.absolute;
  String _energyReference = 'Midgap = 0';
  String _materialPreset = 'Custom';

  // Sliders / parameters
  double _eg = 1.12; // eV
  double _mnEff = 0.26; // x m0
  double _mpEff = 0.39; // x m0
  double _kMaxScaled = 0.5; // x1e10 m^-1
  double _points = 400;
  bool _isAnimating = false;
  double _animSpeed = 1.0;
  double _animProgress = 0.0;
  _AnimTarget _animTarget = _AnimTarget.eg;
  bool _loopEnabled = true;
  bool _holdSelectedK = false;
  bool _reverseDirection = false;
  bool _lockYAxis = false;
  double? _lockedMinY;
  double? _lockedMaxY;
  bool _overlayPrevious = false;
  double _animDirection = 1.0;
  final Map<_AnimTarget, RangeValues> _animRanges = {
    _AnimTarget.eg: const RangeValues(0.6, 1.6),
    _AnimTarget.mn: const RangeValues(0.1, 1.2),
    _AnimTarget.mp: const RangeValues(0.1, 1.2),
    _AnimTarget.kmax: const RangeValues(0.2, 1.0),
  };
  Timer? _animTimer;
  List<_SeriesMeta> _overlaySeries = [];
  List<_GraphPoint> _conductionSamples = [];
  List<_GraphPoint> _valenceSamples = [];

  // Constants
  static const double _kMin = 0.0;
  static const double _kDisplayScale = 1e10; // display k in 1e10 m^-1
  static const double _hbar = 1.054571817e-34; // J*s
  static const double _m0 = 9.1093837015e-31; // kg
  static const double _q = 1.602176634e-19; // C
  static const EdgeInsets _chartPadding =
      EdgeInsets.fromLTRB(52, 12, 12, 32); // align with chart axes/titles
  static const Map<String, String> _uiLatexLabels = {
    'Eg': r'E_g',
    'Ec': r'E_c',
    'Ev': r'E_v',
    'mn': r'm_n^{*}',
    'mp': r'm_p^{*}',
    'kmax': r'k_{\max}',
  };
  static const Map<_AnimTarget, String> _animLabelKeyMap = {
    _AnimTarget.eg: 'Eg',
    _AnimTarget.mn: 'mn',
    _AnimTarget.mp: 'mp',
    _AnimTarget.kmax: 'kmax',
  };

  final List<_PointRef> _pins = [];
  
  // Active point state (updates on hover, drives inspector UI and tooltip)
  final ValueNotifier<_ActivePointState?> _activePointVN = ValueNotifier(null);
  
  final Map<String, Map<int, _ReadoutCache>> _readoutCache = {
    'Conduction': {},
    'Valence': {},
  };
  static const List<Color> _pinPalette = [
    Color(0xFF1E88E5),
    Color(0xFFD81B60),
    Color(0xFF43A047),
    Color(0xFF8E24AA),
    Color(0xFFFB8C00),
    Color(0xFF00897B),
    Color(0xFF5E35B1),
    Color(0xFF6D4C41),
    Color(0xFF3949AB),
    Color(0xFF546E7A),
  ];

  late final Future<LatexSymbolMap> _latexSymbols;
  final NumberFormatter _latexFormatter =
      const NumberFormatter(significantFigures: 3);

  static const _defaultState = {
    'plotMode': PlotMode.absolute,
    'energyReference': 'Midgap = 0',
    'materialPreset': 'Custom',
    'eg': 1.12,
    'mnEff': 0.26,
    'mpEff': 0.39,
    'kMaxScaled': 0.5,
    'points': 400.0,
    'showConduction': true,
    'showValence': true,
  };

  @override
  void initState() {
    super.initState();
    _latexSymbols = ConstantsLoader.loadLatexSymbols();
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _activePointVN.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LatexSymbolMap>(
      future: _latexSymbols,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final latexMap = snapshot.data!;
        return StandardGraphPageScaffold(
          config: const GraphConfig(
            title: 'Parabolic Band Dispersion (E-k)',
            subtitle: 'Band Structure',
            mainEquation:
                r'E_c(k)=E_c+\frac{\hbar^{2}k^{2}}{2\,m_n^{*}},\quad E_v(k)=E_v-\frac{\hbar^{2}k^{2}}{2\,m_p^{*}}',
            controls: ControlsConfig(children: []),
          ),
          aboutSection: _buildAboutCard(context),
          observeSection: _buildObserveCard(context),
          chartBuilder: (context) => ValueListenableBuilder<_ActivePointState?>(
            valueListenable: _activePointVN,
            builder: (_, __, ___) => _buildChartArea(context, latexMap),
          ),
          rightPanelBuilder: (context, config) =>
              _buildRightPanel(context, latexMap),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Parabolic Band Dispersion (E\u2013k)',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Band Structure',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: const LatexText(
              r'E_c(k)=E_c+\frac{\hbar^{2}k^{2}}{2\,m_n^{*}},\quad E_v(k)=E_v-\frac{\hbar^{2}k^{2}}{2\,m_p^{*}}',
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
                  'Shows energy-momentum dispersion relation ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const LatexText(r'E(k)', scale: 1.0),
                Text(
                  ' for parabolic conduction and valence bands near the band edge. Curvature is determined by effective mass ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const LatexText(r'm^{*}', scale: 1.0),
                Text(
                  '.',
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
          _infoBulletSegments([
            const _InlinePiece.text('Near the band edge, '),
            const _InlinePiece.latex(r'E(k)'),
            const _InlinePiece.text(' is parabolic: '),
            const _InlinePiece.latex(
                r'\Delta E(k)=\frac{\hbar^{2}k^{2}}{2m^{*}}'),
          ]),
          _infoBulletSegments([
            const _InlinePiece.text('Conduction: '),
            const _InlinePiece.latex(r'E_c(k)=E_c+\Delta E(k)'),
            const _InlinePiece.text('; Valence: '),
            const _InlinePiece.latex(r'E_v(k)=E_v-\Delta E(k)'),
          ]),
          _infoBulletSegments([
            const _InlinePiece.text('Curvature from effective mass: smaller '),
            const _InlinePiece.latex(r'm^{*}'),
            const _InlinePiece.text(' gives steeper parabola.'),
          ]),
          _infoBulletSegments([
            const _InlinePiece.text('Group velocity: '),
            const _InlinePiece.latex(r'v_g(k)=\frac{\hbar k}{m^{*}}'),
            const _InlinePiece.text(' (linear in k for parabolic bands).'),
          ]),
          const SizedBox(height: 8),
          Text('Try this:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          _infoBulletSegments([
            const _InlinePiece.text('Change '),
            const _InlinePiece.latex(r'm_n^{*}'),
            const _InlinePiece.text(' and '),
            const _InlinePiece.latex(r'm_p^{*}'),
            const _InlinePiece.text(' to see how band curvature affects carrier velocity.'),
          ]),
          _infoBulletSegments([
            const _InlinePiece.text('Use Î”E mode to compare energy offset from band edges directly.'),
          ]),
          _infoBulletSegments([
            const _InlinePiece.text('Hover curve to inspect values; double-click to pin for comparison.'),
          ]),
        ],
      ),
    );
  }

  Widget _buildChartCard(BuildContext context, LatexSymbolMap latexMap) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _buildChartArea(context, latexMap),
        ),
      ),
    );
  }

  Widget _buildChartArea(BuildContext context, LatexSymbolMap latexMap) {
    final ecEv = _deriveEcEv();
    final data = _buildData(ecEv);

    final series = <_SeriesMeta>[];
    if (_showConduction && data.conduction.isNotEmpty) {
      series.add(_SeriesMeta(id: 'Conduction', points: data.conduction));
    }
    if (_showValence && data.valence.isNotEmpty) {
      series.add(_SeriesMeta(id: 'Valence', points: data.valence));
    }

    if (series.isEmpty) {
      return const Center(child: Text('Enable a band to display the graph.'));
    }

    final yValues =
        series.expand((s) => s.points.map((p) => p.yDisplay)).toList();
    double minY = -1;
    double maxY = 1;
    if (yValues.isNotEmpty) {
      minY = yValues.reduce(math.min);
      maxY = yValues.reduce(math.max);
      final pad = (maxY - minY).abs() * 0.1 + 0.05;
      minY -= pad;
      maxY += pad;
      if (minY == maxY) {
        minY -= 0.5;
        maxY += 0.5;
      }
    }
    if (_lockYAxis) {
      _lockedMinY ??= minY;
      _lockedMaxY ??= maxY;
      minY = _lockedMinY!;
      maxY = _lockedMaxY!;
    } else {
      _lockedMinY = null;
      _lockedMaxY = null;
    }

    final conductionColor = Theme.of(context).colorScheme.primary;
    final valenceColor = Theme.of(context).colorScheme.tertiary;
    final ecLineColor = conductionColor.withValues(alpha: 0.35);
    final evLineColor = valenceColor.withValues(alpha: 0.35);

    final lineBars = <LineChartBarData>[];
    if (_overlayPrevious && _overlaySeries.isNotEmpty) {
      for (final meta in _overlaySeries) {
        final color = meta.id == 'Conduction'
            ? conductionColor.withValues(alpha: 0.25)
            : valenceColor.withValues(alpha: 0.25);
        lineBars.add(LineChartBarData(
          spots: meta.points.map((p) => FlSpot(p.kScaled, p.yDisplay)).toList(),
          color: color,
          barWidth: 2,
          isCurved: true,
          dotData: const FlDotData(show: false),
        ));
      }
    }
    final resolvedPins = _pins
        .map((p) => _resolvePoint(p, ecEv))
        .whereType<_GraphPointWithBand>()
        .toList();
    for (final s in series) {
      final color = s.id == 'Conduction' ? conductionColor : valenceColor;
      lineBars.add(
        LineChartBarData(
          spots: s.points.map((p) => FlSpot(p.kScaled, p.yDisplay)).toList(),
          isCurved: false,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      );
    }

    final legendEntries = <Widget>[
      _legendItem(conductionColor, 'Conduction'),
      _legendItem(valenceColor, 'Valence'),
    ];
    if (_plotMode == PlotMode.absolute) {
      legendEntries.addAll([
        _legendItem(ecLineColor,
            _latexSymbol(latexMap, 'Ec', fallback: r'E_c'),
            dashed: true, latex: true, fontSize: _Typo.body),
        _legendItem(evLineColor,
            _latexSymbol(latexMap, 'Ev', fallback: r'E_v'),
            dashed: true, latex: true, fontSize: _Typo.body),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: legendEntries,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return MouseRegion(
                onExit: (_) => _activePointVN.value = null,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: _handleDoubleTap,
                  child: Stack(
                    children: [
                      LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: _kMaxScaled,
                          minY: minY,
                          maxY: maxY,
                          showingTooltipIndicators: () {
                            final a = _activePointVN.value;
                            if (a == null ||
                                a.barIndex < 0 ||
                                a.barIndex >= lineBars.length) {
                              return <ShowingTooltipIndicators>[];
                            }
                            return [
                              ShowingTooltipIndicators([
                                LineBarSpot(
                                  lineBars[a.barIndex],
                                  a.barIndex,
                                  FlSpot(a.point.kScaled, a.point.yDisplay),
                                ),
                              ]),
                            ];
                          }(),
                          rangeAnnotations: _plotMode == PlotMode.absolute
                              ? RangeAnnotations(horizontalRangeAnnotations: [
                                  HorizontalRangeAnnotation(
                                    y1: ecEv.$2,
                                    y2: ecEv.$1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.08),
                                  ),
                                ])
                              : const RangeAnnotations(),
                          extraLinesData: _plotMode == PlotMode.absolute
                              ? ExtraLinesData(
                                  horizontalLines: [
                                    HorizontalLine(
                                      y: ecEv.$1,
                                      color: ecLineColor,
                                      strokeWidth: 1,
                                      dashArray: [4, 4],
                                      label: HorizontalLineLabel(show: false),
                                    ),
                                    HorizontalLine(
                                      y: ecEv.$2,
                                      color: evLineColor,
                                      strokeWidth: 1,
                                      dashArray: [4, 4],
                                      label: HorizontalLineLabel(show: false),
                                    ),
                                  ],
                                )
                              : const ExtraLinesData(),
                          lineTouchData: LineTouchData(
                            enabled: true,
                            handleBuiltInTouches: false, // Manual control via showingTooltipIndicators
                            distanceCalculator: (touchPoint, spotLocation) {
                              // Use Euclidean distance in pixel space (not k-distance)
                              return math.sqrt(
                                math.pow(touchPoint.dx - spotLocation.dx, 2) +
                                    math.pow(touchPoint.dy - spotLocation.dy, 2),
                              );
                            },
                            getTouchedSpotIndicator: (barData, spotIndexes) {
                              return spotIndexes.map((i) {
                                return TouchedSpotIndicatorData(
                                  FlLine(
                                    color:
                                        barData.color?.withValues(alpha: 0.4),
                                    strokeWidth: 1,
                                    dashArray: [4, 4],
                                  ),
                                  FlDotData(
                                    show: true,
                                    getDotPainter: (_, __, ___, ____) =>
                                        FlDotCirclePainter(
                                      radius: 3,
                                      color: barData.color ??
                                          Theme.of(context).colorScheme.primary,
                                      strokeWidth: 1,
                                      strokeColor: Colors.white,
                                    ),
                                  ),
                                );
                              }).toList();
                            },
                            touchCallback: (event, response) {
                              // Update Point Inspector on hover
                              if (response?.lineBarSpots == null || response!.lineBarSpots!.isEmpty) {
                                _activePointVN.value = null;
                                return;
                              }

                              // Choose the actual nearest spot (fl_chart returns all touched bars)
                              final spots = response.lineBarSpots!;
                              final spot = spots.length == 1
                                  ? spots.first
                                  : spots.cast<TouchLineBarSpot>().reduce(
                                        (a, b) =>
                                            a.distance <= b.distance ? a : b);
                              final overlayCount = (_overlayPrevious && _overlaySeries.isNotEmpty)
                                  ? _overlaySeries.length
                                  : 0;
                              final mainBarIndex = spot.barIndex - overlayCount;
                              if (mainBarIndex < 0 || mainBarIndex >= series.length) return;
                              
                              final meta = series[mainBarIndex];
                              final band = meta.id;
                              final samples = meta.points;
                              final pointIndex = spot.spotIndex;
                              
                              if (pointIndex >= samples.length) return;
                              final point = samples[pointIndex];
                              
                              // Update inspector with current hover point (single band only)
                              _activePointVN.value = _ActivePointState(
                                point: _GraphPointWithBand(
                                  band: band,
                                  k: point.k,
                                  kScaled: point.kScaled,
                                  deltaE: point.deltaE,
                                  eAbs: point.eAbs,
                                  velocity: point.velocity,
                                  yDisplay: point.yDisplay,
                                  colorIndex: null,
                                ),
                                index: pointIndex,
                                barIndex: spot.barIndex,
                              );
                            },
                            touchTooltipData: LineTouchTooltipData(
                              fitInsideHorizontally: true,
                              fitInsideVertically: true,
                              getTooltipItems: (spots) {
                                // When handleBuiltInTouches=false, we manually control tooltips
                                // Show tooltip for active point only
                                final active = _activePointVN.value;
                                if (active == null) return [];
                                
                                final kFormatted = _formatKAxisPlain(active.point.kScaled);
                                final eFormatted = _formatEnergyPlain(active.point.yDisplay);
                                final tooltipText =
                                    '${active.point.band}\nk = $kFormatted\nE = $eFormatted';
                                
                                if (kDebugMode) {
                                  assert(
                                    !tooltipText.contains('\\') &&
                                        !tooltipText.contains('{') &&
                                        !tooltipText.contains('}') &&
                                        !tooltipText.contains('_') &&
                                        !tooltipText.contains('mathrm'),
                                    'Tooltip must not contain LaTeX: $tooltipText',
                                  );
                                }
                                
                                return [
                                  LineTooltipItem(
                                    tooltipText,
                                    TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ];
                              },
                            ),
                          ),
                          gridData: const FlGridData(show: true),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              axisNameWidget: LatexText(
                                  _plotMode == PlotMode.absolute
                                      ? r'E\ \mathrm{(eV)}'
                                      : r'\Delta E\ \mathrm{(eV)}',
                                  style: TextStyle(fontSize: _Typo.body)),
                              sideTitles: const SideTitles(
                                  showTitles: true, reservedSize: 52),
                            ),
                            bottomTitles: AxisTitles(
                              axisNameWidget: LatexText(
                                  r'k\ (\times 10^{10}\;\mathrm{m}^{-1})',
                                  style: TextStyle(fontSize: _Typo.body)),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                interval: _kAxisInterval(),
                                getTitlesWidget: (value, meta) {
                                  final label = _formatKTick(value);
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    space: 6,
                                    child: Text(
                                      label,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  );
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: true),
                          lineBarsData: lineBars,
                        ),
                        key: ValueKey(
                          'para-${_eg.toStringAsFixed(3)}-${_mnEff.toStringAsFixed(3)}-${_mpEff.toStringAsFixed(3)}-${_kMaxScaled.toStringAsFixed(3)}-$_plotMode-${_showConduction}-${_showValence}-$_energyReference-$_materialPreset',
                        ),
                      ),
                      if (_plotMode == PlotMode.absolute)
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _EgMarkerPainter(
                              ec: ecEv.$1,
                              ev: ecEv.$2,
                              eg: _eg,
                              minX: 0,
                              maxX: _kMaxScaled,
                              minY: minY,
                              maxY: maxY,
                              padding: _chartPadding,
                              color: valenceColor.withValues(alpha: 0.55),
                              labelColor: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              xFraction: 0.08,
                            ),
                          ),
                        ),
                      if (_plotMode == PlotMode.absolute)
                        IgnorePointer(
                          child: LayoutBuilder(
                            builder: (context, lbConstraints) {
                              final w = lbConstraints.maxWidth;
                              final h = lbConstraints.maxHeight;
                              final dy = (maxY - minY).abs();
                              final innerW = w - _chartPadding.horizontal;
                              final innerH = h - _chartPadding.vertical;
                              if (dy == 0 || innerW <= 0 || innerH <= 0) {
                                return const SizedBox.shrink();
                              }
                              final px = _chartPadding.left +
                                  0.965 * innerW;
                              double yPos(double y) =>
                                  _chartPadding.top +
                                  (1 - ((y - minY) / dy).clamp(0.0, 1.0)) *
                                      innerH;
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const SizedBox.expand(),
                                  Positioned(
                                    left: px,
                                    top: yPos(ecEv.$1) - 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: ecLineColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: LatexText(r'E_c',
                                          style: TextStyle(
                                              fontSize: _Typo.body,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  Positioned(
                                    left: px,
                                    top: yPos(ecEv.$2) - 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: evLineColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: LatexText(r'E_v',
                                          style: TextStyle(
                                              fontSize: _Typo.body,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      // Pinned points overlay
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _MarkersPainter(
                            pins: resolvedPins,
                            minX: 0,
                            maxX: _kMaxScaled,
                            minY: minY,
                            maxY: maxY,
                            conductionColor: conductionColor,
                            valenceColor: valenceColor,
                            palette: _pinPalette,
                            padding: _chartPadding,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Removed _buildHoverTooltip - now using paint-only hover with intent-driven inspector

  Widget _buildRightPanel(BuildContext context, LatexSymbolMap latexMap) {
    return RepaintBoundary(
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildPointInspector(context, latexMap),
              const SizedBox(height: 12),
              _buildAnimationPanel(),
              const SizedBox(height: 12),
              _buildInsights(context),
              const SizedBox(height: 12),
              _buildControls(context, latexMap),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPointInspector(BuildContext context, LatexSymbolMap latexMap) {
    // Intent-driven inspector: only updates on click/tap or pin, NOT on hover
    return ValueListenableBuilder<_ActivePointState?>(
      valueListenable: _activePointVN,
      builder: (context, activeState, _) {
        final activePoint = activeState?.point;
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            initiallyExpanded: true,
        title: Text('Point Inspector',
            style: TextStyle(
                fontSize: _Typo.title, fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (activePoint == null)
            Text(
                'Hover over a curve to inspect. Double-click to pin or unpin a point.',
                style: TextStyle(fontSize: _Typo.hint))
          else ...[
            Text('${activePoint.band} band',
                style: TextStyle(
                    fontSize: _Typo.sectionLabel,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                _detailRow(
                    labelLatex: r'k',
                    valueLatex:
                        _readoutCache[activePoint.band]?[activeState!.index]?.k ??
                            _formatKLatex(activePoint.k)),
                _detailRow(
                    labelLatex: r'k_{\mathrm{axis}}',
                    valueLatex:
                        _readoutCache[activePoint.band]?[activeState!.index]?.kAxis ??
                            _formatKAxisLatex(activePoint.kScaled)),
                _detailRow(
                    labelLatex: activePoint.band == 'Conduction'
                        ? r'\Delta E_c(k)'
                        : r'\Delta E_v(k)',
                    valueLatex: _readoutCache[activePoint.band]
                            ?[activeState!.index]?.deltaE ??
                        _formatEnergyLatex(activePoint.deltaE)),
                if (_plotMode == PlotMode.absolute)
                  _detailRow(
                      labelLatex: activePoint.band == 'Conduction'
                          ? r'E_c(k)'
                          : r'E_v(k)',
                      valueLatex: _readoutCache[activePoint.band]
                              ?[activeState!.index]?.eAbs ??
                          _formatEnergyLatex(activePoint.eAbs)),
                _detailRow(
                    labelLatex: activePoint.band == 'Conduction'
                        ? r'v_{g,c}(k)'
                        : r'v_{g,v}(k)',
                    valueLatex: _readoutCache[activePoint.band]
                            ?[activeState!.index]?.v ??
                        _formatVelocityLatex(activePoint.velocity)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Hover to inspect. Double-click to pin/unpin.',
                    style: TextStyle(fontSize: _Typo.hint),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimationPanel() {
    return EnhancedAnimationPanel<_AnimTarget>(
      controller: _ParabolicAnimationController(this),
    );
  }

  Widget _buildInsights(BuildContext context) {
    final ecEv = _deriveEcEv();
    final activeState = _activePointVN.value;
    final resolvedActive = activeState == null
        ? null
        : _resolvePoint(
            _PointRef(
                band: activeState.point.band,
                k: activeState.point.k,
                colorIndex: activeState.point.colorIndex),
            ecEv);
    final resolvedPins = _pins
        .map((p) => _resolvePoint(p, ecEv))
        .whereType<_GraphPointWithBand>()
        .toList();
    final kRatio = resolvedActive != null && _kMaxScaled > 0
        ? (resolvedActive.kScaled / _kMaxScaled).clamp(0.0, double.infinity)
        : 0.0;
    final ratioPieces = <_InlinePiece>[
      _InlinePiece.latex(
          r'\frac{k}{k_{\max}} \approx ' + _latexFormatter.formatLatex(kRatio)),
    ];
    if (resolvedActive != null && kRatio > 0.7) {
      ratioPieces.add(const _InlinePiece.text(
          '(near the k range limit; parabolic model accuracy drops)'));
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text('Insights & Pins',
            style: TextStyle(
                fontSize: _Typo.title, fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dynamic insight',
                    style: TextStyle(
                        fontSize: _Typo.sectionLabel,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (resolvedActive == null)
                  _infoBulletSegments(const [
                    _InlinePiece.text('Hover a curve to see '),
                    _InlinePiece.latex(r'\Delta E'),
                    _InlinePiece.text(' and '),
                    _InlinePiece.latex(r'v_g'),
                    _InlinePiece.text('. Double-click to pin.'),
                  ])
                else ...[
                  LatexText(
                    r'\Delta E = \frac{\hbar^{2}k^{2}}{2 m^{*}},\quad v_g = \frac{\hbar k}{m^{*}}',
                    displayMode: true,
                    style: TextStyle(fontSize: _Typo.body),
                  ),
                  const SizedBox(height: 4),
                  LatexText(
                    'k = ${_formatKLatex(resolvedActive.k)},\\quad \\Delta E = ${_formatEnergyLatex(resolvedActive.deltaE)},\\quad v_g = ${_formatVelocityLatex(resolvedActive.velocity)}',
                    style: TextStyle(fontSize: _Typo.value),
                  ),
                  const SizedBox(height: 6),
                  _infoBulletSegments([
                    const _InlinePiece.text('Curvature set by'),
                    const _InlinePiece.latex(r'm^{*}'),
                    const _InlinePiece.text(': smaller'),
                    const _InlinePiece.latex(r'm^{*}'),
                    const _InlinePiece.text(' -> larger'),
                    const _InlinePiece.latex(r'|v_g|'),
                    const _InlinePiece.text(' and Î”E at this k.'),
                  ]),
                  _infoBulletSegments(ratioPieces),
                  _infoBulletSegments([
                    const _InlinePiece.text('Energy relative to band edge:'),
                    _InlinePiece.latex(resolvedActive.band == 'Conduction'
                        ? r'E_c + \Delta E'
                        : r'E_v - \Delta E'),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Pinned points',
                  style: TextStyle(
                      fontSize: _Typo.sectionLabel,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_pins.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() => _pins.clear()),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear all'),
                ),
            ],
          ),
          if (_pins.isEmpty)
            _infoBulletSegments(const [
              _InlinePiece.text('Pin multiple points to compare '),
              _InlinePiece.latex(r'\Delta E'),
              _InlinePiece.text(', E, and '),
              _InlinePiece.latex(r'v_g'),
              _InlinePiece.text(' across bands.'),
            ])
          else
            Column(
              children: resolvedPins.map((p) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.35),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: _pinPalette[
                                  (p.colorIndex ?? 0) % _pinPalette.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text('${p.band} band',
                              style: TextStyle(
                                  fontSize: _Typo.sectionLabel,
                                  fontWeight: FontWeight.w700)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Remove pin',
                            onPressed: () => setState(() => _pins.removeWhere(
                                (pin) => _samePoint(
                                    pin, _PointRef(band: p.band, k: p.k)))),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          LatexText(
                            LatexReadoutFormatter.equation(
                              labelLatex: r'k',
                              valueLatex: _formatKLatex(p.k),
                            ),
                            style: TextStyle(fontSize: _Typo.value),
                          ),
                          LatexText(
                            LatexReadoutFormatter.equation(
                              labelLatex: r'\Delta E(k)',
                              valueLatex: _formatEnergyLatex(p.deltaE),
                            ),
                            style: TextStyle(fontSize: _Typo.value),
                          ),
                          if (_plotMode == PlotMode.absolute)
                            LatexText(
                              LatexReadoutFormatter.equation(
                                labelLatex: r'E(k)',
                                valueLatex: _formatEnergyLatex(p.eAbs),
                              ),
                              style: TextStyle(fontSize: _Typo.value),
                            ),
                          LatexText(
                            LatexReadoutFormatter.equation(
                              labelLatex: r'v_g(k)',
                              valueLatex: _formatVelocityLatex(p.velocity),
                            ),
                            style: TextStyle(fontSize: _Typo.value),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (resolvedPins.length >= 2) ...[
            const SizedBox(height: 8),
            _buildPinComparison(resolvedPins),
          ],
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, LatexSymbolMap latexMap) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text('Controls',
            style: TextStyle(
                fontSize: _Typo.title, fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              _toggle('Conduction', _showConduction,
                  (v) => setState(() => _showConduction = v), _Typo.body),
              _toggle('Valence', _showValence,
                  (v) => setState(() => _showValence = v), _Typo.body),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child:                   Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Energy view',
                        style: TextStyle(
                            fontSize: _Typo.sectionLabel,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    SegmentedButton<PlotMode>(
                      segments: const [
                        ButtonSegment(
                            value: PlotMode.absolute,
                            label: Text('Absolute E')),
                        ButtonSegment(
                            value: PlotMode.delta,
                            label: Text('Î”E (relative)')),
                      ],
                      selected: {_plotMode},
                      onSelectionChanged: (s) =>
                          setState(() => _plotMode = s.first),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 260,
                child: _energyReferenceDropdown(),
              ),
              ElevatedButton.icon(
                onPressed: _resetDefaults,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset demo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Material preset',
                    style: TextStyle(
                        fontSize: _Typo.sectionLabel,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                _materialPresetDropdown(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final double maxWidth = constraints.maxWidth;
              final double sliderWidth = maxWidth > 540 ? 260 : maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  _slider(
                    labelLatex:
                        _latexSymbol(latexMap, 'E_g', fallback: r'E_g') +
                            r'\ (\mathrm{eV})',
                    value: _eg,
                    min: 0.2,
                    max: 2.5,
                    divisions: 230,
                    onChanged: (v) => setState(
                        () => _eg = double.parse(v.toStringAsFixed(3))),
                    valueText: _eg.toStringAsFixed(3),
                    width: sliderWidth,
                  ),
                  _slider(
                    labelLatex: r'\frac{m_n^{*}}{m_0}',
                    value: _mnEff,
                    min: 0.05,
                    max: 2.0,
                    divisions: 195,
                    onChanged: (v) => setState(
                        () => _mnEff = double.parse(v.toStringAsFixed(3))),
                    valueText: _mnEff.toStringAsFixed(3),
                    width: sliderWidth,
                  ),
                  _slider(
                    labelLatex: r'\frac{m_p^{*}}{m_0}',
                    value: _mpEff,
                    min: 0.05,
                    max: 2.0,
                    divisions: 195,
                    onChanged: (v) => setState(
                        () => _mpEff = double.parse(v.toStringAsFixed(3))),
                    valueText: _mpEff.toStringAsFixed(3),
                    width: sliderWidth,
                  ),
                  _slider(
                    labelLatex: r'k_{\max}\ (\times 10^{10}\,\mathrm{m^{-1}})',
                    value: _kMaxScaled,
                    min: 0.2,
                    max: 2.0,
                    divisions: 180,
                    onChanged: (v) => setState(
                        () => _kMaxScaled = double.parse(v.toStringAsFixed(3))),
                    valueText: _kMaxScaled.toStringAsFixed(3),
                    width: sliderWidth,
                  ),
                  _slider(
                    labelLatex: r'\mathrm{Points}',
                    value: _points,
                    min: 100,
                    max: 1000,
                    divisions: 9,
                    onChanged: (v) =>
                        setState(() => _points = v.roundToDouble()),
                    valueText: _points.toInt().toString(),
                    width: sliderWidth,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'k-axis: k × 10^10 m^-1',
                style: TextStyle(fontSize: _Typo.hint),
              ),
              Text('E axis in eV; Î”E if relative mode is selected',
                  style: TextStyle(fontSize: _Typo.hint)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Parabolic approximation is best near k ~ 0; very large k may be unrealistic.',
            style: TextStyle(fontSize: _Typo.hint),
          ),
        ],
      ),
    );
  }

  Widget _energyReferenceDropdown() {
    final isDelta = _plotMode == PlotMode.delta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Energy reference',
            style: TextStyle(
                fontSize: _Typo.sectionLabel, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        DropdownButton<String>(
          value: _energyReference,
          isExpanded: true,
          onChanged: isDelta
              ? null
              : (v) {
                  if (v == null) return;
                  setState(() => _energyReference = v);
                },
          items: [
            DropdownMenuItem(
                value: 'Midgap = 0',
                child: Text('Midgap = 0',
                    style: TextStyle(fontSize: _Typo.body))),
            DropdownMenuItem(
                value: 'Ev = 0',
                child: LatexText(r'E_v = 0',
                    style: TextStyle(fontSize: _Typo.body))),
            DropdownMenuItem(
                value: 'Ec = 0',
                child: LatexText(r'E_c = 0',
                    style: TextStyle(fontSize: _Typo.body))),
          ],
        ),
        if (isDelta)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Reference ignored in Î”E mode.',
              style: TextStyle(
                fontSize: _Typo.hint,
                color: Colors.redAccent.shade200,
              ),
            ),
          ),
      ],
    );
  }

  Widget _materialPresetDropdown() {
    return DropdownButton<String>(
      value: _materialPreset,
      isExpanded: true,
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _materialPreset = v;
          _applyPreset(v);
        });
      },
      items: const [
        DropdownMenuItem(value: 'Custom', child: Text('Custom')),
        DropdownMenuItem(value: 'Silicon (Si)', child: Text('Silicon (Si)')),
        DropdownMenuItem(value: 'GaAs', child: Text('GaAs')),
        DropdownMenuItem(
            value: 'Germanium (Ge)', child: Text('Germanium (Ge)')),
      ],
    );
  }

  // --- Data + formatting helpers ---

  _GraphData _buildData((double, double) ecEv) {
    final pts = _points.toInt().clamp(2, 2000);
    final kMax = (_kMaxScaled * _kDisplayScale).clamp(1e8, 1e11);
    _readoutCache.forEach((_, map) => map.clear());

    final ec = ecEv.$1;
    final ev = ecEv.$2;

    final conduction = <_GraphPoint>[];
    final valence = <_GraphPoint>[];

    for (var i = 0; i < pts; i++) {
      final t = pts == 1 ? 0.0 : i / (pts - 1);
      final k = _kMin + (kMax - _kMin) * t;
      final kScaled = k / _kDisplayScale;
      conduction.add(_computePoint('Conduction', k, kScaled, ec, ev));
      valence.add(_computePoint('Valence', k, kScaled, ec, ev));
      _cacheReadout('Conduction', i, conduction.last);
      _cacheReadout('Valence', i, valence.last);
    }

    _conductionSamples = conduction;
    _valenceSamples = valence;

    return _GraphData(conduction: conduction, valence: valence);
  }

  _GraphPoint _computePoint(
      String band, double k, double kScaled, double ec, double ev) {
    final isConduction = band == 'Conduction';
    final mEff = isConduction ? _mnEff : _mpEff;
    final dEJ = (_hbar * _hbar * k * k) / (2 * (mEff * _m0));
    final deltaE = dEJ / _q;
    final eAbs = isConduction ? ec + deltaE : ev - deltaE;
    final yDisplay =
        _plotMode == PlotMode.delta ? (isConduction ? deltaE : -deltaE) : eAbs;
    final velocity = (_hbar * k) / (mEff * _m0) * (isConduction ? 1 : -1);
    return _GraphPoint(
      k: k,
      kScaled: kScaled,
      deltaE: deltaE,
      eAbs: eAbs,
      velocity: velocity,
      yDisplay: yDisplay,
    );
  }

  (double, double) _deriveEcEv() {
    if (_energyReference == 'Ev = 0') {
      return (_eg, 0.0);
    }
    if (_energyReference == 'Ec = 0') {
      return (0.0, -_eg);
    }
    return (_eg / 2, -_eg / 2);
  }

  int _binarySearchK(List<_GraphPoint> points, double kScaled) {
    var low = 0;
    var high = points.length - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (points[mid].kScaled < kScaled) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    if (low > 0 &&
        (points[low].kScaled - kScaled).abs() >
            (points[low - 1].kScaled - kScaled).abs()) {
      return low - 1;
    }
    return low;
  }


  void _cacheReadout(String band, int index, _GraphPoint p) {
    final bucket = _readoutCache[band]!;
    if (bucket.containsKey(index)) return;
    bucket[index] = _ReadoutCache(
      k: _formatKLatex(p.k),
      kAxis: _formatKAxisLatex(p.kScaled),
      deltaE: _formatEnergyLatex(p.deltaE),
      eAbs: _formatEnergyLatex(p.eAbs),
      v: _formatVelocityLatex(p.velocity),
    );
  }

  _GraphPointWithBand? _resolvePoint(_PointRef ref, (double, double) ecEv) {
    final kMax = _kMaxScaled * _kDisplayScale;
    final clampedK = ref.k.clamp(_kMin, kMax);
    final p = _computePoint(
        ref.band, clampedK, clampedK / _kDisplayScale, ecEv.$1, ecEv.$2);
    return _GraphPointWithBand(
      band: ref.band,
      k: clampedK,
      kScaled: clampedK / _kDisplayScale,
      deltaE: p.deltaE,
      eAbs: p.eAbs,
      velocity: p.velocity,
      yDisplay: p.yDisplay,
      colorIndex: ref.colorIndex,
    );
  }

  // --- Interaction helpers ---

  void _applyPreset(String preset) {
    if (preset == 'Silicon (Si)') {
      _eg = 1.12;
      _mnEff = 0.26;
      _mpEff = 0.39;
    } else if (preset == 'GaAs') {
      _eg = 1.42;
      _mnEff = 0.067;
      _mpEff = 0.50;
    } else if (preset == 'Germanium (Ge)') {
      _eg = 0.66;
      _mnEff = 0.12;
      _mpEff = 0.29;
    }
  }

  void _resetDefaults() {
    _animTimer?.cancel();
    setState(() {
      _plotMode = _defaultState['plotMode'] as PlotMode;
      _energyReference = _defaultState['energyReference'] as String;
      _materialPreset = _defaultState['materialPreset'] as String;
      _eg = _defaultState['eg'] as double;
      _mnEff = _defaultState['mnEff'] as double;
      _mpEff = _defaultState['mpEff'] as double;
      _kMaxScaled = _defaultState['kMaxScaled'] as double;
      _points = _defaultState['points'] as double;
      _showConduction = _defaultState['showConduction'] as bool;
      _showValence = _defaultState['showValence'] as bool;
      _activePointVN.value = null;
      _pins.clear();
      _isAnimating = false;
      _animProgress = 0;
    });
  }

  void _togglePin(_PointRef ref) {
    final existing = _pins.indexWhere((p) => _samePoint(p, ref));
    final colorIndex = ref.colorIndex ?? _nextPinColorIndex();
    setState(() {
      if (existing >= 0) {
        _pins.removeAt(existing);
      } else {
        _pins.add(_PointRef(
          band: ref.band,
          k: ref.k,
          colorIndex: colorIndex,
        ));
      }
    });
  }

  bool _samePoint(_PointRef a, _PointRef b) {
    return a.band == b.band && (a.k - b.k).abs() < 1e6;
  }

  int _nextPinColorIndex() {
    final used = _pins.map((p) => p.colorIndex ?? -1).toSet();
    for (var i = 0; i < _pinPalette.length; i++) {
      if (!used.contains(i)) return i;
    }
    return 0;
  }

  // --- Animation ---

  void _toggleAnimation() {
    if (_isAnimating) {
      _stopAnimation();
    } else {
      _animDirection = _reverseDirection ? -1.0 : 1.0;
      _startAnimation();
    }
  }

  void _handleDoubleTap() {
    final active = _activePointVN.value;
    if (active != null) {
      _togglePin(_PointRef(
          band: active.point.band,
          k: active.point.k,
          colorIndex: active.point.colorIndex ?? _nextPinColorIndex()));
    }
  }

  void _startAnimation() {
    if (_isAnimating) return;
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Animation disabled due to reduced motion preference')),
      );
      return;
    }
    setState(() {
      _isAnimating = true;
    });
    _animTimer = Timer.periodic(const Duration(milliseconds: 36), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
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
    _startAnimation();
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
    _captureOverlaySeries();
    final range = _animRanges[_animTarget]!;
    final value = _lerp(range.start, range.end, _animProgress.clamp(0.0, 1.0));
    switch (_animTarget) {
      case _AnimTarget.eg:
        _eg = value;
        break;
      case _AnimTarget.mn:
        _mnEff = value;
        break;
      case _AnimTarget.mp:
        _mpEff = value;
        break;
      case _AnimTarget.kmax:
        _kMaxScaled = value;
        break;
    }
  }

  void _captureOverlaySeries() {
    if (!_overlayPrevious) return;
    final ecEv = _deriveEcEv();
    final data = _buildData(ecEv);
    final list = <_SeriesMeta>[];
    if (_showConduction) {
      list.add(_SeriesMeta(id: 'Conduction', points: data.conduction));
    }
    if (_showValence) {
      list.add(_SeriesMeta(id: 'Valence', points: data.valence));
    }
    _overlaySeries = list;
  }

  (double, double) _rangeBounds(_AnimTarget target) {
    switch (target) {
      case _AnimTarget.eg:
        return (0.2, 2.5);
      case _AnimTarget.mn:
        return (0.05, 2.0);
      case _AnimTarget.mp:
        return (0.05, 2.0);
      case _AnimTarget.kmax:
        return (0.2, 2.5);
    }
  }

  RangeValues _defaultRangeFor(_AnimTarget target) {
    switch (target) {
      case _AnimTarget.eg:
        return const RangeValues(0.6, 1.6);
      case _AnimTarget.mn:
        return const RangeValues(0.1, 1.2);
      case _AnimTarget.mp:
        return const RangeValues(0.1, 1.2);
      case _AnimTarget.kmax:
        return const RangeValues(0.2, 1.0);
    }
  }

  String _animLabelLatex(_AnimTarget target) {
    final key = _animLabelKeyMap[target];
    if (key != null && _uiLatexLabels.containsKey(key)) {
      return _uiLatexLabels[key]!;
    }
    return r'E_g';
  }

  // --- UI helpers ---

  Widget _legendItem(Color color, String label,
      {bool dashed = false, bool latex = false, double? fontSize}) {
    final textSize = fontSize ?? _Typo.body;
    final marker = dashed
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.0),
                child: Container(width: 6, height: 2, color: color),
              ),
            ),
          )
        : Container(
            height: 8,
            width: 18,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(4)),
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 26, child: Center(child: marker)),
        const SizedBox(width: 6),
        latex
            ? LatexText(label, style: TextStyle(fontSize: textSize))
            : Text(label,
                style: TextStyle(fontSize: textSize),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged,
      double fontSize) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: value,
          onChanged: (v) {
            onChanged(v);
          },
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _slider({
    required String labelLatex,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String valueText,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LatexText(labelLatex,
                  style: TextStyle(
                      fontSize: _Typo.body, fontWeight: FontWeight.w600)),
              Text(valueText, style: TextStyle(fontSize: _Typo.value)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) {
              onChanged(v);
              if (_materialPreset != 'Custom' &&
                  (labelLatex.contains('E_g') ||
                      labelLatex.contains('m_') ||
                      labelLatex.contains('k_{\\max}'))) {
                setState(() => _materialPreset = 'Custom');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _detailRow({required String labelLatex, required String valueLatex}) {
    return LatexReadoutRow(
      labelLatex: labelLatex,
      valueLatex: valueLatex,
    );
  }

  Widget _infoBulletSegments(List<_InlinePiece> parts) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('- ', style: TextStyle(fontSize: _Typo.body)),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: parts
                  .map((p) => p.latex
                      ? LatexText(p.text,
                          style: TextStyle(fontSize: _Typo.body))
                      : Text(p.text, style: TextStyle(fontSize: _Typo.body)))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinComparison(List<_GraphPointWithBand> pins) {
    if (pins.length < 2) return const SizedBox.shrink();
    _GraphPointWithBand? a;
    _GraphPointWithBand? b;
    for (var i = 0; i < pins.length; i++) {
      for (var j = i + 1; j < pins.length; j++) {
        final denom = math
            .max(pins[i].k.abs(), pins[j].k.abs())
            .clamp(1e-12, double.infinity);
        if ((pins[i].k - pins[j].k).abs() / denom < 0.05) {
          a = pins[i];
          b = pins[j];
          break;
        }
      }
    }
    if (a == null || b == null) {
      return const SizedBox.shrink();
    }
    final ratio = b.deltaE.abs() > 0 ? a.deltaE / b.deltaE : double.nan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Compare pins at similar k',
            style: TextStyle(
                fontSize: _Typo.sectionLabel, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        LatexText(
          r'\frac{\Delta E(' +
              a.band[0].toLowerCase() +
              r')}{\Delta E(' +
              b.band[0].toLowerCase() +
              r')} \approx ' +
              (ratio.isFinite
                  ? _latexFormatter.formatLatex(ratio)
                  : r'\mathrm{n/a}'),
          style: TextStyle(fontSize: _Typo.value),
        ),
        const SizedBox(height: 2),
        _infoBulletSegments(const [
          _InlinePiece.text('Smaller '),
          _InlinePiece.latex(r'm^{*}'),
          _InlinePiece.text(' gives larger '),
          _InlinePiece.latex(r'\Delta E'),
          _InlinePiece.text(' and '),
          _InlinePiece.latex(r'|v_g|'),
          _InlinePiece.text(' at the same '),
          _InlinePiece.latex(r'k'),
          _InlinePiece.text('.'),
        ]),
      ],
    );
  }

  // --- Formatting helpers ---

  String _formatKLatex(double k) =>
      LatexReadoutFormatter.valueWithUnitText(k, unit: r'm^{-1}');

  String _formatKAxisLatex(double kScaled) =>
      LatexReadoutFormatter.valueWithUnitText(kScaled * 1e10, unit: r'm^{-1}');

  String _formatEnergyLatex(double e) =>
      LatexReadoutFormatter.valueWithUnitText(e, unit: r'eV', forceSci: false);

  String _formatVelocityLatex(double v) =>
      LatexReadoutFormatter.valueWithUnitText(v, unit: r'm\,s^{-1}');

  /// Plain Unicode formatters for tooltip only (no LaTeX commands).
  String _formatKAxisPlain(double kScaled) =>
      '${LatexNumberFormatter.toUnicodeSci(kScaled * 1e10, sigFigs: 3)} mâ»Â¹';

  String _formatEnergyPlain(double e) =>
      '${LatexNumberFormatter.toUnicodeSci(e, sigFigs: 3)} eV';

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _kAxisInterval() {
    final span = _kMaxScaled.clamp(0.1, 5.0);
    const candidates = [0.02, 0.05, 0.1, 0.2, 0.25, 0.5, 1.0, 2.0];
    final targetTicks = 6;
    final raw = span / targetTicks;
    for (final c in candidates) {
      if (c >= raw) return c;
    }
    return (span / targetTicks).clamp(0.05, 2.0);
  }

  String _formatKTick(double value) {
    final step = _kAxisInterval();
    final v = value.abs() < 1e-9 ? 0.0 : value;
    final decimals = step < 0.1
        ? 2
        : step < 1.0
            ? 1
            : 0;
    return v.toStringAsFixed(decimals);
  }

  String _latexSymbol(LatexSymbolMap map, String key, {String? fallback}) {
    final mapped = map.latexOf(key);
    if (mapped.isNotEmpty) return mapped;
    return fallback ?? key;
  }
}

class _ParabolicAnimationController
    implements EnhancedAnimationController<_AnimTarget> {
  final _ParabolicGraphViewState state;
  _ParabolicAnimationController(this.state);

  void _update(VoidCallback fn) {
    // ignore: invalid_use_of_protected_member
    state.setState(fn);
  }

  @override
  List<_AnimTarget> get parameters => _AnimTarget.values;

  @override
  _AnimTarget get selectedParam => state._animTarget;

  @override
  void selectParam(_AnimTarget param) {
    _update(() {
      state._animTarget = param;
      state._animProgress = 0;
    });
  }

  String _descriptor(_AnimTarget t) {
    switch (t) {
      case _AnimTarget.eg:
        return 'bandgap';
      case _AnimTarget.mn:
        return 'electron mass';
      case _AnimTarget.mp:
        return 'hole mass';
      case _AnimTarget.kmax:
        return 'k range';
    }
  }

  @override
  String dropdownLabel(_AnimTarget param) =>
      '${state._animLabelLatex(param)} (${_descriptor(param)})';

  @override
  String valueLabel(_AnimTarget param) => state._animLabelLatex(param);

  @override
  String unitLabel(_AnimTarget param) {
    switch (param) {
      case _AnimTarget.eg:
        return 'eV';
      case _AnimTarget.mn:
      case _AnimTarget.mp:
        return 'm_0';
      case _AnimTarget.kmax:
        return r'10^{10}\,\mathrm{m^{-1}}';
    }
  }

  @override
  String physicsNote(_AnimTarget param) {
    switch (param) {
      case _AnimTarget.eg:
        return 'Band edges shift; curvature unchanged (midgap fixed).';
      case _AnimTarget.mn:
        return 'Conduction curvature changes: smaller m_n* -> steeper.';
      case _AnimTarget.mp:
        return 'Valence curvature changes: smaller m_p* -> steeper.';
      case _AnimTarget.kmax:
        return 'Changes plotted k-domain extent only.';
    }
  }

  @override
  double get currentValue {
    switch (state._animTarget) {
      case _AnimTarget.eg:
        return state._eg;
      case _AnimTarget.mn:
        return state._mnEff;
      case _AnimTarget.mp:
        return state._mpEff;
      case _AnimTarget.kmax:
        return state._kMaxScaled;
    }
  }

  @override
  void setCurrentValue(double value) {
    if (state._isAnimating) state._stopAnimation();
    _update(() {
      switch (state._animTarget) {
        case _AnimTarget.eg:
          state._eg = value;
          break;
        case _AnimTarget.mn:
          state._mnEff = value;
          break;
        case _AnimTarget.mp:
          state._mpEff = value;
          break;
        case _AnimTarget.kmax:
          state._kMaxScaled = value;
          break;
      }
    });
  }

  @override
  double get rangeMin => state._animRanges[state._animTarget]!.start;

  @override
  double get rangeMax => state._animRanges[state._animTarget]!.end;

  (double, double) _boundsFor(_AnimTarget t) => state._rangeBounds(t);

  @override
  double get absoluteMin => _boundsFor(state._animTarget).$1;

  @override
  double get absoluteMax => _boundsFor(state._animTarget).$2;

  @override
  void setRangeMin(double value) => _update(() {
        final current = state._animRanges[state._animTarget]!;
        state._animRanges[state._animTarget] =
            RangeValues(value, current.end.clamp(value, absoluteMax));
      });

  @override
  void setRangeMax(double value) => _update(() {
        final current = state._animRanges[state._animTarget]!;
        state._animRanges[state._animTarget] =
            RangeValues(current.start.clamp(absoluteMin, value), value);
      });

  @override
  void resetRangeToDefault() => _update(() {
        state._animRanges[state._animTarget] =
            state._defaultRangeFor(state._animTarget);
      });

  @override
  double get speed => state._animSpeed;

  @override
  void setSpeed(double multiplier) =>
      _update(() => state._animSpeed = multiplier);

  @override
  bool get loopEnabled => state._loopEnabled;

  @override
  void setLoopEnabled(bool value) =>
      _update(() => state._loopEnabled = value);

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
  void setLockYAxis(bool value) =>
      _update(() => state._lockYAxis = value);

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

class _GraphData {
  final List<_GraphPoint> conduction;
  final List<_GraphPoint> valence;

  _GraphData({required this.conduction, required this.valence});
}

class _GraphPoint {
  final double k;
  final double kScaled;
  final double deltaE;
  final double eAbs;
  final double velocity;
  final double yDisplay;

  _GraphPoint({
    required this.k,
    required this.kScaled,
    required this.deltaE,
    required this.eAbs,
    required this.velocity,
    required this.yDisplay,
  });
}

class _GraphPointWithBand extends _GraphPoint {
  final String band;
  final int? colorIndex;
  _GraphPointWithBand({
    required this.band,
    required super.k,
    required super.kScaled,
    required super.deltaE,
    required super.eAbs,
    required super.velocity,
    required super.yDisplay,
    this.colorIndex,
  });
}

// Active point state (for inspector, updated on hover)
class _ActivePointState {
  final _GraphPointWithBand point;
  final int index;
  final int barIndex; // fl_chart lineBars index for single-marker display

  const _ActivePointState(
      {required this.point, required this.index, required this.barIndex});
}

class _SeriesMeta {
  final String id;
  final List<_GraphPoint> points;
  _SeriesMeta({required this.id, required this.points});
}

class _PointRef {
  final String band;
  final double k;
  final int? colorIndex;
  const _PointRef({required this.band, required this.k, this.colorIndex});
}

class _InlinePiece {
  final String text;
  final bool latex;
  const _InlinePiece(this.text, this.latex);
  const _InlinePiece.text(this.text) : latex = false;
  const _InlinePiece.latex(this.text) : latex = true;
}

class _MarkersPainter extends CustomPainter {
  final List<_GraphPointWithBand> pins;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final Color conductionColor;
  final Color valenceColor;
  final List<Color> palette;
  final EdgeInsets padding;

  const _MarkersPainter({
    required this.pins,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.conductionColor,
    required this.valenceColor,
    required this.palette,
    required this.padding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dx = (maxX - minX).abs();
    final dy = (maxY - minY).abs();
    final innerWidth = size.width - padding.horizontal;
    final innerHeight = size.height - padding.vertical;
    if (dx == 0 || dy == 0 || innerWidth <= 0 || innerHeight <= 0) return;

    void drawMarker(_GraphPointWithBand p,
        {required Color ringColor, double radius = 7}) {
      final tx = ((p.kScaled - minX) / dx).clamp(0.0, 1.0);
      final ty = (1 - ((p.yDisplay - minY) / dy)).clamp(0.0, 1.0);
      final pos = Offset(
          padding.left + tx * innerWidth, padding.top + ty * innerHeight);
      final fill = p.band == 'Conduction' ? conductionColor : valenceColor;
      final ringPaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      final fillPaint = Paint()
        ..color = fill
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, radius, ringPaint);
      canvas.drawCircle(pos, radius - 3, fillPaint);
    }

    // Draw pinned points - color-coded by band (conduction/valence)
    for (final p in pins) {
      final bandColor = p.band == 'Conduction' ? conductionColor : valenceColor;
      final ringColor = bandColor.withValues(alpha: 0.9);
      drawMarker(p, ringColor: ringColor, radius: 7);
    }
  }

  @override
  bool shouldRepaint(covariant _MarkersPainter oldDelegate) {
    return oldDelegate.pins != pins ||
        oldDelegate.minX != minX ||
        oldDelegate.maxX != maxX ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.padding != padding ||
        oldDelegate.conductionColor != conductionColor ||
        oldDelegate.valenceColor != valenceColor ||
        oldDelegate.palette != palette;
  }
}

class _EgMarkerPainter extends CustomPainter {
  final double ec;
  final double ev;
  final double eg;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final EdgeInsets padding;
  final Color color;
  final Color labelColor;
  final double xFraction;

  const _EgMarkerPainter({
    required this.ec,
    required this.ev,
    required this.eg,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.padding,
    required this.color,
    required this.labelColor,
    required this.xFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dx = (maxX - minX).abs();
    final dy = (maxY - minY).abs();
    final innerWidth = size.width - padding.horizontal;
    final innerHeight = size.height - padding.vertical;
    if (dx == 0 || dy == 0 || innerWidth <= 0 || innerHeight <= 0) return;

    // Place bracket slightly inside when minX=0 (per spec: k_ref = 0.02*k_max)
    final chosenX = minX.abs() < 1e-9 ? 0.02 * maxX : minX + dx * xFraction.clamp(0.05, 0.98);
    final tx = ((chosenX - minX) / dx).clamp(0.0, 1.0);
    final px = padding.left + tx * innerWidth;

    double yToScreen(double y) =>
        padding.top + (1 - ((y - minY) / dy).clamp(0.0, 1.0)) * innerHeight;

    final pyTop = yToScreen(math.max(ec, ev));
    final pyBottom = yToScreen(math.min(ec, ev));
    final midY = (pyTop + pyBottom) / 2;

    final paintLine = Paint()
      ..color = color
      ..strokeWidth = 2;

    // Vertical segment from Ev to Ec only (not full-height)
    canvas.drawLine(Offset(px, pyTop), Offset(px, pyBottom), paintLine);

    void drawBracketEnd(double y, double direction) {
      const double len = 8;
      const double head = 4;
      canvas.drawLine(Offset(px, y), Offset(px, y + len * direction), paintLine);
      canvas.drawLine(Offset(px, y), Offset(px - head, y + head * direction),
          paintLine);
      canvas.drawLine(Offset(px, y), Offset(px + head, y + head * direction),
          paintLine);
    }

    drawBracketEnd(pyTop, 1);
    drawBracketEnd(pyBottom, -1);

    final labelText = 'Eg = ${eg.toStringAsFixed(3)} eV';
    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: TextStyle(
          color: labelColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelOffset = Offset(px + 10, midY - textPainter.height / 2);
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelOffset.dx - 4,
        labelOffset.dy - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      ),
      const Radius.circular(4),
    );
    final bgPaint = Paint()..color = color.withValues(alpha: 0.2);
    canvas.drawRRect(bgRect, bgPaint);
    textPainter.paint(canvas, labelOffset);
  }

  @override
  bool shouldRepaint(covariant _EgMarkerPainter oldDelegate) {
    return ec != oldDelegate.ec ||
        ev != oldDelegate.ev ||
        eg != oldDelegate.eg ||
        minX != oldDelegate.minX ||
        maxX != oldDelegate.maxX ||
        minY != oldDelegate.minY ||
        maxY != oldDelegate.maxY ||
        color != oldDelegate.color ||
        labelColor != oldDelegate.labelColor ||
        xFraction != oldDelegate.xFraction ||
        padding != oldDelegate.padding;
  }
}

class _ReadoutCache {
  final String k;
  final String kAxis;
  final String deltaE;
  final String eAbs;
  final String v;
  _ReadoutCache(
      {required this.k,
      required this.kAxis,
      required this.deltaE,
      required this.eAbs,
      required this.v});
}


