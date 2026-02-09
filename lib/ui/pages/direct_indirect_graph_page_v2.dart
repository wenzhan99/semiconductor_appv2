import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/chart_style.dart';
import '../widgets/latex_text.dart';
import '../graphs/common/graph_controller.dart';
import '../graphs/common/readouts_card.dart';
import '../graphs/common/point_inspector_card.dart';
import '../graphs/common/animation_card.dart';
import '../graphs/common/parameters_card.dart';
import '../graphs/common/key_observations_card.dart';
import '../graphs/common/chart_toolbar.dart';
import '../graphs/common/viewport_state.dart';

class DirectIndirectGraphPageV2 extends StatefulWidget {
  const DirectIndirectGraphPageV2({super.key});

  @override
  State<DirectIndirectGraphPageV2> createState() => _DirectIndirectGraphPageV2State();
}

enum GapType { direct, indirect }
enum EnergyReference { midgap, evZero, ecZero }
enum AnimateParam { k0, eg, mnStar, mpStar }

class _SelectedPoint {
  final String band;
  final double k;
  final double kScaled;
  final double energy;

  _SelectedPoint({
    required this.band,
    required this.k,
    required this.kScaled,
    required this.energy,
  });
}

class _DirectIndirectGraphPageV2State extends State<DirectIndirectGraphPageV2>
    with GraphController {
  GapType _gapType = GapType.direct;
  String _preset = 'GaAs (Direct)';

  double _eg = 1.42;
  double _mnEff = 0.067;
  double _mpEff = 0.50;
  double _k0Scaled = 0.0;
  double _kMaxScaled = 1.2;
  double _points = 600;

  bool _showTransitions = true;
  bool _showBandEdges = true;
  EnergyReference _energyReference = EnergyReference.midgap;

  late ViewportState _viewport;
  bool _scaleLineWidthWithZoom = false;

  // Animation
  bool _isAnimating = false;
  Timer? _animationTimer;
  double _animationProgress = 0.0;
  AnimateParam _animateParam = AnimateParam.k0;
  double _animateSpeed = 1.0;
  bool _animateLoop = true;

  _SelectedPoint? _selectedPoint;

  static const double _kDisplayScale = 1e10;
  static const double _hbar = 1.054571817e-34;
  static const double _m0 = 9.1093837015e-31;
  static const double _q = 1.602176634e-19;

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

  @override
  void initState() {
    super.initState();
    _initViewport();
  }

  void _initViewport() {
    _viewport = ViewportState(
      defaultMinX: -_kMaxScaled,
      defaultMaxX: _kMaxScaled,
      defaultMinY: -1.0,
      defaultMaxY: 1.0,
    );
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

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

    return Scaffold(
      appBar: AppBar(title: const Text('Direct vs Indirect Bandgap')),
      body: LayoutBuilder(
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
                      ? _buildWideLayout(context, egDirect, egIndirect, kCbmScaled, ec, ev, kVbm, kCbm, evAtVbm, ecAtGamma)
                      : _buildNarrowLayout(context, egDirect, egIndirect, kCbmScaled, ec, ev, kVbm, kCbm, evAtVbm, ecAtGamma),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Direct vs Indirect Bandgap (Schematic E–k)',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Energy & Band Structure',
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
            child: const Column(
              children: [
                LatexText(
                  r'E_c(k) = E_c + \frac{\hbar^2 (k-k_0)^2}{2 m_e^*}, \quad '
                  r'E_v(k) = E_v - \frac{\hbar^2 k^2}{2 m_h^*}',
                  displayMode: true,
                  scale: 1.1,
                ),
              ],
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
            Text('About', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Shows parabolic conduction and valence bands. Direct bandgap: CBM and VBM at same k → vertical photon transition. Indirect: CBM shifted to k₀ ≠ 0 → phonon needed for momentum conservation.',
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
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _bullet('Direct bandgap: CBM and VBM occur at the same k → vertical (photon) transition possible.'),
          _bullet(r'Indirect bandgap: CBM is shifted to $k_0 \neq 0$ → phonon needed to conserve momentum.'),
          _bullet(r'$E_{g,\text{indirect}}$ is the true minimum gap; $E_{g,\text{direct}}$ is higher for indirect materials.'),
          const SizedBox(height: 8),
          Text('Try this:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          _bullet('Switch between GaAs and Si presets and see the CB minimum shift.'),
          _bullet('Turn on transitions and compare vertical vs diagonal transition.'),
          _bullet(r'Drag $k_0$ and watch $E_{g,\text{indirect}}$ change.'),
          _bullet('Use Animation to see parameters sweep smoothly.'),
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

  Widget _buildWideLayout(BuildContext context, double egDirect, double egIndirect, double kCbmScaled, double ec, double ev, double kVbm, double kCbm, double evAtVbm, double ecAtGamma) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildChartCard(context, ec, ev, kVbm, kCbm, kCbmScaled, evAtVbm, ecAtGamma, egDirect, egIndirect),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildReadoutsCard(egDirect, egIndirect, kCbmScaled, ec, ev),
                const SizedBox(height: 12),
                _buildPointInspectorCard(),
                const SizedBox(height: 12),
                _buildAnimationCard(),
                const SizedBox(height: 12),
                _buildParametersCard(),
                const SizedBox(height: 12),
                _buildKeyObservationsCard(egDirect, egIndirect, kCbmScaled),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, double egDirect, double egIndirect, double kCbmScaled, double ec, double ev, double kVbm, double kCbm, double evAtVbm, double ecAtGamma) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 300, maxHeight: 450),
            child: _buildChartCard(context, ec, ev, kVbm, kCbm, kCbmScaled, evAtVbm, ecAtGamma, egDirect, egIndirect),
          ),
          const SizedBox(height: 12),
          _buildReadoutsCard(egDirect, egIndirect, kCbmScaled, ec, ev),
          const SizedBox(height: 12),
          _buildPointInspectorCard(),
          const SizedBox(height: 12),
          _buildAnimationCard(),
          const SizedBox(height: 12),
          _buildParametersCard(),
          const SizedBox(height: 12),
          _buildKeyObservationsCard(egDirect, egIndirect, kCbmScaled),
        ],
      ),
    );
  }

  Widget _buildReadoutsCard(double egDirect, double egIndirect, double kCbmScaled, double ec, double ev) {
    return ReadoutsCard(
      title: 'Gap Readouts',
      readouts: [
        ReadoutItem(
          label: r'$E_{g,\text{direct}}$',
          value: '${egDirect.toStringAsFixed(3)} eV',
          boldValue: true,
        ),
        ReadoutItem(
          label: r'$E_{g,\text{indirect}}$',
          value: '${egIndirect.toStringAsFixed(3)} eV',
          boldValue: true,
        ),
        ReadoutItem(
          label: r'CBM position $k_0$',
          value: '${kCbmScaled.toStringAsFixed(3)} ×10¹⁰ m⁻¹',
        ),
        ReadoutItem(
          label: r'$E_c$ (conduction edge)',
          value: '${_formatEnergy(ec)} eV',
        ),
        ReadoutItem(
          label: r'$E_v$ (valence edge)',
          value: '${_formatEnergy(ev)} eV',
        ),
        ReadoutItem(
          label: r'Gap type',
          value: _gapType == GapType.direct ? 'Direct' : 'Indirect',
        ),
      ],
    );
  }

  Widget _buildPointInspectorCard() {
    return PointInspectorCard<_SelectedPoint>(
      selectedPoint: _selectedPoint,
      onClear: () => updateChart(() => _selectedPoint = null),
      builder: (sp) {
        final cbmKScaled = _gapType == GapType.direct ? 0.0 : _k0Scaled;
        final nearestEdge = sp.band == 'Valence'
            ? 'VBM (k≈0)'
            : (sp.kScaled - cbmKScaled).abs() < 0.05
                ? 'CBM (k≈${cbmKScaled.toStringAsFixed(2)} ×10¹⁰ m⁻¹)'
                : 'Conduction band';
        return [
          'Band: ${sp.band}',
          'k = ${_sci3(sp.k)} m⁻¹',
          'k = ${sp.kScaled.toStringAsFixed(3)} ×10¹⁰ m⁻¹',
          'E = ${sp.energy.toStringAsFixed(4)} eV',
          'Nearest: $nearestEdge',
        ];
      },
    );
  }

  Widget _buildAnimationCard() {
    final paramName = _animateParam == AnimateParam.k0
        ? 'k₀'
        : _animateParam == AnimateParam.eg
            ? 'Eg'
            : _animateParam == AnimateParam.mnStar
                ? 'mn*'
                : 'mp*';

    return AnimationCard(
      description: 'Animate $paramName',
      currentValue: 'Speed: ${_animateSpeed.toStringAsFixed(2)}×, Loop: ${_animateLoop ? "On" : "Off"}',
      isAnimating: _isAnimating,
      progress: _animationProgress,
      onPlay: _startAnimation,
      onPause: _stopAnimation,
      onReset: _restartAnimation,
      collapsible: true,
      initiallyExpanded: false,
      customControls: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParameterDropdown<AnimateParam>(
            label: 'Animate parameter',
            value: _animateParam,
            items: const [
              DropdownMenuItem(value: AnimateParam.k0, child: Text('k₀')),
              DropdownMenuItem(value: AnimateParam.eg, child: Text('Eg')),
              DropdownMenuItem(value: AnimateParam.mnStar, child: Text('mn*')),
              DropdownMenuItem(value: AnimateParam.mpStar, child: Text('mp*')),
            ],
            onChanged: (v) => setState(() => _animateParam = v!),
          ),
          ParameterSlider(
            label: 'Speed',
            value: _animateSpeed,
            min: 0.25,
            max: 4.0,
            divisions: 15,
            onChanged: (v) => setState(() => _animateSpeed = v),
            valueFormatter: (v) => '${v.toStringAsFixed(2)}×',
          ),
          ParameterSwitch(
            label: 'Loop animation',
            value: _animateLoop,
            onChanged: (v) => setState(() => _animateLoop = v),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _isAnimating ? _stopAnimation : _startAnimation,
                icon: Icon(_isAnimating ? Icons.pause : Icons.play_arrow),
                label: Text(_isAnimating ? 'Pause' : 'Play'),
              ),
              ElevatedButton.icon(
                onPressed: _restartAnimation,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restart'),
              ),
            ],
          ),
          if (_isAnimating) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _animationProgress),
          ],
        ],
      ),
    );
  }

  Widget _buildParametersCard() {
    return ParametersCard(
      title: 'Parameters',
      collapsible: true,
      initiallyExpanded: true,
      children: [
        ParameterSegmented<GapType>(
          label: 'Gap type',
          selected: {_gapType},
          segments: const [
            ButtonSegment(value: GapType.direct, label: Text('Direct')),
            ButtonSegment(value: GapType.indirect, label: Text('Indirect')),
          ],
          onSelectionChanged: (s) => updateChart(() {
            _gapType = s.first;
            if (_gapType == GapType.direct) _k0Scaled = 0.0;
            _selectedPoint = null;
          }),
        ),
        ParameterDropdown<String>(
          label: 'Material preset',
          value: _preset,
          items: const [
            DropdownMenuItem(value: 'GaAs (Direct)', child: Text('GaAs (Direct)')),
            DropdownMenuItem(value: 'Si (Indirect)', child: Text('Si (Indirect)')),
            DropdownMenuItem(value: 'Custom', child: Text('Custom')),
          ],
          onChanged: (v) => updateChart(() {
            _preset = v!;
            _applyPreset(v);
          }),
        ),
        ParameterDropdown<EnergyReference>(
          label: 'Energy reference',
          value: _energyReference,
          items: const [
            DropdownMenuItem(value: EnergyReference.midgap, child: Text('Midgap = 0')),
            DropdownMenuItem(value: EnergyReference.evZero, child: Text('Ev = 0')),
            DropdownMenuItem(value: EnergyReference.ecZero, child: Text('Ec = 0')),
          ],
          onChanged: (v) => updateChart(() {
            _energyReference = v!;
            _selectedPoint = null;
          }),
        ),
        ParameterSlider(
          label: r'$E_g$ (eV)',
          value: _eg,
          min: 0.2,
          max: 2.5,
          divisions: 230,
          onChanged: (v) => _updateCustom(() => _eg = double.parse(v.toStringAsFixed(3))),
        ),
        ParameterSlider(
          label: r'$m_n^*$ (×$m_0$)',
          value: _mnEff,
          min: 0.05,
          max: 2.0,
          divisions: 195,
          onChanged: (v) => _updateCustom(() => _mnEff = double.parse(v.toStringAsFixed(3))),
        ),
        ParameterSlider(
          label: r'$m_p^*$ (×$m_0$)',
          value: _mpEff,
          min: 0.05,
          max: 2.0,
          divisions: 195,
          onChanged: (v) => _updateCustom(() => _mpEff = double.parse(v.toStringAsFixed(3))),
        ),
        ParameterSlider(
          label: r'$k_0$ (×10¹⁰ m⁻¹)',
          value: _k0Scaled,
          min: 0.0,
          max: 1.5,
          divisions: 150,
          onChanged: _gapType == GapType.indirect
              ? (v) => _updateCustom(() => _k0Scaled = double.parse(v.toStringAsFixed(3)))
              : null,
        ),
        ParameterSlider(
          label: r'$k_{\text{max}}$ (×10¹⁰ m⁻¹)',
          value: _kMaxScaled,
          min: 0.5,
          max: 2.0,
          divisions: 150,
          onChanged: (v) => _updateCustom(() => _kMaxScaled = double.parse(v.toStringAsFixed(2))),
        ),
        ParameterSwitch(
          label: 'Show transitions',
          value: _showTransitions,
          onChanged: (v) => updateChart(() => _showTransitions = v),
        ),
        ParameterSwitch(
          label: 'Show band edges',
          value: _showBandEdges,
          onChanged: (v) => updateChart(() => _showBandEdges = v),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _resetDemo,
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text('Reset Demo'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 36)),
        ),
      ],
    );
  }

  Widget _buildKeyObservationsCard(double egDirect, double egIndirect, double kCbmScaled) {
    final dynamicObs = _buildDynamicObservations(egDirect, egIndirect, kCbmScaled);
    final staticObs = _buildStaticObservations();

    return KeyObservationsCard(
      title: 'Key Observations',
      dynamicObservations: dynamicObs.isNotEmpty ? dynamicObs : null,
      staticObservations: staticObs,
      dynamicTitle: 'Current Configuration',
    );
  }

  List<String> _buildDynamicObservations(double egDirect, double egIndirect, double kCbmScaled) {
    final obs = <String>[];

    if (_gapType == GapType.direct) {
      obs.add('Direct gap: CBM and VBM at k≈0 → vertical photon transition. \$E_{g,\\text{dir}} = ${egDirect.toStringAsFixed(3)}\$ eV.');
    } else {
      obs.add('Indirect gap: CBM at \$k_0 = ${kCbmScaled.toStringAsFixed(3)} \\times 10^{10}\$ m⁻¹ → phonon needed. \$E_{g,\\text{ind}} = ${egIndirect.toStringAsFixed(3)}\$ eV.');
      final deltaK = kCbmScaled.abs();
      obs.add('CBM shift: \$\\Delta k = ${deltaK.toStringAsFixed(3)} \\times 10^{10}\$ m⁻¹ from Γ. Larger \$k_0\$ makes gap more indirect.');
    }

    if (_selectedPoint != null) {
      final sp = _selectedPoint!;
      final cbmKScaled = _gapType == GapType.direct ? 0.0 : _k0Scaled;
      final nearestEdge = sp.band == 'Valence' ? 'VBM' : (sp.kScaled - cbmKScaled).abs() < 0.05 ? 'CBM' : 'Away from CBM';
      obs.add('Selected: k=${sp.kScaled.toStringAsFixed(3)} ×10¹⁰ m⁻¹, E=${sp.energy.toStringAsFixed(3)} eV. Nearest: $nearestEdge.');
    }

    return obs;
  }

  List<String> _buildStaticObservations() {
    return [
      r'Parabolic bands: $E \propto k^2$; smaller $m^*$ → steeper curvature.',
      r'Direct gap materials (GaAs, InP): efficient light emission (LEDs, lasers).',
      r'Indirect gap materials (Si, Ge): require phonons → less efficient light emission.',
      r'Momentum conservation: photon has negligible k; phonon provides $\Delta k$.',
    ];
  }

  Widget _buildChartCard(BuildContext context, double ec, double ev, double kVbm, double kCbm, double kCbmScaled, double evAtVbm, double ecAtGamma, double egDirect, double egIndirect) {
    final bandColors = (
      conduction: Theme.of(context).colorScheme.primary,
      valence: Theme.of(context).colorScheme.tertiary,
    );
    final transitionColors = (
      photon: Theme.of(context).colorScheme.secondary,
      phonon: Theme.of(context).colorScheme.error.withOpacity(0.7),
    );

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _gapType == GapType.direct
                    ? 'Direct: CBM and VBM at same k (vertical transition possible)'
                    : 'Indirect: CBM shifted to k₀ ≠ 0 (phonon needed)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _legendSwatch(bandColors.conduction, 'Conduction'),
                      _legendSwatch(bandColors.valence, 'Valence'),
                      if (_showTransitions) _legendDash(transitionColors.photon, 'Photon'),
                      if (_showTransitions && _gapType == GapType.indirect)
                        _legendDash(transitionColors.phonon, 'Phonon'),
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
            Expanded(
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent && HardwareKeyboard.instance.isControlPressed) {
                    final delta = event.scrollDelta.dy;
                    updateChart(() => _viewport.zoom(delta > 0 ? -0.1 : 0.1));
                  }
                },
                child: _buildChart(context, bandColors, transitionColors, kVbm, kCbm, kCbmScaled, evAtVbm, ecAtGamma),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, ({Color conduction, Color valence}) bandColors, ({Color photon, Color phonon}) transitionColors, double kVbm, double kCbm, double kCbmScaled, double evAtVbm, double ecAtGamma) {
    final viewRange = _currentViewXRange();
    final data = _buildData(viewRange.$1, viewRange.$2);

    final yValues = [
      ...data.conduction.map((p) => p.energy),
      ...data.valence.map((p) => p.energy),
    ];
    final minY = yValues.reduce(math.min);
    final maxY = yValues.reduce(math.max);
    final pad = (maxY - minY).abs() * 0.15 + 0.1;

    final centerY = (minY + maxY) / 2;
    final rangeY = (maxY - minY + 2 * pad) / _viewport.zoomScale;
    final zoomedMinY = centerY - rangeY / 2;
    final zoomedMaxY = centerY + rangeY / 2;

    final lineWidth = _scaleLineWidthWithZoom ? 2 * math.sqrt(_viewport.zoomScale.clamp(0.5, 5.0)) : 2.0;

    final lineBars = <LineChartBarData>[
      LineChartBarData(
        spots: data.conduction.map((p) => FlSpot(p.kScaled, p.energy)).toList(),
        isCurved: false,
        color: bandColors.conduction,
        barWidth: lineWidth,
        dotData: const FlDotData(show: false),
      ),
      LineChartBarData(
        spots: data.valence.map((p) => FlSpot(p.kScaled, p.energy)).toList(),
        isCurved: false,
        color: bandColors.valence,
        barWidth: lineWidth,
        dotData: const FlDotData(show: false),
      ),
    ];

    if (_showTransitions) {
      lineBars.add(LineChartBarData(
        spots: [FlSpot(kVbm / _kDisplayScale, evAtVbm), FlSpot(kVbm / _kDisplayScale, ecAtGamma)],
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
      ));

      if (_gapType == GapType.indirect) {
        lineBars.add(LineChartBarData(
          spots: [FlSpot(kVbm / _kDisplayScale, evAtVbm), FlSpot(kCbmScaled, _conductionEnergy(k: kCbm))],
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
        ));
      }
    }

    return LineChart(
      key: ValueKey('direct-$chartVersion'),
      LineChartData(
        minX: _viewport.minX,
        maxX: _viewport.maxX,
        minY: zoomedMinY,
        maxY: zoomedMaxY,
        extraLinesData: _showBandEdges
            ? ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(y: _bandEdges().ec, color: bandColors.conduction.withOpacity(0.35), strokeWidth: 1, dashArray: [4, 4]),
                  HorizontalLine(y: _bandEdges().ev, color: bandColors.valence.withOpacity(0.35), strokeWidth: 1, dashArray: [4, 4]),
                ],
              )
            : null,
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (event is FlTapUpEvent && response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
              final spot = response.lineBarSpots!.first;
              final series = spot.barIndex == 0 ? data.conduction : data.valence;
              final nearest = _nearestPoint(series, spot.x);
              if (nearest != null) {
                setState(() {
                  _selectedPoint = _SelectedPoint(
                    band: spot.barIndex == 0 ? 'Conduction' : 'Valence',
                    k: nearest.k,
                    kScaled: nearest.kScaled,
                    energy: nearest.energy,
                  );
                });
              }
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => List<LineTooltipItem?>.filled(spots.length, null),
          ),
        ),
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: const LatexText(r'E\ (\mathrm{eV})', scale: 0.95),
            axisNameSize: 44,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: context.chartStyle.leftReservedSize,
              getTitlesWidget: (v, _) => Padding(
                padding: context.chartStyle.tickPadding,
                child: Text(v.toStringAsFixed(1), style: context.chartStyle.tickTextStyle),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const LatexText(r'k\ (\times 10^{10}\ \mathrm{m^{-1}})', scale: 0.95),
            axisNameSize: 40,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: context.chartStyle.bottomReservedSize,
              getTitlesWidget: (v, _) => Padding(
                padding: context.chartStyle.tickPadding,
                child: Text(v.toStringAsFixed(1), style: context.chartStyle.tickTextStyle),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: lineBars,
      ),
    );
  }

  // === Physics and helper methods ===
  ({double ec, double ev}) _bandEdges() {
    switch (_energyReference) {
      case EnergyReference.midgap:
        return (ec: _eg / 2, ev: -_eg / 2);
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

    final conduction = <_GraphPoint>[];
    final valence = <_GraphPoint>[];

    for (var i = 0; i < pts; i++) {
      final t = pts == 1 ? 0.0 : i / (pts - 1);
      final k = kMin + (kMax - kMin) * t;
      final kScaled = k / _kDisplayScale;

      final eValence = edges.ev - _bandEnergyTerm(k, _mpEff);
      valence.add(_GraphPoint(k: k, kScaled: kScaled, energy: eValence));

      final eConduction = edges.ec + _bandEnergyTerm(k - k0, _mnEff);
      conduction.add(_GraphPoint(k: k, kScaled: kScaled, energy: eConduction));
    }

    return _GraphData(conduction: conduction, valence: valence);
  }

  double _bandEnergyTerm(double k, double mEff) => (_hbar * _hbar * k * k) / (2 * (mEff * _m0)) / _q;

  double _conductionEnergy({required double k}) {
    final ec = _bandEdges().ec;
    final k0 = (_gapType == GapType.direct ? 0.0 : _k0Scaled) * _kDisplayScale;
    return ec + _bandEnergyTerm(k - k0, _mnEff);
  }

  void _clampK0() {
    final max = _kMaxScaled.abs();
    if (_k0Scaled > max) _k0Scaled = max;
    if (_k0Scaled < -max) _k0Scaled = -max;
  }

  (double, double) _currentViewXRange() {
    final baseRange = _kMaxScaled * 2;
    final range = baseRange / _viewport.zoomScale;
    var min = -range / 2;
    var max = range / 2;
    const double cap = 3.0;
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
    return pts.reduce((a, b) => (a.kScaled - xScaled).abs() < (b.kScaled - xScaled).abs() ? a : b);
  }

  void _applyPreset(String preset) {
    final p = _presets[preset];
    if (p != null) {
      _eg = p.eg;
      _mnEff = p.mnEff;
      _mpEff = p.mpEff;
      _k0Scaled = p.k0Scaled;
      _kMaxScaled = p.kMaxScaled;
      _gapType = p.gapType;
      _selectedPoint = null;
    }
  }

  void _resetDemo() {
    _stopAnimation();
    updateChart(() {
      _preset = 'GaAs (Direct)';
      _applyPreset(_preset);
      _points = 600;
      _showTransitions = true;
      _showBandEdges = true;
      _energyReference = EnergyReference.midgap;
      _selectedPoint = null;
      _viewport.reset();
    });
  }

  void _updateCustom(VoidCallback update) {
    setState(() {
      update();
      if (_preset != 'Custom') _preset = 'Custom';
      if (_gapType == GapType.direct) _k0Scaled = 0.0;
      _selectedPoint = null;
      bumpChart();
    });
  }

  String _formatEnergy(double value) {
    final adjusted = value.abs() < 0.0005 ? 0.0 : value;
    final sign = adjusted >= 0 ? '+' : '';
    return '$sign${adjusted.toStringAsFixed(3)}';
  }

  String _sci3(double value) {
    if (value == 0) return '0';
    final exp = (math.log(value.abs()) / math.ln10).floor();
    final mant = value / math.pow(10, exp);
    return '${mant.toStringAsFixed(3)}×10^$exp';
  }

  Widget _legendSwatch(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 10, width: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
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
          children: List.generate(3, (_) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(width: 6, height: 2, color: color),
          )),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // Animation methods
  void _startAnimation() {
    if (_isAnimating) return;
    setState(() {
      _isAnimating = true;
      _animationProgress = 0.0;
    });

    final ranges = _getAnimationRange(_animateParam);
    final duration = Duration(milliseconds: (2500 / _animateSpeed).round());
    const steps = 60;
    final stepDuration = Duration(milliseconds: duration.inMilliseconds ~/ steps);

    _animationTimer = Timer.periodic(stepDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _animationProgress += 1.0 / steps;
        if (_animationProgress >= 1.0) {
          _animationProgress = 1.0;
          if (_animateLoop) {
            _animationProgress = 0.0;
          } else {
            _isAnimating = false;
            timer.cancel();
          }
        }

        final value = ranges.min + (ranges.max - ranges.min) * _animationProgress;
        switch (_animateParam) {
          case AnimateParam.k0:
            _k0Scaled = value;
            break;
          case AnimateParam.eg:
            _eg = value;
            break;
          case AnimateParam.mnStar:
            _mnEff = value;
            break;
          case AnimateParam.mpStar:
            _mpEff = value;
            break;
        }
        bumpChart();
      });
    });
  }

  void _stopAnimation() {
    _animationTimer?.cancel();
    setState(() => _isAnimating = false);
  }

  void _restartAnimation() {
    _stopAnimation();
    setState(() => _animationProgress = 0.0);
    _startAnimation();
  }

  ({double min, double max}) _getAnimationRange(AnimateParam param) {
    switch (param) {
      case AnimateParam.k0:
        return (min: 0.0, max: 1.2);
      case AnimateParam.eg:
        return (min: 0.5, max: 2.0);
      case AnimateParam.mnStar:
        return (min: 0.05, max: 1.0);
      case AnimateParam.mpStar:
        return (min: 0.05, max: 1.0);
    }
  }
}

class _GraphData {
  final List<_GraphPoint> conduction;
  final List<_GraphPoint> valence;
  _GraphData({required this.conduction, required this.valence});
}

class _GraphPoint {
  final double k, kScaled, energy;
  _GraphPoint({required this.k, required this.kScaled, required this.energy});
}

class _Preset {
  final double eg, mnEff, mpEff, k0Scaled, kMaxScaled;
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
