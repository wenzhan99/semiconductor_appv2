import 'package:flutter/material.dart';

import '../../widgets/latex_text.dart';
import 'latex_rich_text.dart';
import 'graph_scaffold_tokens.dart';

@immutable
class GraphSection {
  final String id;
  final String title;
  final Widget body;
  final bool initiallyExpanded;
  final bool wrapInCard;

  const GraphSection({
    required this.id,
    required this.title,
    required this.body,
    this.initiallyExpanded = true,
    this.wrapInCard = true,
  });
}

class GraphSectionHeader extends StatelessWidget {
  final String text;
  final GraphScaffoldTokens? tokens;

  const GraphSectionHeader({
    super.key,
    required this.text,
    this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTokens = GraphScaffoldTokens.of(context, override: tokens);
    return Text(text, style: resolvedTokens.sectionTitle);
  }
}

class GraphCard extends StatelessWidget {
  final String title;
  final Widget child;
  final GraphScaffoldTokens? tokens;
  final bool collapsible;
  final bool initiallyExpanded;
  final Widget? trailing;

  const GraphCard({
    super.key,
    required this.title,
    required this.child,
    this.tokens,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTokens = GraphScaffoldTokens.of(context, override: tokens);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(resolvedTokens.cardRadius),
    );

    if (collapsible) {
      return Card(
        elevation: 1,
        shape: shape,
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          title: GraphSectionHeader(text: title, tokens: resolvedTokens),
          trailing: trailing,
          childrenPadding: EdgeInsets.fromLTRB(
            resolvedTokens.cardPadding,
            0,
            resolvedTokens.cardPadding,
            resolvedTokens.cardPadding,
          ),
          children: [child],
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: shape,
      child: Padding(
        padding: EdgeInsets.all(resolvedTokens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      GraphSectionHeader(text: title, tokens: resolvedTokens),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            SizedBox(height: resolvedTokens.rowGap),
            child,
          ],
        ),
      ),
    );
  }
}

@immutable
class GraphKeyValueEntry {
  final String label;
  final String value;
  final String? subtitle;
  final bool boldValue;
  final Color? valueColor;
  final double labelScale;

  const GraphKeyValueEntry({
    required this.label,
    required this.value,
    this.subtitle,
    this.boldValue = false,
    this.valueColor,
    this.labelScale = 1.0,
  });
}

class GraphKeyValueRow extends StatelessWidget {
  final Widget label;
  final Widget value;
  final Widget? trailing;
  final String? subtitle;
  final GraphScaffoldTokens? tokens;

  const GraphKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.subtitle,
    this.tokens,
  });

  factory GraphKeyValueRow.text({
    Key? key,
    required String label,
    required String value,
    String? subtitle,
    bool boldValue = false,
    Color? valueColor,
    double labelScale = 1.0,
    GraphScaffoldTokens? tokens,
  }) {
    final baseTokens = tokens;
    final baseLabelStyle = baseTokens?.label;
    final labelStyle = baseLabelStyle == null
        ? null
        : baseLabelStyle.copyWith(
            fontSize: (baseLabelStyle.fontSize ?? 12) * labelScale,
          );
    final valueStyle = baseTokens?.value.copyWith(
      color: valueColor,
      fontWeight: boldValue ? FontWeight.w700 : FontWeight.w600,
    );

    return GraphKeyValueRow(
      key: key,
      tokens: tokens,
      subtitle: subtitle,
      label: _latexAwareText(label, labelStyle),
      value: _latexAwareText(value, valueStyle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedTokens = GraphScaffoldTokens.of(context, override: tokens);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: label),
            SizedBox(width: resolvedTokens.rowGap),
            Flexible(
                child: Align(alignment: Alignment.centerRight, child: value)),
            if (trailing != null) ...[
              SizedBox(width: resolvedTokens.rowGap),
              trailing!,
            ],
          ],
        ),
        if (subtitle != null) ...[
          SizedBox(height: resolvedTokens.rowGap * 0.5),
          Text(
            subtitle!,
            style: resolvedTokens.hint.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class GraphKeyValueTable extends StatelessWidget {
  final List<GraphKeyValueEntry> rows;
  final GraphScaffoldTokens? tokens;

  const GraphKeyValueTable({
    super.key,
    required this.rows,
    this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTokens = GraphScaffoldTokens.of(context, override: tokens);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          GraphKeyValueRow.text(
            label: rows[i].label,
            value: rows[i].value,
            subtitle: rows[i].subtitle,
            boldValue: rows[i].boldValue,
            valueColor: rows[i].valueColor,
            labelScale: rows[i].labelScale,
            tokens: resolvedTokens,
          ),
          if (i != rows.length - 1) SizedBox(height: resolvedTokens.rowGap),
        ],
      ],
    );
  }
}

Widget _latexAwareText(String text, TextStyle? style) {
  if (text.contains(r'$')) {
    return LatexRichText.parse(text, style: style);
  }
  if (_looksLikeLatex(text)) {
    return LatexText(text, style: style);
  }
  return Text(text, style: style);
}

bool _looksLikeLatex(String text) {
  final t = text.trim();
  if (t.isEmpty) return false;
  if (RegExp(r'\\[A-Za-z]+').hasMatch(t)) return true;
  if (t.contains('_{') || t.contains('^{')) return true;
  return !t.contains(' ') && (t.contains('^') || t.contains('_'));
}
