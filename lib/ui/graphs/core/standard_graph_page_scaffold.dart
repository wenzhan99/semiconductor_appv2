import 'package:flutter/material.dart';

import '../../widgets/latex_text.dart';
import '../common/graph_panels.dart';
import '../common/graph_scaffold_tokens.dart';
import '../panels/animation_parameters_panel.dart';
import '../panels/controls_panel.dart';
import '../panels/insights_and_pins_panel.dart';
import '../panels/point_inspector_panel.dart';
import 'graph_config.dart';
import 'standard_panel_stack.dart';

/// Standard scaffold for graph pages.
///
/// Supports two usage modes:
/// 1) Legacy mode: provide [config] + [chartBuilder]
/// 2) Section mode: provide [title], [subtitle], [mainEquation], [chart],
///    and [rightPanelSections]
class StandardGraphPageScaffold extends StatelessWidget {
  static const List<String> _defaultWideLeftSectionIds = <String>[
    'readouts',
    'point_inspector',
    'animation',
  ];
  static const List<String> _defaultWideRightSectionIds = <String>[
    'notes',
    'controls',
  ];

  /// Legacy config-driven mode
  final GraphConfig? config;

  /// Legacy chart builder
  final Widget Function(BuildContext context)? chartBuilder;

  /// Section mode chart
  final Widget? chart;

  /// Section mode title/subtitle/equation
  final String? title;
  final String? subtitle;
  final String? mainEquation;

  /// Section mode right panel sections
  final List<GraphSection>? rightPanelSections;

  /// Optional token override for typography/layout
  final GraphScaffoldTokens? tokensOverride;

  /// Optional top actions shown below header
  final List<Widget>? topActions;

  /// Optional About card shown under header.
  final Widget? aboutSection;

  /// Optional Observe card shown under About section.
  final Widget? observeSection;

  /// Optional extra header widgets shown after Observe.
  final List<Widget>? headerWidgets;

  /// Optional right-panel builder override for legacy mode.
  final Widget Function(BuildContext context, GraphConfig config)?
      rightPanelBuilder;

  /// Whether to show debug badge (for migration verification)
  final bool showDebugBadge;

  /// Debug badge text
  final String debugBadgeText;

  /// Breakpoint for wide vs narrow layout
  final double wideLayoutBreakpoint;

  /// Preferred right-panel width in wide layout.
  final double rightPanelWidth;

  /// Chart height used in narrow mode.
  final double narrowChartHeight;

  /// In wide layout, place about/observe/header widgets in the left chart
  /// column so the right panel can start directly under header.
  final bool placeSectionsInWideLeftColumn;

  /// In wide layout, split section-mode right panel into two independently
  /// scrollable columns.
  final bool useTwoColumnRightPanelInWide;

  /// Preferred section IDs for the left right-panel column in wide layout.
  /// Applies only when [useTwoColumnRightPanelInWide] is true.
  final List<String> wideLeftColumnSectionIds;

  /// Preferred section IDs for the right right-panel column in wide layout.
  /// Applies only when [useTwoColumnRightPanelInWide] is true.
  final List<String> wideRightColumnSectionIds;

  const StandardGraphPageScaffold({
    super.key,
    this.config,
    this.chartBuilder,
    this.chart,
    this.title,
    this.subtitle,
    this.mainEquation,
    this.rightPanelSections,
    this.tokensOverride,
    this.topActions,
    this.aboutSection,
    this.observeSection,
    this.headerWidgets,
    this.rightPanelBuilder,
    this.showDebugBadge = false,
    this.debugBadgeText = 'USING STANDARD SCAFFOLD',
    this.wideLayoutBreakpoint = 1100,
    this.rightPanelWidth = 380,
    this.narrowChartHeight = 420,
    this.placeSectionsInWideLeftColumn = false,
    this.useTwoColumnRightPanelInWide = false,
    this.wideLeftColumnSectionIds = _defaultWideLeftSectionIds,
    this.wideRightColumnSectionIds = _defaultWideRightSectionIds,
  }) : assert(
          chartBuilder != null || chart != null,
          'Provide either chartBuilder (legacy) or chart (section mode).',
        );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tokens =
            GraphScaffoldTokens.of(context, override: tokensOverride);
        final isWide = constraints.maxWidth >= wideLayoutBreakpoint;
        final placeSectionsInLeftColumn =
            isWide && placeSectionsInWideLeftColumn;

        final resolvedTitle = title ?? config?.title;
        final resolvedSubtitle = subtitle ?? config?.subtitle;
        final resolvedEquation = mainEquation ?? config?.mainEquation;

