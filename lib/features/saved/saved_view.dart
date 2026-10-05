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

  @override
  void initState() {
    super.initState();
    final initialQuery =
        ref.read(searchFilterViewModelProvider).searchQuery ?? '';
    _searchController = TextEditingController(text: initialQuery);
    if (initialQuery.isNotEmpty) {
      _isSearchExpanded = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final rawItemsAsync = ref.watch(feedItemsStreamProvider);
    final filter = ref.watch(searchFilterViewModelProvider);
    final filterVm = ref.read(searchFilterViewModelProvider.notifier);
    final settings = ref.watch(settingsViewModelProvider);
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
                  hintText: 'Search titles, notes, subreddits...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
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
                onChanged: (val) => filterVm.setSearchQuery(val),
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
                  rawItemsAsync.when(
                    data: (items) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${items.length}',
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
            icon: Icon(settings.feedLayoutMode.icon),
            tooltip: 'Layout Mode',
            onSelected: (mode) => settingsVm.setFeedLayoutMode(mode),
            itemBuilder: (ctx) => FeedLayoutMode.values.map((mode) {
              final isSelected = settings.feedLayoutMode == mode;
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

          if (settings.isAuthenticatedWithOAuth)
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
                  onPressed: () async {
                    final summary = await ref
                        .read(importExportViewModelProvider.notifier)
                        .pullSavedFromReddit();
                    if (!context.mounted) return;
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
                    } else {
                      final error = ref
                          .read(importExportViewModelProvider)
                          .errorMessage;
                      if (error != null) {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .error,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                      }
                    }
                  },
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

          Expanded(
            child: rawItemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return _buildEmptyState(
                    context,
                    ref,
                    filter.hasActiveFilters,
                  );
                }

                Widget content;
                switch (settings.feedLayoutMode) {
                  case FeedLayoutMode.card:
                    content = ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 4, bottom: 28),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        if (item.itemType == ItemType.comment) {
                          return CommentCard(item: item);
                        }
                        return PostCard(item: item);
                      },
                    );
                    break;

                  case FeedLayoutMode.compact:
                    content = ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 4, bottom: 28),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        return CompactListItem(item: items[index]);
                      },
                    );
                    break;

                  case FeedLayoutMode.gallery:
                    content = GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.82,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        return GalleryItem(item: items[index]);
                      },
                    );
                    break;
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    if (settings.isAuthenticatedWithOAuth) {
                      final summary = await ref
                          .read(importExportViewModelProvider.notifier)
                          .pullSavedFromReddit();
                      if (context.mounted && summary != null) {
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
                      }
                    } else {
                      ref.invalidate(feedItemsStreamProvider);
                    }
                  },
                  child: content,
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
                  avatar: const Icon(Icons.tag_rounded, size: 14),
                  label: Text('r/$sub'),
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
                _searchController.clear();
                filterVm.clearAllFilters();
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
    final settings = ref.watch(settingsViewModelProvider);
    final importState = ref.watch(importExportViewModelProvider);

    if (hasActiveFilters) {
      return Center(
        child: Padding(
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
      child: Padding(
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
              settings.isAuthenticatedWithOAuth
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
            ] else if (settings.isAuthenticatedWithOAuth) ...[
              FilledButton.icon(
                onPressed: () async {
                  final summary = await ref
                      .read(importExportViewModelProvider.notifier)
                      .pullSavedFromReddit();
                  if (context.mounted) {
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
                    } else {
                      final error = ref
                          .read(importExportViewModelProvider)
                          .errorMessage;
                      if (error != null) {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: colorScheme.error,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                      }
                    }
                  }
                },
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
}
