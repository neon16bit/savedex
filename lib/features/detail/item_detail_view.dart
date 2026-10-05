import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/utils/date_formatter.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/detail/item_detail_viewmodel.dart';
import 'package:savedex/features/detail/widgets/detail_badges.dart';
import 'package:savedex/features/detail/widgets/detail_bottom_bar.dart';
import 'package:savedex/features/detail/widgets/detail_comment_card.dart';
import 'package:savedex/features/detail/widgets/detail_dialogs.dart';
import 'package:savedex/features/detail/widgets/detail_markdown_content.dart';
import 'package:savedex/features/detail/widgets/detail_media_view.dart';
import 'package:savedex/features/detail/widgets/detail_user_note_card.dart';
import 'package:savedex/features/detail/widgets/detail_utils.dart';

class ItemDetailView extends ConsumerStatefulWidget {
  final String itemId;

  const ItemDetailView({super.key, required this.itemId});

  @override
  ConsumerState<ItemDetailView> createState() => _ItemDetailViewState();
}

class _ItemDetailViewState extends ConsumerState<ItemDetailView> {
  final Set<String> _enrichingIds = {};
  bool _isEnriching(String id) => _enrichingIds.contains(id);

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
                    openRedditUrl(context, item.fullPermalink);
                  } else if (val == 'copy_link') {
                    Clipboard.setData(ClipboardData(text: item.fullPermalink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Permalink copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else if (val == 'delete') {
                    showConfirmDeleteDialog(
                      context,
                      actions,
                      item.id,
                      onDeletedSelf: () => Navigator.of(context).pop(),
                    );
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
          bottomNavigationBar: DetailBottomBar(
            item: item,
            onOpenReddit: () => openRedditUrl(context, item.fullPermalink),
            onEditNote: () =>
                showEditNoteDialog(context, actions, item.id, item.userNote),
          ),
          body: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              if (isComment) ...[
                DetailDiscussionHeader(commentItem: item),
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
                    DetailBadgeRow(
                      isComment: isComment,
                      isNsfw: item.isNsfw,
                      postFlair: item.postFlair,
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
                    DetailMediaView(item: item),
                    if (item.body != null && item.body!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      DetailMarkdownContent(data: item.body!),
                    ],
                    if (item.userNote != null && item.userNote!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      DetailUserNoteCard(
                        note: item.userNote!,
                        onTap: () => showEditNoteDialog(
                          context,
                          actions,
                          item.id,
                          item.userNote,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        DetailScoreChip(score: item.score),
                        if (!isComment && item.numComments > 0) ...[
                          const SizedBox(width: 8),
                          DetailCommentsChip(count: item.numComments),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              DetailCommentsSection(
                currentItem: item,
                allComments: threadAsync.asData?.value.comments ?? const [],
                actions: actions,
                highlightedCommentId: widget.itemId != item.id
                    ? widget.itemId
                    : null,
                isEnriching: _isEnriching,
                onRefresh: (comment) =>
                    _refreshMetadata(actions, comment, colorScheme),
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
}
