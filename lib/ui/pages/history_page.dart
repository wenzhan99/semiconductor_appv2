import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formulas/formula_repository.dart';
import '../../core/models/workspace.dart';
import '../../services/app_state.dart';
import '../widgets/formula_ui_theme.dart';
import '../widgets/latex_text.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  static final FormulaRepository _formulaRepo = FormulaRepository();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final entries = _buildEntries(appState.workspaces);

        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'No calculation history yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Solve a formula from Topics to see it here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final formula = _formulaRepo.getFormulaById(entry.formulaId);
            final formulaName = formula?.name ?? entry.formulaId;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.calculate_outlined),
                title: Text(formulaName),
                subtitle: Text(
                  '${entry.workspaceName} - ${_formatDate(entry.updatedAt)}',
                ),
                trailing: _StatusChip(status: entry.status),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _HistoryDetailPage(
                        formulaName: formulaName,
                        entry: entry,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  List<_HistoryEntry> _buildEntries(List<Workspace> workspaces) {
    final entries = <_HistoryEntry>[];

    for (final ws in workspaces) {
      for (final panel in ws.panels) {
        final hasActivity =
            panel.status != PanelStatus.needsInputs || panel.outputs.isNotEmpty;
        if (!hasActivity) continue;

        entries.add(
          _HistoryEntry(
            workspaceName: ws.name,
            formulaId: panel.formulaId,
            status: panel.status,
            updatedAt: panel.lastSolvedAt ?? ws.updatedAt,
            solvedFor: panel.lastSolvedFor,
            stepLatexLines: panel.lastStepLatex,
          ),
        );
      }
    }

    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  String _formatDate(DateTime value) {
    final dt = value.toLocal();
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final PanelStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PanelStatus.solved => ('Solved', Colors.green),
      PanelStatus.error => ('Error', Colors.red),
      PanelStatus.stale => ('Stale', Colors.orange),
      PanelStatus.needsInputs => ('Pending', Colors.blueGrey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.workspaceName,
    required this.formulaId,
    required this.status,
    required this.updatedAt,
    required this.solvedFor,
    required this.stepLatexLines,
  });

  final String workspaceName;
  final String formulaId;
  final PanelStatus status;
  final DateTime updatedAt;
  final String? solvedFor;
  final List<String> stepLatexLines;
}

class _HistoryDetailPage extends StatelessWidget {
  const _HistoryDetailPage({
    required this.formulaName,
    required this.entry,
  });

  final String formulaName;
  final _HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final sectionTitleStyle = FormulaUiTheme.stepSectionTitleStyle(context);
    final headerStyle = FormulaUiTheme.stepHeaderTextStyle(context);
    final mathStyle = FormulaUiTheme.stepMathTextStyle(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History Detail'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formulaName, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Text(
                    'Workspace: ${entry.workspaceName}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Solved at: ${_formatStatic(entry.updatedAt)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  _TargetLatexLine(target: entry.solvedFor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Step-by-step working', style: sectionTitleStyle),
                  const SizedBox(height: 8),
                  if (entry.stepLatexLines.isEmpty)
                    Text(
                      'No saved steps for this record. Recompute this formula once to store steps.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    )
                  else
                    ...entry.stepLatexLines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _HistoryStepLine(
                          line: line,
                          headerStyle: headerStyle,
                          mathStyle: mathStyle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatStatic(DateTime value) {
    final dt = value.toLocal();
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}

class _TargetLatexLine extends StatelessWidget {
  const _TargetLatexLine({required this.target});

  final String? target;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final solvedTarget = target?.trim();
    if (solvedTarget == null || solvedTarget.isEmpty) {
      return Text('Target: -', style: style);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Target: ', style: style),
        LatexText(
          solvedTarget,
          style: style,
          displayMode: false,
          scale: 1.0,
        ),
      ],
    );
  }
}

class _HistoryStepLine extends StatelessWidget {
  const _HistoryStepLine({
    required this.line,
    required this.headerStyle,
    required this.mathStyle,
  });

  final String line;
  final TextStyle headerStyle;
  final TextStyle mathStyle;

  @override
  Widget build(BuildContext context) {
    final isStepHeader = line.trimLeft().startsWith(r'\textbf{Step');
    if (isStepHeader) {
      return LatexText(
        line,
        style: headerStyle,
        displayMode: false,
        scale: 1.0,
      );
    }
    return _HistoryMathLine(
      latex: line,
      style: mathStyle,
    );
  }
}

class _HistoryMathLine extends StatefulWidget {
  const _HistoryMathLine({
    required this.latex,
    required this.style,
  });

  final String latex;
  final TextStyle style;

  @override
  State<_HistoryMathLine> createState() => _HistoryMathLineState();
}

class _HistoryMathLineState extends State<_HistoryMathLine> {
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
      thumbVisibility: true,
      notificationPredicate: (notif) => notif.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: LatexText(
          widget.latex,
          style: widget.style,
          displayMode: true,
          scale: FormulaUiTheme.stepMathScale,
        ),
      ),
    );
  }
}
