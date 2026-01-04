import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/models/workspace.dart';
import '../core/utils/parse_utils.dart';

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
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final sanitized = _sanitizeWorkspaceJson(decoded, workspaceId: id);
      final workspace = Workspace.fromJson(sanitized);
      if (!mapEquals(decoded, sanitized)) {
        // Persist cleaned data to avoid repeated sanitization.
        await saveWorkspace(workspace);
      }
      return workspace;
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

  Map<String, dynamic> _sanitizeWorkspaceJson(
    Map<String, dynamic> data, {
    required String workspaceId,
  }) {
    bool changed = false;
    final sanitized = Map<String, dynamic>.from(data);

    Map<String, dynamic> _cleanSymbolValueMap(dynamic raw, String path) {
      final out = <String, dynamic>{};
      if (raw is Map<String, dynamic>) {
        raw.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            final numeric = coerceDouble(value['value'], context: '$path.$key.value');
            if (numeric != null) {
              out[key] = {
                ...value,
                'value': numeric,
              };
              // Normalize unit/source to strings in case other types slipped in.
              out[key]['unit'] = value['unit']?.toString() ?? '';
              out[key]['source'] = value['source']?.toString() ?? 'user';
            } else {
              changed = true;
              debugPrint(
                'Sanitized workspace \"$workspaceId\": removed invalid numeric entry at $path.$key (value=${value['value']} type=${value['value']?.runtimeType})',
              );
            }
          } else {
            changed = true;
            debugPrint(
              'Sanitized workspace \"$workspaceId\": removed non-object entry at $path.$key (value=$value, type=${value.runtimeType})',
            );
          }
        });
      } else if (raw != null) {
        changed = true;
        debugPrint(
          'Sanitized workspace \"$workspaceId\": replaced non-map $path (value=$raw, type=${raw.runtimeType})',
        );
      }
      return out;
    }

    sanitized['globals'] = _cleanSymbolValueMap(data['globals'], 'globals');

    if (data['panels'] is List) {
      final panels = <dynamic>[];
      for (var i = 0; i < (data['panels'] as List).length; i++) {
        final rawPanel = (data['panels'] as List)[i];
        if (rawPanel is Map<String, dynamic>) {
          final panel = Map<String, dynamic>.from(rawPanel);
          panel['overrides'] = _cleanSymbolValueMap(rawPanel['overrides'], 'panels[$i].overrides');
          panel['outputs'] = _cleanSymbolValueMap(rawPanel['outputs'], 'panels[$i].outputs');
          panels.add(panel);
          if (!mapEquals(panel, rawPanel)) {
            changed = true;
          }
        } else {
          changed = true;
          debugPrint(
            'Sanitized workspace \"$workspaceId\": removed non-object panel at index $i (value=$rawPanel, type=${rawPanel.runtimeType})',
          );
        }
      }
      sanitized['panels'] = panels;
    }

    if (changed) {
      debugPrint('Workspace \"$workspaceId\" contained invalid persisted data that was sanitized.');
    }

    return sanitized;
  }
}
