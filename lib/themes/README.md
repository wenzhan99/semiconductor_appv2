# Themes Module

## Overview

The Themes module defines the visual appearance of the application, including colors, typography, and component styles.

## Purpose

- **Visual Design**: Define app-wide visual theme
- **Material 3**: Use Material Design 3 components
- **Consistency**: Ensure consistent styling across the app
- **Light/Dark Mode**: Support both light and dark themes

## Files

### 1. app_theme.dart

**Purpose**: Defines light and dark themes for the application.

**Key Class**: `AppTheme`

**Key Methods**:
- `lightTheme` (static getter) - Returns `ThemeData` for light mode
- `darkTheme` (static getter) - Returns `ThemeData` for dark mode

**Theme Configuration**:

#### Color Scheme
- **Seed Color**: `#6B5CF6` (purple)
- **Brightness**: Light or Dark based on theme mode
- Uses `ColorScheme.fromSeed()` for Material 3 dynamic colors

#### Component Themes

**AppBar**:
- Centered title
- No elevation (flat design)

**Card**:
- Elevation: 2
- Border radius: 12px
- Rounded corners

**Input Fields**:
- Outline border
- Border radius: 8px
- Padding: 16px horizontal, 12px vertical

**Buttons**:
- Rounded corners (8px for light, 12px for dark)
- Padding: 24px horizontal, 12px vertical

**Typography**:
- **Headline Large**: 32px, bold
- **Headline Medium**: 28px, bold
- **Headline Small**: 24px, bold
- **Title Large**: 22px, weight 600
- **Title Medium**: 16px, weight 600
- **Title Small**: 14px, weight 600

**Usage**:
```dart
MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: ThemeMode.light,  // or ThemeMode.dark, ThemeMode.system
)
```

**Current Status**: App is forced to light mode (`themeMode: ThemeMode.light` in `main.dart`).

---

## Dependencies

- `package:flutter/material.dart` - For `ThemeData`, `ColorScheme`

## Customization

To modify the theme:
1. Edit `app_theme.dart`
2. Change seed color, component styles, or typography
3. Hot reload to see changes

## Testing

Key test cases:
1. Light theme renders correctly
2. Dark theme renders correctly
3. All components use theme colors
4. Typography scales correctly
5. Material 3 components work properly

