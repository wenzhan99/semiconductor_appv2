import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../graphs/common/latex_readout.dart';
import '../theme/chart_style.dart';

class DirectIndirectGraphPage extends StatefulWidget {
  const DirectIndirectGraphPage({super.key});

  @override
  State<DirectIndirectGraphPage> createState() =>
      _DirectIndirectGraphPageState();
}

enum GapType { direct, indirect }

enum EnergyReference { midgap, evZero, ecZero }

enum AnimateParam { k0, eg, mnStar, mpStar }

enum LoopMode { off, loop, pingPong }

class _SelectedPoint {
  final String band;
  final double k; // m^-1
  final double kScaled; // x1e10 m^-1
  final double energy; // eV

  _SelectedPoint({
    required this.band,
    required this.k,
    required this.kScaled,
    required this.energy,
  });
}

class _DirectIndirectGraphPageState extends State<DirectIndirectGraphPage> {
  int _chartVersion = 0;
  GapType _gapType = GapType.direct;
  String _preset = 'GaAs (Direct)';

  double _eg = 1.42;
  double _mnEff = 0.067;
  double _mpEff = 0.50;
  double _k0Scaled = 0.0; // x1e10 m^-1
  double _kMaxScaled = 1.2; // x1e10 m^-1
  double _points = 600;

  bool _showTransitions = true;
  bool _showBandEdges = true;
  EnergyReference _energyReference = EnergyReference.midgap;

  // Zoom & Pan state
  double _zoomScale = 1.0;
  double _panOffsetX = 0.0;
  double _panOffsetY = 0.0;
  bool _scaleLineWidthWithZoom = false;

  // Animation state
  bool _isAnimating = false;
  Timer? _animationTimer;
  double _animationProgress = 0.0;
  AnimateParam _animateParam = AnimateParam.k0;
  double _animateSpeed = 1.0;
  LoopMode _loopMode = LoopMode.loop;
  int _animationDirection = 1;
  final Map<AnimateParam, _AnimRange> _animateRanges = {
    AnimateParam.k0: _AnimRange(min: 0.0, max: 1.2),
    AnimateParam.eg: _AnimRange(min: 0.5, max: 2.0),
    AnimateParam.mnStar: _AnimRange(min: 0.05, max: 2.0),
    AnimateParam.mpStar: _AnimRange(min: 0.05, max: 2.0),
  };
  bool _overlayPreviousCurve = false;
  _GraphData? _previousGraphData;
  _GraphData? _lastGraphData;
  bool _lockYAxis = false;
  double? _lockedMinY;
  double? _lockedMaxY;
  bool _holdSelectedK = false;

  // Store previous params for dynamic observations
  Map<String, double>? _prevParams;

  static const double _kDisplayScale = 1e10; // display k in 1e10 m^-1
  static const double _hbar = 1.054571817e-34; // J*s
  static const double _m0 = 9.1093837015e-31; // kg
  static const double _q = 1.602176634e-19; // C

  _SelectedPoint? _selectedPoint;

