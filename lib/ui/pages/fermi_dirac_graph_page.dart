import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/solver/number_formatter.dart';
import '../graphs/common/enhanced_animation_panel.dart';
import '../graphs/common/latex_readout.dart';
import '../widgets/latex_text.dart';
import '../graphs/utils/safe_math.dart';

class FermiDiracGraphPage extends StatelessWidget {
  const FermiDiracGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fermi–Dirac Probability')),
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
  final Offset position;
  _HoveredFDPoint(this.spot, this.position);
}

class _FDPin {
  final FlSpot spot;
  final int colorIndex;
  const _FDPin(this.spot, this.colorIndex);
}

class _FermiDiracGraphViewState extends State<FermiDiracGraphView> {
  int _chartVersion = 0;

  // Parameters
  double _temperature = 300.0; // K
  double _fermiLevel = 0.0; // eV
  bool _relativeToFermi = true;

  // Animation state
  bool _isAnimating = false;
  double _animProgress = 0.0;
  double _animSpeed = 1.0;
  _FDAnimParam _animParam = _FDAnimParam.temperature;
  LoopMode _loopMode = LoopMode.loop;
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
  final List<_FDPin> _pins = [];
  List<FlSpot>? _overlayCurve;

  // Constants
  static const double _kBoltzmannEV = 8.617333262e-5; // eV/K
  static const double _inlineLatexScale = 1.12;
  static const double _inlineLatexScaleSmall = 1.05;
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

