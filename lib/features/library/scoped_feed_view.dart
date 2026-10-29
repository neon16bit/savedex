import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';
import 'package:savedex/features/saved/widgets/comment_card.dart';
import 'package:savedex/features/saved/widgets/post_card.dart';
import 'package:url_launcher/url_launcher.dart';

class ScopedFeedArgs {
  final Collection? collection;
  final String? subreddit;

  const ScopedFeedArgs.collection(this.collection) : subreddit = null;
  const ScopedFeedArgs.subreddit(this.subreddit) : collection = null;

  bool get isCollection => collection != null;
  bool get isSubreddit => subreddit != null;

  String get title =>
      isCollection ? collection!.name : SavedItem.formatSubreddit(subreddit!);
}

class ScopedFeedView extends ConsumerStatefulWidget {
  final ScopedFeedArgs args;

  const ScopedFeedView({super.key, required this.args});

  @override
  ConsumerState<ScopedFeedView> createState() => _ScopedFeedViewState();
}

class _ScopedFeedViewState extends ConsumerState<ScopedFeedView> {
  static const int _pageSize = 100;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  Timer? _dbDebounceTimer;
  StreamSubscription? _dbUpdatesSub;
  StreamSubscription? _itemMutationsSub;
  DateTime? _ignoreDbUpdatesUntil;
  int _generation = 0;

