# Services Module

## Overview

The Services module contains application-level services that manage state, storage, and authentication. These services coordinate between core modules and provide data to the UI.

## Purpose

- **Application State**: Manage global application state (workspaces, theme)
- **Storage**: Persist data to local storage (Hive)
- **Authentication**: Handle user authentication (placeholder for future)
- **Service Coordination**: Orchestrate core modules

## Files

### 1. app_state.dart

**Purpose**: Main application state manager using ChangeNotifier pattern.

**Key Class**: `AppState`

**Fields**:
- `workspaces` (List<Workspace>) - All user workspaces
- `currentWorkspace` (Workspace?) - Currently active workspace
- `themeMode` (ThemeMode) - Light/dark theme preference

**Key Methods**:
- `initialize()` - Initialize app state (loads workspaces)
- `loadWorkspaces()` - Load all workspaces from storage
- `createWorkspace(String name)` - Create new workspace
- `setCurrentWorkspace(Workspace)` - Set active workspace
- `updateCurrentWorkspace(Workspace)` - Update and save workspace
- `deleteWorkspace(String id)` - Delete workspace
- `setThemeMode(ThemeMode)` - Change theme

**State Management**:
- Extends `ChangeNotifier` for reactive updates
- Calls `notifyListeners()` when state changes
- UI consumes via `Consumer<AppState>` or `context.read<AppState>()`

**Dependencies**: `StorageService`, `AuthService`, `core/models/workspace.dart`

**Usage**: Provided via `Provider` in `main.dart`, accessed throughout UI.

---

### 2. storage_service.dart

**Purpose**: Service for local persistence using Hive (key-value database).

**Key Class**: `StorageService`

**Key Methods**:
- `initialize()` - Initialize Hive and open boxes
- `saveWorkspace(Workspace)` - Save workspace to storage
- `loadWorkspace(String id)` - Load workspace by ID
- `getAllWorkspaceIds()` - Get list of all workspace IDs
- `deleteWorkspace(String id)` - Delete workspace from storage

**Storage Strategy**:
- Uses Hive boxes (key-value storage)
- Workspaces stored as JSON strings
- Workspace IDs stored in separate list
- All data persisted locally (no cloud sync)

**Error Handling**:
- JSON decode errors return `null`
- Missing workspaces return `null`
- Callers must check for `null`

**Dependencies**: `package:hive_flutter/hive_flutter.dart`, `core/models/workspace.dart`

---

### 3. auth_service.dart

**Purpose**: Authentication service (currently placeholder for future implementation).

**Key Class**: `AuthService`

**Fields**:
- `userId` (String?) - Current user ID
- `isAuthenticated` (bool) - Authentication status

**Key Methods**:
- `signIn(String email, String password)` - Sign in (placeholder)
- `signOut()` - Sign out
- `signUp(String email, String password)` - Sign up (placeholder)

**Current Status**: Placeholder implementation - always succeeds. TODO: Implement actual authentication.

**State Management**: Extends `ChangeNotifier` for reactive updates.

**Usage**: Provided via `Provider` in `main.dart`, but not actively used yet.

---

### 4. constants_loader.dart

**Purpose**: ⚠️ **DUPLICATE FILE - SHOULD BE DELETED**

**Status**: This file exists but is **NOT USED**. The active version is in `lib/core/constants/constants_loader.dart`.

**Issue**: This file imports from `models/` (old structure) instead of `core/constants/`.

**Recommendation**: Delete this file and use `core/constants/constants_loader.dart` instead.

---

## Data Flow

```
App Startup
    ↓
main.dart initializes services
    ↓
AppState.initialize()
    ↓
StorageService.loadWorkspaces()
    ↓
Workspaces loaded into AppState
    ↓
UI displays workspaces
    ↓
User actions update AppState
    ↓
StorageService saves changes
```

## Dependencies

- `package:flutter/material.dart` - For `ChangeNotifier`, `ThemeMode`
- `package:hive_flutter/hive_flutter.dart` - For local storage
- `core/models/` - For `Workspace` model
- `core/constants/` - (via ConstantsRepository, not directly)

## Error Handling

- Storage errors: Methods return `null` or empty lists
- JSON errors: Caught and handled gracefully
- Missing data: Checked before use

## Testing

Key test cases:
1. `AppState` creates and manages workspaces
2. `StorageService` saves and loads workspaces correctly
3. `AppState` notifies listeners on state changes
4. `AuthService` placeholder works (for now)
5. Handle missing storage gracefully

## Architecture Notes

**Services are coordination layer**:
- Services don't contain business logic (that's in `core/`)
- Services orchestrate core modules
- Services provide state to UI via Provider

**State Management Pattern**:
- Uses Provider pattern (not Redux, not BLoC)
- `AppState` is main state holder
- UI consumes via `Consumer` or `context.read()`

