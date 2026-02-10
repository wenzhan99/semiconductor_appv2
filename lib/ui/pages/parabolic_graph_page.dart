import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/constants_loader.dart';
import '../../core/constants/latex_symbols.dart';
import '../../core/solver/number_formatter.dart';
import '../graphs/common/latex_readout.dart';
import '../widgets/latex_text.dart';

enum PlotMode { absolute, delta }

enum _AnimTarget { eg, mn, mp, kmax }

class ParabolicGraphPage extends StatelessWidget {
  const ParabolicGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parabolic Band Dispersion (E–k)')),
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

  // Constants
  static const double _kMin = 0.0;
  static const double _kDisplayScale = 1e10; // display k in 1e10 m^-1
  static const double _hbar = 1.054571817e-34; // J*s
  static const double _m0 = 9.1093837015e-31; // kg
  static const double _q = 1.602176634e-19; // C

  final List<_PointRef> _pins = [];
  _TooltipData? _hoveredTooltip;
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

  // Animation
  bool _isAnimating = false;
  bool _loopAnimation = true;
  bool _holdSelectedK = true;
  double _animSpeed = 1.0; // 0.25xâ€“4x
  double _animProgress = 0.0;
  _AnimTarget _animTarget = _AnimTarget.eg;
  final Map<_AnimTarget, RangeValues> _animRanges = {
    _AnimTarget.eg: const RangeValues(0.6, 1.6),
    _AnimTarget.mn: const RangeValues(0.1, 1.2),
    _AnimTarget.mp: const RangeValues(0.1, 1.5),
    _AnimTarget.kmax: const RangeValues(0.2, 2.0),
  };
  Timer? _animTimer;

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
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1100;
            final chartCard = _buildChartCard(context, latexMap);
            final rightPanel = _buildRightPanel(context, latexMap);

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                                width: math.min(520, constraints.maxWidth / 2),
                                child: rightPanel,
                              ),
                            ],
                          )
                        : Scrollbar(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                SizedBox(height: 420, child: chartCard),
                                const SizedBox(height: 12),
                                rightPanel,
                              ],
                            ),
                          ),
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
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Parabolic Band Dispersion (E–k)',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const LatexText(
          r'E_c(k)=E_c+\frac{\hbar^{2}k^{2}}{2\,m_n^{*}},\quad E_v(k)=E_v-\frac{\hbar^{2}k^{2}}{2\,m_p^{*}}',
          displayMode: true,
          scale: 1.05,
        ),
      ],
    );
  }

  Widget _buildInfoPanel() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('What you should observe',
            style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _infoBulletSegments([
            const _InlinePiece.text('Near the band edge,'),
            const _InlinePiece.latex(r'E(k)'),
            const _InlinePiece.text('is parabolic:'),
            const _InlinePiece.latex(
                r'\Delta E(k)=\frac{\hbar^{2}k^{2}}{2m^{*}}'),
          ]),
          _infoBulletSegments([
            const _InlinePiece.text('Conduction:'),
            const _InlinePiece.latex(r'E_c(k)=E_c+\Delta E(k);'),
            const _InlinePiece.text('Valence:'),
            const _InlinePiece.latex(r'E_v(k)=E_v-\Delta E(k)'),
          ]),
          _infoBulletSegments([
            const _InlinePiece.text(
                'Curvature comes from effective mass: smaller'),
            const _InlinePiece.latex(r'm^{*}'),
            const _InlinePiece.text('? steeper parabola.'),
          ]),
          _infoBulletSegments([
            const _InlinePiece.text('Group velocity:'),
            const _InlinePiece.latex(r'v_g(k)=\frac{\hbar k}{m^{*}}'),
            const _InlinePiece.text('(linear in k for parabolic bands).'),
          ]),
          _infoBulletSegments([
            const _InlinePiece.text('Use'),
            const _InlinePiece.latex(r'k_{\max}'),
            const _InlinePiece.text('to keep energies realistic;'),
            const _InlinePiece.latex(r'\Delta E'),
            const _InlinePiece.text(
                'mode shows ±ΔE relative to the band edge.'),
          ]),
        ],
      ),
    );
  }

  Widget _buildChartCard(BuildContext context, LatexSymbolMap latexMap) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _buildChartArea(context, latexMap),
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

    final conductionColor = Theme.of(context).colorScheme.primary;
    final valenceColor = Theme.of(context).colorScheme.tertiary;
    final ecLineColor = conductionColor.withValues(alpha: 0.35);
    final evLineColor = valenceColor.withValues(alpha: 0.35);

    final lineBars = <LineChartBarData>[];
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
        _legendItem(ecLineColor, _latexSymbol(latexMap, 'E_c'),
            dashed: true, latex: true),
        _legendItem(evLineColor, _latexSymbol(latexMap, 'E_v'),
            dashed: true, latex: true),
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
                onExit: (_) => setState(() => _hoveredTooltip = null),
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
                          extraLinesData: _plotMode == PlotMode.absolute
                              ? ExtraLinesData(
                                  horizontalLines: [
                                    HorizontalLine(
                                      y: ecEv.$1,
                                      color: ecLineColor,
                                      strokeWidth: 1,
                                      dashArray: [4, 4],
                                      label: HorizontalLineLabel(
                                        show: true,
                                        alignment: Alignment.centerRight,
                                        padding:
                                            const EdgeInsets.only(right: 6),
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                        labelResolver: (_) => 'E_c',
                                      ),
                                    ),
                                    HorizontalLine(
                                      y: ecEv.$2,
                                      color: evLineColor,
                                      strokeWidth: 1,
                                      dashArray: [4, 4],
                                      label: HorizontalLineLabel(
                                        show: true,
                                        alignment: Alignment.centerRight,
                                        padding:
                                            const EdgeInsets.only(right: 6),
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                        labelResolver: (_) => 'E_v',
                                      ),
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
                              final local = event.localPosition;
                              if (local == null) {
                                setState(() => _hoveredTooltip = null);
                                return;
                              }
                              final nearest = _nearestPointGlobal(
                                  local, constraints, minY, maxY, series);
                              if (nearest == null) {
                                setState(() => _hoveredTooltip = null);
                                return;
                              }
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                setState(() {
                                  _hoveredTooltip = _TooltipData(
                                    point: nearest,
                                    position: local,
                                  );
                                });
                              });
                            },
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (_) => const [],
                            ),
                          ),
                          gridData: const FlGridData(show: true),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              axisNameWidget: LatexText(
                                  _plotMode == PlotMode.absolute
                                      ? r'E\ \mathrm{(eV)}'
                                      : r'\Delta E\ \mathrm{(eV)}'),
                              sideTitles: const SideTitles(
                                  showTitles: true, reservedSize: 52),
                            ),
                            bottomTitles: const AxisTitles(
                              axisNameWidget: LatexText(
                                  r'k\ (\times 10^{10}\,\mathrm{m^{-1}})'),
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                interval: 0.5,
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
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _MarkersPainter(
                            pins: resolvedPins,
                            hoveredPoint: _hoveredTooltip?.point, // FIX R3: Add hovered point
                            minX: 0,
                            maxX: _kMaxScaled,
                            minY: minY,
                            maxY: maxY,
                            conductionColor: conductionColor,
                            valenceColor: valenceColor,
                            palette: _pinPalette,
                          ),
                        ),
                      ),
                      if (_hoveredTooltip != null)
                        _buildHoverTooltip(constraints),
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

  Widget _buildHoverTooltip(BoxConstraints constraints) {
    final data = _hoveredTooltip;
    if (data == null) return const SizedBox.shrink();

    const double tooltipWidth = 240;
    const double tooltipHeight = 160;
    const double margin = 8;
    final size = constraints.biggest;
    double left = data.position.dx + 12;
    if (left + tooltipWidth > size.width - margin) {
      left = data.position.dx - tooltipWidth - 12;
    }
    left = left.clamp(
        margin, math.max(margin, size.width - tooltipWidth - margin));

    double top = data.position.dy - tooltipHeight - 12;
    if (top < margin) {
      top = data.position.dy + 12;
    }
    if (top + tooltipHeight > size.height - margin) {
      top = size.height - tooltipHeight - margin;
    }

    final scheme = Theme.of(context).colorScheme;
    final lines = _tooltipLines(data.point);
    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines
              .map(
                (line) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: LatexText(
                    line,
                    style: TextStyle(color: scheme.onSurface),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildRightPanel(BuildContext context, LatexSymbolMap latexMap) {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _buildPointInspector(context, latexMap),
            const SizedBox(height: 12),
            _buildAnimationControls(context),
            const SizedBox(height: 12),
            _buildInsights(context),
            const SizedBox(height: 12),
            _buildControls(context, latexMap),
          ],
        ),
      ),
    );
  }

  Widget _buildPointInspector(BuildContext context, LatexSymbolMap latexMap) {
    final activePoint = _hoveredTooltip?.point; // Get the actual hovered/selected band

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('Point Inspector',
            style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (activePoint == null)
            const Text(
                'Hover or click a curve to inspect. Double-click to pin.')
          else ...[
            // FIX R2: Header with LaTeX rendering (not Text with raw LaTeX)
            LatexText(
              'k = ${_formatKLatex(activePoint.k)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            // FIX R4: Show ONLY the hovered/selected band (single band only)
            Text('${activePoint.band} Band',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            _detailRow(
                labelLatex: r'k_{\text{axis}}',
                valueLatex: _formatKAxisLatex(activePoint.kScaled)),
            _detailRow(
                labelLatex: activePoint.band == 'Conduction' ? r'\Delta E_c(k)' : r'\Delta E_v(k)',
                valueLatex: _formatEnergyLatex(activePoint.deltaE)),
            if (_plotMode == PlotMode.absolute)
              _detailRow(
                  labelLatex: activePoint.band == 'Conduction' ? r'E_c(k)' : r'E_v(k)',
                  valueLatex: _formatEnergyLatex(activePoint.eAbs)),
            _detailRow(
                labelLatex: activePoint.band == 'Conduction' ? r'v_{g,c}(k)' : r'v_{g,v}(k)',
                valueLatex: _formatVelocityLatex(activePoint.velocity)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Double-click to pin. Pins shown below in "Insights & Pins".',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimationControls(BuildContext context) {
    final range = _animRanges[_animTarget]!;
    final statusLatex = _animationStatusLatex();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('Animation',
            style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Animate parameter',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    DropdownButton<_AnimTarget>(
                      value: _animTarget,
                      isExpanded: true,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _animTarget = v;
                          _animProgress = 0;
                        });
                      },
                      items: const [
                        DropdownMenuItem(
                            value: _AnimTarget.eg, child: Text('E_g')),
                        DropdownMenuItem(
                            value: _AnimTarget.mn, child: Text('m_n^*')),
                        DropdownMenuItem(
                            value: _AnimTarget.mp, child: Text('m_p^*')),
                        DropdownMenuItem(
                            value: _AnimTarget.kmax, child: Text('k_max')),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Range',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(
                    width: 280,
                    child: RangeSlider(
                      values: range,
                      min: _rangeBounds(_animTarget).$1,
                      max: _rangeBounds(_animTarget).$2,
                      divisions: 120,
                      labels: RangeLabels(range.start.toStringAsFixed(2),
                          range.end.toStringAsFixed(2)),
                      onChanged: (v) =>
                          setState(() => _animRanges[_animTarget] = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Speed (0.25x–4x)',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Slider(
                      min: 0.25,
                      max: 4,
                      divisions: 15,
                      value: _animSpeed,
                      label: '${_animSpeed.toStringAsFixed(2)}x',
                      onChanged: (v) => setState(() =>
                          _animSpeed = double.parse(v.toStringAsFixed(2))),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _loopAnimation,
                    onChanged: (v) => setState(() => _loopAnimation = v),
                  ),
                  const Text('Loop'),
                  const SizedBox(width: 16),
                  Switch(
                    value: _holdSelectedK,
                    onChanged: (v) => setState(() => _holdSelectedK = v),
                  ),
                  const Text('Hold selected k'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _toggleAnimation,
                icon: Icon(_isAnimating ? Icons.pause : Icons.play_arrow),
                label: Text(_isAnimating ? 'Pause' : 'Play'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _restartAnimation,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restart'),
              ),
              const Spacer(),
              LatexText(
                statusLatex,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsights(BuildContext context) {
    final ecEv = _deriveEcEv();
    final resolvedSelected = null;
    final resolvedPins = _pins
        .map((p) => _resolvePoint(p, ecEv))
        .whereType<_GraphPointWithBand>()
        .toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('Insights & Pins',
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
                if (resolvedSelected == null)
                  const Text('Select a point to see ΔE and v_g at that k.')
                else ...[
                  const LatexText(
                    r'\Delta E = \frac{\hbar^{2}k^{2}}{2 m^{*}},\quad v_g = \frac{\hbar k}{m^{*}}',
                    displayMode: true,
                    scale: 1.05,
                  ),
                  const SizedBox(height: 4),
                  LatexText(
                    r'\Delta E \approx ' +
                        _sciPlaceholder('deltaE', resolvedSelected.deltaE) +
                        r'\,\text{eV},\quad v_g \approx ' +
                        _sciPlaceholder('vg', resolvedSelected.velocity) +
                        r'\,\text{m}\,\text{s}^{-1}',
                  ),
                  const SizedBox(height: 4),
                  const LatexText(
                    r'\text{Smaller }m^{*}\text{ } \Rightarrow \text{ steeper curvature and larger }\Delta E\text{ at the same }k.',
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
            const Text(
                'Pin multiple points to compare ΔE, E, and v_g across bands.')
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
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
                          LatexText(LatexReadoutFormatter.equation(
                            labelLatex: r'k',
                            valueLatex: _formatKLatex(p.k),
                          )),
                          LatexText(LatexReadoutFormatter.equation(
                            labelLatex: r'\Delta E(k)',
                            valueLatex: _formatEnergyLatex(p.deltaE),
                          )),
                          if (_plotMode == PlotMode.absolute)
                            LatexText(LatexReadoutFormatter.equation(
                              labelLatex: r'E(k)',
                              valueLatex: _formatEnergyLatex(p.eAbs),
                            )),
                          LatexText(LatexReadoutFormatter.equation(
                            labelLatex: r'v_g(k)',
                            valueLatex: _formatVelocityLatex(p.velocity),
                          )),
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
        title: const Text('Controls',
            style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              _toggle('Conduction', _showConduction,
                  (v) => setState(() => _showConduction = v)),
              _toggle('Valence', _showValence,
                  (v) => setState(() => _showValence = v)),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Energy view',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    SegmentedButton<PlotMode>(
                      segments: const [
                        ButtonSegment(
                            value: PlotMode.absolute,
                            label: Text('Absolute E')),
                        ButtonSegment(
                            value: PlotMode.delta,
                            label: Text('ΔE (relative)')),
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
                const Text('Material preset',
                    style: TextStyle(fontWeight: FontWeight.w600)),
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
                    labelLatex: r'\text{Points}',
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
            children: const [
              LatexText(r'k\ \text{axis: } k \times 10^{10}\ \mathrm{m^{-1}}'),
              LatexText(
                  r'E\ \text{axis in eV; } \Delta E\ \text{if relative mode is selected}'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Parabolic approximation is best near k ˜ 0; very large k may be unrealistic.',
            style: Theme.of(context).textTheme.bodySmall,
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
        const Text('Energy reference',
            style: TextStyle(fontWeight: FontWeight.w600)),
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
          items: const [
            DropdownMenuItem(value: 'Midgap = 0', child: Text('Midgap = 0')),
            DropdownMenuItem(value: 'Ev = 0', child: Text('Ev = 0')),
            DropdownMenuItem(value: 'Ec = 0', child: Text('Ec = 0')),
          ],
        ),
        if (isDelta)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Reference ignored in ΔE mode.',
              style: TextStyle(
                fontSize: 12,
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
    }

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

  _GraphPointWithBand? _nearestPointGlobal(
      Offset local,
      BoxConstraints constraints,
      double minY,
      double maxY,
      List<_SeriesMeta> series) {
    if (series.isEmpty) return null;
    final dataX = (local.dx / constraints.maxWidth) * (_kMaxScaled - 0) + 0;
    final dataY = maxY - (local.dy / constraints.maxHeight) * (maxY - minY);

    _GraphPointWithBand? best;
    double bestDist = double.infinity;
    for (final meta in series) {
      for (final p in meta.points) {
        final dx = p.kScaled - dataX;
        final dy = p.yDisplay - dataY;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < bestDist) {
          bestDist = dist;
          best = _GraphPointWithBand(
            band: meta.id,
            k: p.k,
            kScaled: p.kScaled,
            deltaE: p.deltaE,
            eAbs: p.eAbs,
            velocity: p.velocity,
            yDisplay: p.yDisplay,
            colorIndex: null,
          );
        }
      }
    }
    return best;
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
      _hoveredTooltip = null;
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
      _startAnimation();
    }
  }

  void _handleDoubleTap() {
    final hovered = _hoveredTooltip?.point;
    if (hovered != null) {
      _togglePin(_PointRef(
          band: hovered.band,
          k: hovered.k,
          colorIndex: hovered.colorIndex ?? _nextPinColorIndex()));
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
      _animProgress += 0.01 * _animSpeed;
      if (_animProgress > 1.0) {
        if (_loopAnimation) {
          _animProgress = 0.0;
        } else {
          _animProgress = 1.0;
          _stopAnimation();
        }
      }
      _applyAnimatedValue();
    });
  }

  void _applyAnimatedValue() {
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

  String _animationStatusLatex() {
    switch (_animTarget) {
      case _AnimTarget.eg:
        return r'E_g: ' +
            _latexFormatter.formatLatex(_eg) +
            r'\ \mathrm{eV}\quad [' +
            _latexFormatter.formatLatex(_animRanges[_AnimTarget.eg]!.start) +
            r'\to' +
            _latexFormatter.formatLatex(_animRanges[_AnimTarget.eg]!.end) +
            r']';
      case _AnimTarget.mn:
        return r'\frac{m_n^{*}}{m_0}: ' +
            _latexFormatter.formatLatex(_mnEff) +
            r'\quad [' +
            _latexFormatter.formatLatex(_animRanges[_AnimTarget.mn]!.start) +
            r'\to' +
            _latexFormatter.formatLatex(_animRanges[_AnimTarget.mn]!.end) +
            r']';
      case _AnimTarget.mp:
        return r'\frac{m_p^{*}}{m_0}: ' +
            _latexFormatter.formatLatex(_mpEff) +
            r'\quad [' +
            _latexFormatter.formatLatex(_animRanges[_AnimTarget.mp]!.start) +
            r'\to' +
            _latexFormatter.formatLatex(_animRanges[_AnimTarget.mp]!.end) +
            r']';
      case _AnimTarget.kmax:
        return r'k_{\max}: ' +
            _latexFormatter.formatLatex(_kMaxScaled) +
            r'\times 10^{10}\,\mathrm{m^{-1}}\quad [' +
            _latexFormatter.formatLatex(_animRanges[_AnimTarget.kmax]!.start) +
            r'\to' +
            _latexFormatter.formatLatex(_animRanges[_AnimTarget.kmax]!.end) +
            r']';
    }
  }

  // --- UI helpers ---

  Widget _legendItem(Color color, String label,
      {bool dashed = false, bool latex = false}) {
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
            ? LatexText(label, style: const TextStyle(fontSize: 12))
            : Text(label,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(valueText),
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
          const Text('• '),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: parts
                  .map((p) => p.latex ? LatexText(p.text) : Text(p.text))
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
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        LatexText(
          r'\frac{\Delta E(' +
              a.band[0].toLowerCase() +
              r')}{\Delta E(' +
              b.band[0].toLowerCase() +
              r')} \approx ' +
              (ratio.isFinite
                  ? _latexFormatter.formatLatex(ratio)
                  : r'\text{n/a}'),
        ),
        const SizedBox(height: 2),
        const LatexText(
          r'\text{Smaller }m^{*}\text{ gives larger } \Delta E \text{ and } |v_g| \text{ at the same } k.',
        ),
      ],
    );
  }

  // --- Formatting helpers ---

  List<String> _tooltipLines(_GraphPointWithBand p) {
    final energyLabel =
        _plotMode == PlotMode.absolute ? r'E(k)' : r'\Delta E(k)';
    final energyValue = _plotMode == PlotMode.absolute
        ? _formatEnergyLatex(p.eAbs)
        : _formatEnergyLatex(p.deltaE);
    final complementary = _plotMode == PlotMode.absolute
        ? '\\Delta E(k) = ${_formatEnergyLatex(p.deltaE)}'
        : 'E(k) = ${_formatEnergyLatex(p.eAbs)}';
    return [
      _bandHeader(p.band),
      'k = ${_formatKLatex(p.k)}',
      'k_{\\text{axis}} = ${_formatKAxisLatex(p.kScaled)}',
      '$energyLabel = $energyValue',
      complementary,
      'v_g(k) = ${_formatVelocityLatex(p.velocity)}',
    ];
  }

  String _formatKLatex(double k) =>
      LatexReadoutFormatter.valueWithUnitText(k, unit: r'm^{-1}');

  String _formatKAxisLatex(double kScaled) =>
      LatexReadoutFormatter.valueWithUnitText(kScaled * 1e10, unit: r'm^{-1}');

  String _formatEnergyLatex(double e) =>
      LatexReadoutFormatter.valueWithUnitText(e, unit: r'eV', forceSci: false);

  String _formatVelocityLatex(double v) =>
      LatexReadoutFormatter.valueWithUnitText(v, unit: r'm\,s^{-1}');

  String _bandHeader(String band) => r'\textbf{' + band + r'}';

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  String _latexSymbol(LatexSymbolMap map, String key, {String? fallback}) {
    final mapped = map.latexOf(key);
    if (mapped.isNotEmpty) return mapped;
    return fallback ?? key;
  }

  static String _sciPlaceholder(String id, double value) {
    final fmt = NumberFormatter(significantFigures: 3, sciThresholdExp: -1000);
    return fmt.formatScientificLatex(value);
  }
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

class _TooltipData {
  final _GraphPointWithBand point;
  final Offset position;

  _TooltipData({required this.point, required this.position});
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
  final _GraphPointWithBand? hoveredPoint; // FIX R3: Add hovered point
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final Color conductionColor;
  final Color valenceColor;
  final List<Color> palette;

  const _MarkersPainter({
    required this.pins,
    this.hoveredPoint, // FIX R3
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.conductionColor,
    required this.valenceColor,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dx = (maxX - minX).abs();
    final dy = (maxY - minY).abs();
    if (dx == 0 || dy == 0) return;

    void drawMarker(_GraphPointWithBand p,
        {required Color ringColor, double radius = 7}) {
      final tx = ((p.kScaled - minX) / dx).clamp(0.0, 1.0);
      final ty = (1 - ((p.yDisplay - minY) / dy)).clamp(0.0, 1.0);
      final pos = Offset(tx * size.width, ty * size.height);
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

    // Draw pinned points
    for (final p in pins) {
      final ringColor = palette[(p.colorIndex ?? 0) % palette.length];
      drawMarker(p, ringColor: ringColor, radius: 7);
    }
    
    // FIX R3: Draw hovered/selected point marker (if not already pinned)
    if (hoveredPoint != null) {
      final isAlreadyPinned = pins.any((pin) =>
          pin.band == hoveredPoint!.band &&
          (pin.k - hoveredPoint!.k).abs() < 1e6);
      
      if (!isAlreadyPinned) {
        // Draw hollow ring for hovered point
        final ringColor = hoveredPoint!.band == 'Conduction' ? conductionColor : valenceColor;
        drawMarker(hoveredPoint!, ringColor: ringColor.withOpacity(0.8), radius: 8);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MarkersPainter oldDelegate) {
    return oldDelegate.pins != pins ||
        oldDelegate.hoveredPoint != hoveredPoint ||
        oldDelegate.minX != minX ||
        oldDelegate.maxX != maxX ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY;
  }
}
