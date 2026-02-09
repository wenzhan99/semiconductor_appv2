import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/latex_symbols.dart';
import '../../core/constants/constants_loader.dart';
import '../../services/app_state.dart';
import '../theme/chart_style.dart';
import '../widgets/latex_text.dart';
import '../graphs/utils/latex_format.dart';
import '../graphs/utils/safe_math.dart';
import '../graphs/utils/visualization_animator.dart';

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

class _FermiDiracGraphViewState extends State<FermiDiracGraphView> with SingleTickerProviderStateMixin {
  int _chartVersion = 0;
  // Parameters
  double _temperature = 300.0; // K
  double _fermiLevel = 0.0; // eV
  bool _relativeToFermi = true;
  
  // Animation
  late VisualizationAnimator _animator;
  bool _loop = true;
  double _speed = 1.0;
  bool _autoPlayed = false;
  
  // Constants
  static const double kBoltzmannEV = 8.617333262e-5; // eV/K
  
  late Future<LatexSymbolMap> _latexSymbols;
  Offset? _tooltipPos;
  String? _tooltipLatex;

  @override
  void initState() {
    super.initState();
    _latexSymbols = ConstantsLoader.loadLatexSymbols();
    _animator = VisualizationAnimator(
      vsync: this,
      min: 100,
      max: 600,
      baseDuration: const Duration(seconds: 4),
      onValue: (v) => setState(() {
        _temperature = v;
        _chartVersion++;
      }),
    );
  }

  @override
  void dispose() {
    _animator.dispose();
    super.dispose();
  }

  List<FlSpot> _computeFermiDiracCurve() {
    const int numPoints = 400;
    final List<FlSpot> points = [];
    
    const double eMin = -0.5; // eV relative to EF
    const double eMax = 0.5;  // eV relative to EF
    
    final kT = kBoltzmannEV * _temperature; // eV
    
    for (int i = 0; i < numPoints; i++) {
      final double eRel = eMin + (eMax - eMin) * i / (numPoints - 1);
      final double eAbs = eRel + _fermiLevel;
      
      // f(E) = 1 / (1 + exp((E - EF)/kT))
      final double exponent = eRel / kT;
      final double f = 1.0 / (1.0 + SafeMath.safeExp(exponent));
      
      final double xValue = _relativeToFermi ? eRel : eAbs;
      points.add(FlSpot(xValue, f));
    }
    
    return points;
  }

