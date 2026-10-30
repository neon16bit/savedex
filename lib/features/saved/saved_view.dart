import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';
import 'package:savedex/features/import_export/import_view.dart';
import 'package:savedex/features/import_export/import_viewmodel.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';
import 'package:savedex/features/saved/widgets/comment_card.dart';
import 'package:savedex/features/saved/widgets/compact_list_item.dart';
import 'package:savedex/features/saved/widgets/gallery_item.dart';
import 'package:savedex/features/saved/widgets/post_card.dart';
import 'package:savedex/features/search/search_viewmodel.dart';
import 'package:savedex/features/search/widgets/sort_sheet.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';
import 'package:savedex/features/shell/app_shell.dart';

typedef FeedView = SavedView;

enum _SavedViewMenuAction {
  postView,
  toggleNsfw,
  syncReddit,
  fetchMetadata,
  pauseMetadata,
  resumeMetadata,
  stopMetadata,
  importExport,
}

class SavedView extends ConsumerStatefulWidget {
  const SavedView({super.key});

  @override
  ConsumerState<SavedView> createState() => _SavedViewState();
}

class _SavedViewState extends ConsumerState<SavedView> {
  late final TextEditingController _searchController;
  Timer? _searchDebounceTimer;
  late final ScrollController _scrollController;
  bool _isScrollingToTop = false;
  int _sliverResetEpoch = 0;
  final GlobalKey<PopupMenuButtonState<_SavedViewMenuAction>> _moreMenuKey =
      GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final initialQuery =
        ref.read(searchFilterViewModelProvider).searchQuery ?? '';
    _searchController = TextEditingController(text: initialQuery);
    if (initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(isSavedSearchExpandedProvider.notifier).setExpanded(true);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatNumber(int number) => number.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );

