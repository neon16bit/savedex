import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/utils/date_formatter.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/detail/item_detail_view.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';

class GroupedCommentsCard extends ConsumerWidget {
  final GroupedCommentsFeedEntry group;

  const GroupedCommentsCard({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'r/${group.subreddit}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${group.comments.length} SAVED COMMENTS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              group.parentTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),

            // list of individual comments
            ...group.comments.map(
              (comment) => _buildCommentItem(context, comment, colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(
    BuildContext context,
    SavedItem comment,
    ColorScheme colorScheme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: colorScheme.primary, width: 3)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => ItemDetailView(itemId: comment.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (comment.author != null)
                  Text(
                    'u/${comment.author}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                const Spacer(),
                if (comment.createdAtUtc != null)
                  Text(
                    DateFormatter.timeAgo(comment.createdAtUtc),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (comment.body != null) ...[
              const SizedBox(height: 4),
              Text(
                comment.body!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
