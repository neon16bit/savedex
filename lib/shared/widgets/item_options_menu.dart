import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/detail/item_detail_viewmodel.dart';
import 'package:savedex/features/detail/widgets/detail_dialogs.dart';
import 'package:savedex/features/detail/widgets/detail_utils.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';
import 'package:savedex/shared/widgets/collection_picker_sheet.dart';
import 'package:savedex/shared/widgets/item_reddit_button.dart';

class ItemOptionsMenu extends ConsumerWidget {
  final SavedItem item;

  const ItemOptionsMenu({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnriching = ref.watch(
      enrichingItemsProvider.select((s) => s.contains(item.id)),
    );

    return PopupMenuButton<String>(
      tooltip: 'More options',
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              size: 22,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
      onSelected: (val) async {
        if (val == 'refresh') {
          final notifier = ref.read(enrichingItemsProvider.notifier);
          if (notifier.isEnriching(item.id)) return;
          notifier.add(item.id);
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content: Text('Refreshing metadata...'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 1),
              ),
            );
          try {
            final result = await ref
                .read(enrichmentViewModelProvider.notifier)
                .enrichSingleItem(item);
            if (context.mounted) {
              if (result.success) {
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Metadata refreshed successfully'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
              } else {
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        result.error ?? 'Failed to refresh metadata',
                      ),
                      backgroundColor: colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
              }
            }
          } finally {
            notifier.remove(item.id);
          }
        } else if (val == 'copy_link') {
          Clipboard.setData(ClipboardData(text: item.fullPermalink));
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content: Text('Permalink copied to clipboard'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
        } else if (val == 'copy_text') {
          if (item.body != null && item.body!.trim().isNotEmpty) {
            Clipboard.setData(ClipboardData(text: item.body!.trim()));
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    item.isComment
                        ? 'Comment text copied to clipboard'
                        : 'Post text copied to clipboard',
                  ),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
          }
        } else if (val == 'open_reddit') {
          openRedditUrl(context, item.fullPermalink);
        } else if (val == 'collections') {
          showCollectionPickerSheet(context, item.id);
        } else if (val == 'delete') {
          showConfirmDeleteDialog(
            context,
            null,
            null,
            onConfirmDelete: () =>
                ref.read(savedViewModelProvider.notifier).deleteItem(item),
            isComment: item.isComment,
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
              Text(isEnriching ? 'Refreshing...' : 'Refresh Metadata'),
            ],
          ),
        ),
        if (item.body != null && item.body!.trim().isNotEmpty)
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
        PopupMenuItem(
          value: 'open_reddit',
          child: Row(
            children: [
              RedditIcon(size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              const Text('Open in Reddit'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy_link',
          child: Row(
            children: [
              Icon(Icons.link_rounded, size: 18),
              SizedBox(width: 10),
              Text('Copy Permalink'),
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
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: colorScheme.error,
              ),
              const SizedBox(width: 10),
              Text(
                item.isComment ? 'Delete Comment' : 'Delete Item',
                style: TextStyle(color: colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