  void _maybeAutoPlay(BuildContext context) {
    if (_autoPlayed) return;
    final reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final auto = context.read<AppState>().autoPlayVisualizations;
    if (auto && !reducedMotion) {
      _autoPlayed = true;
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _animator.start();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _maybeAutoPlay(context);
    return FutureBuilder<LatexSymbolMap>(
      future: _latexSymbols,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildChartArea(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          _buildControls(context),
                          const SizedBox(height: 12),
                          _buildAnimationControls(context),
                          const SizedBox(height: 12),
                          Expanded(child: _buildInsights(context)),
                        ],
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
          'Fermi–Dirac Probability Distribution',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const LatexText(
          r'f(E) = \frac{1}{1 + \exp\left(\frac{E - E_F}{k T}\right)}',
          displayMode: true,
          scale: 1.2,
        ),
      ],
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'The Fermi-Dirac distribution describes the probability that an electron occupies an energy state E at thermal equilibrium.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartArea(BuildContext context) {
    final curveData = _computeFermiDiracCurve();
    
    if (curveData.isEmpty) {
      return const Center(child: Text('No data'));
    }
    
    final xLabel = _relativeToFermi ? r'E - E_F\text{ (eV)}' : r'E\text{ (eV)}';
    
    return Stack(
      children: [
        LineChart(
          key: ValueKey('fermi-$_chartVersion'),
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: 0.2,
              verticalInterval: 0.2,
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                axisNameWidget: const LatexText(r'f(E)', scale: 1.0),
                axisNameSize: 44,
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: context.chartStyle.leftReservedSize,
                  getTitlesWidget: (value, meta) {
                    if (value < 0 || value > 1) return const SizedBox.shrink();
                    return Padding(
                      padding: context.chartStyle.tickPadding,
                      child: LatexText(
                        value.toStringAsFixed(1),
                        style: context.chartStyle.tickTextStyle,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                axisNameWidget: LatexText(xLabel, scale: 1.0),
                axisNameSize: 40,
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: context.chartStyle.bottomReservedSize,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: context.chartStyle.tickPadding,
                      child: LatexText(
                        value.toStringAsFixed(1),
                        style: context.chartStyle.tickTextStyle,
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: true),
            minX: _relativeToFermi ? -0.5 : _fermiLevel - 0.5,
            maxX: _relativeToFermi ? 0.5 : _fermiLevel + 0.5,
            minY: -0.05,
            maxY: 1.05,
            lineBarsData: [
              LineChartBarData(
                spots: curveData,
                isCurved: true,
                color: Theme.of(context).colorScheme.primary,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              handleBuiltInTouches: false,
              touchCallback: (event, response) {
                if (response == null || response.lineBarSpots == null || response.lineBarSpots!.isEmpty) {
                  setState(() {
                    _tooltipLatex = null;
                    _tooltipPos = null;
                  });
                  return;
                }
                final spot = response.lineBarSpots!.first;
                final e = spot.x;
                final f = spot.y;
                final latex = r'\begin{aligned}'
                    '${_relativeToFermi ? r'E-E_F' : r'E'} &= ${e.toStringAsFixed(3)}\\,\\mathrm{eV}\\\\'
                    r'f(E) &= ' '${ScientificLatexFormatter.sci(f, sigFigs: 4)}'
                    r'\end{aligned}';
                setState(() {
                  _tooltipLatex = latex;
                  _tooltipPos = event.localPosition;
                });
              },
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: 0.5,
                  color: Colors.grey.withValues(alpha: 0.5),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ],
              verticalLines: _relativeToFermi
                  ? [
                      VerticalLine(
                        x: 0,
                        color: Colors.grey.withValues(alpha: 0.5),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                    ]
                  : [],
            ),
          ),
        ),
        if (_tooltipLatex != null && _tooltipPos != null)
          Positioned(
            left: _tooltipPos!.dx + 12,
            top: (_tooltipPos!.dy - 60).clamp(0, double.infinity),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: LatexText(_tooltipLatex!, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parameters', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            
            // Temperature slider
            Row(
              children: [
                const SizedBox(
                  width: 60,
                  child: LatexText(r'T', scale: 1.0),
                ),
                Expanded(
                  child: Slider(
                    value: _temperature,
                    min: 1.0,
                    max: 1000.0,
                    divisions: 999,
                    label: '${_temperature.toStringAsFixed(0)} K',
                    onChanged: (value) {
                      _animator.pause();
                      setState(() {
                        _temperature = value;
                        _chartVersion++;
                      });
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 60),
              child: Text(
                '${_temperature.toStringAsFixed(1)} K',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Fermi level slider
            Row(
              children: [
                const SizedBox(
                  width: 60,
                  child: LatexText(r'E_F', scale: 1.0),
                ),
                Expanded(
                  child: Slider(
                    value: _fermiLevel,
                    min: -0.5,
                    max: 0.5,
                    divisions: 100,
                    label: '${_fermiLevel.toStringAsFixed(2)} eV',
                    onChanged: (value) {
                      _animator.pause();
                      setState(() {
                        _fermiLevel = value;
                        _chartVersion++;
                      });
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 60),
              child: Text(
                '${_fermiLevel.toStringAsFixed(3)} eV',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Axis mode toggle
            SwitchListTile(
              title: const Text('Relative to E_F'),
              subtitle: Text(_relativeToFermi ? 'X-axis: E - E_F' : 'X-axis: E (absolute)'),
              value: _relativeToFermi,
              onChanged: (value) {
                setState(() {
                  _relativeToFermi = value;
                  _chartVersion++;
                });
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimationControls(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Animation', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _animator.isAnimating ? _animator.pause : _animator.start,
                  icon: Icon(_animator.isAnimating ? Icons.pause : Icons.play_arrow),
                  label: Text(_animator.isAnimating ? 'Pause' : 'Play'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.replay),
                  tooltip: 'Reset',
                  onPressed: () {
                    _animator.reset();
                    setState(() {
                      _temperature = 100;
                      _chartVersion++;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Speed'),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 0.5, label: Text('0.5x')),
                ButtonSegment(value: 1.0, label: Text('1x')),
                ButtonSegment(value: 2.0, label: Text('2x')),
              ],
              selected: {_speed},
              onSelectionChanged: (s) {
                final v = s.first;
                setState(() {
                  _speed = v;
                  _animator.setSpeed(v);
                  _chartVersion++;
                });
              },
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Loop'),
              value: _loop,
              onChanged: (v) {
                setState(() {
                  _loop = v;
                  _animator.loop = v;
                  _chartVersion++;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key Observations', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  _buildInsightItem('At E = E_F, f(E) = 0.5 for any temperature'),
                  _buildInsightItem('Low T → sharp step function at E_F'),
                  _buildInsightItem('High T → gradual transition (thermal smearing)'),
                  _buildInsightItem('Changing E_F shifts curve horizontally'),
                  _buildInsightItem('Width of transition region ≈ few kT'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}