  String _formatSyncMessage(ImportSummary summary) {
    final totalInDb = summary.totalInDatabase;
    final dbSuffix = totalInDb != null
        ? ' (${_formatNumber(totalInDb)} in library)'
        : '';

    if (summary.newItemsImported > 0 && summary.updatedItems > 0) {
      return 'Reddit sync: ${_formatNumber(summary.newItemsImported)} new, ${_formatNumber(summary.updatedItems)} updated$dbSuffix';
    } else if (summary.newItemsImported > 0) {
      return 'Reddit sync: ${_formatNumber(summary.newItemsImported)} new items added$dbSuffix';
    } else if (summary.updatedItems > 0) {
      return 'Reddit sync: ${_formatNumber(summary.updatedItems)} items refreshed$dbSuffix';
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
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(error, style: TextStyle(color: colorScheme.onError)),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
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
            if (_scrollController.offset > 1500.0) {
              setState(() {
                _sliverResetEpoch++;
              });
            }
            _scrollController.jumpTo(0);
          }
        });
      }
    });

    // clear search query when search mode is closed from bottom navbar or appbar
    ref.listen<bool>(isSavedSearchExpandedProvider, (prev, next) {
      if (prev == true && !next) {
        _searchDebounceTimer?.cancel();
        _searchController.clear();
        ref.read(searchFilterViewModelProvider.notifier).setSearchQuery(null);
      }
    });

    // scroll to top when Saved tab is re-tapped in the bottom dock
    ref.listen<int>(savedScrollToTopTriggerProvider, (prev, next) async {
      if (_isScrollingToTop) return;
      if (!_scrollController.hasClients ||
          _scrollController.positions.length != 1 ||
          _scrollController.offset <= 0) {
        return;
      }

      _isScrollingToTop = true;
      try {
        const jumpThreshold = 1500.0;
        // Keep glideOffset <= default Viewport.cacheExtent (250.0) so that
        // constraints.scrollOffset + constraints.cacheOrigin == 0.0 on the jump frame
        // ensuring index 0 is built immediately and no widgets are
        // constructed/disposed during the animateTo(0) glide.
        const glideOffset = 220.0;

        if (_scrollController.offset > jumpThreshold) {
          ref.read(savedFeedPaginationProvider.notifier).trimToFirstPage();
          setState(() {
            _sliverResetEpoch++;
          });
          _scrollController.jumpTo(glideOffset);
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted ||
              !_scrollController.hasClients ||
              _scrollController.positions.length != 1) {
            return;
          }
        }

        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {
      } finally {
        if (mounted) {
          _isScrollingToTop = false;
        }
      }
    });

    final isSearchExpanded = ref.watch(isSavedSearchExpandedProvider);
    final filter = ref.watch(searchFilterViewModelProvider);
    final filterVm = ref.read(searchFilterViewModelProvider.notifier);
    final hasActiveNonSearchFilters =
        filter.itemType != null ||
        filter.isStarred != null ||
        filter.selectedSubreddits.isNotEmpty ||
        filter.selectedAuthors.isNotEmpty ||
        filter.selectedFlairs.isNotEmpty ||
        filter.selectedMediaTypes.isNotEmpty ||
        filter.selectedCollectionIds.isNotEmpty ||
        filter.isNsfw != null ||
        filter.enrichmentStatus != null ||
        filter.dateRangeStart != null ||
        filter.dateRangeEnd != null;
    final feedLayoutMode = ref.watch(
      settingsViewModelProvider.select((s) => s.feedLayoutMode),
    );
    final hideNsfwInFeed = ref.watch(
      settingsViewModelProvider.select((s) => s.hideNsfwInFeed),
    );
    final isAuthenticatedWithOAuth = ref.watch(
      settingsViewModelProvider.select((s) => s.isAuthenticatedWithOAuth),
    );

    final (isEnrichRunning, isEnrichPaused) = ref.watch(
      enrichmentViewModelProvider.select((s) => (s.isRunning, s.isPaused)),
    );
    final enrichVm = ref.read(enrichmentViewModelProvider.notifier);
    final isSyncingReddit = ref.watch(
      importExportViewModelProvider.select((s) => s.isSyncingReddit),
    );
    final isEnriching = isEnrichRunning || isEnrichPaused;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: isSearchExpanded ? 0 : 12,
        leading: isSearchExpanded
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Close search',
                onPressed: () {
                  ref
                      .read(isSavedSearchExpandedProvider.notifier)
                      .setExpanded(false);
                },
              )
            : null,
        title: isSearchExpanded
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
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            filterVm.setSearchQuery(null);
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (val) {
                  _searchDebounceTimer?.cancel();
                  filterVm.setSearchQuery(val.trim().isEmpty ? null : val);
                },
                onChanged: (val) {
                  setState(() {});
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Savedex',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  feedStateAsync.when(
                    data: (feedState) {
                      if (feedState.totalCount <= 0 &&
                          feedState.items.isNotEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
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
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
        actions: [
          if (!isSearchExpanded) ...[
            IconButton(
              icon: const Icon(Icons.sort_rounded),
              tooltip: 'Sort: ${filter.sortOption.label}',
              visualDensity: VisualDensity.compact,
              onPressed: () => _openSortSheet(context),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                PopupMenuButton<_SavedViewMenuAction>(
                  key: _moreMenuKey,
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'More options',
                  style: IconButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onSelected: (action) {
                    switch (action) {
                      case _SavedViewMenuAction.postView:
                        _openPostViewMenu(context);
                        break;
                      case _SavedViewMenuAction.toggleNsfw:
                        if (filter.isNsfw != null) {
                          filterVm.setNsfwFilter(null);
                        }
                        ref
                            .read(settingsViewModelProvider.notifier)
                            .toggleHideNsfwInFeed();
                        break;
                      case _SavedViewMenuAction.syncReddit:
                        _syncFromReddit(showErrorSnackbar: true);
                        break;
                      case _SavedViewMenuAction.fetchMetadata:
                        enrichVm.startEnrichment();
                        break;
                      case _SavedViewMenuAction.pauseMetadata:
                        enrichVm.pauseEnrichment();
                        break;
                      case _SavedViewMenuAction.resumeMetadata:
                        enrichVm.resumeEnrichment();
                        break;
                      case _SavedViewMenuAction.stopMetadata:
                        enrichVm.stopEnrichment();
                        break;
                      case _SavedViewMenuAction.importExport:
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => const ImportView(),
                          ),
                        );
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem<_SavedViewMenuAction>(
                      value: _SavedViewMenuAction.postView,
                      child: Row(
                        children: [
                          Icon(
                            feedLayoutMode.icon,
                            size: 20,
                            color: colorScheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Post View')),
                          Text(
                            feedLayoutMode.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<_SavedViewMenuAction>(
                      value: _SavedViewMenuAction.toggleNsfw,
                      child: Row(
                        children: [
                          Icon(
                            hideNsfwInFeed
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 20,
                            color: hideNsfwInFeed
                                ? colorScheme.error
                                : colorScheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              hideNsfwInFeed ? 'Show NSFW' : 'Hide NSFW',
                            ),
                          ),
                          if (filter.isNsfw != null)
                            Text(
                              filter.isNsfw! ? 'Filter: NSFW' : 'Filter: SFW',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.outline,
                              ),
                            )
                          else if (hideNsfwInFeed)
                            Text(
                              'Hidden',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.error,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    if (isAuthenticatedWithOAuth)
                      PopupMenuItem<_SavedViewMenuAction>(
                        value: _SavedViewMenuAction.syncReddit,
                        enabled: !isSyncingReddit,
                        child: Row(
                          children: [
                            Icon(
                              Icons.sync_rounded,
                              size: 20,
                              color: isSyncingReddit
                                  ? colorScheme.outline
                                  : colorScheme.onSurface,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isSyncingReddit
                                  ? 'Syncing from Reddit...'
                                  : 'Sync from Reddit',
                            ),
                          ],
                        ),
                      ),
                    if (isEnrichRunning) ...[
                      PopupMenuItem<_SavedViewMenuAction>(
                        value: _SavedViewMenuAction.pauseMetadata,
                        child: Row(
                          children: [
                            Icon(
                              Icons.pause_circle_outline_rounded,
                              size: 20,
                              color: colorScheme.onSurface,
                            ),
                            const SizedBox(width: 12),
                            const Text('Pause Metadata Fetch'),
                          ],
                        ),
                      ),
                      PopupMenuItem<_SavedViewMenuAction>(
                        value: _SavedViewMenuAction.stopMetadata,
                        child: Row(
                          children: [
                            Icon(
                              Icons.stop_circle_outlined,
                              size: 20,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Stop Metadata Fetch',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isEnrichPaused) ...[
                      PopupMenuItem<_SavedViewMenuAction>(
                        value: _SavedViewMenuAction.resumeMetadata,
                        child: Row(
                          children: [
                            Icon(
                              Icons.play_circle_outline_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            const Text('Resume Metadata Fetch'),
                          ],
                        ),
                      ),
                      PopupMenuItem<_SavedViewMenuAction>(
                        value: _SavedViewMenuAction.stopMetadata,
                        child: Row(
                          children: [
                            Icon(
                              Icons.stop_circle_outlined,
                              size: 20,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Stop Metadata Fetch',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      PopupMenuItem<_SavedViewMenuAction>(
                        value: _SavedViewMenuAction.fetchMetadata,
                        child: Consumer(
                          builder: (context, menuRef, _) {
                            final pendingCount =
                                menuRef
                                    .watch(pendingEnrichmentCountProvider)
                                    .asData
                                    ?.value ??
                                0;
                            return Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 20,
                                  color: pendingCount > 0
                                      ? colorScheme.primary
                                      : colorScheme.outline,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  pendingCount > 0
                                      ? 'Fetch Metadata (${_formatNumber(pendingCount)})'
                                      : 'All Metadata Downloaded',
                                  style: TextStyle(
                                    color: pendingCount > 0
                                        ? null
                                        : colorScheme.outline,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    const PopupMenuDivider(),
                    const PopupMenuItem<_SavedViewMenuAction>(
                      value: _SavedViewMenuAction.importExport,
                      child: Row(
                        children: [
                          Icon(Icons.import_export_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Import & Export'),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isEnriching)
                  Positioned(
                    top: 10,
                    right: 8,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isEnrichPaused
                            ? colorScheme.outline
                            : colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: Column(
        children: [
          if (hasActiveNonSearchFilters)
            _buildActiveFiltersBar(context, filter, filterVm),
          if ((feedStateAsync.isLoading && feedStateAsync.hasValue) ||
              isSyncingReddit)
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
                    content = CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          key: ValueKey('feed_list_$_sliverResetEpoch'),
                          padding: const EdgeInsets.only(bottom: 104),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              if (index >= items.length) {
                                return _buildPaginationFooter(
                                  context,
                                  feedState,
                                );
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
                              return PostCard(
                                key: ValueKey(item.id),
                                item: item,
                              );
                            }, childCount: items.length + (showFooter ? 1 : 0)),
                          ),
                        ),
                      ],
                    );
                    break;

                  case FeedLayoutMode.gallery:
                    content = CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          key: ValueKey('feed_grid_$_sliverResetEpoch'),
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 104),
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
                    if (!_isScrollingToTop &&
                        notification.depth == 0 &&
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
                      } else {
                        ref.invalidate(savedFeedPaginationProvider);
                      }
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

  Widget _buildActiveFiltersBar(
    BuildContext context,
    FilterCriteria filter,
    SearchFilterViewModel filterVm,
  ) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          ActionChip(
            avatar: const Icon(Icons.close_rounded, size: 14),
            label: const Text('Clear All'),
            onPressed: () {
              filterVm.clearAllFilters();
              if (_scrollController.hasClients &&
                  _scrollController.positions.length == 1 &&
                  _scrollController.offset > 0) {
                _scrollController.jumpTo(0);
              }
            },
          ),
          const SizedBox(width: 8),

          if (filter.isStarred == true)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: Colors.yellow,
                ),
                label: const Text('Starred'),
                onDeleted: () => filterVm.toggleStarredOnly(false),
              ),
            ),

          if (filter.itemType == ItemType.post)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.article_rounded, size: 14),
                label: const Text('Posts'),
                onDeleted: () => filterVm.setItemType(null),
              ),
            ),

          if (filter.itemType == ItemType.comment)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.chat_bubble_rounded, size: 14),
                label: const Text('Comments'),
                onDeleted: () => filterVm.setItemType(null),
              ),
            ),

          if (filter.isNsfw != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(filter.isNsfw! ? 'NSFW' : 'SFW only'),
                onDeleted: () => filterVm.setNsfwFilter(null),
              ),
            ),

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

  void _openSortSheet(BuildContext context) {
    showModalBottomSheet(context: context, builder: (ctx) => const SortSheet());
  }

  static const _backSentinel = Object();

  Future<void> _openPostViewMenu(BuildContext context) async {
    final renderBox =
        _moreMenuKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final colorScheme = Theme.of(context).colorScheme;
    final currentMode = ref.read(settingsViewModelProvider).feedLayoutMode;

    final target = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromPoints(target, target + renderBox.size.bottomRight(Offset.zero)),
      Offset.zero & overlay.size,
    );

    await Future.delayed(const Duration(milliseconds: 10));
    if (!mounted || !context.mounted) return;

    final selected = await showMenu<Object?>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        PopupMenuItem<Object?>(
          value: _backSentinel,
          height: 38,
          child: Row(
            children: [
              Icon(
                Icons.arrow_back_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Post View',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        ...FeedLayoutMode.values.map((mode) {
          final isSelected = currentMode == mode;
          return PopupMenuItem<Object?>(
            value: mode,
            child: Row(
              children: [
                Icon(
                  mode.icon,
                  size: 20,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    mode.label,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? colorScheme.primary : null,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
              ],
            ),
          );
        }),
      ],
    );

    if (!mounted) return;

    if (identical(selected, _backSentinel)) {
      // return to main more options menu
      _moreMenuKey.currentState?.showButtonMenu();
    } else if (selected is FeedLayoutMode) {
      ref.read(settingsViewModelProvider.notifier).setFeedLayoutMode(selected);
    }
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
