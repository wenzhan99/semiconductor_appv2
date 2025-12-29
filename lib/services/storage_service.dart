import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../core/models/workspace.dart';

/// Service for local storage using Hive.
class StorageService {
  static const String _workspacesBoxName = 'workspaces';
  static const String _workspaceIdsKey = 'workspace_ids';
  Box<String>? _workspacesBox;

  Future<void> initialize() async {
    // Ensure Hive is initialized (safe to call multiple times)
    await Hive.initFlutter();
    _workspacesBox ??= await Hive.openBox<String>(_workspacesBoxName);
  }

  Future<Box<String>> _ensureBox() async {
    if (_workspacesBox == null) {
      await initialize();
    }
    return _workspacesBox!;
  }

  /// Get the persisted list of workspace IDs.
  Future<List<String>> _getWorkspaceIdsList() async {
    final box = await _ensureBox();
    final idsJson = box.get(_workspaceIdsKey);
    if (idsJson == null) return [];
    try {
      final ids = jsonDecode(idsJson) as List<dynamic>;
      return ids.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Save the persisted list of workspace IDs.
  Future<void> _saveWorkspaceIdsList(List<String> ids) async {
    final box = await _ensureBox();
    final idsJson = jsonEncode(ids);
    await box.put(_workspaceIdsKey, idsJson);
  }

  /// Save a workspace.
  Future<void> saveWorkspace(Workspace workspace) async {
    final box = await _ensureBox();
    
    // Save workspace JSON
    final json = jsonEncode(workspace.toJson());
    await box.put(workspace.id, json);
    
    // Update persisted IDs list
    final ids = await _getWorkspaceIdsList();
    if (!ids.contains(workspace.id)) {
      ids.add(workspace.id);
      await _saveWorkspaceIdsList(ids);
    }
  }

  /// Load a workspace by ID.
  Future<Workspace?> loadWorkspace(String id) async {
    final box = await _ensureBox();
    final jsonStr = box.get(id);
    if (jsonStr == null) return null;
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return Workspace.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Load all workspace IDs.
  Future<List<String>> getAllWorkspaceIds() async {
    return await _getWorkspaceIdsList();
  }

  /// Delete a workspace.
  Future<void> deleteWorkspace(String id) async {
    final box = await _ensureBox();
    
    // Delete workspace JSON
    await box.delete(id);
    
    // Remove ID from persisted list
    final ids = await _getWorkspaceIdsList();
    ids.remove(id);
    await _saveWorkspaceIdsList(ids);
  }

  /// Clear all workspaces.
  Future<void> clearAll() async {
    final box = await _ensureBox();
    await box.clear();
    // The IDs list will also be cleared since it's in the same box
  }
}
