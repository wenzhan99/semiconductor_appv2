import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      default:
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              groupValue: appState.themeMode,
              title: const Text('Auto (Follow system)'),
              subtitle: const Text('Automatically match device theme'),
              secondary: const Icon(Icons.brightness_auto),
              onChanged: (mode) {
                if (mode != null) {
                  appState.setThemeMode(mode);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              groupValue: appState.themeMode,
              title: const Text('Light'),
              secondary: const Icon(Icons.brightness_high),
              onChanged: (mode) {
                if (mode != null) {
                  appState.setThemeMode(mode);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              groupValue: appState.themeMode,
              title: const Text('Dark'),
              secondary: const Icon(Icons.brightness_2),
              onChanged: (mode) {
                if (mode != null) {
                  appState.setThemeMode(mode);
                  Navigator.pop(context);
                }
              },
            ),
          ],
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
}



