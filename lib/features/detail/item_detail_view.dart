import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
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
import 'package:savedex/shared/widgets/widgets.dart';

class ItemDetailView extends ConsumerStatefulWidget {
  final String itemId;

  const ItemDetailView({super.key, required this.itemId});

  @override
  ConsumerState<ItemDetailView> createState() => _ItemDetailViewState();
}

class _ItemDetailViewState extends ConsumerState<ItemDetailView> {
  Future<void> _refreshMetadata(
    ItemDetailActions actions,
    SavedItem item,
    ColorScheme colorScheme,
  ) async {
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
      final result = await actions.reEnrich(item);
      if (!mounted) return;
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
              content: Text(result.error ?? 'Failed to refresh metadata'),
              backgroundColor: colorScheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    } finally {
      notifier.remove(item.id);
    }
  }

  Future<void> _recoverFromArchive(
    ItemDetailActions actions,
    SavedItem item,
    ColorScheme colorScheme,
  ) async {
    final notifier = ref.read(enrichingItemsProvider.notifier);
    if (notifier.isEnriching(item.id)) return;
    notifier.add(item.id);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Trying archive recovery...'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    try {
      final result = await actions.recoverFromArchive(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Recovered metadata from archive'
                  : (result.error ?? 'Archive recovery failed'),
            ),
            backgroundColor: result.success ? null : colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    } finally {
      notifier.remove(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemDetailProvider(widget.itemId));
    final actions = ref.read(itemDetailActionsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return itemAsync.when(
      skipLoadingOnReload: true,
      data: (rawItem) {
        if (rawItem == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Item not found')),
          );
        }

        final threadLoading = rawItem.itemType == ItemType.comment
            ? ref.watch(
                relatedThreadProvider(widget.itemId)
                    .select((a) => !a.hasValue && a.isLoading),
              )
            : false;

        if (threadLoading) {
          return Scaffold(
            appBar: AppBar(
              titleSpacing: 0,
              title: Text(rawItem.displaySubreddit),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final parentPost = rawItem.itemType == ItemType.comment
            ? ref.watch(
                relatedThreadProvider(widget.itemId)
                    .select((a) => a.asData?.value.parentPost),
              )
            : null;
        final item = parentPost ?? rawItem;
        final isComment = item.itemType == ItemType.comment;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 2,
            titleSpacing: 0,
            title: Text(
              item.displaySubreddit,
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
              Consumer(
                builder: (context, ref, _) {
                  final isEnriching = ref.watch(
                    enrichingItemsProvider.select((s) => s.contains(item.id)),
                  );

                  return PopupMenuButton<String>(
                    icon: isEnriching
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
                      } else if (val == 'recover_archive') {
                        _recoverFromArchive(actions, item, colorScheme);
                      } else if (val == 'copy_text') {
                        if (item.body != null && item.body!.trim().isNotEmpty) {
                          Clipboard.setData(
                            ClipboardData(text: item.body!.trim()),
                          );
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
                      } else if (val == 'copy_link') {
                        Clipboard.setData(
                          ClipboardData(text: item.fullPermalink),
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
                      } else if (val == 'collections') {
                        showCollectionPickerSheet(context, item.id);
                      } else if (val == 'delete') {
                        showConfirmDeleteDialog(
                          context,
                          actions,
                          item.id,
                          isComment: item.isComment,
                          onDeletedSelf: () => Navigator.of(context).pop(),
                        );
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (item.canAttemptArchiveRecovery)
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
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              item.isComment ? 'Delete Comment' : 'Delete Item',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
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
                    if (!isComment ||
                        item.parentPostTitle == null ||
                        item.parentPostTitle!.isEmpty) ...[
                      Text(
                        item.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Consumer(
                      builder: (context, ref, _) {
                        final colsAsync = ref.watch(
                          itemCollectionsProvider(item.id),
                        );
                        final cols =
                            colsAsync.asData?.value ?? item.collections;
                        return DetailBadgeRow(
                          isComment: isComment,
                          isNsfw: item.isNsfw,
                          postFlair: item.postFlair,
                          collections: cols,
                          onCollectionTap: (_) =>
                              showCollectionPickerSheet(context, item.id),
                        );
                      },
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
                    if (item.body != null && item.body!.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      DetailMarkdownContent(data: item.body!.trim()),
                    ],
                    Consumer(
                      builder: (context, ref, _) {
                        final note = ref.watch(
                          itemNoteProvider((
                            id: item.id,
                            initialNote: item.userNote,
                          )),
                        );
                        if (note == null || note.trim().isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: DetailUserNoteCard(
                            note: note.trim(),
                            onTap: () => showEditNoteDialog(
                              context,
                              actions,
                              item.id,
                              note,
                            ),
                            onDelete: () {
                              actions.updateNote(item.id, null);
                              showNoteSnackBar(
                                context,
                                message: 'Note removed',
                                onUndo: () => actions.updateNote(item.id, note),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        DetailScoreChip(score: item.score),
                        if (!isComment && item.numComments > 0) ...[
                          const SizedBox(width: 8),
                          DetailCommentsChip(count: item.numComments),
                        ],
                        const Spacer(),
                        ItemNoteButton(
                          itemId: item.id,
                          initialNote: item.userNote,
                          showLabel: true,
                          onEditNote: (currentNote) => showEditNoteDialog(
                            context,
                            actions,
                            item.id,
                            currentNote,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              DetailCommentsSection(
                threadRootId: widget.itemId,
                currentItem: item,
                actions: actions,
                highlightedCommentId: widget.itemId != item.id
                    ? widget.itemId
                    : null,
                onRefresh: (comment) =>
                    _refreshMetadata(actions, comment, colorScheme),
                onRecoverArchive: (comment) =>
                    _recoverFromArchive(actions, comment, colorScheme),
              ),
            ],
          ),
          bottomNavigationBar: DetailBottomBar(
            item: item,
            onOpenReddit: () => openRedditUrl(context, item.fullPermalink),
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