        final actions = topActions ?? headerWidgets;

        final bypassRightPanelClamp =
            rightPanelBuilder != null || useTwoColumnRightPanelInWide;
        final autoTwoColumnWidth =
            ((constraints.maxWidth - 12) / 2).clamp(520.0, 1400.0).toDouble();
        final shouldAutoSizeTwoColumn =
            useTwoColumnRightPanelInWide && rightPanelWidth == 380;
        final resolvedRightPanelWidth = shouldAutoSizeTwoColumn
            ? autoTwoColumnWidth
            : bypassRightPanelClamp
                ? rightPanelWidth
                : rightPanelWidth
                    .clamp(tokens.rightPanelMinWidth, tokens.rightPanelMaxWidth)
                    .toDouble();

        final derivedSections =
            rightPanelSections ?? _sectionsFromConfig(tokens);
        final sectionMode = derivedSections != null;
        final effectiveSections = derivedSections ?? const <GraphSection>[];
        final twoColumnSectionMode =
            sectionMode && isWide && useTwoColumnRightPanelInWide;
        final rightPanel = sectionMode
            ? twoColumnSectionMode
                ? _buildTwoColumnSectionStack(
                    context, effectiveSections, tokens)
                : _buildSectionStack(context, effectiveSections, tokens)
            : _buildLegacyRightPanel(context);

