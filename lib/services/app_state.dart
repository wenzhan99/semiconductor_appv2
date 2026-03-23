import 'package:flutter/material.dart';
import '../core/models/workspace.dart';
import 'storage_service.dart';
import 'auth_service.dart';

/// Main application state.
class AppState extends ChangeNotifier {
  final StorageService _storageService;
  final AuthService _authService;

  List<Workspace> _workspaces = [];
  Workspace? _currentWorkspace;
  ThemeMode _themeMode = ThemeMode.light; // Default to light

  AppState(this._storageService, this._authService);

  List<Workspace> get workspaces => List.unmodifiable(_workspaces);
  Workspace? get currentWorkspace => _currentWorkspace;
  ThemeMode get themeMode => _themeMode;

  Future<void> initialize() async {
    await loadWorkspaces();
    await _loadThemePreference();
  }

  /// Load theme preference from storage.
  Future<void> _loadThemePreference() async {
    final saved = await _storageService.loadThemePreference();
    if (saved != null) {
      switch (saved) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        case 'system':
        default:
          _themeMode = ThemeMode.system;
          break;
      }
      notifyListeners();
    }
    // If no saved preference, keep default (ThemeMode.light)
  }

  /// Load all workspaces from storage.
  Future<void> loadWorkspaces() async {
    final ids = await _storageService.getAllWorkspaceIds();
    final loaded = await Future.wait(ids.map(_storageService.loadWorkspace));
    _workspaces = loaded.whereType<Workspace>().toList();
    notifyListeners();
  }

  /// Create a new workspace.
  Future<Workspace> createWorkspace(String name) async {
    final workspace = Workspace.create(name);
    await _storageService.saveWorkspace(workspace);
    _workspaces.add(workspace);
    _currentWorkspace = workspace;
    notifyListeners();
    return workspace;
  }

  /// Set the current workspace.
  void setCurrentWorkspace(Workspace workspace) {
    _currentWorkspace = workspace;
    notifyListeners();
  }

  /// Update the current workspace.
  Future<void> updateCurrentWorkspace(Workspace workspace) async {
    await _storageService.saveWorkspace(workspace);
    final index = _workspaces.indexWhere((w) => w.id == workspace.id);
    if (index >= 0) {
      _workspaces[index] = workspace;
    }
    if (_currentWorkspace?.id == workspace.id) {
      _currentWorkspace = workspace;
    }
    notifyListeners();
  }

  /// Delete a workspace.
  Future<void> deleteWorkspace(String id) async {
    await _storageService.deleteWorkspace(id);
    _workspaces.removeWhere((w) => w.id == id);
    if (_currentWorkspace?.id == id) {
      _currentWorkspace = null;
    }
    notifyListeners();
  }

  /// Set theme mode and persist to storage.
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    
    // Persist to storage
    String modeStr;
    switch (mode) {
      case ThemeMode.light:
        modeStr = 'light';
        break;
      case ThemeMode.dark:
        modeStr = 'dark';
        break;
      case ThemeMode.system:
      default:
        modeStr = 'system';
        break;
    }
    await _storageService.saveThemePreference(modeStr);
    
    notifyListeners();
  }

  /// Ensure a workspace exists for adding formulas.
  /// Creates a new workspace if currentWorkspace is null.
  Future<Workspace> ensureWorkspaceForFormula(String formulaId) async {
    // If one is already selected, use it.
    if (_currentWorkspace != null) return _currentWorkspace!;

    // If there are saved workspaces, select the first.
    if (_workspaces.isNotEmpty) {
      _currentWorkspace = _workspaces.first;
      notifyListeners();
      return _currentWorkspace!;
    }

    // Otherwise create a default workspace.
    final ws = await createWorkspace('Workspace 1');
    return ws;
  }
}

