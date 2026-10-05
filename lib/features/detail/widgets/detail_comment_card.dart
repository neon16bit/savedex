import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/utils/date_formatter.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/detail/item_detail_viewmodel.dart';
import 'package:savedex/features/detail/widgets/detail_dialogs.dart';
import 'package:savedex/features/detail/widgets/detail_markdown_content.dart';
import 'package:savedex/features/detail/widgets/detail_user_note_card.dart';
import 'package:savedex/features/detail/widgets/detail_utils.dart';

class DetailDiscussionHeader extends StatelessWidget {
  final SavedItem commentItem;

  const DetailDiscussionHeader({super.key, required this.commentItem});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (commentItem.parentPostTitle == null ||
        commentItem.parentPostTitle!.isEmpty) {
      return const SizedBox.shrink();
    }

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
}

class DetailCommentsSection extends ConsumerWidget {
  final String threadRootId;
  final SavedItem currentItem;
  final ItemDetailActions actions;
  final String? highlightedCommentId;
  final Future<void> Function(SavedItem item) onRefresh;

  const DetailCommentsSection({
    super.key,
    required this.threadRootId,
    required this.currentItem,
    required this.actions,
    this.highlightedCommentId,
    required this.onRefresh,
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
          (comment) => DetailCommentCard(
            key: ValueKey(comment.id),
            comment: comment,
            actions: actions,
            isHighlighted: comment.id == highlightedCommentId,
            onRefresh: () => onRefresh(comment),
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

  const DetailCommentCard({
    super.key,
    required this.comment,
    required this.actions,
    this.isHighlighted = false,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
            DetailMarkdownContent(data: comment.body!, isComment: true),
          ],
          Consumer(
            builder: (context, ref, _) {
              final note = ref.watch(
                itemNoteProvider((
                  id: comment.id,
                  initialNote: comment.userNote,
                )),
              );
              if (note == null || note.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DetailUserNoteCard(
                  note: note,
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
              Consumer(
                builder: (context, ref, _) {
                  final note = ref.watch(
                    itemNoteProvider((
                      id: comment.id,
                      initialNote: comment.userNote,
                    )),
                  );
                  final hasNote = note != null && note.isNotEmpty;
                  return IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    icon: Icon(
                      hasNote
                          ? Icons.sticky_note_2_rounded
                          : Icons.note_add_outlined,
                      color: hasNote
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    tooltip: hasNote ? 'Edit Note' : 'Add Note',
                    onPressed: () =>
                        showEditNoteDialog(context, actions, comment.id, note),
                  );
                },
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
                onPressed: () => openRedditUrl(context, comment.fullPermalink),
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
                      if (val == 'refresh') {
                        onRefresh();
                      } else if (val == 'copy_text') {
                        if (comment.body != null && comment.body!.isNotEmpty) {
                          Clipboard.setData(ClipboardData(text: comment.body!));
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
                      PopupMenuItem(
                        value: 'refresh',
                        enabled: !isEnriching,
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
