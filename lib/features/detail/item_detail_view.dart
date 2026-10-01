import 'package:extended_image/extended_image.dart' hide MediaType;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/utils/date_formatter.dart';
import 'package:savedex/features/detail/item_detail_viewmodel.dart';
import 'package:url_launcher/url_launcher.dart';

class ItemDetailView extends ConsumerStatefulWidget {
  final String itemId;

  const ItemDetailView({super.key, required this.itemId});

  @override
  ConsumerState<ItemDetailView> createState() => _ItemDetailViewState();
}

class _ItemDetailViewState extends ConsumerState<ItemDetailView> {
  bool _isEnriching = false;

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemDetailProvider(widget.itemId));
    final actions = ref.read(itemDetailActionsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return itemAsync.when(
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Item not found')),
          );
        }

        final isComment = item.itemType == ItemType.comment;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 2,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.7,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.reddit, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'r/${item.subreddit}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton.filledTonal(
                icon: Icon(
                  item.isStarred
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: item.isStarred ? Colors.amber : null,
                  size: 20,
                ),
                tooltip: item.isStarred ? 'Starred' : 'Star',
                onPressed: () => actions.toggleStar(item),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                icon: _isEnriching
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : const Icon(Icons.sync_rounded, size: 20),
                tooltip: 'Refresh metadata',
                onPressed: _isEnriching
                    ? null
                    : () async {
                        setState(() => _isEnriching = true);
                        try {
                          final result = await actions.reEnrich(item);
                          if (!context.mounted) return;
                          if (result.success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Metadata refreshed successfully',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.error ?? 'Failed to refresh metadata',
                                ),
                                backgroundColor: colorScheme.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: colorScheme.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _isEnriching = false);
                          }
                        }
                      },
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert_rounded, size: 18),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (val) {
                  if (val == 'open_reddit') {
                    _openReddit(item.permalink);
                  } else if (val == 'copy_link') {
                    Clipboard.setData(ClipboardData(text: item.permalink));
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
              const SizedBox(width: 12),
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
                      onPressed: () => _openReddit(item.permalink),
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
                      Clipboard.setData(ClipboardData(text: item.permalink));
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // badge row
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // post/commnet
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
                        // Time Ago
                        if (item.createdAtUtc != null)
                          Text(
                            '• ${DateFormatter.timeAgo(item.createdAtUtc)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Text(
                      item.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (item.author != null && item.author!.isNotEmpty)
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
                                  Icons.person_outline_rounded,
                                  size: 14,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'u/${item.author}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                        if (!isComment && item.numComments > 0)
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
                    ),

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
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // note
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.sticky_note_2_outlined,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Personal Note',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: Icon(
                            item.userNote != null && item.userNote!.isNotEmpty
                                ? Icons.edit_outlined
                                : Icons.add_rounded,
                            size: 16,
                          ),
                          label: Text(
                            item.userNote != null && item.userNote!.isNotEmpty
                                ? 'Edit'
                                : 'Add Note',
                          ),
                          onPressed: () => _editNoteDialog(
                            context,
                            actions,
                            item.id,
                            item.userNote,
                          ),
                        ),
                      ],
                    ),
                    if (item.userNote != null && item.userNote!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.userNote!,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'No personal notes added yet.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
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

  void _openReddit(String permalink) async {
    final uri = Uri.parse(permalink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
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

  void _confirmDelete(
    BuildContext context,
    ItemDetailActions actions,
    String itemId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Item?'),
        content: const Text(
          'This will remove the item from your Savedex library.',
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
                Navigator.of(context).pop();
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