  final NumberFormatter _fmt = const NumberFormatter(significantFigures: 3);

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
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
        switch (_loopMode) {
          case LoopMode.off:
            _animProgress = _animProgress.clamp(0.0, 1.0);
            _stopAnimation();
            break;
          case LoopMode.loop:
            _animProgress = _animProgress < 0 ? 1.0 : 0.0;
            break;
          case LoopMode.pingPong:
            _animDirection *= -1;
            _animProgress = _animProgress < 0 ? 0.0 : 1.0;
            break;
        }
      }
      _applyAnimatedValue();
    });
  }

  void _applyAnimatedValue() {
    _captureOverlay();
    final range = _animRanges[_animParam]!;
    final value =
        range.start + (_animProgress.clamp(0.0, 1.0) * (range.end - range.start));
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

  void _togglePin(FlSpot spot) {
    final existing = _pins.indexWhere(
        (p) => (p.spot.x - spot.x).abs() < 1e-6 && (p.spot.y - spot.y).abs() < 1e-6);
    setState(() {
      if (existing >= 0) {
        _pins.removeAt(existing);
      } else {
        _pins.add(_FDPin(spot, _nextPinColor()));
      }
    });
  }

  int _nextPinColor() {
    final used = _pins.map((p) => p.colorIndex).toSet();
    for (var i = 0; i < _pinPalette.length; i++) {
      if (!used.contains(i)) return i;
    }
    return 0;
  }

  double _minX() => _relativeToFermi ? -0.5 : _fermiLevel - 0.5;
  double _maxX() => _relativeToFermi ? 0.5 : _fermiLevel + 0.5;

  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fermi–Dirac Probability Distribution',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const LatexText(
          r'f(E) = \frac{1}{1 + \exp\left(\frac{E - E_F}{k T}\right)}',
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
              'The Fermi–Dirac distribution describes the probability that an electron occupies an energy state E at thermal equilibrium.',
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
    final minY =
        _lockYAxis ? -0.05 : math.min(-0.05, yMinCurve - 0.05);
    final maxY =
        _lockYAxis ? 1.05 : math.max(1.05, yMaxCurve + 0.05);
    final tooltip = _hovered;
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
    final pinsResolved = _pins.map((p) => FlSpot(p.spot.x, p.spot.y)).toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onDoubleTap: () {
            if (_hovered != null) _togglePin(_hovered!.spot);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  LineChart(
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: LatexText(
                                  value.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          axisNameWidget: LatexText(
                              _relativeToFermi
                                  ? r'E - E_F\ \mathrm{(eV)}'
                                  : r'E\ \mathrm{(eV)}'),
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            interval: 0.2,
                            getTitlesWidget: (value, meta) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
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
                        if (pinsResolved.isNotEmpty)
                          LineChartBarData(
                            spots: pinsResolved,
                            isCurved: false,
                            color: Colors.transparent,
                            barWidth: 0,
                            showingIndicators:
                                List.generate(pinsResolved.length, (index) => index),
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, bar, index) {
                                final pin = _pins[index];
                                final ring =
                                    _pinPalette[pin.colorIndex % _pinPalette.length];
                                return FlDotCirclePainter(
                                  radius: 6,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.9),
                                  strokeWidth: 3,
                                  strokeColor: ring,
                                );
                              },
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
                        handleBuiltInTouches: false,
                        touchCallback: (event, response) {
                          if (response == null ||
                              response.lineBarSpots == null ||
                              response.lineBarSpots!.isEmpty ||
                              event.localPosition == null) {
                            setState(() => _hovered = null);
                            return;
                          }
                          final spot = response.lineBarSpots!.first;
                          final local = event.localPosition!;
                          setState(() {
                            _hovered =
                                _HoveredFDPoint(FlSpot(spot.x, spot.y), local);
                          });
                        },
                        touchTooltipData:
                            LineTouchTooltipData(getTooltipItems: (_) => []),
                      ),
                    ),
                  ),
                  if (tooltip != null) _buildHoverTooltip(constraints),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHoverTooltip(BoxConstraints constraints) {
    final data = _hovered;
    if (data == null) return const SizedBox.shrink();
    const double tooltipWidth = 240;
    const double tooltipHeight = 120;
    const double margin = 8;
    final size = constraints.biggest;
    double left = data.position.dx + 12;
    if (left + tooltipWidth > size.width - margin) {
      left = data.position.dx - tooltipWidth - 12;
    }
    left =
        left.clamp(margin, math.max(margin, size.width - tooltipWidth - margin));

    double top = data.position.dy - tooltipHeight - 12;
    if (top < margin) {
      top = data.position.dy + 12;
    }
    if (top + tooltipHeight > size.height - margin) {
      top = size.height - tooltipHeight - margin;
    }

    final spot = data.spot;
    final xLabel = _relativeToFermi ? r'E - E_F' : r'E';
    final latexX = LatexReadoutFormatter.equation(
      labelLatex: xLabel,
      valueLatex: _fmt.formatLatex(spot.x),
      unit: 'eV',
    );
    final latexY = LatexReadoutFormatter.equation(
      labelLatex: r'f(E)',
      valueLatex: _fmt.formatLatex(spot.y),
    );

    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: tooltipWidth,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hover point', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            LatexText(latexX, scale: _inlineLatexScaleSmall),
            const SizedBox(height: 2),
            LatexText(latexY, scale: _inlineLatexScaleSmall),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1100;
          final chartCard = _buildChartCard();
          final sidebar = _buildSidebar();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 12),
              _buildInfoPanel(),
              const SizedBox(height: 12),
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: chartCard),
                          const SizedBox(width: 12),
                          SizedBox(
                              width:
                                  math.min(520, constraints.maxWidth / 2),
                              child: sidebar),
                        ],
                      )
                    : Scrollbar(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            SizedBox(height: 420, child: chartCard),
                            const SizedBox(height: 12),
                            sidebar,
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

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
        title:
            const Text('Point Inspector', style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (hovered == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Hover the curve to inspect values.'),
            )
          else ...[
            LatexReadoutRow(
              labelLatex: _relativeToFermi ? r'E - E_F' : r'E',
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
            const SizedBox(height: 8),
            const Text('Double-click to pin/unpin this point.',
                style: TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 10),
          _buildPins(),
        ],
      ),
    );
  }

  Widget _buildPins() {
    if (_pins.isEmpty) {
      return const Text('No pinned points yet.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _pins.map((p) {
        final ring = _pinPalette[p.colorIndex % _pinPalette.length];
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 6),
                decoration:
                    BoxDecoration(color: ring, shape: BoxShape.circle),
              ),
              Expanded(
                child: LatexText(
                  '${LatexReadoutFormatter.equation(labelLatex: _relativeToFermi ? r'E - E_F' : r'E', valueLatex: _fmt.formatLatex(p.spot.x), unit: 'eV')}'
                  ' \\quad ${LatexReadoutFormatter.equation(labelLatex: r'f(E)', valueLatex: _fmt.formatLatex(p.spot.y))}',
                  scale: _inlineLatexScaleSmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Remove pin',
                onPressed: () => setState(() => _pins.remove(p)),
              ),
            ],
          ),
        );
      }).toList(),
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
        title:
            const Text('Insights & Pins', style: TextStyle(fontWeight: FontWeight.w700)),
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
                    _InlinePiece.text(' and pin points for comparison.'),
                  ], latexScale: _inlineLatexScale)
                else ...[
                  LatexText(
                    'kT \\approx ${_fmt.formatLatex(kT)}\\,\\mathrm{eV},\\quad \\text{width} \\sim ${_fmt.formatLatex(widthApprox)}\\,\\mathrm{eV}',
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
                      r'f(E_F)=0.5 \text{ when } E=E_F',
                      scale: 1.0,
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Pinned points',
                  style: Theme.of(context).textTheme.titleSmall),
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
            _bulletLine(const [
              _InlinePiece.text('Pin multiple points to compare '),
              _InlinePiece.latex(r'f(E)'),
              _InlinePiece.text(' across energies.'),
            ], latexScale: _inlineLatexScale)
          else
            const SizedBox.shrink(),
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
            labelLatex: r'E_F',
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
            title: const Text('Relative to E_F'),
            subtitle:
                Text(_relativeToFermi ? 'X-axis: E - E_F' : 'X-axis: E (absolute)'),
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
                  child:
                      p.latex ? LatexText(p.text, scale: latexScale) : Text(p.text),
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
        return r'E_F';
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
        return 'Higher T increases thermal smearing; slope at E=E_F decreases.';
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
  LoopMode get loopMode => state._loopMode;

  @override
  void setLoopMode(LoopMode mode) => _update(() => state._loopMode = mode);

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
