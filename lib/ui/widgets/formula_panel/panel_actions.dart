import 'package:flutter/material.dart';

class PanelActions extends StatelessWidget {
  const PanelActions({
    super.key,
    required this.isComputing,
    required this.onCompute,
    required this.onClear,
  });

  final bool isComputing;
  final VoidCallback onCompute;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: isComputing ? null : onCompute,
          icon: const Icon(Icons.calculate),
          label: Text(isComputing ? 'Computing...' : 'Compute'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: isComputing ? null : onClear,
          child: const Text('Clear'),
        ),
      ],
    );
  }
}
