import 'package:flutter/material.dart';

import '../common/graph_panels.dart';
import '../common/graph_scaffold_tokens.dart';
import '../core/graph_config.dart';
import '../../widgets/latex_text.dart';

/// Point Inspector panel for StandardGraphPageScaffold.
///
/// Displays information about the currently selected/hovered point on the chart.
class PointInspectorPanel extends StatelessWidget {
  final PointInspectorConfig config;
  final GraphScaffoldTokens? tokensOverride;

  const PointInspectorPanel({
    super.key,
    required this.config,
    this.tokensOverride,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = GraphScaffoldTokens.of(context, override: tokensOverride);
    final hasContent = config.builder != null || config.customBuilder != null;
    final hasInteractionHint = config.interactionHint != null &&
        config.interactionHint!.trim().isNotEmpty;

    Widget body;
    if (!hasContent) {
      body = Text(
        config.emptyMessage,
        style: tokens.hint.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    } else if (config.customBuilder != null) {
      body = config.customBuilder!();
    } else {
      final lines = config.builder!();
      final rows = <GraphKeyValueEntry>[];
      final freeLines = <String>[];
      for (final line in lines) {
        final parsed = _parseKeyValue(line);
        if (parsed == null) {
          freeLines.add(line);
          continue;
        }
        rows.add(GraphKeyValueEntry(label: parsed.$1, value: parsed.$2));
      }

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rows.isNotEmpty)
            GraphKeyValueTable(
              rows: rows,
              tokens: tokens,
            ),
          if (rows.isNotEmpty && freeLines.isNotEmpty)
            SizedBox(height: tokens.rowGap),
          if (freeLines.isNotEmpty)
            ...freeLines.map(
              (line) => Padding(
                padding: EdgeInsets.only(bottom: tokens.rowGap * 0.5),
                child: _latexAwareLine(line, tokens.value),
              ),
            ),
          if (hasInteractionHint) ...[
            if (rows.isNotEmpty || freeLines.isNotEmpty)
              SizedBox(height: tokens.rowGap * 0.5),
            Text(
              config.interactionHint!,
              style: tokens.hint.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    }

    if (!hasContent && hasInteractionHint) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          SizedBox(height: tokens.rowGap * 0.5),
          Text(
            config.interactionHint!,
            style: tokens.hint.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StateChip(isPinned: config.isPinned, tokens: tokens),
        if (hasContent && config.onClear != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: config.onClear,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Clear', style: tokens.label),
          ),
        ],
      ],
    );

    return GraphCard(
      title: 'Point Inspector',
      tokens: tokens,
      trailing: trailing,
      child: body,
    );
  }
}

class _StateChip extends StatelessWidget {
  final bool isPinned;
  final GraphScaffoldTokens tokens;

  const _StateChip({required this.isPinned, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final label = isPinned ? 'Pinned' : 'Live';
    final color = isPinned
        ? Colors.blueAccent.withValues(alpha: 0.15)
        : Colors.green.withValues(alpha: 0.15);
    final textColor = isPinned ? Colors.blueAccent : Colors.green.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: tokens.hint.copyWith(
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

(String, String)? _parseKeyValue(String line) {
  String text = line.trim();
  if (text.isEmpty) return null;

  // Remove leading bullet marker when provided by callers.
  if (text.startsWith('- ')) {
    text = text.substring(2).trim();
  }

  final equals = text.indexOf('=');
  if (equals > 0) {
    final left = text.substring(0, equals).trim();
    final right = text.substring(equals + 1).trim();
    if (left.isNotEmpty && right.isNotEmpty) {
      return (left, right);
    }
  }

  final colon = text.indexOf(':');
  if (colon > 0) {
    final left = text.substring(0, colon).trim();
    final right = text.substring(colon + 1).trim();
    if (left.isNotEmpty && right.isNotEmpty) {
      return (left, right);
    }
  }

  return null;
}

Widget _latexAwareLine(String line, TextStyle style) {
  if (_looksLikeMath(line)) {
    return LatexText(line, style: style);
  }
  return Text(line, style: style);
}

bool _looksLikeMath(String line) {
  return line.contains(r'\') ||
      line.contains('^') ||
      line.contains('_') ||
      line.contains('{') ||
      line.contains('}') ||
      line.contains(r'$');
}
