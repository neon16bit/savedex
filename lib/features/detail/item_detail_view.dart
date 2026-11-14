import 'package:material_ui/material_ui.dart';
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
import 'package:savedex/features/library/scoped_feed_view.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class ItemDetailView extends ConsumerStatefulWidget {
  final String itemId;
  final int initialMediaIndex;

  const ItemDetailView({
    super.key,
    required this.itemId,
    this.initialMediaIndex = 0,
  });

  @override
  ConsumerState<ItemDetailView> createState() => _ItemDetailViewState();
}

class _ItemDetailViewState extends ConsumerState<ItemDetailView> {
  late int _mediaIndex;

  @override
  void initState() {
    super.initState();
    _mediaIndex = widget.initialMediaIndex;
  }

  Future<void> _refreshMetadata(
    ItemDetailActions actions,
    SavedItem item,
  ) async {
    final notifier = ref.read(enrichingItemsProvider.notifier);
    if (notifier.isEnriching(item.id)) return;
    if (item.isArchiveRecovered) {
      final confirmed = await showArchiveRefreshWarningDialog(context);
      if (!confirmed || !mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);

    notifier.add(item.id);
    showAppSnackBarOnMessenger(
      messenger,
      message: 'Refreshing metadata...',
      duration: const Duration(seconds: 1),
    );
    try {
      final result = await actions.reEnrich(item);
      if (!messenger.mounted) return;
      if (result.success) {
        showAppSnackBarOnMessenger(
          messenger,
          message: 'Metadata refreshed successfully',
          duration: const Duration(seconds: 2),
        );
      } else {
        showAppSnackBarOnMessenger(
          messenger,
          message: result.error?.isNotEmpty == true
              ? result.error!
              : 'Failed to refresh metadata',
          isError: true,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (!messenger.mounted) return;
      showAppSnackBarOnMessenger(
        messenger,
        message: 'Error: $e',
        isError: true,
        duration: const Duration(seconds: 3),
      );
    } finally {
      notifier.remove(item.id);
    }
  }

  Future<void> _recoverFromArchive(
    ItemDetailActions actions,
    SavedItem item,
  ) async {
    final notifier = ref.read(enrichingItemsProvider.notifier);
    if (notifier.isEnriching(item.id)) return;
    final messenger = ScaffoldMessenger.of(context);

    notifier.add(item.id);
    showAppSnackBarOnMessenger(
      messenger,
      message: 'Trying archive recovery...',
      duration: const Duration(seconds: 1),
    );
    try {
      final result = await actions.recoverFromArchive(item, force: true);
      if (!messenger.mounted) return;
      showAppSnackBarOnMessenger(
        messenger,
        message: result.success
            ? 'Recovered metadata from archive'
            : (result.error?.isNotEmpty == true
                  ? result.error!
                  : 'Archive recovery failed'),
        isError: !result.success,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      if (!messenger.mounted) return;
      showAppSnackBarOnMessenger(
        messenger,
        message: 'Error: $e',
        isError: true,
        duration: const Duration(seconds: 3),
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
        final enableFrosted = watchFrostedEffects(ref);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            Navigator.of(context).pop(_mediaIndex);
          },
          child: Scaffold(
            extendBodyBehindAppBar: enableFrosted,
            extendBody: true,
            appBar: AppBar(
              leading: BackButton(
                onPressed: () => Navigator.of(context).pop(_mediaIndex),
              ),
              backgroundColor: enableFrosted ? Colors.transparent : null,
              elevation: 0,
              scrolledUnderElevation: enableFrosted ? 0 : 2,
              surfaceTintColor: enableFrosted ? Colors.transparent : null,
              flexibleSpace: FrostedAppBarBackground(enableBlur: enableFrosted),
              titleSpacing: 0,
              title: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    ScopedFeedView.openSubreddit(context, item.subreddit),
                child: Text(
                  item.displaySubreddit,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    item.isStarred
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: item.isStarred ? colorScheme.primary : null,
                  ),
                  tooltip: item.isStarred ? 'Starred' : 'Star',
                  onPressed: () => actions.toggleStar(item),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final isEnriching = ref.watch(
                      enrichingItemsProvider.select((s) => s.contains(item.id)),
                    );

                    return FrostedPopupMenuButton<String>(
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
                          _refreshMetadata(actions, item);
                        } else if (val == 'recover_archive') {
                          _recoverFromArchive(actions, item);
                        } else if (val == 'copy_text') {
                          if (item.body != null &&
                              item.body!.trim().isNotEmpty) {
                            Clipboard.setData(
                              ClipboardData(text: item.body!.trim()),
                            );
                            showAppSnackBar(
                              context,
                              item.isComment
                                  ? 'Comment text copied to clipboard'
                                  : 'Post text copied to clipboard',
                            );
                          }
                        } else if (val == 'open_reddit') {
                          openRedditUrl(context, item.fullPermalink);
                        } else if (val == 'copy_link') {
                          Clipboard.setData(
                            ClipboardData(text: item.fullPermalink),
                          );
                          showAppSnackBar(
                            context,
                            'Permalink copied to clipboard',
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
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: isEnriching
                                ? null
                                : () =>
                                      Navigator.of(ctx).pop('recover_archive'),
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
                              Icon(
                                Icons.collections_bookmark_outlined,
                                size: 18,
                              ),
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
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                item.isComment
                                    ? 'Delete Comment'
                                    : 'Delete Item',
                                style: TextStyle(color: colorScheme.error),
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
            body: Builder(
              builder: (bodyContext) {
                final bodyPadding = MediaQuery.paddingOf(bodyContext);
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    bodyPadding.top + 8,
                    0,
                    bodyPadding.bottom + 32,
                  ),
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
                                isArchiveRecovered: item.isArchiveRecovered,
                                collections: cols,
                                onCollectionTap: (_) =>
                                    showCollectionPickerSheet(context, item.id),
                              );
                            },
                          ),
                          if (item.author != null &&
                              item.author!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: item.author != '[deleted]'
                                      ? () => ScopedFeedView.openAuthor(
                                          context,
                                          item.author!,
                                        )
                                      : null,
                                  child: Text(
                                    'u/${item.author}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface,
                                    ),
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
                          if (item.isCrosspost) ...[
                            const SizedBox(height: 12),
                            DetailCrosspostOriginCard(item: item),
                          ],
                        ],
                      ),
                    ),
                    DetailMediaView(
                      item: item,
                      initialIndex: _mediaIndex,
                      onIndexChanged: (idx) => _mediaIndex = idx,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.body != null &&
                              item.body!.trim().isNotEmpty) ...[
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
                                      onUndo: () =>
                                          actions.updateNote(item.id, note),
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
                          _refreshMetadata(actions, comment),
                      onRecoverArchive: (comment) =>
                          _recoverFromArchive(actions, comment),
                    ),
                  ],
                );
              },
            ),
            bottomNavigationBar: DetailBottomBar(
              item: item,
              onOpenReddit: () => openRedditUrl(context, item.fullPermalink),
            ),
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

class DetailCrosspostOriginCard extends StatelessWidget {
  final SavedItem item;

  const DetailCrosspostOriginCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final permalink = item.originalPostPermalink;
    final originSub = item.crosspostSubreddit;
    final origTitle = item.originalPostTitle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.repeat_rounded, size: 14, color: colorScheme.primary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  originSub != null
                      ? 'Crossposted from $originSub'
                      : 'Crossposted',
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
              if (permalink != null) ...[
                const SizedBox(width: 8),
                Material(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => openRedditUrl(context, permalink),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Original',
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
          if (origTitle != null && origTitle.trim().isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.reply_rounded,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    origTitle.trim(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
