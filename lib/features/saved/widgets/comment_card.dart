import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/utils/date_formatter.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/detail/item_detail_view.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';

class CommentCard extends ConsumerWidget {
  final SavedItem item;

  const CommentCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewModel = ref.read(savedViewModelProvider.notifier);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => ItemDetailView(itemId: item.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tag_rounded,
                          size: 13,
                          color: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'r/${item.subreddit}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer.withValues(
                        alpha: 0.7,
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_rounded,
                          size: 11,
                          color: colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Comment',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.enrichmentStatus == EnrichmentStatus.slugOnly) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.65,
                        ),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_sync_outlined,
                            size: 11,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.85,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'PENDING METADATA',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: () => viewModel.toggleStar(item),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          item.isStarred
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 22,
                          color: item.isStarred
                              ? Colors.yellow
                              : colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              if ((item.author != null && item.author!.isNotEmpty) ||
                  item.createdAtUtc != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      if (item.author != null && item.author!.isNotEmpty) ...[
                        Container(
                          width: 17,
                          height: 17,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            item.author![0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'u/${item.author}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (item.createdAtUtc != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormatter.timeAgo(item.createdAtUtc),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              if (item.parentPostTitle != null || item.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    item.parentPostTitle != null
                        ? 'On: ${item.parentPostTitle}'
                        : item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                      color: colorScheme.primary,
                    ),
                  ),
                ),

              if (item.body != null && item.body!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    item.body!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: colorScheme.onSurface,
                    ),
                  ),
                )
              else if (item.enrichmentStatus == EnrichmentStatus.slugOnly)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hourglass_empty_rounded,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Comment body will be downloaded during metadata enrichment.',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: item.score > 0
                      ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                      : colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 13,
                      color: item.score > 0
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      DateFormatter.compactNumber(item.score),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: item.score > 0
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
