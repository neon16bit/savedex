import 'package:extended_image/extended_image.dart' hide MediaType;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/utils/date_formatter.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/detail/item_detail_view.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class PostCard extends ConsumerWidget {
  final SavedItem item;

  const PostCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasThumbnail = item.hasDisplayImage;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                        Text(
                          item.displaySubreddit,
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

                  if (item.postFlair != null &&
                      item.postFlair!.trim().isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer.withValues(
                            alpha: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          item.postFlair!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (item.isNsfw) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: const Text(
                        'NSFW',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],

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

                  CollectionBadgeRow(
                    itemId: item.id,
                    initialCollections: item.collections,
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

              if (item.hasDisplayImage) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 240),
                    width: double.infinity,
                    color: colorScheme.surfaceContainerHigh,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ExtendedImage.network(
                          item.displayImageUrl!,
                          width: double.infinity,
                          cacheWidth: 800,
                          fit: BoxFit.cover,
                          cache: true,
                          printError: false,
                          loadStateChanged: (state) {
                            if (state.extendedImageLoadState ==
                                LoadState.loading) {
                              return Container(
                                height: 180,
                                color: colorScheme.surfaceContainerHigh,
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                    ),
                                  ),
                                ),
                              );
                            } else if (state.extendedImageLoadState ==
                                LoadState.failed) {
                              return Container(
                                height: 100,
                                color: colorScheme.surfaceContainerHigh,
                                child: Center(
                                  child: Icon(
                                    item.isVideo
                                        ? Icons.videocam_rounded
                                        : Icons.image_not_supported_outlined,
                                    size: 28,
                                    color: colorScheme.outline,
                                  ),
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                        if (item.isVideo)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Video',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ] else if (item.isVideo) ...[
                const SizedBox(height: 12),
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_circle_fill_rounded,
                          size: 30,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Reddit Video',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (!hasThumbnail &&
                  item.body != null &&
                  item.body!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
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
              ],

              const SizedBox(height: 12),

              Row(
                children: [
                  // Score Pill
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

                  const SizedBox(width: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormatter.compactNumber(item.numComments),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (item.mediaType != MediaType.text) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getMediaIcon(item.mediaType),
                            size: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.mediaType.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  NoteIndicatorBadge(
                    itemId: item.id,
                    initialNote: item.userNote,
                  ),

                  const Spacer(),
                  ItemStarButton(item: item),
                  const SizedBox(width: 2),
                  ItemOptionsMenu(item: item),
                ],
              ),
            ],
          ),
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
    }
  }
}
