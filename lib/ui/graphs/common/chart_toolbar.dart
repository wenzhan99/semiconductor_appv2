import 'package:flutter/material.dart';

/// Toolbar for chart zoom and pan controls.
/// 
/// Provides:
/// - Zoom In button
/// - Zoom Out button
/// - Reset/Fit button
/// 
/// Usage:
/// ```dart
/// ChartToolbar(
///   onZoomIn: () => viewport.zoom(0.2),
///   onZoomOut: () => viewport.zoom(-0.2),
///   onReset: () => viewport.reset(),
/// )
/// ```
class ChartToolbar extends StatelessWidget {
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onReset;
  final VoidCallback? onFit;
  final bool showFit;
  final bool compact;

  const ChartToolbar({
    super.key,
    this.onZoomIn,
    this.onZoomOut,
    this.onReset,
    this.onFit,
    this.showFit = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonSize = compact ? 16.0 : 20.0;
    final buttonPadding = compact ? 2.0 : 4.0;
    final minSize = compact ? 28.0 : 32.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(buttonPadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.zoom_in, size: buttonSize),
              tooltip: 'Zoom In',
              onPressed: onZoomIn,
              padding: EdgeInsets.all(buttonPadding),
              constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
            ),
            IconButton(
              icon: Icon(Icons.zoom_out, size: buttonSize),
              tooltip: 'Zoom Out',
              onPressed: onZoomOut,
              padding: EdgeInsets.all(buttonPadding),
              constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
            ),
            IconButton(
              icon: Icon(Icons.restart_alt, size: buttonSize),
              tooltip: 'Reset View',
              onPressed: onReset,
              padding: EdgeInsets.all(buttonPadding),
              constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
            ),
            if (showFit && onFit != null)
              IconButton(
                icon: Icon(Icons.fit_screen, size: buttonSize),
                tooltip: 'Fit to Data',
                onPressed: onFit,
                padding: EdgeInsets.all(buttonPadding),
                constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
              ),
          ],
        ),
      ),
    );
  }
}