  List<SavedItem> _items = [];
  FeedCursor? _nextCursor;
  int _totalCount = 0;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  bool _isSearchExpanded = false;
  String? _searchQuery;
  ItemType? _selectedItemType;
  bool? _isStarredOnly;
  SortOption _sortOption = SortOption.savedOrderDesc;
  final Set<String> _selectedSubreddits = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final db = ref.read(databaseProvider);
      _dbUpdatesSub = db
          .tableUpdates(
            TableUpdateQuery.onAllTables([
              db.savedItemsTable,
              db.collectionsTable,
              db.itemCollectionsTable,
            ]),
          )
          .listen((_) => _onDbUpdate());
      _itemMutationsSub = ref
          .read(savedFeedPaginationProvider.notifier)
          .itemMutations
          .listen(_onSingleItemMutated);
    });
  }

  @override
  void didUpdateWidget(covariant ScopedFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final collectionChanged =
        oldWidget.args.collection?.id != widget.args.collection?.id ||
        oldWidget.args.collection?.name != widget.args.collection?.name;
    final subredditChanged = oldWidget.args.subreddit != widget.args.subreddit;

    if (collectionChanged || subredditChanged) {
      _searchDebounceTimer?.cancel();
      _dbDebounceTimer?.cancel();
      _selectedSubreddits.clear();
      _searchQuery = null;
      _searchController.clear();
      _selectedItemType = null;
      _isStarredOnly = null;
      _loadInitial();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _dbDebounceTimer?.cancel();
    _dbUpdatesSub?.cancel();
    _itemMutationsSub?.cancel();
    super.dispose();
  }

  void _onSingleItemMutated(
    ({String itemId, SavedItem? item, bool deleted}) event,
  ) {
    if (!mounted) return;
    _ignoreDbUpdatesUntil = DateTime.now().add(
      const Duration(milliseconds: 600),
    );
    _dbDebounceTimer?.cancel();

    final index = _items.indexWhere((i) => i.id == event.itemId);
    if (event.deleted || event.item == null) {
      if (index != -1) {
        setState(() {
          _items = List.of(_items)..removeAt(index);
          if (_totalCount > 0) _totalCount--;
        });
      }
      return;
    }

    final updated = event.item!;
    final shouldRemove =
        (_isStarredOnly == true && !updated.isStarred) ||
        (widget.args.isCollection &&
            !updated.collections.any(
              (c) => c.id == widget.args.collection!.id,
            ));

    if (index != -1) {
      if (shouldRemove) {
        setState(() {
          _items = List.of(_items)..removeAt(index);
          if (_totalCount > 0) _totalCount--;
        });
      } else if (_items[index] != updated) {
        setState(() {
          final next = List.of(_items);
          next[index] = updated;
          _items = next;
        });
      }
    }
  }

  FilterCriteria _buildFilter() {
    return FilterCriteria(
      selectedCollectionIds: widget.args.isCollection
          ? {widget.args.collection!.id}
          : const {},
      selectedSubreddits: widget.args.isSubreddit
          ? {widget.args.subreddit!}
          : _selectedSubreddits,
      searchQuery: _searchQuery,
      itemType: _selectedItemType,
      isStarred: _isStarredOnly,
      sortOption: _sortOption,
    );
  }

  Future<void> _loadInitial() async {
    _generation++;
    final currentGen = _generation;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(savedItemRepositoryProvider);
      final db = ref.read(databaseProvider);
      final filter = _buildFilter();

      final results = await Future.wait([
        repo.getSavedItemsPage(filter: filter, cursor: null, limit: _pageSize),
        db.countFilteredSavedItems(filter),
      ]);

      if (!mounted || currentGen != _generation) return;
      final page = results[0] as PagedRows<SavedItem>;
      final count = results[1] as int;

      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _totalCount = count;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentGen != _generation) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _reloadInBackground() async {
    if (!mounted || _isLoading) return;
    final currentGen = _generation;

    try {
      final repo = ref.read(savedItemRepositoryProvider);
      final db = ref.read(databaseProvider);
      final filter = _buildFilter();

      final targetLimit = _items.length <= _pageSize
          ? _pageSize
          : _items.length;

      final results = await Future.wait([
        repo.getSavedItemsPage(
          filter: filter,
          cursor: null,
          limit: targetLimit,
        ),
        db.countFilteredSavedItems(filter),
      ]);

      if (!mounted || currentGen != _generation || _isLoading) return;
      final page = results[0] as PagedRows<SavedItem>;
      final count = results[1] as int;

      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _totalCount = count;
        _hasMore = page.items.length < count;
      });
    } catch (_) {
      // do not wipe items on background update failure
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    final currentGen = _generation;
    setState(() => _isLoadingMore = true);

    try {
      final repo = ref.read(savedItemRepositoryProvider);
      final filter = _buildFilter();

      final page = await repo.getSavedItemsPage(
        filter: filter,
        cursor: _nextCursor,
        limit: _pageSize,
      );

      if (!mounted || currentGen != _generation) return;
      final existingIds = _items.map((i) => i.id).toSet();
      final newItems = page.items.where((i) => !existingIds.contains(i.id));

      setState(() {
        _items = [..._items, ...newItems];
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted && currentGen == _generation) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 2000) {
      _loadMore();
    }
  }

  void _onDbUpdate() {
    final until = _ignoreDbUpdatesUntil;
    if (until != null && DateTime.now().isBefore(until)) return;
    _dbDebounceTimer?.cancel();
    _dbDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      final checkUntil = _ignoreDbUpdatesUntil;
      if (checkUntil != null && DateTime.now().isBefore(checkUntil)) return;
      _reloadInBackground();
    });
  }

  void _onSearchChanged(String val) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = val.trim().isNotEmpty ? val.trim() : null;
      });
      _loadInitial();
    });
  }

  Future<void> _openInReddit(String subreddit) async {
    final cleanSub = subreddit.replaceAll(RegExp(r'^[ru]/'), '');
    final uri = Uri.parse('https://www.reddit.com/r/$cleanSub/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openSubredditFilterSheet(BuildContext context) {
    if (!widget.args.isCollection) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _CollectionSubredditFilterSheet(
        collectionId: widget.args.collection!.id,
        collectionName: widget.args.collection!.name,
        selectedSubreddits: _selectedSubreddits,
        onToggleSubreddit: (sub) {
          setState(() {
            if (_selectedSubreddits.contains(sub)) {
              _selectedSubreddits.remove(sub);
            } else {
              _selectedSubreddits.add(sub);
            }
          });
          _loadInitial();
        },
        onReset: () {
          setState(() {
            _selectedSubreddits.clear();
          });
          _loadInitial();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (widget.args.isCollection) ...[
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Color(widget.args.collection!.colorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                Flexible(
                  child: Text(
                    widget.args.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            Text(
              _isLoading
                  ? 'Loading...'
                  : '$_totalCount saved ${_totalCount == 1 ? 'item' : 'items'}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
            ),
            tooltip: _isSearchExpanded ? 'Close search' : 'Search items',
            onPressed: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                if (!_isSearchExpanded) {
                  _searchController.clear();
                  _searchQuery = null;
                  _loadInitial();
                }
              });
            },
          ),
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort order',
            initialValue: _sortOption,
            onSelected: (sort) {
              setState(() => _sortOption = sort);
              _loadInitial();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: SortOption.savedOrderDesc,
                child: Text('Saved (Newest first)'),
              ),
              const PopupMenuItem(
                value: SortOption.savedOrderAsc,
                child: Text('Saved (Oldest first)'),
              ),
              const PopupMenuItem(
                value: SortOption.createdDateDesc,
                child: Text('Post Date (Newest)'),
              ),
              const PopupMenuItem(
                value: SortOption.createdDateAsc,
                child: Text('Post Date (Oldest)'),
              ),
              const PopupMenuItem(
                value: SortOption.scoreDesc,
                child: Text('Score (Highest)'),
              ),
              const PopupMenuItem(
                value: SortOption.titleAsc,
                child: Text('Title (A → Z)'),
              ),
              const PopupMenuItem(
                value: SortOption.subredditAsc,
                child: Text('Subreddit (A → Z)'),
              ),
            ],
          ),
          if (widget.args.isCollection) ...[
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: 'Filter subreddits',
                  onPressed: () => _openSubredditFilterSheet(context),
                ),
                if (_selectedSubreddits.isNotEmpty)
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
          ],
          if (widget.args.isSubreddit) ...[
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded),
              tooltip: 'Open subreddit on Reddit',
              onPressed: () => _openInReddit(widget.args.subreddit!),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (_isSearchExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search within ${widget.args.title}...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
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

          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected:
                      _selectedItemType == null &&
                      _isStarredOnly != true &&
                      _selectedSubreddits.isEmpty,
                  onSelected: (_) {
                    setState(() {
                      _selectedItemType = null;
                      _isStarredOnly = null;
                      _selectedSubreddits.clear();
                    });
                    _loadInitial();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: Icon(
                    _isStarredOnly == true
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: _isStarredOnly == true ? Colors.yellow : null,
                  ),
                  label: const Text('Starred'),
                  selected: _isStarredOnly == true,
                  onSelected: (val) {
                    setState(() => _isStarredOnly = val ? true : null);
                    _loadInitial();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.article_rounded, size: 15),
                  label: const Text('Posts'),
                  selected: _selectedItemType == ItemType.post,
                  onSelected: (val) {
                    setState(
                      () => _selectedItemType = val ? ItemType.post : null,
                    );
                    _loadInitial();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.chat_bubble_rounded, size: 14),
                  label: const Text('Comments'),
                  selected: _selectedItemType == ItemType.comment,
                  onSelected: (val) {
                    setState(
                      () => _selectedItemType = val ? ItemType.comment : null,
                    );
                    _loadInitial();
                  },
                ),
                if (widget.args.isCollection &&
                    _selectedSubreddits.isNotEmpty) ...[
                  ..._selectedSubreddits.map(
                    (sub) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(
                        avatar: Icon(
                          SavedItem.isUserSubreddit(sub)
                              ? Icons.person_rounded
                              : Icons.tag_rounded,
                          size: 14,
                        ),
                        label: Text(SavedItem.formatSubreddit(sub)),
                        onDeleted: () {
                          setState(() => _selectedSubreddits.remove(sub));
                          _loadInitial();
                        },
                      ),
                    ),
                  ),
                ],
                if (_selectedItemType != null ||
                    _isStarredOnly == true ||
                    _selectedSubreddits.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.close_rounded, size: 14),
                    label: const Text('Clear Filters'),
                    onPressed: () {
                      setState(() {
                        _selectedItemType = null;
                        _isStarredOnly = null;
                        _selectedSubreddits.clear();
                      });
                      _loadInitial();
                    },
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Error loading items',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonal(
                            onPressed: _loadInitial,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildFeedList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_items.isEmpty) {
      final isSearching = _searchQuery != null && _searchQuery!.isNotEmpty;
      final isFiltered =
          _selectedSubreddits.isNotEmpty ||
          _selectedItemType != null ||
          _isStarredOnly == true;

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
                  isSearching || isFiltered
                      ? Icons.search_off_rounded
                      : (widget.args.isCollection
                            ? Icons.bookmark_border_rounded
                            : Icons.tag_rounded),
                  size: 48,
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isSearching || isFiltered
                    ? 'No matching items'
                    : (widget.args.isCollection
                          ? 'Collection is empty'
                          : 'No saved items in this subreddit'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSearching || isFiltered
                    ? 'Try different keywords or reset your filters.'
                    : (widget.args.isCollection
                          ? 'Tap the Collections button or 3-dot menu on any saved post or comment to add it here.'
                          : 'Saved posts or comments from this subreddit will appear here.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              if (isSearching || isFiltered) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () {
                    if (isSearching) {
                      _searchController.clear();
                      _onSearchChanged('');
                    }
                    if (isFiltered) {
                      setState(() {
                        _selectedSubreddits.clear();
                        _selectedItemType = null;
                        _isStarredOnly = null;
                      });
                      _loadInitial();
                    }
                  },
                  child: Text(
                    isSearching && isFiltered
                        ? 'Reset All'
                        : (isSearching ? 'Clear Search' : 'Reset Filters'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _isLoadingMore
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }

          final item = _items[index];
          if (item.isComment) {
            return CommentCard(key: ValueKey(item.id), item: item);
          } else {
            return PostCard(key: ValueKey(item.id), item: item);
          }
        },
      ),
    );
  }
}

