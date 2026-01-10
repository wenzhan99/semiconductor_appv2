import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formulas/formula_repository.dart';
import '../../core/formulas/formula.dart';
import '../../core/models/workspace.dart';
import '../../core/models/unit_preferences.dart';
import '../../services/app_state.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  final FormulaRepository _formulaRepo = FormulaRepository();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final workspace = appState.currentWorkspace;

        if (workspace == null) {
          return const Center(
            child: Text('No workspace available'),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Global settings bar
              _buildGlobalSettingsBar(context, appState, workspace),
              const SizedBox(height: 16),
              // Workspace panels
              Expanded(
                child: workspace.panels.isEmpty
                    ? _buildEmptyWorkspace(context)
                    : _buildWorkspacePanels(context, appState, workspace),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlobalSettingsBar(
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
                          ButtonSegment(value: UnitSystem.si, label: Text('SI')),
                          ButtonSegment(value: UnitSystem.cm, label: Text('cm')),
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
                // Temperature unit selector
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Temperature Unit'),
                      const SizedBox(height: 4),
                      SegmentedButton<TemperatureUnit>(
                        segments: const [
                          ButtonSegment(
                            value: TemperatureUnit.kelvin,
                            label: Text('Kelvin'),
                          ),
                          ButtonSegment(
                            value: TemperatureUnit.celsius,
                            label: Text('Celsius'),
                          ),
                        ],
                        selected: {workspace.temperatureUnit},
                        onSelectionChanged: (s) {
                          appState.updateCurrentWorkspace(
                            workspace.copyWith(temperatureUnit: s.first),
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
                    _computeAllPanels(context, appState);
                  },
                  icon: const Icon(Icons.calculate),
                  label: const Text('Compute All'),
                ),
                const SizedBox(width: 8),
                // Clear workspace button
                OutlinedButton.icon(
                  onPressed: appState.currentWorkspace?.panels.isEmpty ?? true
                      ? null
                      : () {
                          _clearWorkspace(context, appState);
                        },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWorkspace(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.science,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No formulas in workspace',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Go to the Topics tab to add semiconductor formulas',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to topics tab
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Navigate to Topics tab to add formulas')),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Browse Topics'),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspacePanels(
    BuildContext context,
    AppState appState,
    Workspace workspace,
  ) {
    // Sort panels by order index
    final sortedPanels = List<WorkspacePanel>.from(workspace.panels)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return ListView.builder(
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
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              // Control bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        formula.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (index > 0)
                      IconButton(
                        icon: const Icon(Icons.arrow_upward),
                        iconSize: 20,
                        tooltip: 'Move up',
                        onPressed: () => _movePanel(context, appState, panel.id, -1),
                      ),
                    if (index < sortedPanels.length - 1)
                      IconButton(
                        icon: const Icon(Icons.arrow_downward),
                        iconSize: 20,
                        tooltip: 'Move down',
                        onPressed: () => _movePanel(context, appState, panel.id, 1),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                      tooltip: 'Remove',
                      onPressed: () => _removePanel(context, appState, panel.id),
                    ),
                  ],
                ),
              ),
              // Formula content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Formula equation
                    Text(
                      formula.equationLatex,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                      ),
                    ),
                    // Panel status
                    const SizedBox(height: 12),
                    _buildPanelStatus(context, panel),
                    // TODO: Add formula calculator UI here
                    // This would include input fields, solve button, and result display
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPanelStatus(BuildContext context, WorkspacePanel panel) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (panel.status) {
      case PanelStatus.solved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Solved';
        break;
      case PanelStatus.needsInputs:
        statusColor = Colors.orange;
        statusIcon = Icons.info;
        statusText = 'Needs Inputs';
        break;
      case PanelStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Error';
        break;
      case PanelStatus.stale:
        statusColor = Theme.of(context).colorScheme.outline;
        statusIcon = Icons.refresh;
        statusText = 'Stale';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _computeAllPanels(BuildContext context, AppState appState) {
    final workspace = appState.currentWorkspace;
    if (workspace == null) return;

    // TODO: Implement computation for all panels using FormulaSolver
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Computing all formulas...'),
      ),
    );
  }

  void _clearWorkspace(BuildContext context, AppState appState) {
    final workspace = appState.currentWorkspace;
    if (workspace == null) return;

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Workspace?'),
        content: const Text(
          'This will remove all formulas from the workspace. You can add them back from the Topics tab.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final updatedWorkspace = workspace.copyWith(panels: []);
              appState.updateCurrentWorkspace(updatedWorkspace);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Workspace cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _updatePanel(BuildContext context, AppState appState, WorkspacePanel panel) {
    final workspace = appState.currentWorkspace;
    if (workspace == null) return;

    final updatedPanels = workspace.panels.map((p) {
      return p.id == panel.id ? panel : p;
    }).toList();

    final updatedWorkspace = workspace.copyWith(panels: updatedPanels);
    appState.updateCurrentWorkspace(updatedWorkspace);
  }

  void _removePanel(BuildContext context, AppState appState, String panelId) {
    final workspace = appState.currentWorkspace;
    if (workspace == null) return;

    final updatedPanels = workspace.panels.where((p) => p.id != panelId).toList();
    final updatedWorkspace = workspace.copyWith(panels: updatedPanels);
    appState.updateCurrentWorkspace(updatedWorkspace);
  }

  void _movePanel(BuildContext context, AppState appState, String panelId, int direction) {
    final workspace = appState.currentWorkspace;
    if (workspace == null) return;

    final panels = List<WorkspacePanel>.from(workspace.panels);
    final currentIndex = panels.indexWhere((p) => p.id == panelId);

    if (currentIndex == -1) return;

    final newIndex = currentIndex + direction;
    if (newIndex < 0 || newIndex >= panels.length) return;

    // Swap panels
    final temp = panels[currentIndex];
    panels[currentIndex] = panels[newIndex];
    panels[newIndex] = temp;

    // Update order indices
    for (int i = 0; i < panels.length; i++) {
      panels[i] = WorkspacePanel(
        id: panels[i].id,
        formulaId: panels[i].formulaId,
        overrides: panels[i].overrides,
        outputs: panels[i].outputs,
        status: panels[i].status,
        orderIndex: i,
      );
    }

    final updatedWorkspace = workspace.copyWith(panels: panels);
    appState.updateCurrentWorkspace(updatedWorkspace);
  }
}



