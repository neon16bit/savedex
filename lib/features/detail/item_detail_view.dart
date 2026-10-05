import 'package:extended_image/extended_image.dart' hide MediaType;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/utils/date_formatter.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/detail/item_detail_viewmodel.dart';
import 'package:url_launcher/url_launcher.dart';

class ItemDetailView extends ConsumerStatefulWidget {
  final String itemId;

  const ItemDetailView({super.key, required this.itemId});

  @override
  ConsumerState<ItemDetailView> createState() => _ItemDetailViewState();
}

class _ItemDetailViewState extends ConsumerState<ItemDetailView> {
  final Set<String> _enrichingIds = {};
  bool _isEnriching(String id) => _enrichingIds.contains(id);

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemDetailProvider(widget.itemId));
    final threadAsync = ref.watch(relatedThreadProvider(widget.itemId));
    final actions = ref.read(itemDetailActionsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return itemAsync.when(
      data: (rawItem) {
        if (rawItem == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Item not found')),
          );
        }

        if (rawItem.itemType == ItemType.comment && threadAsync.isLoading) {
          return Scaffold(
            appBar: AppBar(
              titleSpacing: 0,
              title: Text('r/${rawItem.subreddit}'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final parentPost = threadAsync.asData?.value.parentPost;
        final item = parentPost ?? rawItem;
        final isComment = item.itemType == ItemType.comment;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 2,
            titleSpacing: 0,
            title: Text(
              'r/${item.subreddit}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  item.isStarred
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: item.isStarred ? Colors.amber : null,
                ),
                tooltip: item.isStarred ? 'Starred' : 'Star',
                onPressed: () => actions.toggleStar(item),
              ),
              PopupMenuButton<String>(
                icon: _isEnriching(item.id)
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : const Icon(Icons.more_vert_rounded),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (val) {
                  if (val == 'refresh') {
                    _refreshMetadata(actions, item, colorScheme);
                  } else if (val == 'open_reddit') {
                    _openReddit(item.fullPermalink);
                  } else if (val == 'copy_link') {
                    Clipboard.setData(ClipboardData(text: item.fullPermalink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Permalink copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else if (val == 'delete') {
                    _confirmDelete(context, actions, item.id);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'refresh',
                    enabled: !_isEnriching(item.id),
                    child: Row(
                      children: [
                        const Icon(Icons.sync_rounded, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          _isEnriching(item.id)
                              ? 'Refreshing...'
                              : 'Refresh Metadata',
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'open_reddit',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_browser_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Open in Reddit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy_link',
                    child: Row(
                      children: [
                        Icon(Icons.link_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Copy Link'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.red,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Delete Item',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => _openReddit(item.fullPermalink),
                      icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                      label: const Text(
                        'Open on Reddit',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(13),
                    ),
                    icon: Icon(
                      item.userNote != null && item.userNote!.isNotEmpty
                          ? Icons.sticky_note_2_rounded
                          : Icons.note_add_outlined,
                      size: 20,
                    ),
                    tooltip: 'Personal Note',
                    onPressed: () => _editNoteDialog(
                      context,
                      actions,
                      item.id,
                      item.userNote,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(13),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 20),
                    tooltip: 'Share',
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: item.fullPermalink),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              if (isComment) ...[
                _buildThreadDiscussionHeader(context, item, colorScheme, theme),
                const SizedBox(height: 8),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // badge row
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // post/comment
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isComment
                                ? colorScheme.tertiaryContainer.withValues(
                                    alpha: 0.8,
                                  )
                                : colorScheme.primaryContainer.withValues(
                                    alpha: 0.8,
                                  ),
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
                        if (item.isNsfw)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.4),
                              ),
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
                        if (item.postFlair != null &&
                            item.postFlair!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer.withValues(
                                alpha: 0.7,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.postFlair!,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (item.author != null && item.author!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'u/${item.author}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          if (item.createdAtUtc != null)
                            Text(
                              ' • ${DateFormatter.timeAgo(item.createdAtUtc)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],

                    // media container
                    if (item.hasDisplayImage) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          if (item.isVideo) {
                            final videoUrl = item.mediaUrl ?? item.url;
                            if (videoUrl != null) {
                              launchUrl(
                                Uri.parse(videoUrl),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          } else {
                            _openFullscreenMedia(
                              context,
                              item.displayImageUrl!,
                            );
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 400),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ExtendedImage.network(
                                  item.displayImageUrl!,
                                  fit: BoxFit.contain,
                                  cache: true,
                                  printError: false,
                                  loadStateChanged: (state) {
                                    switch (state.extendedImageLoadState) {
                                      case LoadState.loading:
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(32),
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      case LoadState.completed:
                                        return null;
                                      case LoadState.failed:
                                        return Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: Icon(
                                              item.isVideo
                                                  ? Icons.videocam_rounded
                                                  : Icons.broken_image_rounded,
                                              size: 44,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        );
                                    }
                                  },
                                ),
                                if (item.isVideo)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.7,
                                      ),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Play Video',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else if (item.isVideo) ...[
                      const SizedBox(height: 16),
                      Material(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            final videoUrl = item.mediaUrl ?? item.url;
                            if (videoUrl != null) {
                              launchUrl(
                                Uri.parse(videoUrl),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          child: Container(
                            height: 140,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_circle_fill_rounded,
                                    size: 48,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Reddit Video',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tap to play external video',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (item.url != null &&
                        !item.url!.contains('reddit.com') &&
                        item.mediaType == MediaType.link) ...[
                      const SizedBox(height: 14),
                      Material(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => launchUrl(
                            Uri.parse(item.url!),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer
                                        .withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.link_rounded,
                                    size: 18,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.url!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tap to open external link',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    // content
                    if (item.body != null && item.body!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      MarkdownBody(
                        data: item.body!,
                        selectable: true,
                        onTapLink: (text, href, title) {
                          if (href != null) {
                            launchUrl(
                              Uri.parse(href),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        styleSheet: MarkdownStyleSheet.fromTheme(theme)
                            .copyWith(
                              p: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.55,
                                fontSize: 14.5,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border(
                                  left: BorderSide(
                                    color: colorScheme.primary,
                                    width: 4,
                                  ),
                                ),
                              ),
                            ),
                      ),
                    ],

                    if (item.userNote != null && item.userNote!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.18,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border(
                            left: BorderSide(
                              color: colorScheme.primary,
                              width: 3.5,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.sticky_note_2_rounded,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => _editNoteDialog(
                                  context,
                                  actions,
                                  item.id,
                                  item.userNote,
                                ),
                                child: Text(
                                  item.userNote!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    height: 1.35,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              iconSize: 16,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              icon: Icon(
                                Icons.edit_outlined,
                                color: colorScheme.primary.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                              tooltip: 'Edit Note',
                              onPressed: () => _editNoteDialog(
                                context,
                                actions,
                                item.id,
                                item.userNote,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.6),
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
                                DateFormatter.compactNumber(item.score),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isComment && item.numComments > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.6),
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
                                  DateFormatter.compactNumber(item.numComments),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              _buildThreadCommentsSection(
                context,
                item,
                threadAsync.asData?.value.comments ?? const [],
                actions,
                colorScheme,
                theme,
                highlightedCommentId: widget.itemId != item.id
                    ? widget.itemId
                    : null,
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  void _openFullscreenMedia(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: ExtendedImage.network(
              imageUrl,
              fit: BoxFit.contain,
              mode: ExtendedImageMode.gesture,
              cache: true,
              printError: false,
              initGestureConfigHandler: (state) {
                return GestureConfig(
                  minScale: 0.9,
                  animationMinScale: 0.7,
                  maxScale: 4.0,
                  animationMaxScale: 4.5,
                  speed: 1.0,
                  inertialSpeed: 100.0,
                  initialScale: 1.0,
                  inPageView: false,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshMetadata(
    ItemDetailActions actions,
    SavedItem item,
    ColorScheme colorScheme,
  ) async {
    if (_isEnriching(item.id)) return;
    setState(() => _enrichingIds.add(item.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing metadata...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
    try {
      final result = await actions.reEnrich(item);
      if (!mounted) return;
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metadata refreshed successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to refresh metadata'),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _enrichingIds.remove(item.id));
      }
    }
  }

  void _openReddit(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open Reddit link: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _editNoteDialog(
    BuildContext context,
    ItemDetailActions actions,
    String itemId,
    String? currentNote,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _NoteDialog(
        initialNote: currentNote,
        onSave: (note) => actions.updateNote(itemId, note),
      ),
    );
  }

  Widget _buildThreadDiscussionHeader(
    BuildContext context,
    SavedItem commentItem,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    if (commentItem.parentPostTitle != null &&
        commentItem.parentPostTitle!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.forum_outlined, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THREAD DISCUSSION',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      commentItem.parentPostTitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildThreadCommentsSection(
    BuildContext context,
    SavedItem currentItem,
    List<SavedItem> allComments,
    ItemDetailActions actions,
    ColorScheme colorScheme,
    ThemeData theme, {
    String? highlightedCommentId,
  }) {
    final isComment = currentItem.itemType == ItemType.comment;
    final relevantComments = isComment
        ? allComments.where((c) => c.id != currentItem.id).toList()
        : allComments;

    if (relevantComments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer.withValues(alpha: 0.5),
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                width: 1,
              ),
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.forum_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isComment
                              ? 'Other Saved Comments'
                              : 'Saved Comments in Thread',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${relevantComments.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Saved in your library from this discussion',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...relevantComments.map(
          (comment) => _buildInlineCommentCard(
            context,
            comment,
            actions,
            colorScheme,
            theme,
            isHighlighted: comment.id == highlightedCommentId,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInlineCommentCard(
    BuildContext context,
    SavedItem comment,
    ItemDetailActions actions,
    ColorScheme colorScheme,
    ThemeData theme, {
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isHighlighted
            ? colorScheme.primaryContainer.withValues(alpha: 0.22)
            : colorScheme.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? colorScheme.primary.withValues(alpha: 0.7)
              : colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 13,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                comment.author != null ? 'u/${comment.author}' : 'u/[deleted]',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isHighlighted
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
              if (comment.createdAtUtc != null) ...[
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
                  DateFormatter.timeAgo(comment.createdAtUtc),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          if (comment.body != null && comment.body!.isNotEmpty) ...[
            const SizedBox(height: 6),
            MarkdownBody(
              data: comment.body!,
              selectable: true,
              onTapLink: (text, href, title) {
                if (href != null) {
                  launchUrl(
                    Uri.parse(href),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
          if (comment.userNote != null && comment.userNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _editNoteDialog(
                context,
                actions,
                comment.id,
                comment.userNote,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: colorScheme.primary, width: 3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.sticky_note_2_rounded,
                        size: 13,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        comment.userNote!,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: colorScheme.onSurface,
                          height: 1.3,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      size: 13,
                      color: colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 4),
          //const Divider(height: 1),
          Row(
            children: [
              if (comment.score > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        DateFormatter.compactNumber(comment.score),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: Icon(
                  comment.userNote != null && comment.userNote!.isNotEmpty
                      ? Icons.sticky_note_2_rounded
                      : Icons.note_add_outlined,
                  color:
                      comment.userNote != null && comment.userNote!.isNotEmpty
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                tooltip:
                    comment.userNote != null && comment.userNote!.isNotEmpty
                    ? 'Edit Note'
                    : 'Add Note',
                onPressed: () => _editNoteDialog(
                  context,
                  actions,
                  comment.id,
                  comment.userNote,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: Icon(
                  comment.isStarred
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: comment.isStarred
                      ? Colors.amber
                      : colorScheme.onSurfaceVariant,
                ),
                tooltip: comment.isStarred ? 'Starred' : 'Star',
                onPressed: () => actions.toggleStar(comment),
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: SvgPicture.asset(
                  'assets/icons/reddit.svg',
                  width: 17,
                  height: 17,
                  colorFilter: ColorFilter.mode(
                    colorScheme.onSurfaceVariant,
                    BlendMode.srcIn,
                  ),
                ),
                tooltip: 'Open in Reddit',
                onPressed: () => _openReddit(comment.fullPermalink),
              ),
              const SizedBox(width: 2),
              PopupMenuButton<String>(
                tooltip: 'More options',
                iconSize: 18,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                icon: _isEnriching(comment.id)
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                onSelected: (val) {
                  if (val == 'refresh') {
                    _refreshMetadata(actions, comment, colorScheme);
                  } else if (val == 'copy_text') {
                    if (comment.body != null && comment.body!.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: comment.body!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Comment text copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } else if (val == 'copy_link') {
                    Clipboard.setData(
                      ClipboardData(text: comment.fullPermalink),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Permalink copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else if (val == 'open_reddit') {
                    _openReddit(comment.fullPermalink);
                  } else if (val == 'delete') {
                    _confirmDelete(
                      context,
                      actions,
                      comment.id,
                      isComment: true,
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'refresh',
                    enabled: !_isEnriching(comment.id),
                    child: Row(
                      children: [
                        const Icon(Icons.sync_rounded, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          _isEnriching(comment.id)
                              ? 'Refreshing...'
                              : 'Refresh Metadata',
                        ),
                      ],
                    ),
                  ),
                  if (comment.body != null && comment.body!.isNotEmpty)
                    const PopupMenuItem(
                      value: 'copy_text',
                      child: Row(
                        children: [
                          Icon(Icons.content_copy_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Copy Text'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'copy_link',
                    child: Row(
                      children: [
                        Icon(Icons.link_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Copy Link'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'open_reddit',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_browser_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Open in Reddit'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.red,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Delete Comment',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    ItemDetailActions actions,
    String itemId, {
    bool isComment = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(isComment ? 'Delete Comment?' : 'Delete Item?'),
        content: Text(
          isComment
              ? 'This will remove the comment from your Savedex library.'
              : 'This will remove the item from your Savedex library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await actions.deleteItem(itemId);
              if (context.mounted) {
                if (itemId == widget.itemId) {
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Comment removed from saved items'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  final String? initialNote;
  final ValueChanged<String> onSave;

  const _NoteDialog({this.initialNote, required this.onSave});

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Personal Note',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Add personal notes or reminders about this post...',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () {
            widget.onSave(_controller.text);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
