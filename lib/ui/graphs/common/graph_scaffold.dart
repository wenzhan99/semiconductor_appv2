import 'package:flutter/material.dart';
import 'latex_rich_text.dart';
import 'latex_bullet_list.dart';
import '../../widgets/latex_text.dart';

/// Standardized scaffold for all graph pages.
/// 
/// Provides:
/// - Responsive layout (wide: side-by-side, narrow: stacked)
/// - Standard header with title, formula, and About section
/// - "What you should observe" collapsible panel
/// - Chart area with legend and toolbar
/// - Right panel with scrollable cards in standard order:
///   Readouts -> Point Inspector -> Animation -> Parameters -> Key Observations
/// 
/// Usage:
/// ```dart
/// GraphScaffold(
///   title: 'Intrinsic Carrier Concentration vs Temperature',
///   category: 'DOS & Statistics',
///   formula: r'n_i = \sqrt{N_c N_v}\,\exp\!\left(-\frac{E_g}{2\,k\,T}\right)',
///   formulaEquivalent: r'n_i^2 = N_c N_v \exp\!\left(-\frac{E_g}{k T}\right)',
///   aboutText: 'Shows how intrinsic carrier concentration $n_i$ increases exponentially...',
///   observeBullets: [
///     r'$n_i$ rises exponentially with T.',
///     r'Larger $E_g$ suppresses $n_i$.',
///   ],
///   chartBuilder: (context) => YourChartWidget(),
///   rightPanelCards: [
///     ReadoutsCard(...),
///     PointInspectorCard(...),
///     AnimationCard(...),
///     ParametersCard(...),
///     KeyObservationsCard(...),
///   ],
/// )
/// ```
class GraphScaffold extends StatelessWidget {
  // Header
  final String title;
  final String? category;
  final String? formula; // Main formula (LaTeX)
  final String? formulaEquivalent; // Alternative form (LaTeX)
  final String? aboutText; // Supports inline $...$ LaTeX
  final List<String>? observeBullets; // Supports inline $...$ LaTeX
  final bool observeInitiallyExpanded;

  // Chart area
  final Widget Function(BuildContext context) chartBuilder;
  final Widget? chartLegend;
  final Widget? chartToolbar;

  // Right panel cards (in order)
  final List<Widget> rightPanelCards;

  // Layout
  final double responsiveBreakpoint;
  final bool showAppBar;

  const GraphScaffold({
    super.key,
    required this.title,
    this.category,
    this.formula,
    this.formulaEquivalent,
    this.aboutText,
    this.observeBullets,
    this.observeInitiallyExpanded = false,
    required this.chartBuilder,
    this.chartLegend,
    this.chartToolbar,
    required this.rightPanelCards,
    this.responsiveBreakpoint = 1100.0,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: showAppBar
          ? AppBar(title: Text(title))
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= responsiveBreakpoint;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                _buildHeader(context),
                const SizedBox(height: 12),

                // About section (if provided)
                if (aboutText != null) ...[
                  _buildAboutCard(context),
                  const SizedBox(height: 12),
                ],

                // Observe section (if provided)
                if (observeBullets != null && observeBullets!.isNotEmpty) ...[
                  _buildObserveCard(context),
                  const SizedBox(height: 12),
                ],

                // Main content area
                Expanded(
                  child: isWide
                      ? _buildWideLayout(context)
                      : _buildNarrowLayout(context),
                ),
              ],
            ),
          );
        },
      ),
    );

    return scaffold;
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and category
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (category != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      category!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        // Formula (if provided)
        if (formula != null) ...[
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  LatexText(
                    formula!,
                    displayMode: true,
                    scale: 1.2,
                  ),
                  if (formulaEquivalent != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Equivalent form:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 4),
                    LatexText(
                      formulaEquivalent!,
                      displayMode: true,
                      scale: 1.0,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
            LatexRichText.parse(
              aboutText!,
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
        initiallyExpanded: observeInitiallyExpanded,
        title: Text(
          'What you should observe',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          LatexBulletList(
            bullets: observeBullets!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart area (left, 2/3 width)
        Expanded(
          flex: 2,
          child: _buildChartCard(context),
        ),
        const SizedBox(width: 12),

        // Right panel (1/3 width, scrollable)
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: _buildRightPanelCards(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Chart on top
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 300,
              maxHeight: 450,
            ),
            child: _buildChartCard(context),
          ),
          const SizedBox(height: 12),

          // Cards below
          ..._buildRightPanelCards(),
        ],
      ),
    );
  }

  Widget _buildChartCard(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Legend and toolbar row
            if (chartLegend != null || chartToolbar != null)
              Row(
                children: [
                  if (chartLegend != null) Expanded(child: chartLegend!),
                  if (chartToolbar != null) chartToolbar!,
                ],
              ),
            if (chartLegend != null || chartToolbar != null) const SizedBox(height: 8),

            // Chart
            Expanded(
              child: chartBuilder(context),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRightPanelCards() {
    return rightPanelCards
        .map((card) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: card,
            ))
        .toList();
  }
}


