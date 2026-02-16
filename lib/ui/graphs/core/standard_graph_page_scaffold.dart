import 'package:flutter/material.dart';
import 'graph_config.dart';
import 'standard_panel_stack.dart';
import '../../widgets/latex_text.dart';
import '../common/enhanced_animation_panel.dart';

typedef _Typo = GraphPanelTextStyles;

/// Standard scaffold for graph pages.
/// 
/// Handles layout only - does not manage state or physics.
/// 
/// Features:
/// - Responsive layout (wide/narrow)
/// - Fixed panel order in right column
/// - Optional header with title, subtitle, equation
/// - Chart area (left or top depending on layout)
/// - Standard panel stack (right or bottom depending on layout)
/// 
/// Usage:
/// ```dart
/// StandardGraphPageScaffold(
///   config: _buildGraphConfig(),
///   chartBuilder: (context) => _buildChart(),
///   showDebugBadge: true, // optional, for migration verification
/// )
/// ```
class StandardGraphPageScaffold extends StatelessWidget {
  /// Graph configuration (drives panels)
  final GraphConfig config;
  
  /// Builder for chart widget
  final Widget Function(BuildContext context) chartBuilder;
  
  /// Optional About card shown under header.
  final Widget? aboutSection;

  /// Optional Observe card shown under About section.
  final Widget? observeSection;

  /// Optional extra header widgets shown after Observe.
  final List<Widget>? headerWidgets;

  /// Optional right-panel builder override.
  /// Defaults to [StandardPanelStack] when not provided.
  final Widget Function(BuildContext context, GraphConfig config)? rightPanelBuilder;
  
  /// Whether to show debug badge (for migration verification)
  final bool showDebugBadge;
  
  /// Debug badge text
  final String debugBadgeText;
  
  /// Breakpoint for wide vs narrow layout
  final double wideLayoutBreakpoint;

  /// Fixed right-panel width in wide layout.
  final double rightPanelWidth;

  /// Chart height used in narrow ListView mode.
  final double narrowChartHeight;

  const StandardGraphPageScaffold({
    super.key,
    required this.config,
    required this.chartBuilder,
    this.aboutSection,
    this.observeSection,
    this.headerWidgets,
    this.rightPanelBuilder,
    this.showDebugBadge = false,
    this.debugBadgeText = 'USING STANDARD SCAFFOLD',
    this.wideLayoutBreakpoint = 1100,
    this.rightPanelWidth = 520,
    this.narrowChartHeight = 420,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= wideLayoutBreakpoint;
        final rightPanel = rightPanelBuilder?.call(context, config) ??
            StandardPanelStack(config: config);
        
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header section
                  if (config.title != null || 
                      config.subtitle != null || 
                      config.mainEquation != null)
                    _buildHeader(context),
                  
                  if (config.title != null || 
                      config.subtitle != null || 
                      config.mainEquation != null)
                    const SizedBox(height: 12),

                  if (aboutSection != null) ...[
                    aboutSection!,
                    const SizedBox(height: 12),
                  ],

                  if (observeSection != null) ...[
                    observeSection!,
                    const SizedBox(height: 12),
                  ],

                  // Optional extra header widgets
                  if (headerWidgets != null) ...[
                    ...headerWidgets!.map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: w,
                        )),
                  ],
                  
                  // Main layout (chart + panels)
                  Expanded(
                    child: isWide
                        ? _buildWideLayout(context, rightPanel)
                        : _buildNarrowLayout(context, rightPanel),
                  ),
                ],
              ),
            ),
            
            // Debug badge
            if (showDebugBadge)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    debugBadgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (config.title != null) ...[
          Text(
            config.title!,
            style: TextStyle(
              fontSize: _Typo.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (config.subtitle != null) ...[
          Text(
            config.subtitle!,
            style: TextStyle(
              fontSize: _Typo.body,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (config.mainEquation != null) ...[
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
              child: LatexText(
                config.mainEquation!,
                displayMode: true,
                style: TextStyle(fontSize: _Typo.body),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    Widget rightPanel,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart area
        Expanded(
          child: _buildChartCard(context),
        ),
        const SizedBox(width: 12),
        // Right panel
        SizedBox(
          width: rightPanelWidth,
          child: rightPanel,
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, Widget rightPanel) {
    return Scrollbar(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: narrowChartHeight,
            child: _buildChartCard(context),
          ),
          const SizedBox(height: 12),
          rightPanel,
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
        child: chartBuilder(context),
      ),
    );
  }
}