  @override
  void initState() {
    super.initState();
    _syncAnimationProgressWithCurrentParam();
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  void _updateAndRebuild(void Function() updater) {
    _snapshotGraphForOverlay();
    setState(() {
      updater();
      _refreshSelectedPointIfHeld();
      _syncAnimationProgressWithCurrentParam();
      _chartVersion++;
    });
  }

  static final Map<String, _Preset> _presets = {
    'GaAs (Direct)': _Preset(
      eg: 1.42,
      mnEff: 0.067,
      mpEff: 0.50,
      k0Scaled: 0.0,
      kMaxScaled: 1.2,
      gapType: GapType.direct,
    ),
    'Si (Indirect)': _Preset(
      eg: 1.12,
      mnEff: 0.26,
      mpEff: 0.39,
      k0Scaled: 0.85,
      kMaxScaled: 1.2,
      gapType: GapType.indirect,
    ),
  };

  static const _defaultState = {
    'preset': 'GaAs (Direct)',
    'gapType': GapType.direct,
    'eg': 1.42,
    'mnEff': 0.067,
    'mpEff': 0.50,
    'k0Scaled': 0.0,
    'kMaxScaled': 1.2,
    'points': 600.0,
    'showTransitions': true,
    'showBandEdges': true,
    'energyReference': EnergyReference.midgap,
  };

  @override
  Widget build(BuildContext context) {
    _clampK0();
    final edges = _bandEdges();
    final ec = edges.ec;
    final ev = edges.ev;

    final kVbm = 0.0;
    final kCbmScaled = _gapType == GapType.direct ? 0.0 : _k0Scaled;
    final kCbm = kCbmScaled * _kDisplayScale;
    final evAtVbm = ev;
    final ecAtK0 = _conductionEnergy(k: kCbm);
    final ecAtGamma = _conductionEnergy(k: 0);

    final egDirect = (ecAtGamma - evAtVbm).clamp(-100.0, 100.0);
    final egIndirect = (ecAtK0 - evAtVbm).clamp(-100.0, 100.0);

    final bandColors = (
      conduction: Theme.of(context).colorScheme.primary,
      valence: Theme.of(context).colorScheme.tertiary,
    );
    final transitionColors = (
      photon: Theme.of(context).colorScheme.secondary,
      phonon: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Direct vs Indirect Bandgap')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive breakpoints
          final isMedium =
              constraints.maxWidth >= 750 && constraints.maxWidth < 1100;
          final isNarrow = constraints.maxWidth < 750;

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
                  child: isNarrow
                      ? _buildNarrowLayout(
                          context,
                          ec,
                          ev,
                          kVbm,
                          kCbm,
                          kCbmScaled,
                          evAtVbm,
                          ecAtGamma,
                          egDirect,
                          egIndirect,
                          bandColors,
                          transitionColors,
                          isMedium,
                        )
                      : _buildWideLayout(
                          context,
                          ec,
                          ev,
                          kVbm,
                          kCbm,
                          kCbmScaled,
                          evAtVbm,
                          ecAtGamma,
                          egDirect,
                          egIndirect,
                          bandColors,
                          transitionColors,
                          isMedium,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    double ec,
    double ev,
    double kVbm,
    double kCbm,
    double kCbmScaled,
    double evAtVbm,
    double ecAtGamma,
    double egDirect,
    double egIndirect,
    ({Color conduction, Color valence}) bandColors,
    ({Color photon, Color phonon}) transitionColors,
    bool isMedium,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Chart first
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 300,
              maxHeight: 400,
            ),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _buildChartArea(
                  context: context,
                  ec: ec,
                  ev: ev,
                  kVbm: kVbm,
                  kCbm: kCbm,
                  kCbmScaled: kCbmScaled,
                  evAtVbm: evAtVbm,
                  ecAtGamma: ecAtGamma,
                  egDirect: egDirect,
                  egIndirect: egIndirect,
                  bandColors: bandColors,
                  transitionColors: transitionColors,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Controls below
          _buildGapReadout(context, egDirect, egIndirect, kCbmScaled),
          const SizedBox(height: 12),
          _buildBandEdgeReadout(context, ec, ev, egDirect, egIndirect),
          const SizedBox(height: 12),
          _buildPointInspector(context),
          const SizedBox(height: 12),
          _buildAnimationControls(context),
          const SizedBox(height: 12),
          _buildDynamicObservations(context, egDirect, egIndirect, kCbmScaled),
          const SizedBox(height: 12),
          _buildControls(context),
        ],
      ),
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    double ec,
    double ev,
    double kVbm,
    double kCbm,
    double kCbmScaled,
    double evAtVbm,
    double ecAtGamma,
    double egDirect,
    double egIndirect,
    ({Color conduction, Color valence}) bandColors,
    ({Color photon, Color phonon}) transitionColors,
    bool isMedium,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart left (2/3 width)
        Expanded(
          flex: 2,
          child: Card(
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 400),
                child: _buildChartArea(
                  context: context,
                  ec: ec,
                  ev: ev,
                  kVbm: kVbm,
                  kCbm: kCbm,
                  kCbmScaled: kCbmScaled,
                  evAtVbm: evAtVbm,
                  ecAtGamma: ecAtGamma,
                  egDirect: egDirect,
                  egIndirect: egIndirect,
                  bandColors: bandColors,
                  transitionColors: transitionColors,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Right panel (1/3 width, scrollable)
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildGapReadout(context, egDirect, egIndirect, kCbmScaled),
                const SizedBox(height: 12),
                _buildBandEdgeReadout(context, ec, ev, egDirect, egIndirect),
                const SizedBox(height: 12),
                _buildPointInspector(context),
                const SizedBox(height: 12),
                _buildAnimationControls(context),
                const SizedBox(height: 12),
                _buildDynamicObservations(
                    context, egDirect, egIndirect, kCbmScaled),
                const SizedBox(height: 12),
                _buildControls(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Direct vs Indirect Bandgap (Schematic E–k)',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Energy & Band Structure',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: false,
        title: const Text('What you should observe',
            style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _infoBullet(
              'Direct bandgap: CBM and VBM occur at the same k → vertical (photon) transition possible.'),
          _infoBullet(
              'Indirect bandgap: CBM is shifted to k0 ≠ 0 → phonon is needed to conserve momentum.'),
          _infoBullet(
              'Eg_indirect is the true minimum gap; Eg_direct is higher for indirect materials.'),
          const SizedBox(height: 8),
          const Text('Try this:',
              style: TextStyle(fontWeight: FontWeight.w700)),
          _infoBullet(
              'Switch between GaAs and Si presets and see the CB minimum shift.'),
          _infoBullet(
              'Turn on transitions and compare vertical vs diagonal transition.'),
          _infoBullet('Drag k0 and watch Eg_indirect change.'),
          _infoBullet('Use Animation to see parameters sweep smoothly.'),
          _infoBullet('Zoom in/out and pan to examine details.'),
        ],
      ),
    );
  }

  Widget _infoBullet(String text) {
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

  Widget _buildGapReadout(BuildContext context, double egDirect,
      double egIndirect, double kCbmScaled) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gap readouts',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Eg_direct'),
                Text('${egDirect.toStringAsFixed(3)} eV',
                    style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Eg_indirect'),
                Text('${egIndirect.toStringAsFixed(3)} eV',
                    style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
            const SizedBox(height: 8),
            Text('CBM k ≈ ${kCbmScaled.toStringAsFixed(3)} ×10¹⁰ m⁻¹'),
          ],
        ),
      ),
    );
  }

  Widget _buildBandEdgeReadout(BuildContext context, double ec, double ev,
      double egDirect, double egIndirect) {
    return Card(
      elevation: 1,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Band-edge readout',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ec'),
                Text('${_formatEnergy(ec)} eV',
                    style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ev'),
                Text('${_formatEnergy(ev)} eV',
                    style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Eg (Ec - Ev)'),
                Text('${(ec - ev).toStringAsFixed(3)} eV',
                    style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartArea({
    required BuildContext context,
    required double ec,
    required double ev,
    required double kVbm,
    required double kCbm,
    required double kCbmScaled,
    required double evAtVbm,
    required double ecAtGamma,
    required double egDirect,
    required double egIndirect,
    required ({Color conduction, Color valence}) bandColors,
    required ({Color photon, Color phonon}) transitionColors,
  }) {
    final viewRange = _currentViewXRange();
    final data = _buildData(viewRange.$1, viewRange.$2);
    final series = <_SeriesMeta>[
      _SeriesMeta(id: 'Conduction', points: data.conduction),
      _SeriesMeta(id: 'Valence', points: data.valence),
    ];

    final yValues =
        series.expand((s) => s.points.map((p) => p.energy)).toList();
    final transitionYs = <double>[
      if (_showTransitions) evAtVbm,
      if (_showTransitions) ecAtGamma,
      if (_showTransitions && _gapType == GapType.indirect)
        _conductionEnergy(k: kCbm),
    ];
    final allY = [...yValues, ...transitionYs];
    double minY = -1;
    double maxY = 1;
    if (allY.isNotEmpty) {
      minY = allY.reduce(math.min);
      maxY = allY.reduce(math.max);
      final pad = (maxY - minY).abs() * 0.15 + 0.1;
      minY -= pad;
      maxY += pad;
    }

    if (_lockYAxis) {
      _lockedMinY ??= minY;
      _lockedMaxY ??= maxY;
      minY = _lockedMinY!;
      maxY = _lockedMaxY!;
    } else {
      _lockedMinY = minY;
      _lockedMaxY = maxY;
    }

    // Apply zoom and pan
    final centerY = (minY + maxY) / 2;
    final rangeY = (maxY - minY) / _zoomScale;
    final zoomedMinY = centerY - rangeY / 2 + _panOffsetY;
    final zoomedMaxY = centerY + rangeY / 2 + _panOffsetY;

    final zoomedMinX = viewRange.$1;
    final zoomedMaxX = viewRange.$2;
    final lineWidth = _scaleLineWidthWithZoom
        ? 2 * math.sqrt(_zoomScale.clamp(0.5, 5.0))
        : 2.0;

    final lineBars = <LineChartBarData>[
      LineChartBarData(
        spots:
            series[0].points.map((p) => FlSpot(p.kScaled, p.energy)).toList(),
        isCurved: false,
        color: bandColors.conduction,
        barWidth: lineWidth,
        dotData: const FlDotData(show: false),
      ),
      LineChartBarData(
        spots:
            series[1].points.map((p) => FlSpot(p.kScaled, p.energy)).toList(),
        isCurved: false,
        color: bandColors.valence,
        barWidth: lineWidth,
        dotData: const FlDotData(show: false),
      ),
    ];

    if (_overlayPreviousCurve && _previousGraphData != null) {
      final prev = _previousGraphData!;
      final fadedWidth = math.max(1.0, lineWidth * 0.75);
      lineBars.insertAll(0, [
        LineChartBarData(
          spots:
              prev.conduction.map((p) => FlSpot(p.kScaled, p.energy)).toList(),
          isCurved: false,
          color: bandColors.conduction.withValues(alpha: 0.35),
          barWidth: fadedWidth,
          dashArray: const [6, 4],
          dotData: const FlDotData(show: false),
        ),
        LineChartBarData(
          spots: prev.valence.map((p) => FlSpot(p.kScaled, p.energy)).toList(),
          isCurved: false,
          color: bandColors.valence.withValues(alpha: 0.35),
          barWidth: fadedWidth,
          dashArray: const [6, 4],
          dotData: const FlDotData(show: false),
        ),
      ]);
    }

    if (_showTransitions) {
      lineBars.add(
        LineChartBarData(
          spots: [
            FlSpot(kVbm / _kDisplayScale, evAtVbm),
            FlSpot(kVbm / _kDisplayScale, ecAtGamma),
          ],
          isCurved: false,
          color: transitionColors.photon,
          barWidth: 2,
          dashArray: [6, 3],
          dotData: FlDotData(
            show: true,
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
              radius: 3,
              color: transitionColors.photon,
              strokeWidth: 1,
              strokeColor: Colors.white,
            ),
          ),
        ),
      );
      if (_gapType == GapType.indirect) {
        lineBars.add(
          LineChartBarData(
            spots: [
              FlSpot(kVbm / _kDisplayScale, evAtVbm),
              FlSpot(kCbmScaled, _conductionEnergy(k: kCbm)),
            ],
            isCurved: false,
            color: transitionColors.phonon,
            barWidth: 2,
            dashArray: [4, 4],
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: transitionColors.phonon,
                strokeWidth: 1,
                strokeColor: Colors.white,
              ),
            ),
          ),
        );
      }
    }

    lineBars.addAll([
      LineChartBarData(
        spots: [FlSpot(kVbm / _kDisplayScale, evAtVbm)],
        isCurved: false,
        color: Colors.transparent,
        barWidth: 0,
        dotData: FlDotData(
          show: true,
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
            radius: 4,
            color: bandColors.valence,
            strokeWidth: 1.5,
            strokeColor: Colors.white,
          ),
        ),
      ),
      LineChartBarData(
        spots: [FlSpot(kCbmScaled, _conductionEnergy(k: kCbm))],
        isCurved: false,
        color: Colors.transparent,
        barWidth: 0,
        dotData: FlDotData(
          show: true,
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
            radius: 4.5,
            color: bandColors.conduction,
            strokeWidth: 1.5,
            strokeColor: Colors.white,
          ),
        ),
      ),
    ]);

    _lastGraphData = data;

    final modeLabel = _gapType == GapType.direct
        ? 'Direct: CBM and VBM at same k (vertical transition possible)'
        : 'Indirect: CBM shifted to k0 ≠ 0 (phonon needed for momentum)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            modeLabel,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _legendSwatch(bandColors.conduction, 'Conduction'),
                  _legendSwatch(bandColors.valence, 'Valence'),
                  if (_showTransitions)
                    _legendDash(transitionColors.photon, 'Photon'),
                  if (_showTransitions && _gapType == GapType.indirect)
                    _legendDash(transitionColors.phonon, 'Phonon'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildZoomControls(),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _toggle('Lock y-axis', _lockYAxis, (v) {
              setState(() {
                _lockYAxis = v;
                if (!_lockYAxis) {
                  _lockedMinY = null;
                  _lockedMaxY = null;
                }
                _chartVersion++;
              });
            }),
            _toggle('Overlay previous curve', _overlayPreviousCurve, (v) {
              setState(() {
                _overlayPreviousCurve = v;
                if (!_overlayPreviousCurve) {
                  _previousGraphData = null;
                } else if (_lastGraphData != null) {
                  _previousGraphData = _lastGraphData;
                }
                _chartVersion++;
              });
            }),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                if (HardwareKeyboard.instance.isControlPressed) {
                  // Ctrl+Scroll to zoom
                  final delta = event.scrollDelta.dy;
                  _handleZoom(delta > 0 ? -0.1 : 0.1);
                }
              }
            },
            child: GestureDetector(
              onPanUpdate: _zoomScale > 1.0
                  ? (details) {
                      setState(() {
                        _panOffsetX -= details.delta.dx * 0.01;
                        _panOffsetY += details.delta.dy * 0.01;
                        _chartVersion++;
                      });
                    }
                  : null,
              child: LineChart(
                key: ValueKey('direct-$_chartVersion'),
                LineChartData(
                  minX: zoomedMinX,
                  maxX: zoomedMaxX,
                  minY: zoomedMinY,
                  maxY: zoomedMaxY,
                  extraLinesData: _showBandEdges
                      ? ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: ec,
                              color:
                                  bandColors.conduction.withValues(alpha: 0.35),
                              strokeWidth: 1,
                              dashArray: [4, 4],
                            ),
                            HorizontalLine(
                              y: ev,
                              color: bandColors.valence.withValues(alpha: 0.35),
                              strokeWidth: 1,
                              dashArray: [4, 4],
                            ),
                          ],
                        )
                      : const ExtraLinesData(),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    handleBuiltInTouches: true,
                    getTouchedSpotIndicator: (barData, spotIndexes) {
                      return spotIndexes.map((i) {
                        return TouchedSpotIndicatorData(
                          FlLine(
                            color: barData.color?.withValues(alpha: 0.4) ??
                                Theme.of(context).colorScheme.primary,
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
                      final spots = response?.lineBarSpots;
                      if (spots == null || spots.isEmpty) return;
                      final touchable = spots
                          .where((s) => s.barIndex < series.length)
                          .toList();
                      if (touchable.isEmpty) return;
                      final refX = touchable.first.x;
                      final refY = touchable.first.y;
                      final best = touchable.reduce((a, b) {
                        final da = (a.x - refX).abs() + (a.y - refY).abs();
                        final db = (b.x - refX).abs() + (b.y - refY).abs();
                        return da < db ? a : b;
                      });
                      final meta = series[best.barIndex];
                      final nearest = _nearestPoint(meta.points, best.x);
                      if (nearest != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() {
                            _selectedPoint = _SelectedPoint(
                              band: meta.id,
                              k: nearest.k,
                              kScaled: nearest.kScaled,
                              energy: nearest.energy,
                            );
                          });
                        });
                      }
                    },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) =>
                          List<LineTooltipItem?>.filled(spots.length, null),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: Text('E (eV)',
                          style: context.chartStyle.axisTitleTextStyle),
                      axisNameSize: 44,
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: context.chartStyle.leftReservedSize,
                        getTitlesWidget: (value, meta) {
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
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text('k (×10¹⁰ m⁻¹)',
                          style: context.chartStyle.axisTitleTextStyle),
                      axisNameSize: 40,
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: context.chartStyle.bottomReservedSize,
                        interval: 0.4 / _zoomScale,
                        getTitlesWidget: (value, meta) {
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
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: lineBars,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZoomControls() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.zoom_in, size: 20),
              tooltip: 'Zoom In',
              onPressed: () => _handleZoom(0.2),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out, size: 20),
              tooltip: 'Zoom Out',
              onPressed: () => _handleZoom(-0.2),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: const Icon(Icons.fit_screen, size: 20),
              tooltip: 'Reset/Fit',
              onPressed: _resetZoom,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Tooltip(
              message: 'Scale line width with zoom (optional)',
              child: Switch(
                value: _scaleLineWidthWithZoom,
                onChanged: (v) => setState(() {
                  _scaleLineWidthWithZoom = v;
                  _chartVersion++;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleZoom(double delta) {
    setState(() {
      _zoomScale = (_zoomScale + delta).clamp(0.5, 5.0);
      _refreshSelectedPointIfHeld();
      _chartVersion++;
    });
  }

  void _resetZoom() {
    setState(() {
      _zoomScale = 1.0;
      _panOffsetX = 0.0;
      _panOffsetY = 0.0;
      _refreshSelectedPointIfHeld();
      _chartVersion++;
    });
  }

  Widget _buildAnimationControls(BuildContext context) {
    final range = _animateRanges[_animateParam]!;
    final domain = _paramDomain(_animateParam);
    final currentValue = _currentAnimatedValue().clamp(range.min, range.max);
    final paramLabel = _animateParamLabel(_animateParam);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: false,
        title: const Text('Animation',
            style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Animate parameter:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButton<AnimateParam>(
                value: _animateParam,
                isExpanded: true,
                onChanged: (v) {
                  if (v == null) return;
                  _stopAnimation();
                  setState(() {
                    _animateParam = v;
                    _syncAnimationProgressWithCurrentParam();
                  });
                },
                items: const [
                  DropdownMenuItem(value: AnimateParam.k0, child: Text('k0')),
                  DropdownMenuItem(value: AnimateParam.eg, child: Text('Eg')),
                  DropdownMenuItem(
                      value: AnimateParam.mnStar, child: Text('mn*')),
                  DropdownMenuItem(
                      value: AnimateParam.mpStar, child: Text('mp*')),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Range: ${range.min.toStringAsFixed(3)} -> ${range.max.toStringAsFixed(3)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              RangeSlider(
                values: RangeValues(range.min, range.max),
                min: domain.min,
                max: domain.max,
                divisions: 200,
                labels: RangeLabels(
                    range.min.toStringAsFixed(2), range.max.toStringAsFixed(2)),
                onChanged: _updateAnimateRange,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$paramLabel = ${currentValue.toStringAsFixed(3)}'),
                  Text(
                      'Direction: ${_animationDirection > 0 ? 'Forward' : 'Reverse'}'),
                ],
              ),
              Slider(
                value: currentValue,
                min: range.min,
                max: range.max,
                divisions: _divisionsForParam(_animateParam),
                onChangeStart: (_) {
                  if (_isAnimating) _stopAnimation();
                },
                onChanged: _handleManualScrub,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isAnimating ? _stopAnimation : _startAnimation,
                    icon: Icon(_isAnimating ? Icons.pause : Icons.play_arrow),
                    label: Text(_isAnimating ? 'Pause' : 'Play'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _restartAnimation(),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Restart'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _reverseAnimationDirection,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Reverse'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Loop mode',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      SegmentedButton<LoopMode>(
                        segments: const [
                          ButtonSegment(
                              value: LoopMode.off, label: Text('Off')),
                          ButtonSegment(
                              value: LoopMode.loop, label: Text('Loop')),
                          ButtonSegment(
                              value: LoopMode.pingPong,
                              label: Text('PingPong')),
                        ],
                        selected: {_loopMode},
                        onSelectionChanged: (s) =>
                            setState(() => _loopMode = s.first),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 240,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Speed: ${_animateSpeed.toStringAsFixed(2)}x',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Slider(
                          value: _animateSpeed,
                          min: 0.25,
                          max: 3.0,
                          divisions: 22,
                          onChanged: (v) => setState(() => _animateSpeed = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Hold selected k'),
                value: _holdSelectedK,
                onChanged: (v) => setState(() => _holdSelectedK = v ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              if (_isAnimating)
                LinearProgressIndicator(
                    value: _animationProgress.clamp(0.0, 1.0)),
            ],
          ),
        ],
      ),
    );
  }

  String _animateParamLabel(AnimateParam param) {
    switch (param) {
      case AnimateParam.k0:
        return 'k0 (x10^10 m^-1)';
      case AnimateParam.eg:
        return 'Eg (eV)';
      case AnimateParam.mnStar:
        return 'mn* (x m0)';
      case AnimateParam.mpStar:
        return 'mp* (x m0)';
    }
  }

  double _currentAnimatedValue() {
    switch (_animateParam) {
      case AnimateParam.k0:
        return _k0Scaled;
      case AnimateParam.eg:
        return _eg;
      case AnimateParam.mnStar:
        return _mnEff;
      case AnimateParam.mpStar:
        return _mpEff;
    }
  }

  ({double min, double max}) _paramDomain(AnimateParam param) {
    switch (param) {
      case AnimateParam.k0:
        return (min: 0.0, max: 1.5);
      case AnimateParam.eg:
        return (min: 0.2, max: 2.5);
      case AnimateParam.mnStar:
      case AnimateParam.mpStar:
        return (min: 0.05, max: 2.0);
    }
  }

  int _divisionsForParam(AnimateParam param) {
    switch (param) {
      case AnimateParam.eg:
        return 230;
      case AnimateParam.mnStar:
      case AnimateParam.mpStar:
        return 195;
      case AnimateParam.k0:
        return 150;
    }
  }

  double _normalizeToRange(double value, _AnimRange range) {
    final span = (range.max - range.min).abs();
    if (span < 1e-9) return 0.0;
    return ((value - range.min) / span).clamp(0.0, 1.0);
  }

  void _syncAnimationProgressWithCurrentParam() {
    final range = _getAnimationRange(_animateParam);
    _animationProgress = _normalizeToRange(_currentAnimatedValue(), range);
  }

  void _snapshotGraphForOverlay() {
    if (_overlayPreviousCurve && _lastGraphData != null) {
      _previousGraphData = _lastGraphData;
    }
  }

  void _refreshSelectedPointIfHeld() {
    if (_selectedPoint == null) return;
    if (!_holdSelectedK) {
      _selectedPoint = null;
      return;
    }
    final sp = _selectedPoint!;
    final edges = _bandEdges();
    final k0 = (_gapType == GapType.direct ? 0.0 : _k0Scaled) * _kDisplayScale;
    final updatedEnergy = sp.band == 'Valence'
        ? edges.ev - _bandEnergyTerm(sp.k, _mpEff)
        : edges.ec + _bandEnergyTerm(sp.k - k0, _mnEff);
    _selectedPoint = _SelectedPoint(
      band: sp.band,
      k: sp.k,
      kScaled: sp.kScaled,
      energy: updatedEnergy,
    );
  }

  void _applyAnimatedParamValue(double value,
      {bool fromAnimation = false, double? progressOverride}) {
    final range = _getAnimationRange(_animateParam);
    final domain = _paramDomain(_animateParam);
    final clamped = value
        .clamp(range.min, range.max)
        .clamp(domain.min, domain.max)
        .toDouble();
    _snapshotGraphForOverlay();
    if (!fromAnimation) {
      _captureParams();
    }
    setState(() {
      switch (_animateParam) {
        case AnimateParam.k0:
          _k0Scaled = clamped;
          break;
        case AnimateParam.eg:
          _eg = clamped;
          break;
        case AnimateParam.mnStar:
          _mnEff = clamped;
          break;
        case AnimateParam.mpStar:
          _mpEff = clamped;
          break;
      }
      if (_gapType == GapType.direct && _animateParam == AnimateParam.k0) {
        _k0Scaled = 0.0;
      }
      if (!fromAnimation && _preset != 'Custom') {
        _preset = 'Custom';
      }
      _animationProgress =
          progressOverride ?? _normalizeToRange(clamped, range);
      _refreshSelectedPointIfHeld();
      _chartVersion++;
    });
  }

  void _handleManualScrub(double value) {
    if (_isAnimating) {
      _stopAnimation(preserveProgress: true);
    }
    _applyAnimatedParamValue(value);
  }

  void _updateAnimateRange(RangeValues values) {
    final domain = _paramDomain(_animateParam);
    final min = values.start.clamp(domain.min, domain.max).toDouble();
    final max = values.end.clamp(domain.min, domain.max).toDouble();
    final orderedMin = math.min(min, max);
    final orderedMax = math.max(min, max);
    setState(() {
      _animateRanges[_animateParam] =
          _AnimRange(min: orderedMin, max: orderedMax);
    });
    final current = _currentAnimatedValue();
    final clampedCurrent = current.clamp(orderedMin, orderedMax);
    if (clampedCurrent != current) {
      _applyAnimatedParamValue(clampedCurrent);
    } else {
      _animationProgress =
          _normalizeToRange(current, _getAnimationRange(_animateParam));
    }
  }

  void _reverseAnimationDirection() {
    setState(() {
      _animationDirection *= -1;
    });
  }

  void _startAnimation() {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);

    final totalMs = (2500 / _animateSpeed).round();
    const steps = 90;
    final stepDuration = Duration(milliseconds: math.max(8, totalMs ~/ steps));

    _animationTimer = Timer.periodic(stepDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final range = _getAnimationRange(_animateParam);
      final step = _animationDirection / steps;
      var nextProgress = (_animationProgress + step).clamp(0.0, 1.0);
      final hitMax = _animationDirection > 0 && nextProgress >= 1.0 - 1e-6;
      final hitMin = _animationDirection < 0 && nextProgress <= 0.0 + 1e-6;
      if (hitMax) nextProgress = 1.0;
      if (hitMin) nextProgress = 0.0;

      final value = range.min + (range.max - range.min) * nextProgress;
      _applyAnimatedParamValue(value,
          fromAnimation: true, progressOverride: nextProgress);

      if (hitMax || hitMin) {
        switch (_loopMode) {
          case LoopMode.off:
            _stopAnimation(preserveProgress: true);
            timer.cancel();
            break;
          case LoopMode.loop:
            _animationProgress = _animationDirection > 0 ? 0.0 : 1.0;
            final loopValue =
                range.min + (range.max - range.min) * _animationProgress;
            _applyAnimatedParamValue(loopValue,
                fromAnimation: true, progressOverride: _animationProgress);
            break;
          case LoopMode.pingPong:
            _animationDirection *= -1;
            break;
        }
      }
    });
  }

  void _stopAnimation({bool preserveProgress = true}) {
    _animationTimer?.cancel();
    _animationTimer = null;
    setState(() {
      _isAnimating = false;
      if (!preserveProgress) {
        _animationProgress = _animationDirection > 0 ? 0.0 : 1.0;
      }
    });
  }

  void _restartAnimation() {
    _stopAnimation(preserveProgress: true);
    final startProgress = _animationDirection > 0 ? 0.0 : 1.0;
    final range = _getAnimationRange(_animateParam);
    final startValue = range.min + (range.max - range.min) * startProgress;
    _applyAnimatedParamValue(startValue,
        fromAnimation: true, progressOverride: startProgress);
    _startAnimation();
  }

  _AnimRange _getAnimationRange(AnimateParam param) => _animateRanges[param]!;

  Widget _buildDynamicObservations(BuildContext context, double egDirect,
      double egIndirect, double kCbmScaled) {
    final observations =
        _generateObservations(egDirect, egIndirect, kCbmScaled);

    return Card(
      elevation: 1,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('Dynamic Observations',
            style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: observations.map((obs) => _infoBullet(obs)).toList(),
          ),
        ],
      ),
    );
  }

  List<String> _generateObservations(
      double egDirect, double egIndirect, double kCbmScaled) {
    final observations = <String>[];

    // Static observations based on gap type
    if (_gapType == GapType.direct) {
      observations.add(
          'Direct gap: CBM and VBM at k≈0 → vertical photon transition. Eg_dir = ${egDirect.toStringAsFixed(3)} eV.');
    } else {
      observations.add(
          'Indirect gap: CBM at k0 = ${kCbmScaled.toStringAsFixed(3)} ×10¹⁰ m⁻¹ → phonon needed. Eg_ind = ${egIndirect.toStringAsFixed(3)} eV.');
      final deltaK = kCbmScaled.abs();
      observations.add(
          'CBM shift: Δk = ${deltaK.toStringAsFixed(3)} ×10¹⁰ m⁻¹ from Γ. Larger k0 makes gap more indirect.');
    }

    // Curvature observation
    final probeK = _kMaxScaled * 0.5 * _kDisplayScale;
    final deltaEc = _bandEnergyTerm(probeK, _mnEff);
    final deltaEv = _bandEnergyTerm(probeK, _mpEff);
    observations.add(
        'Curvature: At k=${(_kMaxScaled * 0.5).toStringAsFixed(2)} ×10¹⁰ m⁻¹, ΔEc=${deltaEc.toStringAsFixed(3)} eV, ΔEv=${deltaEv.toStringAsFixed(3)} eV.');

    // Parameter change observations (compare with previous)
    if (_prevParams != null) {
      final dK0 = (_k0Scaled - (_prevParams!['k0'] ?? _k0Scaled)).abs();
      if (dK0 > 0.05) {
        observations.add(
            'You changed k0: CBM shifted by Δk = ${dK0.toStringAsFixed(3)} ×10¹⁰ m⁻¹.');
      }

      final dMn = (_mnEff - (_prevParams!['mn'] ?? _mnEff)).abs();
      final dMp = (_mpEff - (_prevParams!['mp'] ?? _mpEff)).abs();
      if (dMn > 0.01 || dMp > 0.01) {
        observations.add(
            'Curvature changed: Smaller m* → steeper parabola (energy grows faster with k).');
      }
    }

    // Selected point observations
    if (_selectedPoint != null) {
      final sp = _selectedPoint!;
      final cbmKScaled = _gapType == GapType.direct ? 0.0 : _k0Scaled;
      final nearestEdge = sp.band == 'Valence'
          ? 'VBM (k≈0)'
          : (sp.kScaled - cbmKScaled).abs() < 0.05
              ? 'CBM (k≈${cbmKScaled.toStringAsFixed(2)} ×10¹⁰ m⁻¹)'
              : 'Conduction band';
      final edges = _bandEdges();
      final deltaE = sp.band == 'Valence'
          ? (edges.ev - sp.energy).abs()
          : (sp.energy - edges.ec).abs();
      observations.add(
          'Selected: k=${sp.kScaled.toStringAsFixed(3)} ×10¹⁰ m⁻¹, E=${sp.energy.toStringAsFixed(3)} eV. Nearest: $nearestEdge, ΔE=${deltaE.toStringAsFixed(3)} eV.');
    }

    // Cap at 6 bullets
    if (observations.length > 6) {
      return observations.sublist(0, 6);
    }

    return observations;
  }

  void _captureParams() {
    _prevParams = {
      'k0': _k0Scaled,
      'eg': _eg,
      'mn': _mnEff,
      'mp': _mpEff,
    };
  }

  Widget _buildControls(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('Parameters',
            style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final double halfWidth = (constraints.maxWidth - 12) / 2;
              final double controlWidth =
                  halfWidth.clamp(220.0, constraints.maxWidth).toDouble();
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: controlWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Gap type',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              SegmentedButton<GapType>(
                                segments: const [
                                  ButtonSegment(
                                      value: GapType.direct,
                                      label: Text('Direct')),
                                  ButtonSegment(
                                      value: GapType.indirect,
                                      label: Text('Indirect')),
                                ],
                                selected: {_gapType},
                                onSelectionChanged: (s) =>
                                    _updateAndRebuild(() {
                                  _captureParams();
                                  _gapType = s.first;
                                  if (_gapType == GapType.direct) {
                                    _k0Scaled = 0.0;
                                  }
                                }),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: controlWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Material preset',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              DropdownButton<String>(
                                value: _preset,
                                isExpanded: true,
                                onChanged: (v) {
                                  if (v == null) return;
                                  _updateAndRebuild(() {
                                    _captureParams();
                                    _preset = v;
                                    _applyPreset(v);
                                  });
                                },
                                items: const [
                                  DropdownMenuItem(
                                      value: 'GaAs (Direct)',
                                      child: Text('GaAs (Direct)')),
                                  DropdownMenuItem(
                                      value: 'Si (Indirect)',
                                      child: Text('Si (Indirect)')),
                                  DropdownMenuItem(
                                      value: 'Custom', child: Text('Custom')),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: controlWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Energy reference',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              DropdownButton<EnergyReference>(
                                value: _energyReference,
                                isExpanded: true,
                                onChanged: (v) {
                                  if (v == null) return;
                                  _updateAndRebuild(() {
                                    _energyReference = v;
                                    _refreshSelectedPointIfHeld();
                                  });
                                },
                                items: const [
                                  DropdownMenuItem(
                                      value: EnergyReference.midgap,
                                      child: Text('Midgap = 0')),
                                  DropdownMenuItem(
                                      value: EnergyReference.evZero,
                                      child: Text('Ev = 0')),
                                  DropdownMenuItem(
                                      value: EnergyReference.ecZero,
                                      child: Text('Ec = 0')),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _toggle(
                                'Transitions',
                                _showTransitions,
                                (v) => _updateAndRebuild(
                                    () => _showTransitions = v)),
                            _toggle(
                                'Band edges',
                                _showBandEdges,
                                (v) => _updateAndRebuild(
                                    () => _showBandEdges = v)),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _resetDemo,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset Demo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _slider(
                          label: 'Eg (eV)',
                          value: _eg,
                          min: 0.2,
                          max: 2.5,
                          divisions: 230,
                          valueText: _eg.toStringAsFixed(3),
                          onChanged: (v) => _updateCustom(
                              () => _eg = double.parse(v.toStringAsFixed(3))),
                        ),
                        _slider(
                          label: 'mn* (×m0)',
                          value: _mnEff,
                          min: 0.05,
                          max: 2.0,
                          divisions: 195,
                          valueText: _mnEff.toStringAsFixed(3),
                          onChanged: (v) => _updateCustom(() =>
                              _mnEff = double.parse(v.toStringAsFixed(3))),
                        ),
                        _slider(
                          label: 'mp* (×m0)',
                          value: _mpEff,
                          min: 0.05,
                          max: 2.0,
                          divisions: 195,
                          valueText: _mpEff.toStringAsFixed(3),
                          onChanged: (v) => _updateCustom(() =>
                              _mpEff = double.parse(v.toStringAsFixed(3))),
                        ),
                        _slider(
                          label: 'k0 (×10¹⁰ m⁻¹)',
                          value: _k0Scaled,
                          min: 0.0,
                          max: 1.5,
                          divisions: 150,
                          valueText: _k0Scaled.toStringAsFixed(3),
                          onChanged: _gapType == GapType.indirect
                              ? (v) => _updateCustom(() => _k0Scaled =
                                  double.parse(v.toStringAsFixed(3)))
                              : null,
                        ),
                        _slider(
                          label: 'kMax (×10¹⁰ m⁻¹)',
                          value: _kMaxScaled,
                          min: 0.5,
                          max: 2.0,
                          divisions: 150,
                          valueText: _kMaxScaled.toStringAsFixed(2),
                          onChanged: (v) => _updateCustom(() =>
                              _kMaxScaled = double.parse(v.toStringAsFixed(2))),
                        ),
                        _slider(
                          label: 'Points',
                          value: _points,
                          min: 200,
                          max: 1200,
                          divisions: 10,
                          valueText: _points.toInt().toString(),
                          onChanged: (v) =>
                              _updateCustom(() => _points = v.roundToDouble()),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPointInspector(BuildContext context) {
    final sp = _selectedPoint;
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
                const Text('Point Inspector',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (sp != null)
                  TextButton(
                    onPressed: () =>
                        _updateAndRebuild(() => _selectedPoint = null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (sp == null)
              const Text('Tap/click a curve to inspect k and E(k).')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Band: ${sp.band}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  LatexReadoutRow(
                    labelLatex: r'k',
                    valueLatex: _formatKLatex(sp.k),
                  ),
                  LatexReadoutRow(
                    labelLatex: r'k_{\text{axis}}',
                    valueLatex: _formatKAxisLatex(sp.kScaled),
                  ),
                  LatexReadoutRow(
                    labelLatex: r'E(k)',
                    valueLatex: _formatEnergyLatex(sp.energy),
                  ),
                  const SizedBox(height: 6),
                  Builder(
                    builder: (_) {
                      final cbmKScaled =
                          _gapType == GapType.direct ? 0.0 : _k0Scaled;
                      final nearestEdge = sp.band == 'Valence'
                          ? 'VBM (k≈0)'
                          : (sp.kScaled - cbmKScaled).abs() < 0.05
                              ? 'CBM (k≈${cbmKScaled.toStringAsFixed(2)})'
                              : 'Conduction band away from CBM';
                      return Text('Nearest edge: $nearestEdge');
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _legendSwatch(Color color, String label, {bool square = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 10,
          width: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(square ? 2 : 6),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _legendDash(Color color, String label) {
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

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(value: value, onChanged: onChanged),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueText,
    required ValueChanged<double>? onChanged,
  }) {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(valueText,
                  style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  ({double ec, double ev}) _bandEdges() {
    switch (_energyReference) {
      case EnergyReference.midgap:
        final halfEg = _eg / 2;
        return (ec: halfEg, ev: -halfEg);
      case EnergyReference.evZero:
        return (ec: _eg, ev: 0.0);
      case EnergyReference.ecZero:
        return (ec: 0.0, ev: -_eg);
    }
  }

  _GraphData _buildData(double kMinScaled, double kMaxScaled) {
    final pts = _points.toInt().clamp(2, 2000);
    final kMin = kMinScaled * _kDisplayScale;
    final kMax = kMaxScaled * _kDisplayScale;
    final k0 = (_gapType == GapType.direct ? 0.0 : _k0Scaled) * _kDisplayScale;
    final edges = _bandEdges();
    final ec = edges.ec;
    final ev = edges.ev;

    final conduction = <_GraphPoint>[];
    final valence = <_GraphPoint>[];

    for (var i = 0; i < pts; i++) {
      final t = pts == 1 ? 0.0 : i / (pts - 1);
      final k = kMin + (kMax - kMin) * t;
      final kScaled = k / _kDisplayScale;

      final eValence = ev - _bandEnergyTerm(k, _mpEff);
      valence.add(_GraphPoint(k: k, kScaled: kScaled, energy: eValence));

      final eConduction = ec + _bandEnergyTerm(k - k0, _mnEff);
      conduction.add(_GraphPoint(k: k, kScaled: kScaled, energy: eConduction));
    }

    return _GraphData(conduction: conduction, valence: valence);
  }

  double _bandEnergyTerm(double k, double mEff) {
    return (_hbar * _hbar * k * k) / (2 * (mEff * _m0)) / _q;
  }

  double _conductionEnergy({required double k}) {
    final ec = _bandEdges().ec;
    final term = _bandEnergyTerm(
        k - ((_gapType == GapType.direct ? 0.0 : _k0Scaled) * _kDisplayScale),
        _mnEff);
    return ec + term;
  }

  void _clampK0() {
    final max = _kMaxScaled.abs();
    if (_k0Scaled > max) _k0Scaled = max;
    if (_k0Scaled < -max) _k0Scaled = -max;
  }

  (double, double) _currentViewXRange() {
    final baseRange = _kMaxScaled * 2;
    final range = baseRange / _zoomScale;
    final center = _panOffsetX + 0.0;
    var min = center - range / 2;
    var max = center + range / 2;
    const double cap = 3.0; // allow zooming out up to 3x default domain
    min = min.clamp(-cap * _kMaxScaled.abs(), cap * _kMaxScaled.abs());
    max = max.clamp(-cap * _kMaxScaled.abs(), cap * _kMaxScaled.abs());
    if (min == max) {
      min -= 0.1;
      max += 0.1;
    }
    return (min, max);
  }

  _GraphPoint? _nearestPoint(List<_GraphPoint> pts, double xScaled) {
    if (pts.isEmpty) return null;
    _GraphPoint best = pts.first;
    double bestDx = (pts.first.kScaled - xScaled).abs();
    for (final p in pts) {
      final dx = (p.kScaled - xScaled).abs();
      if (dx < bestDx) {
        bestDx = dx;
        best = p;
      }
    }
    return best;
  }

  void _applyPreset(String preset) {
    _snapshotGraphForOverlay();
    final p = _presets[preset];
    if (p != null) {
      _eg = p.eg;
      _mnEff = p.mnEff;
      _mpEff = p.mpEff;
      _k0Scaled = p.k0Scaled;
      _kMaxScaled = p.kMaxScaled;
      _gapType = p.gapType;
      _refreshSelectedPointIfHeld();
      _syncAnimationProgressWithCurrentParam();
    }
  }

  void _resetDemo() {
    _stopAnimation(preserveProgress: false);
    setState(() {
      final targetPreset =
          _preset == 'Custom' ? _defaultState['preset'] as String : _preset;
      _preset = targetPreset;
      _applyPreset(_preset);
      _points = _defaultState['points'] as double;
      _showTransitions = _defaultState['showTransitions'] as bool;
      _showBandEdges = _defaultState['showBandEdges'] as bool;
      _energyReference = _defaultState['energyReference'] as EnergyReference;
      _lockedMinY = null;
      _lockedMaxY = null;
      _selectedPoint = null;
      _zoomScale = 1.0;
      _panOffsetX = 0.0;
      _panOffsetY = 0.0;
      _animationDirection = 1;
      _syncAnimationProgressWithCurrentParam();
      _chartVersion++;
    });
  }

  void _updateCustom(VoidCallback update) {
    _captureParams();
    _snapshotGraphForOverlay();
    setState(() {
      update();
      if (_preset != 'Custom') {
        _preset = 'Custom';
      }
      if (_gapType == GapType.direct) {
        _k0Scaled = 0.0;
      }
      _refreshSelectedPointIfHeld();
      _syncAnimationProgressWithCurrentParam();
      _chartVersion++;
    });
  }

  String _formatEnergy(double value) {
    final adjusted = value.abs() < 0.0005 ? 0.0 : value;
    final sign = adjusted >= 0 ? '+' : '';
    return '$sign${adjusted.toStringAsFixed(3)}';
  }

  String _formatKLatex(double k) =>
      LatexReadoutFormatter.valueWithUnitText(k, unit: r'm^{-1}');

  String _formatKAxisLatex(double kScaled) =>
      LatexReadoutFormatter.valueWithUnitText(kScaled * _kDisplayScale,
          unit: r'm^{-1}');

  String _formatEnergyLatex(double e) =>
      LatexReadoutFormatter.valueWithUnitText(e, unit: r'eV', forceSci: false);

}

class _GraphData {
  final List<_GraphPoint> conduction;
  final List<_GraphPoint> valence;

  _GraphData({required this.conduction, required this.valence});
}

class _GraphPoint {
  final double k;
  final double kScaled;
  final double energy;

  _GraphPoint({required this.k, required this.kScaled, required this.energy});
}

class _SeriesMeta {
  final String id;
  final List<_GraphPoint> points;

  _SeriesMeta({required this.id, required this.points});
}

class _AnimRange {
  double min;
  double max;

  _AnimRange({required this.min, required this.max});
}

class _Preset {
  final double eg;
  final double mnEff;
  final double mpEff;
  final double k0Scaled;
  final double kMaxScaled;
  final GapType gapType;

  _Preset({
    required this.eg,
    required this.mnEff,
    required this.mpEff,
    required this.k0Scaled,
    required this.kMaxScaled,
    required this.gapType,
  });
}

extension on double {
}
