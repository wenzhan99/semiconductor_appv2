import 'package:flutter/material.dart';
import 'graph_config.dart';
import 'standard_panel_stack.dart';
import '../../widgets/latex_text.dart';

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
  
  /// Optional header widgets (About, Observe, etc.) - shown above main layout
  final List<Widget>? headerWidgets;
  
  /// Whether to show debug badge (for migration verification)
  final bool showDebugBadge;
  
  /// Debug badge text
  final String debugBadgeText;
  
  /// Breakpoint for wide vs narrow layout
  final double wideLayoutBreakpoint;

  const StandardGraphPageScaffold({
    super.key,
    required this.config,
    required this.chartBuilder,
    this.headerWidgets,
    this.showDebugBadge = false,
    this.debugBadgeText = 'USING STANDARD SCAFFOLD',
    this.wideLayoutBreakpoint = 1100,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= wideLayoutBreakpoint;
        
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
                  
                  // Optional header widgets (About, Observe, etc.)
                  if (headerWidgets != null) ...[
                    ...headerWidgets!.map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: w,
                        )),
                  ],
                  
                  // Main layout (chart + panels)
                  Expanded(
                    child: isWide
                        ? _buildWideLayout(context)
                        : _buildNarrowLayout(context),
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
        ],
        if (config.subtitle != null) ...[
          Text(
            config.subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart area (2/3 width)
        Expanded(
          flex: 2,
          child: _buildChartCard(context),
        ),
        const SizedBox(width: 12),
        // Panel stack (1/3 width)
        Expanded(
          child: StandardPanelStack(config: config),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Chart area
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 300, maxHeight: 450),
            child: _buildChartCard(context),
          ),
          const SizedBox(height: 12),
          // Panel stack
          StandardPanelStack(config: config),
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
