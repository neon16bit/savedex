import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/import_export/import_view.dart';
import 'package:savedex/features/import_export/import_viewmodel.dart';
import 'package:savedex/features/import_export/widgets/import_export_progress_card.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';
import 'package:savedex/features/saved/widgets/comment_card.dart';
import 'package:savedex/features/saved/widgets/compact_list_item.dart';
import 'package:savedex/features/saved/widgets/gallery_item.dart';
import 'package:savedex/features/saved/widgets/post_card.dart';
import 'package:savedex/features/search/search_viewmodel.dart';
import 'package:savedex/features/search/widgets/filter_sheet.dart';
import 'package:savedex/features/search/widgets/sort_sheet.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';

typedef FeedView = SavedView;

class SavedView extends ConsumerStatefulWidget {
  const SavedView({super.key});

  @override
  ConsumerState<SavedView> createState() => _SavedViewState();
}

class _SavedViewState extends ConsumerState<SavedView> {
  bool _isSearchExpanded = false;
  late final TextEditingController _searchController;
  Timer? _searchDebounceTimer;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final initialQuery =
        ref.read(searchFilterViewModelProvider).searchQuery ?? '';
    _searchController = TextEditingController(text: initialQuery);
    if (initialQuery.isNotEmpty) {
      _isSearchExpanded = true;
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatSyncMessage(ImportSummary summary) {
    final totalInDb = summary.totalInDatabase;
    final dbSuffix = totalInDb != null ? ' ($totalInDb in library)' : '';
    if (summary.newItemsImported > 0 && summary.updatedItems > 0) {
      return 'Reddit sync: ${summary.newItemsImported} new, ${summary.updatedItems} updated$dbSuffix';
    } else if (summary.newItemsImported > 0) {
      return 'Reddit sync: ${summary.newItemsImported} new items added$dbSuffix';
    } else if (summary.updatedItems > 0) {
      return 'Reddit sync: ${summary.updatedItems} items refreshed$dbSuffix';
    } else {
      return 'Library is up to date$dbSuffix';
    }
  }

  Future<ImportSummary?> _syncFromReddit({
    bool showErrorSnackbar = true,
  }) async {
    final summary = await ref
        .read(importExportViewModelProvider.notifier)
        .pullSavedFromReddit();
    if (!mounted) return summary;

    if (summary != null) {
      final message = _formatSyncMessage(summary);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    } else if (showErrorSnackbar) {
      final error =
          ref.read(importExportViewModelProvider).errorMessage ??
          'Sync from Reddit failed';
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    }
    return summary;
  }

  @override
  Widget build(BuildContext context) {
    final feedStateAsync = ref.watch(savedFeedPaginationProvider);

    // fetch next page only when items change
    ref.listen(savedFeedPaginationProvider, (prev, next) {
      final feedState = next.value;
      if (feedState == null ||
          !feedState.hasMore ||
          feedState.isLoadingMore ||
          feedState.paginationError != null) {
        return;
      }

      final prevLength = prev?.value?.items.length ?? 0;
      if (feedState.items.isNotEmpty && feedState.items.length != prevLength) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scrollController.hasClients &&
              _scrollController.positions.length == 1 &&
              _scrollController.position.maxScrollExtent == 0) {
            ref.read(savedFeedPaginationProvider.notifier).fetchNextPage();
          }
        });
      }
    });

    // reset scroll to top when filters change
    ref.listen(searchFilterViewModelProvider, (prev, next) {
      if (prev != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scrollController.hasClients &&
              _scrollController.positions.length == 1 &&
              _scrollController.offset > 0) {
            _scrollController.jumpTo(0);
          }
        });
      }
    });

    final filter = ref.watch(searchFilterViewModelProvider);
    final filterVm = ref.read(searchFilterViewModelProvider.notifier);
    final feedLayoutMode = ref.watch(
      settingsViewModelProvider.select((s) => s.feedLayoutMode),
    );
    final isAuthenticatedWithOAuth = ref.watch(
      settingsViewModelProvider.select((s) => s.isAuthenticatedWithOAuth),
    );
    final settingsVm = ref.read(settingsViewModelProvider.notifier);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: _isSearchExpanded
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Search titles, comments, threads, notes...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchDebounceTimer?.cancel();
                      _searchController.clear();
                      filterVm.setSearchQuery(null);
                      setState(() {
                        _isSearchExpanded = false;
                      });
                    },
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (val) {
                  _searchDebounceTimer?.cancel();
                  filterVm.setSearchQuery(val.trim().isEmpty ? null : val);
                },
                onChanged: (val) {
                  _searchDebounceTimer?.cancel();
                  _searchDebounceTimer = Timer(
                    const Duration(milliseconds: 250),
                    () {
                      if (mounted) {
                        filterVm.setSearchQuery(
                          val.trim().isEmpty ? null : val,
                        );
                      }
                    },
                  );
                },
              )
            : Row(
                children: [
                  Text(
                    'Savedex',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  feedStateAsync.when(
                    data: (feedState) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${feedState.totalCount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
        actions: [
          if (!_isSearchExpanded)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Search',
              onPressed: () {
                setState(() {
                  _isSearchExpanded = true;
                });
              },
            ),

          PopupMenuButton<FeedLayoutMode>(
            icon: Icon(feedLayoutMode.icon),
            tooltip: 'Layout Mode',
            onSelected: (mode) => settingsVm.setFeedLayoutMode(mode),
            itemBuilder: (ctx) => FeedLayoutMode.values.map((mode) {
              final isSelected = feedLayoutMode == mode;
              return PopupMenuItem(
                value: mode,
                child: Row(
                  children: [
                    Icon(
                      mode.icon,
                      size: 18,
                      color: isSelected ? colorScheme.primary : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      mode.label,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? colorScheme.primary : null,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort: ${filter.sortOption.label}',
            onPressed: () => _openSortSheet(context),
          ),

          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'All Filters',
                onPressed: () => _openFilterSheet(context),
              ),
              if (filter.hasActiveFilters)
                Positioned(
                  top: 9,
                  right: 9,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),

          if (isAuthenticatedWithOAuth)
            Consumer(
              builder: (context, ref, _) {
                final importState = ref.watch(importExportViewModelProvider);
                if (importState.isImporting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                return IconButton(
                  icon: const Icon(Icons.sync_rounded),
                  tooltip: 'Pull Saved from Reddit',
                  onPressed: _syncFromReddit,
                );
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildQuickFilterBar(context, filter, filterVm, colorScheme),
          const ImportExportProgressCard(
            margin: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            isDense: true,
          ),
          if (feedStateAsync.isLoading && feedStateAsync.hasValue)
            const LinearProgressIndicator(minHeight: 2),

          Expanded(
            child: feedStateAsync.when(
              skipLoadingOnReload: true,
              data: (feedState) {
                final items = feedState.items;
                if (items.isEmpty) {
                  return _buildEmptyState(
                    context,
                    ref,
                    filter.hasActiveFilters,
                  );
                }

                final showFooter =
                    feedState.hasMore ||
                    feedState.isLoadingMore ||
                    feedState.paginationError != null;

                Widget content;
                switch (feedLayoutMode) {
                  case FeedLayoutMode.card:
                  case FeedLayoutMode.compact:
                    content = ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 28),
                      itemCount: items.length + (showFooter ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= items.length) {
                          return _buildPaginationFooter(context, feedState);
                        }
                        final item = items[index];
                        if (feedLayoutMode == FeedLayoutMode.compact) {
                          return CompactListItem(
                            key: ValueKey(item.id),
                            item: item,
                          );
                        }
                        if (item.itemType == ItemType.comment) {
                          return CommentCard(
                            key: ValueKey(item.id),
                            item: item,
                          );
                        }
                        return PostCard(key: ValueKey(item.id), item: item);
                      },
                    );
                    break;

                  case FeedLayoutMode.gallery:
                    content = CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.82,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final item = items[index];
                              return GalleryItem(
                                key: ValueKey(item.id),
                                item: item,
                              );
                            }, childCount: items.length),
                          ),
                        ),
                        if (showFooter)
                          SliverToBoxAdapter(
                            child: _buildPaginationFooter(context, feedState),
                          ),
                      ],
                    );
                    break;
                }

                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.depth == 0 &&
                        notification.metrics.pixels >=
                            notification.metrics.maxScrollExtent - 3000) {
                      final current = ref
                          .read(savedFeedPaginationProvider)
                          .value;
                      if (current != null &&
                          current.hasMore &&
                          !current.isLoadingMore &&
                          current.paginationError == null) {
                        ref
                            .read(savedFeedPaginationProvider.notifier)
                            .fetchNextPage();
                      }
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: () async {
                      if (isAuthenticatedWithOAuth) {
                        await _syncFromReddit(showErrorSnackbar: true);
                      }
                      ref.invalidate(savedFeedPaginationProvider);
                      await ref.read(savedFeedPaginationProvider.future);
                    },
                    child: content,
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error loading feed: $err'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterBar(
    BuildContext context,
    FilterCriteria filter,
    SearchFilterViewModel filterVm,
    ColorScheme colorScheme,
  ) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: filter.itemType == null && filter.isStarred != true,
            onSelected: (_) {
              filterVm.setItemType(null);
              filterVm.toggleStarredOnly(false);
            },
          ),
          const SizedBox(width: 8),

          FilterChip(
            avatar: Icon(
              filter.isStarred == true
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: 16,
              color: filter.isStarred == true ? Colors.yellow : null,
            ),
            label: const Text('Starred'),
            selected: filter.isStarred == true,
            onSelected: (val) => filterVm.toggleStarredOnly(val),
          ),
          const SizedBox(width: 8),

          FilterChip(
            avatar: const Icon(Icons.article_rounded, size: 15),
            label: const Text('Posts'),
            selected: filter.itemType == ItemType.post,
            onSelected: (val) =>
                filterVm.setItemType(val ? ItemType.post : null),
          ),
          const SizedBox(width: 8),

          FilterChip(
            avatar: const Icon(Icons.chat_bubble_rounded, size: 14),
            label: const Text('Comments'),
            selected: filter.itemType == ItemType.comment,
            onSelected: (val) =>
                filterVm.setItemType(val ? ItemType.comment : null),
          ),
          const SizedBox(width: 8),

          // sub  filter
          if (filter.selectedSubreddits.isNotEmpty) ...[
            ...filter.selectedSubreddits.map(
              (sub) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  avatar: Icon(
                    SavedItem.isUserSubreddit(sub)
                        ? Icons.person_rounded
                        : Icons.tag_rounded,
                    size: 14,
                  ),
                  label: Text(SavedItem.formatSubreddit(sub)),
                  onDeleted: () => filterVm.toggleSubreddit(sub),
                ),
              ),
            ),
          ],

          // author filter
          if (filter.selectedAuthors.isNotEmpty) ...[
            ...filter.selectedAuthors.map(
              (author) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  avatar: const Icon(Icons.person_rounded, size: 14),
                  label: Text('u/$author'),
                  onDeleted: () => filterVm.toggleAuthor(author),
                ),
              ),
            ),
          ],

          // flair filter
          if (filter.selectedFlairs.isNotEmpty) ...[
            ...filter.selectedFlairs.map(
              (flair) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text(flair),
                  onDeleted: () => filterVm.toggleFlair(flair),
                ),
              ),
            ),
          ],

          // Clear all filter
          if (filter.hasActiveFilters) ...[
            ActionChip(
              avatar: const Icon(Icons.close_rounded, size: 14),
              label: const Text('Clear All'),
              onPressed: () {
                _searchDebounceTimer?.cancel();
                _searchController.clear();
                setState(() {
                  _isSearchExpanded = false;
                });
                filterVm.clearAllFilters();
                if (_scrollController.hasClients &&
                    _scrollController.positions.length == 1 &&
                    _scrollController.offset > 0) {
                  _scrollController.jumpTo(0);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref,
    bool hasActiveFilters,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAuthenticatedWithOAuth = ref.watch(
      settingsViewModelProvider.select((s) => s.isAuthenticatedWithOAuth),
    );
    final importState = ref.watch(importExportViewModelProvider);

    if (hasActiveFilters) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No matching saved items',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your keywords or clearing active filters.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: () {
                  _searchDebounceTimer?.cancel();
                  _searchController.clear();
                  ref
                      .read(searchFilterViewModelProvider.notifier)
                      .clearAllFilters();
                },
                child: const Text('Reset All Filters'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmarks_rounded,
                size: 52,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Saved Posts Yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isAuthenticatedWithOAuth
                  ? 'Your Reddit account is connected! Pull your latest saved posts & comments directly from Reddit, or import an export file.'
                  : 'Import your Reddit Takeout CSV/ZIP or connect your Reddit account in Settings to start exploring saved items.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 24),
            if (importState.isImporting) ...[
              const SizedBox(width: 220, child: LinearProgressIndicator()),
              const SizedBox(height: 12),
              Text(
                importState.statusMessage ??
                    'Syncing saved items from Reddit...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ] else if (isAuthenticatedWithOAuth) ...[
              FilledButton.icon(
                onPressed: _syncFromReddit,
                icon: const Icon(Icons.cloud_download_rounded),
                label: const Text('Pull Saved from Reddit (OAuth)'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4500),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const ImportView()),
                  );
                },
                icon: const Icon(Icons.file_upload_rounded),
                label: const Text('Import Reddit Takeout CSV'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const ImportView()),
                  );
                },
                icon: const Icon(Icons.file_upload_rounded),
                label: const Text('Import Reddit Takeout'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const FilterSheet(),
    );
  }

  void _openSortSheet(BuildContext context) {
    showModalBottomSheet(context: context, builder: (ctx) => const SortSheet());
  }

  Widget _buildPaginationFooter(
    BuildContext context,
    SavedFeedState feedState,
  ) {
    if (feedState.paginationError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: TextButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Failed to load more. Tap to retry'),
            onPressed: () =>
                ref.read(savedFeedPaginationProvider.notifier).retryNextPage(),
          ),
        ),
      );
    }

    if (feedState.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
