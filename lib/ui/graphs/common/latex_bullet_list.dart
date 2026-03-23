import 'package:flutter/material.dart';
import 'latex_rich_text.dart';
import '../../widgets/latex_text.dart';

/// Renders a list of bullet points with LaTeX support.
///
/// Each bullet can contain inline LaTeX tokens wrapped in $.
///
/// Usage:
/// ```dart
/// LatexBulletList(
///   bullets: [
///     'The bandgap $E_g$ has exponential effect on $n_i$.',
///     'At higher T, $n_i \\propto \\exp(-E_g/2kT)$ increases.',
///   ],
/// )
/// ```
class LatexBulletList extends StatelessWidget {
  final List<String> bullets;
  final TextStyle? style;
  final double latexScale;
  final double spacing;

  const LatexBulletList({
    super.key,
    required this.bullets,
    this.style,
    this.latexScale = 1.0,
    this.spacing = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: bullets.map((bullet) {
        final hasInlineLatexDelimiters = bullet.contains(r'$');
        final renderAsLatexBlock =
            !hasInlineLatexDelimiters && _looksLikeStandaloneLatex(bullet);

        return Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('\u2022 ', style: style),
              Expanded(
                child: renderAsLatexBlock
                    ? LatexText(
                        bullet,
                        style: style,
                        scale: latexScale,
                      )
                    : hasInlineLatexDelimiters
                        ? LatexRichText.parse(
                            bullet,
                            style: style,
                            latexScale: latexScale,
                          )
                        : Text(bullet, style: style),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  bool _looksLikeStandaloneLatex(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    // Raw TeX commands are the most reliable signal.
    if (t.contains(r'\')) return true;
    // Fallback for compact symbols like k_max or E^2 when whole bullet is math-like.
    final hasMathToken = t.contains('^') || t.contains('_');
    final hasNoSpaces = !t.contains(' ');
    return hasMathToken && hasNoSpaces;
  }
}
