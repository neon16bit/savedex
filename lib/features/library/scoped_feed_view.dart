import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/saved/widgets/comment_card.dart';
import 'package:savedex/features/saved/widgets/post_card.dart';
import 'package:savedex/shared/widgets/widgets.dart';
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
  StreamSubscription? _dbUpdatesSub;

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final db = ref.read(databaseProvider);
      _dbUpdatesSub = db.tableUpdates().listen((_) => _onDbUpdate());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _dbUpdatesSub?.cancel();
    super.dispose();
  }

  FilterCriteria _buildFilter() {
    return FilterCriteria(
      selectedCollectionIds: widget.args.isCollection
          ? {widget.args.collection!.id}
          : const {},
      selectedSubreddits: widget.args.isSubreddit
          ? {widget.args.subreddit!}
          : const {},
      searchQuery: _searchQuery,
      itemType: _selectedItemType,
      isStarred: _isStarredOnly,
      sortOption: _sortOption,
    );
  }

  Future<void> _loadInitial() async {
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

      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final repo = ref.read(savedItemRepositoryProvider);
      final filter = _buildFilter();

      final page = await repo.getSavedItemsPage(
        filter: filter,
        cursor: _nextCursor,
        limit: _pageSize,
      );

      if (!mounted) return;
      final existingIds = _items.map((i) => i.id).toSet();
      final newItems = page.items.where((i) => !existingIds.contains(i.id));

      setState(() {
        _items = [..._items, ...newItems];
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  void _onDbUpdate() {
    _loadInitial();
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
            IconButton(
              icon: const Icon(Icons.edit_note_rounded),
              tooltip: 'Edit collection',
              onPressed: () async {
                await showCollectionFormDialog(
                  context,
                  initialCollection: widget.args.collection,
                );
                if (mounted) _loadInitial();
              },
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

          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _selectedItemType == null && _isStarredOnly != true,
                  onSelected: (_) {
                    setState(() {
                      _selectedItemType = null;
                      _isStarredOnly = null;
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
                  isSearching
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
                isSearching
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
                isSearching
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
              if (isSearching) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  child: const Text('Clear Search'),
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