        final chartWidget = chart ?? chartBuilder!(context);

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (resolvedTitle != null ||
                      resolvedSubtitle != null ||
                      resolvedEquation != null)
                    _buildHeader(
                      context,
                      tokens: tokens,
                      title: resolvedTitle,
                      subtitle: resolvedSubtitle,
                      equation: resolvedEquation,
                    ),
                  if (resolvedTitle != null ||
                      resolvedSubtitle != null ||
                      resolvedEquation != null)
                    SizedBox(height: tokens.cardGap),
                  if (!placeSectionsInLeftColumn) ...[
                    if (aboutSection != null) ...[
                      aboutSection!,
                      SizedBox(height: tokens.cardGap),
                    ],
                    if (observeSection != null) ...[
                      observeSection!,
                      SizedBox(height: tokens.cardGap),
                    ],
                    if (actions != null) ...[
                      ...actions.map(
                        (w) => Padding(
                          padding: EdgeInsets.only(bottom: tokens.cardGap),
                          child: w,
                        ),
                      ),
                    ],
                  ],
                  Expanded(
                    child: placeSectionsInLeftColumn
                        ? _buildWideLayoutWithLeftSections(
                            context,
                            chartWidget,
                            rightPanel,
                            tokens,
                            resolvedRightPanelWidth,
                            actions,
                          )
                        : isWide
                            ? _buildWideLayout(
                                context,
                                chartWidget,
                                rightPanel,
                                resolvedRightPanelWidth,
                              )
                            : sectionMode
                                ? _buildNarrowTabbedLayout(
                                    context,
                                    chartWidget,
                                    effectiveSections,
                                    tokens,
                                  )
                                : _buildNarrowLegacyLayout(
                                    context,
                                    chartWidget,
                                    rightPanel,
                                    tokens,
                                  ),
                  ),
                ],
              ),
            ),
            if (showDebugBadge)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _buildHeader(
    BuildContext context, {
    required GraphScaffoldTokens tokens,
    required String? title,
    required String? subtitle,
    required String? equation,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title,
              style: tokens.sectionTitle.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
        ],
        if (subtitle != null) ...[
          Text(
            subtitle,
            style: tokens.label.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (equation != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2),
                ),
              ),
              child: LatexText(
                equation,
                displayMode: true,
                style: tokens.label,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLegacyRightPanel(BuildContext context) {
    if (config == null) {
      return const SizedBox.shrink();
    }
    return rightPanelBuilder?.call(context, config!) ??
        StandardPanelStack(config: config!, tokensOverride: tokensOverride);
  }

  List<GraphSection>? _sectionsFromConfig(GraphScaffoldTokens tokens) {
    if (config == null) return null;
    if (rightPanelBuilder != null) return null;

    final cfg = config!;
    final sections = <GraphSection>[];

    if (cfg.readouts != null && cfg.readouts!.isNotEmpty) {
      sections.add(
        GraphSection(
          id: 'readouts',
          title: 'Readouts',
          body: GraphKeyValueTable(
            tokens: tokens,
            rows: cfg.readouts!
                .map(
                  (item) => GraphKeyValueEntry(
                    label: item.label,
                    value: item.value,
                    subtitle: item.subtitle,
                    boldValue: item.boldValue,
                    valueColor: item.valueColor,
                    labelScale: item.labelScale,
                  ),
                )
                .toList(growable: false),
          ),
        ),
      );
    }

    if (cfg.pointInspector != null && cfg.pointInspector!.enabled) {
      sections.add(
        GraphSection(
          id: 'point_inspector',
          title: 'Point Inspector',
          wrapInCard: false,
          body: PointInspectorPanel(
            config: cfg.pointInspector!,
            tokensOverride: tokens,
          ),
        ),
      );
    }

    if (cfg.animation != null) {
      sections.add(
        GraphSection(
          id: 'animation',
          title: 'Animation Parameters',
          wrapInCard: false,
          body: AnimationParametersPanel(
            config: cfg.animation!,
            tokensOverride: tokens,
          ),
        ),
      );
    }

    if (cfg.controls.children.isNotEmpty) {
      sections.add(
        GraphSection(
          id: 'controls',
          title: 'Controls',
          wrapInCard: false,
          body: ControlsPanel(
            config: cfg.controls,
            tokensOverride: tokens,
          ),
        ),
      );
    }

    if (cfg.insights != null) {
      sections.add(
        GraphSection(
          id: 'notes',
          title: 'Notes',
          wrapInCard: false,
          body: InsightsAndPinsPanel(
            config: cfg.insights!,
            tokensOverride: tokens,
          ),
        ),
      );
    }

    return sections;
  }

  Widget _renderSection(GraphSection section, GraphScaffoldTokens tokens) {
    if (!section.wrapInCard) return section.body;
    return GraphCard(
      title: section.title,
      child: section.body,
      tokens: tokens,
      collapsible: false,
      initiallyExpanded: section.initiallyExpanded,
    );
  }

  Widget _buildSectionStack(
    BuildContext context,
    List<GraphSection> sections,
    GraphScaffoldTokens tokens,
  ) {
    return _VerticalScrollbarScrollView(
      child: Column(
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            _renderSection(sections[i], tokens),
            if (i != sections.length - 1) SizedBox(height: tokens.cardGap),
          ],
        ],
      ),
    );
  }

  Widget _buildTwoColumnSectionStack(
    BuildContext context,
    List<GraphSection> sections,
    GraphScaffoldTokens tokens,
  ) {
    final split = _splitSectionsForWideColumns(sections);
    final leftSections = split.$1;
    final rightSections = split.$2;

    // If one side is empty (unusual custom configuration), fall back to the
    // single-column stack for predictable behavior.
    if (leftSections.isEmpty || rightSections.isEmpty) {
      return _buildSectionStack(context, sections, tokens);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildSectionColumn(leftSections, tokens)),
        SizedBox(width: tokens.cardGap),
        Expanded(child: _buildSectionColumn(rightSections, tokens)),
      ],
    );
  }

  Widget _buildSectionColumn(
    List<GraphSection> sections,
    GraphScaffoldTokens tokens,
  ) {
    return _VerticalScrollbarScrollView(
      child: Column(
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            _renderSection(sections[i], tokens),
            if (i != sections.length - 1) SizedBox(height: tokens.cardGap),
          ],
        ],
      ),
    );
  }

  (List<GraphSection>, List<GraphSection>) _splitSectionsForWideColumns(
    List<GraphSection> sections,
  ) {
    final leftPreferred = wideLeftColumnSectionIds
        .map((id) => id.toLowerCase().trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final rightPreferred = wideRightColumnSectionIds
        .map((id) => id.toLowerCase().trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    final remaining = List<GraphSection>.from(sections);
    final left = <GraphSection>[];
    final right = <GraphSection>[];

    void movePreferred(String preferredId, List<GraphSection> target) {
      final index = remaining.indexWhere(
        (section) => section.id.toLowerCase().trim() == preferredId,
      );
      if (index >= 0) {
        target.add(remaining.removeAt(index));
      }
    }

    for (final id in leftPreferred) {
      movePreferred(id, left);
    }
    for (final id in rightPreferred) {
      movePreferred(id, right);
    }

    for (final section in remaining) {
      if (left.length <= right.length) {
        left.add(section);
      } else {
        right.add(section);
      }
    }

    return (left, right);
  }

  Widget _buildWideLayout(
    BuildContext context,
    Widget chartWidget,
    Widget rightPanel,
    double rightPanelWidth,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildChartCard(context, chartWidget)),
        const SizedBox(width: 12),
        SizedBox(width: rightPanelWidth, child: rightPanel),
      ],
    );
  }

  Widget _buildWideLayoutWithLeftSections(
    BuildContext context,
    Widget chartWidget,
    Widget rightPanel,
    GraphScaffoldTokens tokens,
    double rightPanelWidth,
    List<Widget>? actions,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (aboutSection != null) ...[
                aboutSection!,
                SizedBox(height: tokens.cardGap),
              ],
              if (observeSection != null) ...[
                observeSection!,
                SizedBox(height: tokens.cardGap),
              ],
              if (actions != null) ...[
                ...actions.map((w) => Padding(
                      padding: EdgeInsets.only(bottom: tokens.cardGap),
                      child: w,
                    )),
              ],
              Expanded(child: _buildChartCard(context, chartWidget)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: rightPanelWidth, child: rightPanel),
      ],
    );
  }

  Widget _buildNarrowLegacyLayout(
    BuildContext context,
    Widget chartWidget,
    Widget rightPanel,
    GraphScaffoldTokens tokens,
  ) {
    return _VerticalScrollbarListView(
      children: [
        SizedBox(
          height: narrowChartHeight,
          child: _buildChartCard(context, chartWidget),
        ),
        SizedBox(height: tokens.cardGap),
        rightPanel,
      ],
    );
  }

  Widget _buildNarrowTabbedLayout(
    BuildContext context,
    Widget chartWidget,
    List<GraphSection> sections,
    GraphScaffoldTokens tokens,
  ) {
    final tabs = _groupSectionsForTabs(sections);
    if (tabs.isEmpty) {
      return _VerticalScrollbarListView(
        children: [
          SizedBox(
            height: narrowChartHeight,
            child: _buildChartCard(context, chartWidget),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          height: narrowChartHeight,
          child: _buildChartCard(context, chartWidget),
        ),
        SizedBox(height: tokens.cardGap),
        Expanded(
          child: DefaultTabController(
            length: tabs.length,
            child: Column(
              children: [
                TabBar(
                  isScrollable: tabs.length > 3,
                  tabs: tabs
                      .map((entry) => Tab(text: entry.$1))
                      .toList(growable: false),
                ),
                SizedBox(height: tokens.rowGap),
                Expanded(
                  child: TabBarView(
                    children: tabs.map((entry) {
                      final tabSections = entry.$2;
                      return _VerticalScrollbarScrollView(
                        child: Column(
                          children: [
                            for (var i = 0; i < tabSections.length; i++) ...[
                              _renderSection(tabSections[i], tokens),
                              if (i != tabSections.length - 1)
                                SizedBox(height: tokens.cardGap),
                            ],
                          ],
                        ),
                      );
                    }).toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<(String, List<GraphSection>)> _groupSectionsForTabs(
    List<GraphSection> sections,
  ) {
    final values = <GraphSection>[];
    final animate = <GraphSection>[];
    final controls = <GraphSection>[];
    final notes = <GraphSection>[];

    for (final section in sections) {
      final id = section.id.toLowerCase();
      if (id.contains('readout') ||
          id.contains('inspector') ||
          id == 'values') {
        values.add(section);
      } else if (id.contains('anim')) {
        animate.add(section);
      } else if (id.contains('control')) {
        controls.add(section);
      } else {
        notes.add(section);
      }
    }

    final out = <(String, List<GraphSection>)>[];
    if (values.isNotEmpty) out.add(('Values', values));
    if (animate.isNotEmpty) out.add(('Animate', animate));
    if (controls.isNotEmpty) out.add(('Controls', controls));
    if (notes.isNotEmpty) out.add(('Notes', notes));
    return out;
  }

  Widget _buildChartCard(BuildContext context, Widget chartWidget) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: chartWidget,
      ),
    );
  }
}

class _VerticalScrollbarScrollView extends StatefulWidget {
  const _VerticalScrollbarScrollView({
    required this.child,
  });

  final Widget child;

  @override
  State<_VerticalScrollbarScrollView> createState() =>
      _VerticalScrollbarScrollViewState();
}

class _VerticalScrollbarScrollViewState
    extends State<_VerticalScrollbarScrollView> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      child: SingleChildScrollView(
        controller: _controller,
        padding: EdgeInsets.zero,
        child: widget.child,
      ),
    );
  }
}

class _VerticalScrollbarListView extends StatefulWidget {
  const _VerticalScrollbarListView({
    required this.children,
  });

  final List<Widget> children;

  @override
  State<_VerticalScrollbarListView> createState() =>
      _VerticalScrollbarListViewState();
}

class _VerticalScrollbarListViewState
    extends State<_VerticalScrollbarListView> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      child: ListView(
        controller: _controller,
        padding: EdgeInsets.zero,
        children: widget.children,
      ),
    );
  }
}
