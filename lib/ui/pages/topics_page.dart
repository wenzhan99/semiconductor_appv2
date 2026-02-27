import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/latex_symbols.dart';
import '../../core/formulas/formula_repository.dart';
import '../../core/formulas/formula.dart';
import '../../core/formulas/formula_category.dart';
import '../../core/formulas/formula_registry.dart';
import '../../core/models/workspace.dart';
import '../../core/models/unit_preferences.dart';
import '../../services/app_state.dart';
import '../widgets/formula_panel.dart';
import '../widgets/latex_text.dart';

class TopicsPage extends StatefulWidget {
  const TopicsPage({super.key});

  @override
  State<TopicsPage> createState() => _TopicsPageState();
}

class _TopicsPageState extends State<TopicsPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, bool> _selectedFormulas = {};
  final Map<String, bool> _categoryExpanded = {};
  bool _showSelectedOnly = false;

  late final FormulaRepository _formulaRepo;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _formulaRepo = FormulaRepository();
    _loadFormulas();

    // Initialize expansion state for each category
    for (final category in formulaCategories) {
      _categoryExpanded[category.id] = false;
    }
  }

  Future<void> _loadFormulas() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      await _formulaRepo.preloadAll();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load formulas: $e';
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final workspace = appState.currentWorkspace;

        // Sync selected formulas with workspace panels
        if (workspace != null) {
          final workspaceFormulaIds =
              workspace.panels.map((p) => p.formulaId).toSet();
          // Remove selections that are no longer in workspace
          _selectedFormulas
              .removeWhere((id, _) => !workspaceFormulaIds.contains(id));
          // Add selections for formulas that are in workspace
          for (final id in workspaceFormulaIds) {
            _selectedFormulas[id] = true;
          }
        }

        if (_isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (_loadError != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading Formulas',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loadError!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadFormulas,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: _scrollController,
            children: [
              Text(
                'Semiconductor Topics',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              _buildToolbar(),
              const SizedBox(height: 16),
              ..._buildCategorySections(),
              const SizedBox(height: 24),
              if (workspace != null && workspace.panels.isNotEmpty)
                _buildWorkspaceSection(context, appState, workspace),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkspaceSection(
    BuildContext context,
    AppState appState,
    Workspace workspace,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workspace',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildWorkspaceSettingsCard(context, appState, workspace),
            const SizedBox(height: 12),
            _buildEmbeddedWorkspacePanels(
              context,
              appState,
              workspace,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategorySections() {
    final widgets = <Widget>[];
    const hiddenCategoryIds = <String>{
      'contacts_breakdown',
    };

    // Build sections for all categories from registry (always show all categories)
    for (final category in formulaCategories) {
      if (hiddenCategoryIds.contains(category.id)) {
        continue;
      }
      final formulas = _formulaRepo.getFormulasInCategory(category.id);

      // Filter by selection if needed
      if (_showSelectedOnly) {
        final hasSelection =
            formulas.any((f) => _selectedFormulas[f.id] ?? false);
        if (!hasSelection) continue;
      }

      // Always build the category card, even if formulas list is empty
      widgets.add(_buildCategoryCard(category, formulas));
    }

    return widgets;
  }

  Widget _buildCategoryCard(FormulaCategory category, List<Formula> formulas) {
    final expanded = _categoryExpanded[category.id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        key: PageStorageKey('category_${category.id}'),
        initiallyExpanded: expanded,
        onExpansionChanged: (value) {
          setState(() {
            _categoryExpanded[category.id] = value;
          });
        },
        title: Text(
          category.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (formulas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No formulas loaded for this category yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  )
                else if (category.id == 'carrier_transport_fundamentals')
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth < 360 ? 1 : 2;
                      const spacing = 12.0;
                      final availableWidth =
                          constraints.maxWidth - spacing * (crossAxisCount - 1);
                      final tileWidth = availableWidth / crossAxisCount;
                      final targetHeight =
                          constraints.maxWidth < 720 ? 140.0 : 120.0;
                      final aspectRatio = tileWidth / targetHeight;
                      return GridView.builder(
                        primary: false,
                        controller: ScrollController(keepScrollOffset: false),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: aspectRatio,
                        ),
                        itemCount: formulas.length,
                        itemBuilder: (context, index) =>
                            _safeFormulaCard(formulas[index]),
                      );
                    },
                  )
                else if (category.id == 'density_of_states_statistics' ||
                    category.id == 'carrier_concentration_equilibrium')
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth < 360 ? 1 : 2;
                      const spacing = 12.0;
                      final availableWidth =
                          constraints.maxWidth - spacing * (crossAxisCount - 1);
                      final tileWidth = availableWidth / crossAxisCount;
                      final targetHeight =
                          constraints.maxWidth < 720 ? 190.0 : 160.0;
                      final aspectRatio = tileWidth / targetHeight;
                      return GridView.builder(
                        primary: false,
                        controller: ScrollController(keepScrollOffset: false),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          childAspectRatio: aspectRatio,
                        ),
                        itemCount: formulas.length,
                        itemBuilder: (context, index) =>
                            _safeFormulaCard(formulas[index]),
                      );
                    },
                  )
                else if (category.id == 'pn_junction')
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth < 360 ? 1 : 2;
                      const spacing = 12.0;
                      final availableWidth =
                          constraints.maxWidth - spacing * (crossAxisCount - 1);
                      final tileWidth = availableWidth / crossAxisCount;
                      final targetHeight =
                          constraints.maxWidth < 720 ? 170.0 : 150.0;
                      final aspectRatio = tileWidth / targetHeight;
                      return GridView.builder(
                        primary: false,
                        controller: ScrollController(keepScrollOffset: false),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          childAspectRatio: aspectRatio,
                        ),
                        itemCount: formulas.length,
                        itemBuilder: (context, index) =>
                            _safeFormulaCard(formulas[index]),
                      );
                    },
                  )
                else
                  ...formulas
                      .map<Widget>((formula) => _safeFormulaCard(formula)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonal(
          onPressed: () {
            setState(() {
              _categoryExpanded.updateAll((key, value) => true);
            });
          },
          child: const Text('Expand all'),
        ),
        FilledButton.tonal(
          onPressed: () {
            setState(() {
              _categoryExpanded.updateAll((key, value) => false);
            });
          },
          child: const Text('Collapse all'),
        ),
        FilterChip(
          selected: _showSelectedOnly,
          onSelected: (value) {
            setState(() {
              _showSelectedOnly = value;
            });
          },
          label: const Text('Show selected only'),
        ),
      ],
    );
  }

  Widget _buildFormulaCard(Formula formula) {
    final isSelected = _selectedFormulas[formula.id] ?? false;
    final latexMap = context.read<LatexSymbolMap>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Checkbox(
                value: isSelected,
                onChanged: (value) async {
                  await _toggleFormulaSelection(formula.id, value ?? false);
                },
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formula.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SingleChildScrollView(
                      key: PageStorageKey(
                          'formula_equation_preview_${formula.id}'),
                      scrollDirection: Axis.horizontal,
                      child: LatexText(
                        latexMap.sanitizeEquationLatexForRender(
                            formula.equationLatex),
                        style: const TextStyle(fontSize: 14),
                        displayMode: true,
                        scale: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'In Workspace',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Guarded wrapper to avoid crashing the grid if a single card fails to build.
  Widget _safeFormulaCard(Formula formula) {
    try {
      return _buildFormulaCard(formula);
    } catch (e, st) {
      debugPrint('Error building formula card for ${formula.id}: $e\n$st');
      return Card(
        color: Colors.red[50],
        child: ListTile(
          title: Text('Error loading ${formula.name}'),
          subtitle: Text(e.toString()),
        ),
      );
    }
  }

  Widget _buildWorkspaceSettingsCard(
    BuildContext context,
    AppState appState,
    Workspace workspace,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Global Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Unit system selector
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Unit System'),
                      const SizedBox(height: 4),
                      SegmentedButton<UnitSystem>(
                        segments: const [
                          ButtonSegment(
                              value: UnitSystem.si, label: Text('SI')),
                          ButtonSegment(
                              value: UnitSystem.cm, label: Text('cm')),
                        ],
                        selected: {workspace.unitSystem},
                        onSelectionChanged: (s) {
                          appState.updateCurrentWorkspace(
                            workspace.copyWith(unitSystem: s.first),
                          );
                        },
                        selectedIcon: const Icon(Icons.check, size: 0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Compute all button
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement compute all
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Computing all formulas...')),
                    );
                  },
                  icon: const Icon(Icons.calculate),
                  label: const Text('Compute All'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedWorkspacePanels(
    BuildContext context,
    AppState appState,
    Workspace workspace,
  ) {
    final sortedPanels = List<WorkspacePanel>.from(workspace.panels)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedPanels.length,
      itemBuilder: (context, index) {
        final panel = sortedPanels[index];
        final formula = _formulaRepo.getFormulaById(panel.formulaId);

        if (formula == null) {
          return Card(
            child: ListTile(
              title: const Text('Unknown Formula'),
              subtitle: Text('ID: ${panel.formulaId}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _removePanel(context, appState, panel.id),
              ),
            ),
          );
        }

        return Card(
          key: ValueKey(panel.id),
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FormulaPanel(
              formula: formula,
              panel: panel,
              showHeader: true,
              showTitleInHeader: true,
              headerTrailing: IconButton(
                icon: const Icon(Icons.close),
                iconSize: 20,
                tooltip: 'Remove',
                onPressed: () => _removePanel(context, appState, panel.id),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleFormulaSelection(String formulaId, bool selected) async {
    if (selected) {
      setState(() {
        _selectedFormulas[formulaId] = true;
      });
      await _addFormulaToWorkspace([formulaId]);
    } else {
      setState(() {
        _selectedFormulas.remove(formulaId);
        _removePanelByFormula(formulaId);
      });
    }
  }

  Future<void> _addFormulaToWorkspace(List<String> formulaIds) async {
    final appState = context.read<AppState>();

    // Ensure workspace exists (creates one if needed)
    final workspace =
        await appState.ensureWorkspaceForFormula(formulaIds.first);

    final newPanels = <WorkspacePanel>[];
    int maxOrder = workspace.panels.isEmpty
        ? 0
        : workspace.panels
            .map((p) => p.orderIndex)
            .reduce((a, b) => a > b ? a : b);

    for (final formulaId in formulaIds) {
      final alreadyExists =
          workspace.panels.any((panel) => panel.formulaId == formulaId);
      if (alreadyExists) continue;
      newPanels.add(WorkspacePanel.create(formulaId, ++maxOrder));
      _selectedFormulas[formulaId] = true;
    }

    if (newPanels.isEmpty) return;

    final updatedWorkspace = workspace.copyWith(
      panels: [...workspace.panels, ...newPanels],
    );

    await appState.updateCurrentWorkspace(updatedWorkspace);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formula added to workspace'),
        ),
      );

      // Auto-scroll to workspace section after formula is added
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _removePanelByFormula(String formulaId) {
    final appState = context.read<AppState>();
    final workspace = appState.currentWorkspace;
    if (workspace == null) return;

    final updatedPanels =
        workspace.panels.where((p) => p.formulaId != formulaId).toList();
    appState.updateCurrentWorkspace(workspace.copyWith(panels: updatedPanels));
  }

  void _removePanel(BuildContext context, AppState appState, String panelId) {
    final workspace = appState.currentWorkspace;
    if (workspace == null) return;

    final panel = workspace.panels.firstWhere((p) => p.id == panelId);
    final updatedPanels =
        workspace.panels.where((p) => p.id != panelId).toList();
    appState.updateCurrentWorkspace(workspace.copyWith(panels: updatedPanels));

    setState(() {
      _selectedFormulas.remove(panel.formulaId);
    });
  }
}
