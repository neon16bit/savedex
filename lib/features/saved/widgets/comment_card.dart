import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/utils/date_formatter.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/detail/item_detail_view.dart';
import 'package:savedex/features/library/scoped_feed_view.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class CommentCard extends ConsumerWidget {
  final SavedItem item;

  const CommentCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => ItemDetailView(itemId: item.id),
            ),
          );
          if (context.mounted) {
            ref.read(savedFeedPaginationProvider.notifier).refreshItem(item.id);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => ScopedFeedView.openSubreddit(
                          context,
                          item.subreddit,
                        ),
                        child: Text(
                          item.displaySubreddit,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),

                      if (item.isArchiveRecovered) ...[
                        const SizedBox(width: 4),
                        const ArchiveRecoveredBadge(
                          variant: ArchiveBadgeVariant.icon,
                        ),
                      ],

                      if (item.isNsfw) ...[
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'NSFW',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: Colors.red,
                          ),
                        ),
                      ],

                      if (item.enrichmentStatus ==
                          EnrichmentStatus.slugOnly) ...[
                        const SizedBox(width: 6),
                        const PendingMetadataBadge(),
                      ],
                    ],
                  ),

                  const SizedBox(height: 6),

                  if ((item.author != null && item.author!.isNotEmpty) ||
                      item.createdAtUtc != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          if (item.author != null &&
                              item.author!.isNotEmpty) ...[
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: item.author != '[deleted]'
                                  ? () => ScopedFeedView.openAuthor(
                                      context,
                                      item.author!,
                                    )
                                  : null,
                              child: Text(
                                'u/${item.author}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
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

                  () {
                    final contextTitle =
                        (item.parentPostTitle != null &&
                            item.parentPostTitle!.trim().isNotEmpty)
                        ? item.parentPostTitle!.trim()
                        : (item.title.trim().isNotEmpty
                              ? item.title.trim()
                              : null);

                    if (contextTitle == null) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply_rounded,
                            size: 14,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.75,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              contextTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurfaceVariant,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }(),

                  if (item.body != null && item.body!.trim().isNotEmpty)
                    Text(
                      item.body!.trim(),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: colorScheme.onSurface,
                      ),
                    )
                  else if (item.enrichmentStatus == EnrichmentStatus.slugOnly)
                    Text(
                      'Comment body will be downloaded during metadata sync.',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: CollectionBadgeRow(
                                itemId: item.id,
                                initialCollections: item.collections,
                                leadingSpacing: false,
                                maxBadges: 1,
                              ),
                            ),
                            NoteIndicatorBadge(
                              itemId: item.id,
                              initialNote: item.userNote,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ItemStarButton(item: item),
                          const SizedBox(width: 2),
                          ItemOptionsMenu(item: item),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.8,
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}
