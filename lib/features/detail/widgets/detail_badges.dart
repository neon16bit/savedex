import 'package:flutter/material.dart';
import 'package:savedex/core/utils/date_formatter.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class DetailBadgeRow extends StatelessWidget {
  final bool isComment;
  final bool isNsfw;
  final String? postFlair;
  final bool isArchiveRecovered;
  final bool isCrosspost;
  final List<Collection> collections;
  final ValueChanged<Collection>? onCollectionTap;

  const DetailBadgeRow({
    super.key,
    required this.isComment,
    required this.isNsfw,
    this.postFlair,
    this.isArchiveRecovered = false,
    this.isCrosspost = false,
    this.collections = const [],
    this.onCollectionTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isComment
                ? colorScheme.tertiaryContainer.withValues(alpha: 0.8)
                : colorScheme.primaryContainer.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isComment ? 'COMMENT' : 'POST',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isComment
                  ? colorScheme.onTertiaryContainer
                  : colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        if (isNsfw)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
            ),
            child: const Text(
              'NSFW',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Colors.red,
              ),
            ),
          ),
        if (postFlair != null && postFlair!.trim().isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              postFlair!.trim(),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        if (isCrosspost)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.repeat_rounded,
                  size: 11,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  'CROSSPOST',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        if (isArchiveRecovered)
          const ArchiveRecoveredBadge(variant: ArchiveBadgeVariant.detail),
        for (final col in collections)
          CollectionBadge(
            collection: col,
            onTap: onCollectionTap != null ? () => onCollectionTap!(col) : null,
            fontSize: 10.5,
            iconSize: 11,
          ),
      ],
    );
  }
}

class DetailScoreChip extends StatelessWidget {
  final int score;

  const DetailScoreChip({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.arrow_upward_rounded,
            size: 14,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            DateFormatter.compactNumber(score),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class DetailCommentsChip extends StatelessWidget {
  final int count;

  const DetailCommentsChip({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 13,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            DateFormatter.compactNumber(count),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
