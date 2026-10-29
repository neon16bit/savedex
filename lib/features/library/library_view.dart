import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/data/models/subreddit_info.dart';
import 'package:savedex/features/library/library_viewmodel.dart';
import 'package:savedex/features/library/scoped_feed_view.dart';
import 'package:savedex/features/shell/app_shell.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class LibraryView extends ConsumerStatefulWidget {
  const LibraryView({super.key});

  @override
  ConsumerState<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends ConsumerState<LibraryView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _subredditSearchController =
      TextEditingController();
  final FocusNode _subredditSearchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
        ref
            .read(librarySubTabProvider.notifier)
            .setSubTab(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subredditSearchController.dispose();
    _subredditSearchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _deleteCollection(BuildContext context, Collection col) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${col.name}"?'),
        content: const Text(
          'This collection will be deleted. None of your saved posts or comments will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(collectionRepositoryProvider).deleteCollection(col.id);
      ref.read(itemCollectionsOverrideProvider.notifier).clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Deleted collection "${col.name}"'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(subredditSearchFocusTriggerProvider, (prev, next) {
      if (_tabController.index != 1) {
        _tabController.animateTo(1);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _subredditSearchFocusNode.requestFocus();
        }
      });
    });

    final collectionsAsync = ref.watch(sortedCollectionsProvider);
    final subredditsAsync = ref.watch(filteredSubredditsProvider);

    final collectionCount = collectionsAsync.asData?.value.length ?? 0;
    final subredditCount =
        ref.watch(rawSubredditsWithCountsProvider).asData?.value.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Library',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmark_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Collections ($collectionCount)'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tag_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Subreddits ($subredditCount)'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCollectionsTab(context, collectionsAsync),
          _buildSubredditsTab(context, subredditsAsync),
        ],
      ),
    );
  }

  Widget _buildCollectionsTab(
    BuildContext context,
    AsyncValue<List<Collection>> collectionsAsync,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return collectionsAsync.when(
      data: (collections) {
        if (collections.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.35,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.folder_open_rounded,
                      size: 52,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Collections Yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create custom collections to categorize and group your favorite Reddit posts and comments.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => showCollectionFormDialog(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create Collection'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 104),
          itemCount: collections.length,
          separatorBuilder: (context, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final col = collections[index];
            final colColor = Color(col.colorValue);

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              color: colorScheme.surfaceContainerLowest,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) =>
                          ScopedFeedView(args: ScopedFeedArgs.collection(col)),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colColor.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          Icons.bookmark_rounded,
                          color: colColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              col.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (col.description != null &&
                                col.description!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                col.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                '${col.itemCount} ${col.itemCount == 1 ? 'saved item' : 'saved items'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded),
                        tooltip: 'Collection options',
                        onSelected: (val) {
                          if (val == 'edit') {
                            showCollectionFormDialog(
                              context,
                              initialCollection: col,
                            );
                          } else if (val == 'delete') {
                            _deleteCollection(context, col);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_note_rounded, size: 20),
                                SizedBox(width: 10),
                                Text('Edit Collection'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: colorScheme.error,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Delete Collection',
                                  style: TextStyle(color: colorScheme.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading collections: $err')),
    );
  }

  String _getSubredditInitial(String name) {
    final clean = name.replaceFirst(RegExp(r'^[ru][/_-]'), '').trim();
    if (clean.isEmpty) return 'R';
    return clean[0].toUpperCase();
  }

  Widget _buildSubredditPlaceholder(
    ColorScheme colorScheme,
    bool isUser,
    String subName,
  ) {
    if (isUser) {
      return Icon(
        Icons.person_rounded,
        color: colorScheme.onSecondaryContainer,
        size: 20,
      );
    }
    return Center(
      child: Text(
        _getSubredditInitial(subName),
        style: TextStyle(
          fontSize: 16.5,
          fontWeight: FontWeight.w800,
          color: colorScheme.primary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildSubredditsTab(
    BuildContext context,
    AsyncValue<List<SubredditInfo>> subredditsAsync,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentSort = ref.watch(subredditSortOptionProvider);
    final sortNotifier = ref.read(subredditSortOptionProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: TextField(
            controller: _subredditSearchController,
            focusNode: _subredditSearchFocusNode,
            onChanged: (val) {
              ref.read(subredditSearchQueryProvider.notifier).setQuery(val);
            },
            decoration: InputDecoration(
              hintText: 'Search saved subreddits...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _subredditSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _subredditSearchController.clear();
                        ref.read(subredditSearchQueryProvider.notifier).clear();
                      },
                    )
                  : null,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: SubredditSortOption.values.map((sortOpt) {
              final isSelected = currentSort == sortOpt;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(sortOpt.label),
                  selected: isSelected,
                  onSelected: (_) => sortNotifier.setSort(sortOpt),
                ),
              );
            }).toList(),
          ),
        ),

        const Divider(height: 1),

        Expanded(
          child: subredditsAsync.when(
            data: (subreddits) {
              if (subreddits.isEmpty) {
                final query = ref.watch(subredditSearchQueryProvider);
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          query.isNotEmpty
                              ? 'No subreddits matching "$query"'
                              : 'No saved subreddits found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (query.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () {
                              _subredditSearchController.clear();
                              ref
                                  .read(subredditSearchQueryProvider.notifier)
                                  .clear();
                            },
                            child: const Text('Clear Search'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 104),
                itemCount: subreddits.length,
                separatorBuilder: (context, _) => Divider(
                  height: 1,
                  indent: 68,
                  endIndent: 14,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                itemBuilder: (context, index) {
                  final item = subreddits[index];
                  final subName = item.$1;
                  final count = item.$2;
                  final isUser = SavedItem.isUserSubreddit(subName);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isUser
                            ? colorScheme.secondaryContainer
                            : colorScheme.primaryContainer.withValues(
                                alpha: 0.5,
                              ),
                        shape: BoxShape.circle,
                      ),
                      child: item.iconUrl != null && item.iconUrl!.isNotEmpty
                          ? ExtendedImage.network(
                              item.iconUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              shape: BoxShape.circle,
                              cache: true,
                              loadStateChanged: (state) {
                                if (state.extendedImageLoadState ==
                                    LoadState.completed) {
                                  return null;
                                }
                                return _buildSubredditPlaceholder(
                                  colorScheme,
                                  isUser,
                                  subName,
                                );
                              },
                            )
                          : _buildSubredditPlaceholder(
                              colorScheme,
                              isUser,
                              subName,
                            ),
                    ),
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            SavedItem.formatSubreddit(subName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (item.isNsfw) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'NSFW',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            '$count saved',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => ScopedFeedView(
                            args: ScopedFeedArgs.subreddit(subName),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) =>
                Center(child: Text('Error loading subreddits: $err')),
          ),
        ),
      ],
    );
  }
}
