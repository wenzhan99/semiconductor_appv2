import 'dart:math' as math;
import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../widgets/latex_text.dart';
import '../graphs/common/graph_controller.dart';
import '../graphs/common/parameters_card.dart';
import '../graphs/common/chart_toolbar.dart';
import '../graphs/common/viewport_state.dart';
import '../graphs/core/graph_config.dart';
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
  State<_DensityOfStatesGraphView> createState() =>
      _DensityOfStatesGraphViewState();
}

enum _DosAnimParam { bandgap, meEff, mhEff, energyWindow, fermiOffset }

class _DosPointRef {
  final String band; // Conduction | Valence
  final FlSpot spot;

  const _DosPointRef({
    required this.band,
    required this.spot,
  });
}

class _DensityOfStatesGraphViewState extends State<_DensityOfStatesGraphView>
    with GraphController {
  static const int _maxPins = 2;
  static const Color _pinBlue = Color(0xFF1E88E5);
  static const Color _pinRed = Color(0xFFE53935);
  static const String _dosEquationLatex =
      r'g_c(E)=\frac{1}{2\pi^2}\left(\frac{2m_e^{*}}{\hbar^2}\right)^{3/2}\sqrt{E-E_c},\quad '
      r'g_v(E)=\frac{1}{2\pi^2}\left(\frac{2m_h^{*}}{\hbar^2}\right)^{3/2}\sqrt{E_v-E}';

  // Parameters
  double _eg = 1.12;
  double _meEff = 0.26;
  double _mhEff = 0.39;
  double _energyWindow = 1.0;
  double _fermiOffset = 0.0;

  // Selection / interaction
  _DosPointRef? _hoverPoint;
  final List<_DosPointRef> _pinnedPoints = [];

  // Animation state
  bool _isAnimating = false;
  double _animProgress = 0.0;
  double _animSpeed = 1.0;
  bool _loopEnabled = true;
  bool _reverseDirection = false;
  double _animDirection = 1.0;
  _DosAnimParam _animParam = _DosAnimParam.bandgap;
  late final Map<_DosAnimParam, RangeValues> _animRanges;
  Timer? _animTimer;

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
    _animRanges = {
      _DosAnimParam.bandgap: const RangeValues(0.4, 2.5),
      _DosAnimParam.meEff: const RangeValues(0.05, 2.0),
      _DosAnimParam.mhEff: const RangeValues(0.05, 2.0),
      _DosAnimParam.energyWindow: const RangeValues(0.2, 1.6),
      _DosAnimParam.fermiOffset: const RangeValues(-1.5, 1.5),
    };
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
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
    final panelConfig = _buildPanelConfig(ec, ev);

    return StandardGraphPageScaffold(
      config: panelConfig.copyWith(
        title: 'Density of States g(E) vs Energy',
        subtitle: 'DOS & Statistics',
        mainEquation: _dosEquationLatex,
      ),
      aboutSection: _buildAboutCard(context),
      observeSection: _buildObserveCard(context),
      placeSectionsInWideLeftColumn: true,
      useTwoColumnRightPanelInWide: true,
      wideLeftColumnSectionIds: const ['point_inspector', 'animation'],
      wideRightColumnSectionIds: const ['notes', 'controls'],
      chartBuilder: (context) => _buildChartCard(context, data, ec, ev),
    );
  }

  // ignore: unused_element
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
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.2),
              ),
            ),
            child: const LatexText(
              _dosEquationLatex,
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
              _bullet(
                  r'$g(E)$ rises as $\sqrt{|E-E_{c,v}|}$; heavier $m^*$ raises DOS.'),
              _bullet(
                  r'Conduction DOS starts at $E_c$; valence DOS starts at $E_v$.'),
              _bullet(
                  r'Fermi level ($E_F$) positioning + DOS shape explains carrier counts.'),
              const SizedBox(height: 8),
              Text('Try this:',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              _bullet(r'Change $m_e^*$ and $m_h^*$ to see asymmetric DOS.'),
              _bullet(
                  r'Move $E_F$ and observe overlap with conduction/valence DOS.'),
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

  GraphConfig _buildPanelConfig(double ec, double ev) {
    final dynamicObservations = _buildDynamicObservations(ec, ev);
    return GraphConfig(
      pointInspector: _buildPointInspectorConfig(),
      animation: _buildAnimationConfig(),
      insights: InsightsConfig(
        dynamicObservations:
            dynamicObservations.isEmpty ? null : dynamicObservations,
        staticObservations: _buildStaticObservations(),
        dynamicTitle: _pinnedPoints.isNotEmpty
            ? 'From Your Pins'
            : (_hoverPoint != null ? 'Current Hover' : null),
        pinnedCount: _pinnedPoints.length,
        maxPins: _maxPins,
        onClearPins: _pinnedPoints.isEmpty
            ? null
            : () => updateChart(() {
                  _pinnedPoints.clear();
                  _hoverPoint = null;
                }),
      ),
      controls: ControlsConfig(
        children: _buildControlsChildren(),
        collapsible: true,
        initiallyExpanded: true,
      ),
    );
  }

  // ignore: unused_element
  List<ReadoutItem> _buildReadouts(double ec, double ev) {
    final dosAtEc = _dosCoeff(_meEff) * math.sqrt(0.1);
    final dosAtEv = _dosCoeff(_mhEff) * math.sqrt(0.1);

    return [
      ReadoutItem(
        label: r'E_c (conduction edge)',
        value: '${ec.toStringAsFixed(3)} eV',
      ),
      ReadoutItem(
        label: r'E_v (valence edge)',
        value: '${ev.toStringAsFixed(3)} eV',
      ),
      ReadoutItem(
        label: r'E_g (bandgap)',
        value: '${_eg.toStringAsFixed(3)} eV',
        boldValue: true,
      ),
      ReadoutItem(
        label: r'E_F (Fermi level)',
        value: '${_fermiOffset.toStringAsFixed(3)} eV',
      ),
      ReadoutItem(
        label: r'g_c at E_c + 0.1 eV',
        value: dosAtEc.toStringAsPrecision(3),
        subtitle: 'Arbitrary units',
      ),
      ReadoutItem(
        label: r'g_v at E_v - 0.1 eV',
        value: dosAtEv.toStringAsPrecision(3),
        subtitle: 'Arbitrary units',
      ),
    ];
  }

  PointInspectorConfig _buildPointInspectorConfig() {
    final pinned = _pinnedPoints.isNotEmpty ? _pinnedPoints.last : null;
    final hover = _hoverPoint;
    return PointInspectorConfig(
      enabled: true,
      emptyMessage: 'Hover DOS curves to inspect values. Tap to pin.',
      onClear: () => updateChart(() {
        _hoverPoint = null;
        _pinnedPoints.clear();
      }),
      interactionHint:
          'Tap curve to pin/unpin (max $_maxPins); tap empty area to clear.',
      isPinned: pinned != null,
      builder: (pinned == null && hover == null)
          ? null
          : () {
              final lines = <String>[];
              if (pinned != null) {
                final edgeDelta =
                    _distanceToBandEdge(pinned.spot.x, pinned.band);
                lines.add('Pinned band: ${pinned.band}');
                lines.add(
                    'Pinned energy = ${pinned.spot.x.toStringAsFixed(3)}\\,\\mathrm{eV}');
                lines.add(
                    'Pinned DOS = ${pinned.spot.y.toStringAsPrecision(4)}');
                lines.add(
                    'Pinned distance to edge = ${edgeDelta.toStringAsFixed(3)}\\,\\mathrm{eV}');
              }
              if (hover != null) {
                final edgeDelta = _distanceToBandEdge(hover.spot.x, hover.band);
                lines.add('Hover band: ${hover.band}');
                lines.add(
                    'Hover energy = ${hover.spot.x.toStringAsFixed(3)}\\,\\mathrm{eV}');
                lines.add('Hover DOS = ${hover.spot.y.toStringAsPrecision(4)}');
                lines.add(
                    'Hover distance to edge = ${edgeDelta.toStringAsFixed(3)}\\,\\mathrm{eV}');
              }
              return lines;
            },
    );
  }

  double _distanceToBandEdge(double e, String band) {
    final ec = _eg / 2;
    final ev = -_eg / 2;
    if (band == 'Conduction') {
      return (e - ec).abs();
    } else {
      return (ev - e).abs();
    }
  }

  Color _pinColorForIndex(int index) => index.isEven ? _pinBlue : _pinRed;

  Color _hoverColorForBand(String band) =>
      band == 'Conduction' ? _pinBlue : _pinRed;

  bool _samePointRef(_DosPointRef a, _DosPointRef b) =>
      a.band == b.band &&
      (a.spot.x - b.spot.x).abs() < 1e-6 &&
      (a.spot.y - b.spot.y).abs() < 1e-6;

  void _togglePinnedPoint(_DosPointRef point) {
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

  String _animParamId(_DosAnimParam param) {
    switch (param) {
      case _DosAnimParam.bandgap:
        return 'eg';
      case _DosAnimParam.meEff:
        return 'me';
      case _DosAnimParam.mhEff:
        return 'mh';
      case _DosAnimParam.energyWindow:
        return 'pad';
      case _DosAnimParam.fermiOffset:
        return 'ef';
    }
  }

  _DosAnimParam _animParamFromId(String id) {
    switch (id) {
      case 'eg':
        return _DosAnimParam.bandgap;
      case 'me':
        return _DosAnimParam.meEff;
      case 'mh':
        return _DosAnimParam.mhEff;
      case 'pad':
        return _DosAnimParam.energyWindow;
      case 'ef':
      default:
        return _DosAnimParam.fermiOffset;
    }
  }

  String _animParamLabel(_DosAnimParam param) {
    switch (param) {
      case _DosAnimParam.bandgap:
        return r'E_g (bandgap)';
      case _DosAnimParam.meEff:
        return r'm_e^* / m_0 (electrons)';
      case _DosAnimParam.mhEff:
        return r'm_h^* / m_0 (holes)';
      case _DosAnimParam.energyWindow:
        return r'\Delta E_{\mathrm{pad}}';
      case _DosAnimParam.fermiOffset:
        return 'E_F (offset)';
    }
  }

  String _animParamSymbol(_DosAnimParam param) {
    switch (param) {
      case _DosAnimParam.bandgap:
        return r'E_g';
      case _DosAnimParam.meEff:
        return r'm_e^* / m_0';
      case _DosAnimParam.mhEff:
        return r'm_h^* / m_0';
      case _DosAnimParam.energyWindow:
        return r'\Delta E_{\mathrm{pad}}';
      case _DosAnimParam.fermiOffset:
        return r'E_F';
    }
  }

  String _animParamUnit(_DosAnimParam param) {
    switch (param) {
      case _DosAnimParam.bandgap:
      case _DosAnimParam.energyWindow:
      case _DosAnimParam.fermiOffset:
        return r'\mathrm{eV}';
      case _DosAnimParam.meEff:
      case _DosAnimParam.mhEff:
        return '';
    }
  }

  double _getCurrentAnimValue(_DosAnimParam param) {
    switch (param) {
      case _DosAnimParam.bandgap:
        return _eg;
      case _DosAnimParam.meEff:
        return _meEff;
      case _DosAnimParam.mhEff:
        return _mhEff;
      case _DosAnimParam.energyWindow:
        return _energyWindow;
      case _DosAnimParam.fermiOffset:
        return _fermiOffset;
    }
  }

  void _setCurrentAnimValue(_DosAnimParam param, double value) {
    switch (param) {
      case _DosAnimParam.bandgap:
        _eg = double.parse(value.toStringAsFixed(3));
        break;
      case _DosAnimParam.meEff:
        _meEff = double.parse(value.toStringAsFixed(3));
        break;
      case _DosAnimParam.mhEff:
        _mhEff = double.parse(value.toStringAsFixed(3));
        break;
      case _DosAnimParam.energyWindow:
        _energyWindow = double.parse(value.toStringAsFixed(2));
        break;
      case _DosAnimParam.fermiOffset:
        _fermiOffset = double.parse(value.toStringAsFixed(3));
        break;
    }
  }

  void _toggleAnimation() {
    if (_isAnimating) {
      _stopAnimation();
    } else {
      _animDirection = _reverseDirection ? -1.0 : 1.0;
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
    if (!mounted) return;
    setState(() => _isAnimating = false);
  }

  void _restartAnimation() {
    _animTimer?.cancel();
    setState(() {
      _animProgress = 0.0;
      _isAnimating = false;
      bumpChart();
    });
    _toggleAnimation();
  }

  void _stepAnimation() {
    var shouldStop = false;
    setState(() {
      _animProgress += 0.01 * _animSpeed * _animDirection;
      if (_animProgress > 1.0 || _animProgress < 0.0) {
        if (_loopEnabled) {
          _animProgress = _animProgress < 0 ? 1.0 : 0.0;
        } else {
          _animProgress = _animProgress.clamp(0.0, 1.0);
          shouldStop = true;
        }
      }
      final range = _animRanges[_animParam]!;
      final value = range.start +
          (_animProgress.clamp(0.0, 1.0) * (range.end - range.start));
      _setCurrentAnimValue(_animParam, value);
      _hoverPoint = null;
      _pinnedPoints.clear();
      bumpChart();
    });
    if (shouldStop) {
      _stopAnimation();
    }
  }

  AnimationConfig _buildAnimationConfig() {
    final params = _DosAnimParam.values.map((param) {
      final range = _animRanges[param]!;
      final isSelected = _animParam == param;
      return AnimatableParameter(
        id: _animParamId(param),
        label: _animParamLabel(param),
        symbol: _animParamSymbol(param),
        unit: _animParamUnit(param),
        currentValue: _getCurrentAnimValue(param),
        rangeMin: range.start,
        rangeMax: range.end,
        absoluteMin: range.start,
        absoluteMax: range.end,
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
          setState(() {
            _setCurrentAnimValue(param, value);
            _hoverPoint = null;
            _pinnedPoints.clear();
            bumpChart();
          });
        },
        onRangeChanged: (min, max) {
          setState(() {
            _animRanges[param] = RangeValues(min, max);
          });
        },
      );
    }).toList();

    return AnimationConfig(
      parameters: params,
      selectedParameterId: _animParamId(_animParam),
      onParameterSelected: (id) {
        setState(() {
          _animParam = _animParamFromId(id);
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
  }

  List<Widget> _buildControlsChildren() {
    return [
      ParameterSlider(
        label: r'Bandgap $E_g$ (eV)',
        value: _eg,
        min: 0.4,
        max: 2.5,
        divisions: 210,
        onChanged: (v) {
          _stopAnimation();
          setState(() {
            _eg = double.parse(v.toStringAsFixed(3));
            _hoverPoint = null;
            _pinnedPoints.clear();
            bumpChart();
          });
        },
      ),
      ParameterSlider(
        label: r'$m_e^*$ / $m_0$ (electrons)',
        value: _meEff,
        min: 0.05,
        max: 2.0,
        divisions: 195,
        onChanged: (v) {
          _stopAnimation();
          setState(() {
            _meEff = double.parse(v.toStringAsFixed(3));
            _hoverPoint = null;
            _pinnedPoints.clear();
            bumpChart();
          });
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
          _stopAnimation();
          setState(() {
            _mhEff = double.parse(v.toStringAsFixed(3));
            _hoverPoint = null;
            _pinnedPoints.clear();
            bumpChart();
          });
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
          _stopAnimation();
          setState(() {
            _energyWindow = double.parse(v.toStringAsFixed(2));
            _hoverPoint = null;
            _pinnedPoints.clear();
            bumpChart();
          });
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
          _stopAnimation();
          setState(() {
            _fermiOffset = double.parse(v.toStringAsFixed(3));
            _hoverPoint = null;
            _pinnedPoints.clear();
            bumpChart();
          });
        },
        subtitle: 'Fermi level position',
      ),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: () {
          _stopAnimation();
          updateChart(() {
            _eg = 1.12;
            _meEff = 0.26;
            _mhEff = 0.39;
            _energyWindow = 1.0;
            _fermiOffset = 0.0;
            _hoverPoint = null;
            _pinnedPoints.clear();
          });
        },
        icon: const Icon(Icons.restart_alt, size: 18),
        label: const Text('Reset to Silicon'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 36),
        ),
      ),
    ];
  }

  List<String> _buildDynamicObservations(double ec, double ev) {
    final obs = <String>[];
    for (var i = 0; i < _pinnedPoints.length; i++) {
      final pin = _pinnedPoints[i];
      final e = pin.spot.x;
      final dos = pin.spot.y;
      final deltaE = pin.band == 'Conduction' ? (e - ec).abs() : (ev - e).abs();
      final edge = pin.band == 'Conduction' ? r'E_c' : r'E_v';
      obs.add('Pin ${i + 1} (${pin.band}): '
          '\$E = ${e.toStringAsFixed(3)}\\,\\mathrm{eV}\$, '
          'DOS = ${dos.toStringAsPrecision(4)}, '
          '\$\\Delta E = ${deltaE.toStringAsFixed(3)}\\,\\mathrm{eV}\$ '
          'from \$$edge\$.');
    }

    if (_hoverPoint != null) {
      final hover = _hoverPoint!;
      final e = hover.spot.x;
      final dos = hover.spot.y;
      final deltaE =
          hover.band == 'Conduction' ? (e - ec).abs() : (ev - e).abs();
      final edge = hover.band == 'Conduction' ? r'E_c' : r'E_v';
      obs.add('Current hover (${hover.band}): '
          '\$E = ${e.toStringAsFixed(3)}\\,\\mathrm{eV}\$, '
          'DOS = ${dos.toStringAsPrecision(4)}, '
          '\$\\Delta E = ${deltaE.toStringAsFixed(3)}\\,\\mathrm{eV}\$ '
          'from \$$edge\$.');
    }

    return obs;
  }

  List<String> _buildStaticObservations() {
    return [
      r'DOS $\propto (m^*)^{3/2}$; heavier effective mass -> more available states.',
      r'Conduction DOS: $g_c(E) \propto \sqrt{E - E_c}$ (parabolic band).',
      r'Valence DOS: $g_v(E) \propto \sqrt{E_v - E}$ (parabolic band).',
      r'Carrier concentration $\propto$ DOS $\times$ Fermi-Dirac distribution.',
    ];
  }

  Widget _buildChartCard(
      BuildContext context, _DosData data, double ec, double ev) {
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
                      _legendSwatch(
                          Theme.of(context).colorScheme.primary, 'Conduction'),
                      _legendSwatch(
                          Theme.of(context).colorScheme.tertiary, 'Valence'),
                      _legendLine(
                          Theme.of(context).colorScheme.error, r'$E_F$'),
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
        LatexText(label, scale: 0.95, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildChart(
      BuildContext context, _DosData data, double ec, double ev) {
    final conductionColor = Theme.of(context).colorScheme.primary;
    final valenceColor = Theme.of(context).colorScheme.tertiary;
    final efColor = Theme.of(context).colorScheme.error;
    final hover = _hoverPoint;

    final lineBars = <LineChartBarData>[
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
                  radius: 5.0,
                  strokeColor: Colors.white,
                  strokeWidth: 2.0,
                ),
              ),
            ),
          ),
      if (hover != null && !_pinnedPoints.any((p) => _samePointRef(p, hover)))
        LineChartBarData(
          spots: [hover.spot],
          isCurved: false,
          color: Colors.transparent,
          barWidth: 0,
          dotData: FlDotData(
            show: true,
            checkToShowDot: (_, __) => true,
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
              color: _hoverColorForBand(hover.band).withValues(alpha: 0.22),
              radius: 5.8,
              strokeColor: _hoverColorForBand(hover.band),
              strokeWidth: 2.4,
            ),
          ),
        ),
    ];

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
              color: conductionColor.withValues(alpha: 0.45),
              dashArray: [6, 4],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(bottom: 6, right: 4),
                labelResolver: (_) => 'Ec',
              ),
            ),
            VerticalLine(
              x: ev,
              color: valenceColor.withValues(alpha: 0.45),
              dashArray: [6, 4],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                labelResolver: (_) => 'Ev',
              ),
            ),
            VerticalLine(
              x: _fermiOffset,
              color: efColor.withValues(alpha: 0.5),
              strokeWidth: 2,
              dashArray: [4, 4],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.only(top: 4, right: 4),
                labelResolver: (_) => 'Ef',
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
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchSpotThreshold: 28,
          distanceCalculator: (touchPoint, spotPixelCoordinates) {
            final delta = touchPoint - spotPixelCoordinates;
            return delta.distance;
          },
          getTouchedSpotIndicator: (bar, indexes) {
            return indexes
                .map(
                  (_) => TouchedSpotIndicatorData(
                    FlLine(
                        color: bar.color?.withValues(alpha: 0.4),
                        dashArray: [4, 4],
                        strokeWidth: 1),
                    FlDotData(show: false),
                  ),
                )
                .toList();
          },
          touchCallback: (event, response) {
            final spots = response?.lineBarSpots;
            if (spots == null || spots.isEmpty) {
              if (event is FlTapUpEvent &&
                  (_hoverPoint != null || _pinnedPoints.isNotEmpty)) {
                updateChart(() {
                  _hoverPoint = null;
                  _pinnedPoints.clear();
                });
                return;
              }
              if (event is FlPointerExitEvent) {
                setState(() {
                  _hoverPoint = null;
                });
              }
              return;
            }
            final candidates =
                spots.where((s) => s.barIndex == 0 || s.barIndex == 1).toList();
            if (candidates.isEmpty) {
              return;
            }
            final spot = candidates.first;
            final band = switch (spot.barIndex) {
              0 => 'Conduction',
              1 => 'Valence',
              _ => null,
            };
            if (band == null) return;
            final next = _DosPointRef(
              band: band,
              spot: FlSpot(spot.x, spot.y),
            );

            if (event is FlTapUpEvent) {
              updateChart(() {
                _hoverPoint = next;
                _togglePinnedPoint(next);
              });
              return;
            }

            if (_hoverPoint != null && _samePointRef(_hoverPoint!, next))
              return;
            setState(() => _hoverPoint = next);
          },
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => Colors.white.withValues(alpha: 0.98),
            tooltipBorder: BorderSide(
              color: Colors.black.withValues(alpha: 0.16),
              width: 1,
            ),
            getTooltipItems: (spots) => spots
                .where((s) => s.barIndex == 0 || s.barIndex == 1)
                .map(
                  (s) => LineTooltipItem(
                    '${s.barIndex == 0 ? 'Conduction' : 'Valence'}\n'
                    'E = ${s.x.toStringAsFixed(3)} eV\n'
                    'DOS = ${s.y.toStringAsPrecision(4)}',
                    const TextStyle(
                      color: Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: lineBars,
      ),
    );
  }

  _DosData _buildData(
      {required double ec,
      required double ev,
      required double eMin,
      required double eMax}) {
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

  _DosData(
      {required this.conduction, required this.valence, required this.maxDos});
}
