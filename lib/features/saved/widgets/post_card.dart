import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/utils/date_formatter.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/detail/item_detail_view.dart';
import 'package:savedex/features/detail/widgets/detail_media_view.dart';
import 'package:savedex/features/library/scoped_feed_view.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class PostCard extends ConsumerStatefulWidget {
  final SavedItem item;

  static const bool debugShowMediaTypeBadge = false;

  const PostCard({super.key, required this.item});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  int _galleryIndex = 0;

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _galleryIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final item = widget.item;

    final hasThumbnail = item.hasDisplayImage;

    return Material(
      color: colorScheme.surface,
      child: InkWell(
        onTap: () async {
          final returnIndex = await Navigator.of(context).push<int>(
            MaterialPageRoute(
              builder: (ctx) => ItemDetailView(
                itemId: item.id,
                initialMediaIndex: _galleryIndex,
              ),
            ),
          );
          if (returnIndex != null && mounted && returnIndex != _galleryIndex) {
            setState(() => _galleryIndex = returnIndex);
          }
          if (context.mounted) {
            ref.read(savedFeedPaginationProvider.notifier).refreshItem(item.id);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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

                      if (item.isCrosspost) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Crosspost',
                          child: Icon(
                            Icons.repeat_rounded,
                            size: 13,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ],

                      if (item.isArchiveRecovered) ...[
                        const SizedBox(width: 4),
                        const ArchiveRecoveredBadge(
                          variant: ArchiveBadgeVariant.icon,
                        ),
                      ],

                      if (item.postFlair != null &&
                          item.postFlair!.trim().isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.postFlair!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.tertiary,
                            ),
                          ),
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

                  Text(
                    item.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      height: 1.32,
                    ),
                  ),

                  if (item.enrichmentStatus == EnrichmentStatus.slugOnly &&
                      !hasThumbnail &&
                      (item.body == null || item.body!.isEmpty)) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.link_rounded,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.permalink,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (hasThumbnail || item.isPlayableMedia) ...[
              const SizedBox(height: 12),
              ItemMediaView(
                item: item,
                initialIndex: _galleryIndex,
                onIndexChanged: (index) {
                  _galleryIndex = index;
                },
              ),
            ],

            Padding(
              padding: EdgeInsets.fromLTRB(16, hasThumbnail ? 2 : 6, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasThumbnail &&
                      item.body != null &&
                      item.body!.trim().isNotEmpty) ...[
                    Text(
                      item.body!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

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

                            if (PostCard.debugShowMediaTypeBadge &&
                                item.mediaType != MediaType.text) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getMediaIcon(item.mediaType),
                                      size: 11,
                                      color: colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 3.5),
                                    Text(
                                      item.mediaType.name.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

  IconData _getMediaIcon(MediaType type) {
    switch (type) {
      case MediaType.image:
        return Icons.image_rounded;
      case MediaType.video:
        return Icons.videocam_rounded;
      case MediaType.gallery:
        return Icons.photo_library_rounded;
      case MediaType.link:
        return Icons.link_rounded;
      case MediaType.comment:
        return Icons.chat_bubble_rounded;
      case MediaType.text:
        return Icons.text_snippet_rounded;
      case MediaType.gif:
        return Icons.gif_box_rounded;
    }
  }
}
