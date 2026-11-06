import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/core/utils/date_formatter.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/detail/item_detail_viewmodel.dart';
import 'package:savedex/features/detail/widgets/detail_dialogs.dart';
import 'package:savedex/features/detail/widgets/detail_markdown_content.dart';
import 'package:savedex/features/detail/widgets/detail_user_note_card.dart';
import 'package:savedex/features/detail/widgets/detail_utils.dart';
import 'package:savedex/features/library/scoped_feed_view.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class DetailDiscussionHeader extends StatelessWidget {
  final SavedItem commentItem;

  const DetailDiscussionHeader({super.key, required this.commentItem});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final parentTitle = commentItem.parentPostTitle;

    if (parentTitle == null || parentTitle.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final parentId = commentItem.parentPostId;
    final threadPermalink = parentId != null && parentId.trim().isNotEmpty
        ? 'https://www.reddit.com/comments/${parentId.trim().replaceFirst('t3_', '')}'
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forum_rounded, size: 14, color: colorScheme.primary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Thread Discussion',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              if (threadPermalink != null) ...[
                const SizedBox(width: 8),
                Material(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => openRedditUrl(context, threadPermalink),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Thread',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 10.5,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Text(
            parentTitle.trim(),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
              fontSize: 18,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class DetailCommentsSection extends ConsumerWidget {
  final String threadRootId;
  final SavedItem currentItem;
  final ItemDetailActions actions;
  final String? highlightedCommentId;
  final Future<void> Function(SavedItem item) onRefresh;
  final Future<void> Function(SavedItem item)? onRecoverArchive;

  const DetailCommentsSection({
    super.key,
    required this.threadRootId,
    required this.currentItem,
    required this.actions,
    this.highlightedCommentId,
    required this.onRefresh,
    this.onRecoverArchive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isComment = currentItem.itemType == ItemType.comment;
    final allComments = ref.watch(
      relatedThreadProvider(threadRootId)
          .select((a) => a.asData?.value.comments ?? const <SavedItem>[]),
    );
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
                            color: colorScheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${relevantComments.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
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
          (comment) => DetailCommentCard(
            key: ValueKey(comment.id),
            comment: comment,
            actions: actions,
            isHighlighted: comment.id == highlightedCommentId,
            onRefresh: () => onRefresh(comment),
            onRecoverArchive: onRecoverArchive != null
                ? () => onRecoverArchive!(comment)
                : null,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class DetailCommentCard extends StatelessWidget {
  final SavedItem comment;
  final ItemDetailActions actions;
  final bool isHighlighted;
  final VoidCallback onRefresh;
  final VoidCallback? onRecoverArchive;

  const DetailCommentCard({
    super.key,
    required this.comment,
    required this.actions,
    this.isHighlighted = false,
    required this.onRefresh,
    this.onRecoverArchive,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isHighlighted
            ? colorScheme.primaryContainer.withValues(alpha: 0.15)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 0.8,
          ),
          left: isHighlighted
              ? BorderSide(color: colorScheme.primary, width: 3.5)
              : BorderSide.none,
        ),
      ),
      padding: EdgeInsets.fromLTRB(isHighlighted ? 12.5 : 16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap:
                    (comment.author != null &&
                        comment.author!.isNotEmpty &&
                        comment.author != '[deleted]')
                    ? () => ScopedFeedView.openAuthor(context, comment.author!)
                    : null,
                child: Text(
                  comment.author != null
                      ? 'u/${comment.author}'
                      : 'u/[deleted]',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
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
              if (comment.isArchiveRecovered) ...[
                const SizedBox(width: 6),
                Text(
                  '•',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.outlineVariant,
                  ),
                ),
                const SizedBox(width: 6),
                const ArchiveRecoveredBadge(
                  variant: ArchiveBadgeVariant.comment,
                ),
              ],
            ],
          ),
          if (comment.body != null && comment.body!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            DetailMarkdownContent(data: comment.body!.trim(), isComment: true),
          ],
          Consumer(
            builder: (context, ref, _) {
              final note = ref.watch(
                itemNoteProvider((
                  id: comment.id,
                  initialNote: comment.userNote,
                )),
              );
              if (note == null || note.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DetailUserNoteCard(
                  note: note.trim(),
                  onTap: () =>
                      showEditNoteDialog(context, actions, comment.id, note),
                  onDelete: () {
                    actions.updateNote(comment.id, null);
                    showNoteSnackBar(
                      context,
                      message: 'Note removed',
                      onUndo: () => actions.updateNote(comment.id, note),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final colsAsync = ref.watch(
                    itemCollectionsProvider(comment.id),
                  );
                  final cols = colsAsync.asData?.value ?? comment.collections;
                  final hasCollections = cols.isNotEmpty;
                  final hasScore = comment.score > 0;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasScore)
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
                      if (hasScore && hasCollections) ...[
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (hasCollections)
                        CollectionBadgeRow(
                          itemId: comment.id,
                          initialCollections: comment.collections,
                          leadingSpacing: false,
                        ),
                    ],
                  );
                },
              ),
              const Spacer(),
              ItemNoteButton(
                itemId: comment.id,
                initialNote: comment.userNote,
                onEditNote: (currentNote) => showEditNoteDialog(
                  context,
                  actions,
                  comment.id,
                  currentNote,
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
              const SizedBox(width: 2),
              Consumer(
                builder: (context, ref, _) {
                  final isEnriching = ref.watch(
                    enrichingItemsProvider.select(
                      (s) => s.contains(comment.id),
                    ),
                  );
                  return PopupMenuButton<String>(
                    tooltip: 'More options',
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    icon: isEnriching
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
                      if (val == 'recover_archive') {
                        if (onRecoverArchive != null) {
                          onRecoverArchive!();
                        } else {
                          actions.recoverFromArchive(comment, force: true);
                        }
                      } else if (val == 'refresh') {
                        onRefresh();
                      } else if (val == 'copy_text') {
                        if (comment.body != null &&
                            comment.body!.trim().isNotEmpty) {
                          Clipboard.setData(
                            ClipboardData(text: comment.body!.trim()),
                          );
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Comment text copied to clipboard',
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                        }
                      } else if (val == 'copy_link') {
                        Clipboard.setData(
                          ClipboardData(text: comment.fullPermalink),
                        );
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Permalink copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                      } else if (val == 'open_reddit') {
                        openRedditUrl(context, comment.fullPermalink);
                      } else if (val == 'collections') {
                        showCollectionPickerSheet(context, comment.id);
                      } else if (val == 'delete') {
                        showConfirmDeleteDialog(
                          context,
                          actions,
                          comment.id,
                          isComment: true,
                        );
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (comment.canAttemptArchiveRecovery)
                        PopupMenuItem(
                          value: 'recover_archive',
                          enabled: !isEnriching,
                          child: const Row(
                            children: [
                              Icon(Icons.archive_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Try Archive Recovery'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'refresh',
                        enabled: !isEnriching,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: isEnriching
                              ? null
                              : () => Navigator.of(ctx).pop('recover_archive'),
                          child: Row(
                            children: [
                              const Icon(Icons.sync_rounded, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                isEnriching
                                    ? 'Refreshing...'
                                    : 'Refresh Metadata',
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (comment.body != null &&
                          comment.body!.trim().isNotEmpty)
                        const PopupMenuItem(
                          value: 'copy_text',
                          child: Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 18),
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
                      PopupMenuItem(
                        value: 'open_reddit',
                        child: Row(
                          children: [
                            RedditIcon(
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            const Text('Open in Reddit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'collections',
                        child: Row(
                          children: [
                            Icon(Icons.collections_bookmark_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Manage Collections'),
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
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
