import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/constants_loader.dart';
import '../../core/constants/constants_repository.dart';
import '../../core/formulas/formula_repository.dart';
import '../../dev/step3_audit_runner.dart';
import '../../services/app_state.dart';
import '../../services/storage_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                // Theme Settings
                _buildThemeCard(context),
                const SizedBox(height: 16),
                // Data Management
                _buildDataManagementCard(context),
                const SizedBox(height: 16),
                if (kDebugMode) ...[
                  _buildDeveloperCard(context),
                  const SizedBox(height: 16),
                ],
                // About
                _buildAboutCard(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentTheme = appState.themeMode;
    String themeLabel;
    switch (currentTheme) {
      case ThemeMode.light:
        themeLabel = 'Light';
        break;
      case ThemeMode.dark:
        themeLabel = 'Dark';
        break;
      case ThemeMode.system:
        themeLabel = 'Auto (Follow system)';
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Theme'),
              subtitle: Text('Current: $themeLabel'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showThemeDialog(context, appState);
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Font Size'),
              subtitle: const Text('Adjust text size'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showFontSizeDialog(context);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.animation),
              title: const Text('Animate step-by-step working'),
              subtitle: const Text('Watch solutions unfold line-by-line'),
              value: appState.animateSteps,
              onChanged: (value) {
                debugPrint('ðŸŽ¬ Settings toggle changed to: $value');
                appState.setAnimateSteps(value);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.play_circle_fill),
              title: const Text('Auto-play visualizations'),
              subtitle: const Text(
                  'Start graph animations automatically (respects reduced motion)'),
              value: appState.autoPlayVisualizations,
              onChanged: (value) => appState.setAutoPlayVisualizations(value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Management',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export Data'),
              subtitle: const Text('Export your workspaces and settings'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _exportData(context),
            ),
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('Import Data'),
              subtitle: const Text('Import workspaces and settings'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _importData(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Clear All Data'),
              subtitle: const Text('Remove all local data'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _clearAllData(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Version'),
              subtitle: const Text('1.0.0'),
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help & Tutorials'),
              subtitle: const Text('Learn how to use the app'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showHelp(context),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Report Issue'),
              subtitle: const Text('Report bugs or request features'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _reportIssue(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: RadioGroup<ThemeMode>(
          groupValue: appState.themeMode,
          onChanged: (mode) {
            if (mode == null) return;
            appState.setThemeMode(mode);
            Navigator.pop(context);
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                title: Text('Auto (Follow system)'),
                subtitle: Text('Automatically match device theme'),
                secondary: Icon(Icons.brightness_auto),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                title: Text('Light'),
                secondary: Icon(Icons.brightness_high),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                title: Text('Dark'),
                secondary: Icon(Icons.brightness_2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFontSizeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Font Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Small'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement font size change
              },
            ),
            ListTile(
              title: const Text('Medium'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement font size change
              },
            ),
            ListTile(
              title: const Text('Large'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement font size change
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon')),
    );
  }

  void _importData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import functionality coming soon')),
    );
  }

  void _clearAllData(BuildContext context) {
    final appState = context.read<AppState>();
    final storageService = context.read<StorageService>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will remove all your workspaces, settings, and history. '
          'This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await storageService.clearAll();
              await appState.loadWorkspaces();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared')),
                );
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Help & Tutorials coming soon')),
    );
  }

  void _reportIssue(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Issue reporting coming soon')),
    );
  }

  Widget _buildDeveloperCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Developer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.rule),
              title: const Text('Audit Step 3 (PN Junction)'),
              subtitle:
                  const Text('Runs substitution audit across all PN formulas'),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => _runPnAudit(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runPnAudit(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final formulas = FormulaRepository();
      await formulas.preloadAll();
      final constants = ConstantsRepository();
      await constants.load();
      final latexMap = await ConstantsLoader.loadLatexSymbols();

      final runner = Step3AuditRunner(
        formulas: formulas,
        constants: constants,
        latexMap: latexMap,
      );

      final results = await runner.runPnAudit();
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close spinner
      _showAuditReport(context, results);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close spinner
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audit failed: $e')),
      );
    }
  }

  void _showAuditReport(BuildContext context, List<Step3AuditResult> results) {
    final passCount = results.where((r) => r.passed).length;
    final failCount = results.length - passCount;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        builder: (context, controller) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step 3 Audit (PN Junction)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'PASS: $passCount   FAIL: $failCount   Total: ${results.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final r = results[index];
                      final color = r.passed ? Colors.green : Colors.red;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text('${r.formulaName} - ${r.solveFor}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.passed
                                    ? 'PASS'
                                    : 'Missing: ${r.missingSymbols.join(", ")}',
                                style: TextStyle(color: color),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                r.substitutionPreview,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
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
        },
      ),
    );
  }
}
