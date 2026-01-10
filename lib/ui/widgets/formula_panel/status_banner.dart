import 'package:flutter/material.dart';

import '../formula_ui_theme.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.message,
  });

  const StatusBanner.error({
    super.key,
    required this.message,
    required Color background,
    required Color foreground,
  })  : icon = Icons.error_outline,
        backgroundColor = background,
        foregroundColor = foreground;

  const StatusBanner.notice({
    super.key,
    required this.message,
    required Color background,
    required Color foreground,
  })  : icon = Icons.info_outline,
        backgroundColor = background,
        foregroundColor = foreground;

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: FormulaUiTheme.fieldRadius,
      ),
      child: Row(
        children: [
          Icon(icon, color: foregroundColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foregroundColor),
            ),
          ),
        ],
      ),
    );
  }
}