class _CollectionSubredditFilterSheet extends ConsumerStatefulWidget {
  final int collectionId;
  final String collectionName;
  final Set<String> selectedSubreddits;
  final ValueChanged<String> onToggleSubreddit;
  final VoidCallback onReset;

  const _CollectionSubredditFilterSheet({
    required this.collectionId,
    required this.collectionName,
    required this.selectedSubreddits,
    required this.onToggleSubreddit,
    required this.onReset,
  });

  @override
  ConsumerState<_CollectionSubredditFilterSheet> createState() =>
      _CollectionSubredditFilterSheetState();
}

class _CollectionSubredditFilterSheetState
    extends ConsumerState<_CollectionSubredditFilterSheet> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<(String, int)>> _subredditsFuture;
  late Set<String> _selected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedSubreddits);
    _subredditsFuture = ref
        .read(collectionRepositoryProvider)
        .getSubredditsForCollection(widget.collectionId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filter by Subreddit',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.collectionName,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selected.isNotEmpty)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          setState(() => _selected.clear());
                          widget.onReset();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Reset',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim().toLowerCase());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search subreddits in collection...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    isDense: true,
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
              Expanded(
                child: FutureBuilder<List<(String, int)>>(
                  future: _subredditsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Error: ${snapshot.error}'),
                        ),
                      );
                    }
                    final allSubreddits = snapshot.data ?? [];
                    if (allSubreddits.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No subreddits found in this collection.',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }

                    final filtered = _searchQuery.isEmpty
                        ? allSubreddits
                        : allSubreddits
                              .where(
                                (t) =>
                                    t.$1.toLowerCase().contains(_searchQuery) ||
                                    SavedItem.formatSubreddit(t.$1)
                                        .toLowerCase()
                                        .contains(_searchQuery),
                              )
                              .toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No subreddits matching "$_searchQuery"',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }

                    final displayItems = <(String, int)>[
                      ...filtered.where((t) => _selected.contains(t.$1)),
                      ...filtered
                          .where((t) => !_selected.contains(t.$1))
                          .take(15),
                    ];

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: displayItems.map((tuple) {
                            final name = tuple.$1;
                            final count = tuple.$2;
                            final isSelected = _selected.contains(name);

                            return FilterChip(
                              avatar: Icon(
                                SavedItem.isUserSubreddit(name)
                                    ? Icons.person_rounded
                                    : Icons.tag_rounded,
                                size: 14,
                              ),
                              label: Text(
                                '${SavedItem.formatSubreddit(name)} ($count)',
                              ),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() {
                                  if (isSelected) {
                                    _selected.remove(name);
                                  } else {
                                    _selected.add(name);
                                  }
                                });
                                widget.onToggleSubreddit(name);
                              },
                            );
                          }).toList(),
                        ),
                        if (filtered.length > displayItems.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Showing top 15 matches, type above to search more',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        _selected.isNotEmpty
                            ? 'Show Results (${_selected.length} Selected)'
                            : 'Done',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
