import 'package:material_ui/material_ui.dart';

enum ArchiveBadgeVariant { icon, badge, comment }

class ArchiveRecoveredBadge extends StatelessWidget {
  final ArchiveBadgeVariant variant;
  final String? customLabel;

  const ArchiveRecoveredBadge({
    super.key,
    this.variant = ArchiveBadgeVariant.badge,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Widget content;
    switch (variant) {
      case ArchiveBadgeVariant.icon:
      case ArchiveBadgeVariant.comment:
        content = Icon(
          Icons.archive_outlined,
          size: variant == ArchiveBadgeVariant.icon ? 13 : 12,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
        );
        break;

      case ArchiveBadgeVariant.badge:
        final label = (customLabel != null && customLabel!.trim().isNotEmpty)
            ? customLabel!.trim()
            : 'ARCHIVED';

        content = Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.archive_outlined,
                size: 12,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
        break;
    }

    return Tooltip(
      message: 'Recovered from public archive records',
      child: content,
    );
  }
}
