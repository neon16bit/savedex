import 'package:extended_image/extended_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/utils/date_formatter.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/detail/item_detail_view.dart';
import 'package:savedex/features/library/scoped_feed_view.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';

class CompactListItem extends ConsumerWidget {
  final SavedItem item;

  const CompactListItem({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewModel = ref.read(savedViewModelProvider.notifier);
    final isComment = item.itemType == ItemType.comment;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      clipBehavior: Clip.antiAlias,
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
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: item.displayImageUrl != null
                      ? ExtendedImage.network(
                          item.displayImageUrl!,
                          cacheWidth: 120,
                          cacheHeight: 120,
                          fit: BoxFit.cover,
                          cache: true,
                          retries: 1,
                          printError: false,
                          loadStateChanged: (state) {
                            if (state.extendedImageLoadState ==
                                LoadState.failed) {
                              return Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  item.isVideo
                                      ? Icons.videocam_rounded
                                      : Icons.broken_image_outlined,
                                  size: 20,
                                  color: colorScheme.outline,
                                ),
                              );
                            }
                            return null;
                          },
                        )
                      : Container(
                          color: isComment
                              ? colorScheme.tertiaryContainer
                              : (item.isVideo
                                    ? colorScheme.primaryContainer
                                    : colorScheme.secondaryContainer),
                          child: Icon(
                            isComment
                                ? Icons.chat_bubble_rounded
                                : (item.isVideo
                                      ? Icons.videocam_rounded
                                      : Icons.article_rounded),
                            size: 22,
                            color: isComment
                                ? colorScheme.onTertiaryContainer
                                : (item.isVideo
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSecondaryContainer),
                          ),
                        ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
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
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        if (item.isCrosspost) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.repeat_rounded,
                            size: 12,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ],
                        if (item.postFlair != null &&
                            item.postFlair!.trim().isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '• ${item.postFlair!.trim()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.tertiary,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_upward_rounded,
                          size: 11,
                          color: colorScheme.primary,
                        ),
                        Text(
                          DateFormatter.compactNumber(item.score),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              IconButton(
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  item.isStarred
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: item.isStarred
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                onPressed: () => viewModel.toggleStar(item),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
