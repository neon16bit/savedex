import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';
import 'package:savedex/features/saved/widgets/comment_card.dart';
import 'package:savedex/features/saved/widgets/post_card.dart';
import 'package:savedex/features/search/search_viewmodel.dart';
import 'package:savedex/features/search/widgets/filter_sheet.dart';
import 'package:savedex/features/search/widgets/sort_sheet.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class SearchView extends ConsumerStatefulWidget {
  const SearchView({super.key});

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<SearchView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final currentQuery =
        ref.read(searchFilterViewModelProvider).searchQuery ?? '';
    _searchController = TextEditingController(text: currentQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filterVm = ref.read(searchFilterViewModelProvider.notifier);
    final feedStateAsync = ref.watch(savedFeedPaginationProvider);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: TextField(
          controller: _searchController,
          autofocus: false,
          decoration: InputDecoration(
            hintText: 'Search titles, comments, threads, notes...',
            hintStyle: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      filterVm.setSearchQuery(null);
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          onChanged: (query) {
            filterVm.setSearchQuery(query);
            setState(() {});
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filter Options',
            onPressed: () => _openFilterSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort Options',
            onPressed: () => _openSortSheet(context),
          ),
        ],
      ),
      body: feedStateAsync.when(
        data: (feedState) {
          final items = feedState.items;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 56,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchController.text.isNotEmpty
                          ? 'No matches found'
                          : 'Search your saved library',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _searchController.text.isNotEmpty
                          ? 'Try different keywords, subreddits, or clear active filters'
                          : 'Search across titles, comments, parent threads, and notes',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item.itemType == ItemType.comment) {
                return CommentCard(item: item);
              }
              return PostCard(item: item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Search error: $err')),
      ),
    );
  }

  void _openFilterSheet(BuildContext context) {
    showFrostedModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const FilterSheet(),
    );
  }

  void _openSortSheet(BuildContext context) {
    showFrostedModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const SortSheet(),
    );
  }
}
