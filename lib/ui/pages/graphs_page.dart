import 'package:flutter/material.dart';

import '../widgets/latex_text.dart';
import 'carrier_concentration_graph_page.dart';
import 'density_of_states_graph_page.dart';
import 'direct_indirect_graph_page.dart';
import 'drift_diffusion_graph_page.dart';
import 'fermi_dirac_graph_page.dart';
import 'intrinsic_carrier_graph_page.dart';
import 'parabolic_graph_page.dart';
import 'pn_band_diagram_graph_page.dart';
import 'pn_depletion_graph_page.dart';

class GraphsPage extends StatefulWidget {
  const GraphsPage({super.key});

  @override
  State<GraphsPage> createState() => _GraphsPageState();
}

class _GraphsPageState extends State<GraphsPage> {
  late final List<GraphTopic> _topics = _buildTopics();
  late String _selectedTopicId = _topics.first.topicId;

  @override
  Widget build(BuildContext context) {
    final selectedTopic = _topics.firstWhere((t) => t.topicId == _selectedTopicId);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Graphs & Visualizations',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _topics
                .map(
                  (t) => ChoiceChip(
                    label: Text(t.topicTitle),
                    selected: _selectedTopicId == t.topicId,
                    onSelected: (_) => setState(() => _selectedTopicId = t.topicId),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Text(
            selectedTopic.topicDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: selectedTopic.subcategories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final sub = selectedTopic.subcategories[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sub.subTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(sub.learningOutcome, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        ...sub.graphs.map((g) => _GraphTile(info: g)).toList(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<GraphTopic> _buildTopics() {
    return [
      GraphTopic(
        topicId: 'energy_band_structure',
        topicTitle: 'Energy & Band Structure',
        topicDescription: 'Understand E-k relations, effective mass, and bandgap type.',
        subcategories: [
          GraphSubcategory(
            subId: 'ek_dispersion',
            subTitle: 'E-k Dispersion',
            learningOutcome: 'Relate curvature of E-k to effective mass and group velocity.',
            graphs: [
              GraphInfo(
                graphId: 'graph_parabolic_band_dispersion',
                title: 'Parabolic Band Dispersion (E-k)',
                subtitle: 'Explore conduction/valence parabolas, effective masses, and group velocity.',
                learningOutcome: 'See how curvature links to m* and v_g(k).',
                inputsSummary: ['m*_e', 'm*_h', 'k-range', 'E0 offsets (Ec0/Ev0)'],
                builder: (context) => const ParabolicGraphPage(),
              ),
            ],
          ),
          GraphSubcategory(
            subId: 'direct_indirect',
            subTitle: 'Direct vs Indirect Bandgap',
            learningOutcome: 'Compare CBM/VBM alignment in k-space and understand phonon-assisted transitions.',
            graphs: [
              GraphInfo(
                graphId: 'graph_direct_vs_indirect_bandgap',
                title: 'Direct vs Indirect Bandgap (Schematic E-k)',
                subtitle: 'Compare VBM/CBM alignment in k-space, gap readouts, and photon/phonon transitions.',
                learningOutcome: 'Distinguish direct gaps from indirect gaps in k-space.',
                inputsSummary: ['Eg', 'k-offset (indirect)', 'display markers: VBM/CBM'],
                builder: (context) => const DirectIndirectGraphPage(),
              ),
            ],
          ),
        ],
      ),
      GraphTopic(
        topicId: 'dos_statistics',
        topicTitle: 'Density of States & Statistics',
        topicDescription: 'Connect DOS and occupancy to carrier population behavior.',
        subcategories: [
          GraphSubcategory(
            subId: 'occupancy',
            subTitle: 'Occupancy Probability',
            learningOutcome: 'Visualize Fermi-Dirac distribution and thermal smearing with temperature.',
            graphs: [
              GraphInfo(
                graphId: 'graph_fermi_dirac_probability',
                title: 'Fermi-Dirac Probability f(E) vs E',
                subtitle: 'Interactive visualization of electron occupation probability. Adjust temperature and Fermi level.',
                learningOutcome: 'See how T and E_F shift occupancy across the gap.',
                inputsSummary: ['T', 'E_F', 'E-range', 'optional markers (0.1/0.5/0.9)'],
                builder: (context) => const FermiDiracGraphPage(),
              ),
            ],
          ),
          GraphSubcategory(
            subId: 'dos_shape',
            subTitle: 'Density of States',
            learningOutcome: 'See how DOS varies with energy and why available states matter beyond occupancy alone.',
            graphs: [
              GraphInfo(
                graphId: 'graph_density_of_states_vs_energy',
                title: 'Density of States g(E) vs E (3D)',
                subtitle: 'Show conduction and valence band DOS shapes and band-edge thresholds.',
                learningOutcome: 'Connect band-edge thresholds to state availability.',
                inputsSummary: ['m*_e', 'm*_h', 'E_c', 'E_v', 'E-range', 'constants (h)'],
                builder: (context) => const DensityOfStatesGraphPage(),
                isNew: true,
              ),
            ],
          ),
        ],
      ),
      GraphTopic(
        topicId: 'carrier_concentration_equilibrium',
        topicTitle: 'Carrier Concentration (Equilibrium)',
        topicDescription: 'Understand how n, p, and n_i depend on temperature and Fermi level.',
        subcategories: [
          GraphSubcategory(
            subId: 'intrinsic_vs_temperature',
            subTitle: 'Intrinsic Concentration Trends',
            learningOutcome: 'Explore how n_i changes with temperature and bandgap (orders of magnitude).',
            graphs: [
              GraphInfo(
                graphId: 'graph_intrinsic_carrier_concentration_vs_temperature',
                title: 'Intrinsic Carrier Concentration vs Temperature',
                subtitle: 'Explore how n_i varies exponentially with temperature and bandgap (log-scale).',
                learningOutcome: 'Relate n_i, T, and E_g on a log scale.',
                inputsSummary: ['T-range', 'E_g(T) model (optional)', 'N_c(T), N_v(T) model (optional)'],
                builder: (context) => const IntrinsicCarrierGraphPage(),
              ),
            ],
          ),
          GraphSubcategory(
            subId: 'np_vs_fermi_level',
            subTitle: 'n & p vs Fermi Level',
            learningOutcome: 'See how shifting E_F across the bandgap changes electron and hole concentrations.',
            graphs: [
              GraphInfo(
                graphId: 'graph_carrier_concentration_vs_fermi_level',
                title: 'Carrier Concentration vs Fermi Level (n & p vs E_F)',
                subtitle: 'Log-scale view of n and p as E_F moves through the bandgap; includes band-edge markers and n_i reference.',
                learningOutcome: 'Track n and p as E_F moves between E_c and E_v.',
                inputsSummary: ['E_F sweep range', 'E_c, E_v, E_i markers', 'T'],
                builder: (context) => const CarrierConcentrationGraphPage(),
              ),
            ],
          ),
        ],
      ),
      GraphTopic(
        topicId: 'carrier_transport_fundamentals',
        topicTitle: 'Carrier Transport (Fundamentals)',
        topicDescription: 'Compare drift and diffusion and how fields/gradients form total current.',
        subcategories: [
          GraphSubcategory(
            subId: 'drift_diffusion_1d',
            subTitle: 'Drift-Diffusion (1D)',
            learningOutcome: 'Decompose total current into drift and diffusion components across a 1D profile.',
            graphs: [
              GraphInfo(
                graphId: 'graph_drift_vs_diffusion_current_1d',
                title: 'Drift vs Diffusion Current (1D)',
                subtitle: 'Compare drift and diffusion current components across a 1D profile; see how gradients and fields add to J_total.',
                learningOutcome: 'Understand J_drift + J_diffusion composition.',
                inputsSummary: ['E(x) profile', 'n(x), p(x) profiles', 'mu_n, mu_p', 'D_n, D_p', 'q'],
                builder: (context) => const DriftDiffusionGraphPage(),
              ),
            ],
          ),
        ],
      ),
      GraphTopic(
        topicId: 'pn_junction',
        topicTitle: 'PN Junction',
        topicDescription: 'Visualize depletion approximation, fields, potentials, and band diagrams under bias.',
        subcategories: [
          GraphSubcategory(
            subId: 'depletion_profiles',
            subTitle: 'Depletion Profiles (rho, E, V)',
            learningOutcome: 'Understand charge density, electric field shape, potential, and depletion widths in an abrupt PN junction.',
            graphs: [
              GraphInfo(
                graphId: 'graph_pn_junction_depletion_profiles',
                title: 'PN Junction Depletion Profiles (rho, E, V)',
                subtitle: 'Abrupt junction depletion approximation with charge density, electric field, potential, and depletion widths under bias.',
                learningOutcome: 'Connect doping to depletion width, field, and potential.',
                inputsSummary: ['N_A, N_D', 'epsilon_s', 'V_A (bias)', 'T (optional)', 'built-in potential model'],
                builder: (context) => const PnDepletionGraphPage(),
              ),
            ],
          ),
          GraphSubcategory(
            subId: 'pn_band_diagram',
            subTitle: 'Band Diagram vs Position',
            learningOutcome: 'Connect electrostatics to energy bands; see band bending at equilibrium and changes under bias.',
            graphs: [
              GraphInfo(
                graphId: 'graph_pn_junction_band_diagram',
                title: 'PN Junction Band Diagram (E vs x)',
                subtitle: 'Show E_c(x), E_v(x), E_i(x), and quasi-Fermi levels under equilibrium/forward/reverse bias.',
                learningOutcome: 'Relate bias to band bending and quasi-Fermi levels.',
                inputsSummary: ['N_A, N_D', 'V_A (eq/fwd/rev)', 'T', 'E_g', 'optional: E_Fn, E_Fp'],
                builder: (context) => const PnBandDiagramGraphPage(),
                isNew: true,
              ),
            ],
          ),
        ],
      ),
    ];
  }
}

class _GraphTile extends StatelessWidget {
  final GraphInfo info;
  const _GraphTile({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(info.subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (info.isNew)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('NEW', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(info.learningOutcome, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: info.inputsSummary.map((s) => _ChipLabel(raw: s)).toList(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: info.builder));
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open'),
            ),
          ),
        ],
      ),
    );
  }
}

class GraphTopic {
  final String topicId;
  final String topicTitle;
  final String topicDescription;
  final List<GraphSubcategory> subcategories;

  const GraphTopic({
    required this.topicId,
    required this.topicTitle,
    required this.topicDescription,
    required this.subcategories,
  });
}

class GraphSubcategory {
  final String subId;
  final String subTitle;
  final String learningOutcome;
  final List<GraphInfo> graphs;

  const GraphSubcategory({
    required this.subId,
    required this.subTitle,
    required this.learningOutcome,
    required this.graphs,
  });
}

class GraphInfo {
  final String graphId;
  final String title;
  final String subtitle;
  final String learningOutcome;
  final List<String> inputsSummary;
  final WidgetBuilder builder;
  final bool isNew;

  const GraphInfo({
    required this.graphId,
    required this.title,
    required this.subtitle,
    required this.learningOutcome,
    required this.inputsSummary,
    required this.builder,
    this.isNew = false,
  });
}

/// Renders chip labels with LaTeX mapping and safe fallbacks.
class _ChipLabel extends StatelessWidget {
  final String raw;
  const _ChipLabel({required this.raw});

  static const Map<String, String> _map = {
    'm*_e': r'm_{e}^{*}',
    'm*_h': r'm_{h}^{*}',
    'm_n^*': r'm_{n}^{*}',
    'm_p^*': r'm_{p}^{*}',
    'mu_n': r'\mu_{n}',
    'mu_p': r'\mu_{p}',
    'D_n': r'D_{n}',
    'D_p': r'D_{p}',
    'Eg': r'E_{g}',
    'E_g': r'E_{g}',
    'E_g(T)': r'E_{g}(T)',
    'T': r'T',
    'E_F': r'E_{F}',
    'E_c': r'E_{c}',
    'E_v': r'E_{v}',
    'E_i': r'E_{i}',
    'E0 offsets (Ec0/Ev0)': r'E_{c0},E_{v0}',
    'k-range': r'k',
    'k-offset (indirect)': r'k_0',
    'display markers: VBM/CBM': r'k_{VBM},k_{CBM}',
    'E-range': r'E',
    'optional markers (0.1/0.5/0.9)': r'0.1,0.5,0.9',
    'constants (h)': r'h',
    'T-range': r'T',
    'E_g(T) model (optional)': r'E_{g}(T)',
    'N_c(T), N_v(T) model (optional)': r'N_{c}(T),N_{v}(T)',
    'E_F sweep range': r'E_{F}',
    'E_c, E_v, E_i markers': r'E_{c},E_{v},E_{i}',
    'E(x) profile': r'E(x)',
    'n(x), p(x) profiles': r'n(x),p(x)',
    'mu_n, mu_p': r'\mu_{n},\,\mu_{p}',
    'D_n, D_p': r'D_{n},\,D_{p}',
    'q': r'q',
    'N_A, N_D': r'N_{A},\,N_{D}',
    'epsilon_s': r'\varepsilon_{s}',
    'V_A (bias)': r'V_{A}',
    'T (optional)': r'T',
    'built-in potential model': r'V_{bi}',
    'V_A (eq/fwd/rev)': r'V_{A}',
    'optional: E_Fn, E_Fp': r'E_{Fn},E_{Fp}',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: _map.containsKey(raw)
          ? LatexText(
              _map[raw]!,
              style: const TextStyle(fontSize: 12),
            )
          : Text(
              raw,
              style: const TextStyle(fontSize: 12),
            ),
    );
  }
}

