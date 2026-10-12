import 'package:flutter/material.dart';

enum ArchiveBadgeVariant { pill, compact, detail }

class ArchiveRecoveredBadge extends StatelessWidget {
  final ArchiveBadgeVariant variant;
  final String? customLabel;

  const ArchiveRecoveredBadge({
    super.key,
    this.variant = ArchiveBadgeVariant.pill,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final EdgeInsetsGeometry padding;
    final BorderRadius borderRadius;
    final double iconSize;
    final double spacing;
    final String label;
    final TextStyle textStyle;
    final double bgAlpha;
    final double borderAlpha;

    switch (variant) {
      case ArchiveBadgeVariant.pill:
        padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 3);
        borderRadius = BorderRadius.circular(100);
        iconSize = 11;
        spacing = 3;
        label = customLabel ?? 'ARCHIVED';
        textStyle = TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: colorScheme.primary,
        );
        bgAlpha = 0.65;
        borderAlpha = 0.4;
        break;

      case ArchiveBadgeVariant.compact:
        padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5);
        borderRadius = BorderRadius.circular(4);
        iconSize = 10.5;
        spacing = 3;
        label = customLabel ?? 'ARCHIVED';
        textStyle = TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: colorScheme.primary,
        );
        bgAlpha = 0.6;
        borderAlpha = 0.35;
        break;

      case ArchiveBadgeVariant.detail:
        padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
        borderRadius = BorderRadius.circular(8);
        iconSize = 12;
        spacing = 4;
        label = customLabel ?? 'ARCHIVED';
        textStyle = TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: colorScheme.primary,
        );
        bgAlpha = 0.7;
        borderAlpha = 0.4;
        break;
    }

    return Tooltip(
      message: 'Recovered from public archive records',
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: bgAlpha),
          borderRadius: borderRadius,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: borderAlpha),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.archive_outlined,
              size: iconSize,
              color: colorScheme.primary,
            ),
            SizedBox(width: spacing),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}
