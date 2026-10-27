import 'package:extended_image/extended_image.dart' hide MediaType;
import 'package:flutter/foundation.dart';
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

class PostCard extends ConsumerWidget {
  final SavedItem item;

  static const bool debugShowMediaTypeBadge = false;

  const PostCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasThumbnail = item.hasDisplayImage;

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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => ScopedFeedView(
                                args: ScopedFeedArgs.subreddit(item.subreddit),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          item.displaySubreddit,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: colorScheme.onSurface,
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
                ],
              ),
            ),

            if (hasThumbnail) ...[
              const SizedBox(height: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FullscreenMediaViewer(item: item),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  color: colorScheme.surfaceContainerHigh,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _SavedFeedMedia(item: item, colorScheme: colorScheme),
                      if (item.isVideo || item.isGif)
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: item.isVideo
                                ? const Padding(
                                    padding: EdgeInsets.only(left: 2),
                                    child: Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  )
                                : const Icon(
                                    Icons.gif_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ] else if (item.isPlayableMedia) ...[
              const SizedBox(height: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FullscreenMediaViewer(item: item),
                    ),
                  );
                },
                child: Container(
                  height: 90,
                  width: double.infinity,
                  color: colorScheme.surfaceContainerHigh,
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: item.isVideo
                            ? Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 30,
                                  color: colorScheme.primary,
                                ),
                              )
                            : Icon(
                                Icons.gif_rounded,
                                size: 30,
                                color: colorScheme.primary,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
                    const SizedBox(height: 12),
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

                            if (debugShowMediaTypeBadge &&
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

class _SavedFeedMedia extends StatefulWidget {
  final SavedItem item;
  final ColorScheme colorScheme;

  const _SavedFeedMedia({required this.item, required this.colorScheme});

  @override
  State<_SavedFeedMedia> createState() => _SavedFeedMediaState();
}

class _SavedFeedMediaState extends State<_SavedFeedMedia> {
  late final PageController _controller;
  int _index = 0;
  double? _galleryAspectRatio;

  bool get _desktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void didUpdateWidget(covariant _SavedFeedMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _index = 0;
      _galleryAspectRatio = null;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildImage(String url, {BoxFit fit = BoxFit.fitWidth}) {
    return ExtendedImage.network(
      url,
      width: double.infinity,
      cacheWidth: 800,
      fit: fit,
      cache: true,
      retries: 1,
      printError: false,
      loadStateChanged: (state) {
        if (state.extendedImageLoadState == LoadState.loading) {
          return Container(
            height: 180,
            color: widget.colorScheme.surfaceContainerHigh,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          );
        }
        if (state.extendedImageLoadState == LoadState.completed &&
            _galleryAspectRatio == null) {
          final info = state.extendedImageInfo;
          if (info != null && info.image.width > 0 && info.image.height > 0) {
            final r = info.image.width / info.image.height;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _galleryAspectRatio == null) {
                setState(() => _galleryAspectRatio = r.clamp(0.6, 1.8));
              }
            });
          }
        }
        if (state.extendedImageLoadState == LoadState.failed) {
          return Container(
            height: 100,
            color: widget.colorScheme.surfaceContainerHigh,
            child: Center(
              child: Icon(
                widget.item.isVideo
                    ? Icons.videocam_rounded
                    : Icons.image_not_supported_outlined,
                size: 28,
                color: widget.colorScheme.outline,
              ),
            ),
          );
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final urls = item.galleryPreviewUrls;
    final isGallery = item.mediaType == MediaType.gallery && urls.length > 1;

    if (!isGallery) {
      final singleUrl = urls.isNotEmpty ? urls.first : item.displayImageUrl;
      if (singleUrl == null) return const SizedBox.shrink();
      return _buildImage(singleUrl, fit: BoxFit.fitWidth);
    }

    return AspectRatio(
      aspectRatio: _galleryAspectRatio ?? (16 / 9),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: urls.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) =>
                _buildImage(urls[index], fit: BoxFit.cover),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _GalleryCounter(current: _index + 1, total: urls.length),
          ),
          if (_desktop)
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _GalleryButton(
                    icon: Icons.chevron_left_rounded,
                    enabled: _index > 0,
                    onPressed: () => _controller.previousPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
                  ),
                  _GalleryButton(
                    icon: Icons.chevron_right_rounded,
                    enabled: _index < urls.length - 1,
                    onPressed: () => _controller.nextPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GalleryCounter extends StatelessWidget {
  final int current;
  final int total;

  const _GalleryCounter({required this.current, required this.total});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      '$current/$total',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _GalleryButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _GalleryButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: IconButton(
      onPressed: enabled ? onPressed : null,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.65),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38,
      ),
      icon: Icon(icon),
    ),
  );
}
