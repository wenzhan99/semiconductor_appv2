import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../core/models/workspace.dart';
import 'pages/topics_page.dart';
import 'pages/workspace_page.dart';
import 'pages/constants_units_page.dart';
import 'pages/settings_page.dart';
import 'pages/graphs_page.dart';

/// Main app screen with tab navigation.
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        // If no current workspace but workspaces exist, select the first one
        if (appState.currentWorkspace == null && appState.workspaces.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            appState.setCurrentWorkspace(appState.workspaces.first);
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Semiconductor Formula Calculator'),
            actions: [
              IconButton(
                icon: const Icon(Icons.person),
                onPressed: () {
                  // TODO: Show user profile
                },
                tooltip: 'Profile',
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Topics'),
                Tab(text: 'Graphs'),
                Tab(text: 'History'),
                Tab(text: 'Constants/Units'),
                Tab(text: 'Settings'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: const [
              TopicsPage(),
              GraphsPage(),
              _PlaceholderPage(title: 'History', message: 'Calculation history coming soon'),
              ConstantsUnitsPage(),
              SettingsPage(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createNewWorkspace(BuildContext context) async {
    final appState = context.read<AppState>();
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Workspace'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Workspace Name',
            hintText: 'Enter workspace name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final workspace = await appState.createWorkspace(result);
      appState.setCurrentWorkspace(workspace);
    }
  }
}

/// Placeholder page for tabs not yet implemented.
class _PlaceholderPage extends StatelessWidget {
  final String title;
  final String message;

  const _PlaceholderPage({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
