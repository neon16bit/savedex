import 'dart:async';

import 'package:drift/drift.dart' show TableUpdate, TableUpdateQuery;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/core/utils/external_url_launcher.dart';
import 'package:savedex/core/utils/responsive_layout.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';
import 'package:savedex/features/saved/widgets/comment_card.dart';
import 'package:savedex/features/saved/widgets/compact_list_item.dart';
import 'package:savedex/features/saved/widgets/gallery_item.dart';
import 'package:savedex/features/saved/widgets/post_card.dart';
import 'package:savedex/features/search/widgets/filter_sheet.dart';
import 'package:savedex/features/search/widgets/sort_sheet.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';
import 'package:savedex/features/shell/widgets/floating_nav_bar.dart';
import 'package:savedex/shared/widgets/widgets.dart';

class ScopedFeedArgs {
  final Collection? collection;
  final String? subreddit;
  final String? author;

  const ScopedFeedArgs.collection(this.collection)
    : subreddit = null,
      author = null;
  const ScopedFeedArgs.subreddit(this.subreddit)
    : collection = null,
      author = null;
  const ScopedFeedArgs.author(this.author)
    : collection = null,
      subreddit = null;

  bool get isCollection => collection != null;
  bool get isSubreddit => subreddit != null;
  bool get isAuthor => author != null;

  String get title {
    if (isCollection) return collection!.name;
    if (isSubreddit) return SavedItem.formatSubreddit(subreddit!);
    final cleanAuthor = (author ?? '').replaceFirst(RegExp(r'^[ru]/'), '');
    return 'u/$cleanAuthor';
  }
}

class _ScopedFeedInherited extends InheritedWidget {
  final ScopedFeedArgs args;

  const _ScopedFeedInherited({required this.args, required super.child});

  static ScopedFeedArgs? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ScopedFeedInherited>()
        ?.args;
  }

  @override
  bool updateShouldNotify(_ScopedFeedInherited oldWidget) =>
      oldWidget.args != args;
}

class ScopedFeedView extends ConsumerStatefulWidget {
  final ScopedFeedArgs args;

  const ScopedFeedView({super.key, required this.args});

  static void openSubreddit(BuildContext context, String subreddit) {
    final cleanSub = subreddit.trim().replaceFirst(RegExp(r'^[ru]/'), '');
    if (cleanSub.isEmpty) return;
    final current = _ScopedFeedInherited.maybeOf(context);
    if (current != null &&
        current.isSubreddit &&
        current.subreddit!
                .trim()
                .replaceFirst(RegExp(r'^[ru]/'), '')
                .toLowerCase() ==
            cleanSub.toLowerCase()) {
      return;
    }
    ResponsiveLayout.unfocusEditableText();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) =>
            ScopedFeedView(args: ScopedFeedArgs.subreddit(cleanSub)),
      ),
    );
  }

  static void openAuthor(BuildContext context, String author) {
    final cleanAuthor = author.trim().replaceFirst(RegExp(r'^[ru]/'), '');
    if (cleanAuthor.isEmpty || cleanAuthor == '[deleted]') return;
    final current = _ScopedFeedInherited.maybeOf(context);
    if (current != null &&
        current.isAuthor &&
        current.author!
                .trim()
                .replaceFirst(RegExp(r'^[ru]/'), '')
                .toLowerCase() ==
            cleanAuthor.toLowerCase()) {
      return;
    }
    ResponsiveLayout.unfocusEditableText();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) =>
            ScopedFeedView(args: ScopedFeedArgs.author(cleanAuthor)),
      ),
    );
  }

  @override
  ConsumerState<ScopedFeedView> createState() => _ScopedFeedViewState();
}

class _ScopedFeedViewState extends ConsumerState<ScopedFeedView> {
  static const int _pageSize = 100;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _searchFocusNode;
  late final FocusScopeNode _shortcutFocusScopeNode;
  final GlobalKey _feedPaneKey = GlobalKey();
  Timer? _searchDebounceTimer;
  Timer? _dbDebounceTimer;
  StreamSubscription? _dbUpdatesSub;
  StreamSubscription? _itemMutationsSub;
  DateTime? _ignoreDbUpdatesUntil;
  int _generation = 0;

  List<SavedItem> _items = [];
  FeedCursor? _nextCursor;
  int _totalCount = 0;
  bool _isTotalCountPending = false;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  Object? _paginationError;
  String? _errorMessage;
  int _sliverResetEpoch = 0;
  bool _isScopedEntityNsfw = false;

  bool _isSearchExpanded = false;
  bool? _lastIsDesktop;
  bool _isFilterExpanded = false;
  bool _morphFromFilter = false;
  bool _openedViaFilter = false;
  FilterCriteria _scopedFilter = const FilterCriteria();

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode()..addListener(_onSearchFocusChanged);
    _shortcutFocusScopeNode = FocusScopeNode();
    _scrollController.addListener(_onScroll);
    _loadInitial(showFullScreenLoader: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final db = ref.read(databaseProvider);
      _dbUpdatesSub = db
          .tableUpdates(
            TableUpdateQuery.onAllTables([
              db.savedItemsTable,
              db.collectionsTable,
              db.itemCollectionsTable,
              db.subredditsTable,
            ]),
          )
          .listen(_onDbUpdate);
      _itemMutationsSub = ref
          .read(savedFeedPaginationProvider.notifier)
          .itemMutations
          .listen(_onSingleItemMutated);
    });
  }

  Future<void> _refreshScopedEntityNsfw([List<SavedItem>? loadedItems]) async {
    if (!mounted) return;
    if (widget.args.isCollection) {
      if (_isScopedEntityNsfw) {
        setState(() {
          _isScopedEntityNsfw = false;
        });
      }
      return;
    }

    final expectedIsSubreddit = widget.args.isSubreddit;
    final expectedSub = widget.args.subreddit;
    final expectedAuthor = widget.args.author;

    final repo = ref.read(savedItemRepositoryProvider);
    final bool nextNsfw;
    if (expectedIsSubreddit && expectedSub != null) {
      final override = await repo.getSubredditNsfwEntry(expectedSub);
      final items = loadedItems ?? _items;
      nextNsfw = override ?? (items.isNotEmpty && items.every((i) => i.isNsfw));
    } else if (!expectedIsSubreddit &&
        expectedAuthor != null &&
        expectedAuthor != '[deleted]') {
      final clean = expectedAuthor.trim().toLowerCase().replaceFirst(
        RegExp(r'^/?[ru]/'),
        '',
      );
      final override = clean.isEmpty
          ? null
          : await repo.getSubredditNsfwEntry('u_$clean');
      nextNsfw = override ?? false;
    } else {
      nextNsfw = false;
    }

    if (!mounted ||
        widget.args.isCollection ||
        widget.args.subreddit != expectedSub ||
        widget.args.author != expectedAuthor ||
        _isScopedEntityNsfw == nextNsfw) {
      return;
    }
    setState(() {
      _isScopedEntityNsfw = nextNsfw;
    });
  }

  Future<void> _toggleScopedEntityNsfw() async {
    if (widget.args.isCollection) return;
    final nextNsfw = !_isScopedEntityNsfw;
    setState(() {
      _isScopedEntityNsfw = nextNsfw;
    });
    final repo = ref.read(savedItemRepositoryProvider);
    if (widget.args.isSubreddit) {
      await repo.setSubredditNsfw(widget.args.subreddit!, isNsfw: nextNsfw);
    } else if (widget.args.isAuthor && widget.args.author != '[deleted]') {
      await repo.setAuthorNsfw(widget.args.author!, isNsfw: nextNsfw);
    }
    if (mounted) {
      showAppSnackBar(
        context,
        'Marked ${widget.args.title} as ${nextNsfw ? 'NSFW' : 'SFW'}',
      );
    }
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      _openedViaFilter = false;
    }
  }

  @override
  void didUpdateWidget(covariant ScopedFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final collectionChanged =
        oldWidget.args.collection?.id != widget.args.collection?.id ||
        oldWidget.args.collection?.name != widget.args.collection?.name;
    final subredditChanged = oldWidget.args.subreddit != widget.args.subreddit;
    final authorChanged = oldWidget.args.author != widget.args.author;

    if (collectionChanged || subredditChanged || authorChanged) {
      _searchDebounceTimer?.cancel();
      _dbDebounceTimer?.cancel();
      _searchController.clear();
      _scopedFilter = const FilterCriteria();
      _isSearchExpanded = false;
      _isFilterExpanded = false;
      _morphFromFilter = false;
      _openedViaFilter = false;
      _isScopedEntityNsfw = false;
      _items = [];
      _loadInitial(showFullScreenLoader: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _shortcutFocusScopeNode.dispose();
    _searchDebounceTimer?.cancel();
    _dbDebounceTimer?.cancel();
    _dbUpdatesSub?.cancel();
    _itemMutationsSub?.cancel();
    super.dispose();
  }

  void _dismissKeyboard() {
    _searchFocusNode.unfocus();
    _shortcutFocusScopeNode.focusedChild?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  Future<void> _onSingleItemMutated(
    ({String itemId, SavedItem? item, bool deleted}) event,
  ) async {
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
    var filter = _buildFilter();
    bool? subNsfw;
    if (filter.isNsfw != null) {
      subNsfw = await ref
          .read(savedItemRepositoryProvider)
          .isSubredditNsfw(updated.subreddit, author: updated.author);
      if (!mounted) return;
      filter = _buildFilter();
    }
    final currentIndex = _items.indexWhere((i) => i.id == event.itemId);
    final matches = SavedFeedPaginationNotifier.itemMatchesFilter(
      updated,
      filter,
      isSubredditNsfw: filter.isNsfw != null ? subNsfw : null,
    );

    if (currentIndex != -1) {
      if (!matches) {
        setState(() {
          _items = List.of(_items)..removeAt(currentIndex);
          if (_totalCount > 0) _totalCount--;
        });
      } else if (_items[currentIndex] != updated) {
        setState(() {
          final next = List.of(_items);
          next[currentIndex] = updated;
          _items = next;
        });
      }
    } else if (matches) {
      _reloadInBackground();
    }
  }

  FilterCriteria _buildFilter() {
    final cleanAuthor = widget.args.author?.replaceFirst(RegExp(r'^[ru]/'), '');

    return _scopedFilter.copyWith(
      selectedCollectionIds: widget.args.isCollection
          ? {widget.args.collection!.id}
          : const {},
      selectedSubreddits: widget.args.isSubreddit
          ? {widget.args.subreddit!}
          : _scopedFilter.selectedSubreddits,
      selectedAuthors: widget.args.isAuthor && cleanAuthor != null
          ? {cleanAuthor}
          : _scopedFilter.selectedAuthors,
    );
  }

  Future<void> _loadInitial({
    bool showFullScreenLoader = false,
    bool resetScroll = false,
  }) async {
    _generation++;
    final currentGen = _generation;

    if (!mounted) return;
    setState(() {
      if (showFullScreenLoader || _items.isEmpty) {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      final repo = ref.read(savedItemRepositoryProvider);
      final filter = _buildFilter();

      final page = await repo.getSavedItemsPage(
        filter: filter,
        cursor: null,
        limit: _pageSize,
      );

      if (!mounted || currentGen != _generation) return;

      unawaited(_refreshScopedEntityNsfw(page.items));

      final knownCollectionCount =
          widget.args.isCollection && !_scopedFilter.hasActiveFilters
          ? widget.args.collection!.itemCount
          : 0;
      final useOptimisticCollectionCount =
          page.hasMore &&
          showFullScreenLoader &&
          knownCollectionCount >= page.items.length;
      final initialCount = !page.hasMore
          ? page.items.length
          : (useOptimisticCollectionCount
                ? knownCollectionCount
                : page.items.length);
      final countPending = page.hasMore && !useOptimisticCollectionCount;

      final shouldResetEpoch =
          resetScroll &&
          _scrollController.hasClients &&
          _scrollController.offset > 1500.0;

      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _totalCount = initialCount;
        _isTotalCountPending = countPending;
        _hasMore = page.hasMore;
        _isLoading = false;
        _isLoadingMore = false;
        _paginationError = null;
        if (shouldResetEpoch) {
          _sliverResetEpoch++;
        }
      });

      if (page.hasMore) {
        _refreshTotalCountInBackground(filter, currentGen);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || currentGen != _generation) return;
        if (resetScroll &&
            _scrollController.hasClients &&
            _scrollController.offset > 0) {
          _scrollController.jumpTo(0);
        }
        if (_hasMore &&
            !_isLoadingMore &&
            _paginationError == null &&
            _scrollController.hasClients &&
            _scrollController.position.maxScrollExtent == 0) {
          _loadMore();
        }
      });
    } catch (e) {
      if (!mounted || currentGen != _generation) return;
      setState(() {
        _isLoading = false;
        _isTotalCountPending = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _refreshTotalCountInBackground(FilterCriteria filter, int targetGen) {
    unawaited(() async {
      try {
        final db = ref.read(databaseProvider);
        final count = await db.countFilteredSavedItems(filter);
        if (!mounted || targetGen != _generation) return;
        setState(() {
          _totalCount = count;
          _isTotalCountPending = false;
          _hasMore = _items.length < count;
        });
      } catch (_) {
        if (!mounted || targetGen != _generation) return;
        if (_isTotalCountPending) {
          setState(() {
            _isTotalCountPending = false;
          });
        }
      }
    }());
  }

  Future<void> _reloadInBackground() async {
    if (!mounted || _isLoading) return;
    final currentGen = _generation;

    try {
      final repo = ref.read(savedItemRepositoryProvider);
      final filter = _buildFilter();

      final targetLimit = _items.length <= _pageSize
          ? _pageSize
          : _items.length;

      final page = await repo.getSavedItemsPage(
        filter: filter,
        cursor: null,
        limit: targetLimit,
      );
      if (!mounted || currentGen != _generation || _isLoading) return;

      unawaited(_refreshScopedEntityNsfw(page.items));

      final count = page.hasMore
          ? await ref.read(databaseProvider).countFilteredSavedItems(filter)
          : page.items.length;

      if (!mounted || currentGen != _generation || _isLoading) return;

      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _totalCount = count;
        _isTotalCountPending = false;
        _hasMore = page.items.length < count;
      });
    } catch (_) {
      // do not wipe items on background update failure
    }
  }

  Future<void> _loadMore({bool isRetry = false}) async {
    if (_isLoading ||
        _isLoadingMore ||
        !_hasMore ||
        (!isRetry && _paginationError != null)) {
      return;
    }
    final currentGen = _generation;
    setState(() {
      _isLoadingMore = true;
      _paginationError = null;
    });

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
        _paginationError = null;
      });
    } catch (err) {
      if (mounted && currentGen == _generation) {
        setState(() {
          _isLoadingMore = false;
          _paginationError = err;
        });
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoading || _isLoadingMore || !_hasMore || _paginationError != null) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 2500) {
      _loadMore();
    }
  }

  void _onDbUpdate(Set<TableUpdate> updates) {
    if (!mounted) return;
    final until = _ignoreDbUpdatesUntil;
    if (until != null && DateTime.now().isBefore(until)) return;
    if (ref
        .read(savedItemRepositoryProvider)
        .shouldIgnoreSubredditTableUpdate(
          updates,
          effectiveIsNsfw: _buildFilter().isNsfw,
        )) {
      return;
    }

    final isBackgroundEnriching =
        ref.read(enrichmentViewModelProvider).isRunning ||
        ref.read(archiveRecoveryStateProvider).isRunning;
    if (isBackgroundEnriching && (_dbDebounceTimer?.isActive ?? false)) {
      return;
    }

    _dbDebounceTimer?.cancel();
    final delay = isBackgroundEnriching
        ? const Duration(milliseconds: 3000)
        : const Duration(milliseconds: 300);

    _dbDebounceTimer = Timer(delay, () {
      if (!mounted) return;
      final checkUntil = _ignoreDbUpdatesUntil;
      if (checkUntil != null && DateTime.now().isBefore(checkUntil)) return;
      if (_buildFilter().isNsfw != null) {
        unawaited(
          ref
              .read(savedItemRepositoryProvider)
              .ensureSubredditsEnrichedInBackground(),
        );
      }
      _reloadInBackground();
    });
  }

  void _onSearchChanged(String val) {
    if (val.trim().isNotEmpty) {
      _openedViaFilter = false;
    }
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final trimmed = val.trim();
      final nextFilter = _scopedFilter.copyWith(
        searchQuery: trimmed.isEmpty ? null : trimmed,
        clearSearchQuery: trimmed.isEmpty,
      );
      if (nextFilter == _scopedFilter) return;
      setState(() {
        _scopedFilter = nextFilter;
      });
      _loadInitial(resetScroll: true);
    });
  }

  void _onSearchSubmitted(String val) {
    _searchDebounceTimer?.cancel();
    final trimmed = val.trim();
    final nextFilter = _scopedFilter.copyWith(
      searchQuery: trimmed.isEmpty ? null : trimmed,
      clearSearchQuery: trimmed.isEmpty,
    );
    _searchFocusNode.unfocus();
    if (nextFilter == _scopedFilter) return;
    setState(() {
      _scopedFilter = nextFilter;
    });
    _loadInitial(resetScroll: true);
  }

  void _closeScopedSearch() {
    _dismissKeyboard();
    _searchDebounceTimer?.cancel();
    final hadQuery =
        _scopedFilter.searchQuery != null &&
        _scopedFilter.searchQuery!.isNotEmpty;
    _searchController.clear();
    setState(() {
      _openedViaFilter = false;
      _isFilterExpanded = false;
      _isSearchExpanded = false;
      if (hadQuery) {
        _scopedFilter = _scopedFilter.copyWith(clearSearchQuery: true);
      }
    });
    if (hadQuery) {
      _loadInitial(resetScroll: true);
    }
  }

  void _clearDesktopSearch() {
    _searchDebounceTimer?.cancel();
    final hadQuery =
        _scopedFilter.searchQuery != null &&
        _scopedFilter.searchQuery!.isNotEmpty;
    _searchController.clear();
    if (hadQuery) {
      setState(() {
        _scopedFilter = _scopedFilter.copyWith(clearSearchQuery: true);
      });
      _loadInitial(resetScroll: true);
    }
  }

  void _closeScopedFilter() {
    if (!_isFilterExpanded) return;
    setState(() {
      _isFilterExpanded = false;
    });
    if (_openedViaFilter) {
      _closeScopedSearch();
    }
  }

  void _openScopedSearch() {
    HapticFeedback.lightImpact();
    setState(() {
      _morphFromFilter = false;
      _openedViaFilter = false;
      _isSearchExpanded = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _searchFocusNode.canRequestFocus) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _toggleScopedFilterButton() {
    HapticFeedback.lightImpact();
    if (_isFilterExpanded) {
      _closeScopedFilter();
      return;
    }
    setState(() {
      if (!_isSearchExpanded) {
        _morphFromFilter = true;
        _openedViaFilter = true;
        _isSearchExpanded = true;
      } else {
        _openedViaFilter = false;
      }
      _isFilterExpanded = true;
    });
  }

  void _onScopedFilterChanged(FilterCriteria nextFilter) {
    if (nextFilter == _scopedFilter) return;
    setState(() {
      _scopedFilter = nextFilter;
    });
    _loadInitial(resetScroll: true);
  }

  void _openSortSheet(BuildContext context) {
    final excluded = <SortOption>{
      if (widget.args.isSubreddit) ...{
        SortOption.subredditAsc,
        SortOption.subredditDesc,
      },
      if (widget.args.isAuthor) ...{
        SortOption.authorAsc,
        SortOption.authorDesc,
      },
    };

    showFrostedModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SortSheet(
        currentSort: _scopedFilter.sortOption,
        excludedOptions: excluded,
        onSortSelected: (sort) {
          if (sort == _scopedFilter.sortOption) return;
          setState(() {
            _scopedFilter = _scopedFilter.copyWith(sortOption: sort);
          });
          _loadInitial(resetScroll: true);
        },
      ),
    );
  }

  Widget _buildScopedSearchBar({
    required ColorScheme colorScheme,
    required bool isDark,
    required bool hasActiveNonSearchFilters,
  }) {
    return Row(
      children: [
        const SizedBox(width: 4),
        Icon(Icons.search_rounded, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onTap: () {
              _openedViaFilter = false;
            },
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search in ${widget.args.title}...',
              hintStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: _onSearchChanged,
            onSubmitted: _onSearchSubmitted,
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            if (_isFilterExpanded) {
              setState(() {
                _isFilterExpanded = false;
              });
            } else {
              setState(() {
                _openedViaFilter = false;
                _isFilterExpanded = true;
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 19,
                  color: (hasActiveNonSearchFilters || _isFilterExpanded)
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                if (hasActiveNonSearchFilters)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 2),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            _closeScopedSearch();
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildScopedActionSurface(
    BuildContext context, {
    required bool enableFrosted,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasActiveNonSearchFilters = _scopedFilter.hasActiveNonSearchFilters;

    final baseDockSurface = isDark
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerHighest;
    final dockSurface = enableFrosted
        ? baseDockSurface.withValues(
            alpha: isDark ? kNavBarBlurAlphaDark : kNavBarBlurAlphaLight,
          )
        : baseDockSurface;
    final dockBorder = colorScheme.outlineVariant.withValues(
      alpha: isDark
          ? (enableFrosted ? 0.40 : 0.55)
          : (enableFrosted ? 0.35 : 0.45),
    );

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom > 0
        ? MediaQuery.viewInsetsOf(context).bottom
        : MediaQueryData.fromView(View.of(context)).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;

    final contextActions = [
      ContextActionSpec(
        key: 'scoped_open_search',
        tooltip: 'Search ${widget.args.title}',
        icon: Icons.search_rounded,
        isActive: _isSearchExpanded,
        onTap: _openScopedSearch,
      ),
      ContextActionSpec(
        key: 'scoped_filter',
        tooltip: 'Filter Items',
        icon: Icons.tune_rounded,
        isActive: hasActiveNonSearchFilters || _isFilterExpanded,
        hasBadge: hasActiveNonSearchFilters,
        onTap: _toggleScopedFilterButton,
      ),
    ];

    final cleanAuthor = widget.args.author?.replaceFirst(RegExp(r'^[ru]/'), '');

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: RepaintBoundary(
        child: SafeArea(
          top: false,
          bottom: !isKeyboardOpen,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, isKeyboardOpen ? 8 : 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth <= 0) {
                  return const SizedBox.shrink();
                }

                final m = NavBarLayoutMetrics.compute(
                  context: context,
                  maxAvailableWidth: constraints.maxWidth,
                  actionCount: contextActions.length,
                  bottomInset: bottomInset,
                  isKeyboardOpen: isKeyboardOpen,
                );

                return Center(
                  child: SizedBox(
                    width: m.totalBarWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          reverseDuration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return UnclippedSizeTransition(
                              sizeFactor: animation,
                              alignment: Alignment.bottomCenter,
                              child: child,
                            );
                          },
                          child: _isFilterExpanded
                              ? Padding(
                                  key: const ValueKey(
                                    'scoped_filter_sheet_expanded',
                                  ),
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: InteractiveFilterCard(
                                    width: m.totalBarWidth,
                                    height: m.cardHeight,
                                    onClose: () {
                                      HapticFeedback.lightImpact();
                                      _closeScopedFilter();
                                    },
                                    child: FrostedNavBarIsland(
                                      width: m.totalBarWidth,
                                      height: m.cardHeight,
                                      borderRadius: 24.0,
                                      surfaceColor: dockSurface,
                                      borderColor: dockBorder,
                                      isDark: isDark,
                                      enableBlur: enableFrosted,
                                      customShadow: const BoxShadow(
                                        color: Colors.transparent,
                                      ),
                                      child: FilterSheet(
                                        isFloatingCard: true,
                                        scopedFilter: _scopedFilter,
                                        onScopedFilterChanged:
                                            _onScopedFilterChanged,
                                        scopedCollectionId:
                                            widget.args.collection?.id,
                                        scopedSubreddit: widget.args.subreddit,
                                        scopedAuthor: cleanAuthor,
                                        onClose: () {
                                          HapticFeedback.lightImpact();
                                          _closeScopedFilter();
                                        },
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey(
                                    'scoped_filter_sheet_collapsed',
                                  ),
                                ),
                        ),

                        SizedBox(
                          width: m.totalBarWidth,
                          height: m.barHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (_morphFromFilter) ...[
                                Positioned(
                                  key: const ValueKey(
                                    'scoped_static_search_action',
                                  ),
                                  left: m.searchLeftNormal,
                                  top: m.actionButtonTop,
                                  width: kNavBarActionButtonSize,
                                  height: kNavBarActionButtonSize,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    opacity: _isSearchExpanded ? 0.0 : 1.0,
                                    child: IgnorePointer(
                                      ignoring: _isSearchExpanded,
                                      child: StandaloneFloatingActionButton(
                                        spec: contextActions[0],
                                        dockSurface: dockSurface,
                                        dockBorder: dockBorder,
                                        isDark: isDark,
                                        enableBlur: enableFrosted,
                                      ),
                                    ),
                                  ),
                                ),

                                AnimatedPositioned(
                                  key: const ValueKey(
                                    'scoped_morph_filter_action',
                                  ),
                                  duration: kNavBarExpandDuration,
                                  curve: Curves.fastOutSlowIn,
                                  left: _isSearchExpanded
                                      ? 0.0
                                      : m.filterLeftNormal,
                                  top: _isSearchExpanded
                                      ? m.dockTop
                                      : m.actionButtonTop,
                                  width: _isSearchExpanded
                                      ? m.totalBarWidth
                                      : kNavBarActionButtonSize,
                                  height: _isSearchExpanded
                                      ? m.dockHeight
                                      : kNavBarActionButtonSize,
                                  child: _isSearchExpanded
                                      ? FrostedNavBarIsland(
                                          animate: true,
                                          animationDuration:
                                              kNavBarExpandDuration,
                                          animationCurve: Curves.fastOutSlowIn,
                                          borderRadius: m.dockRadius,
                                          surfaceColor: dockSurface,
                                          borderColor: dockBorder,
                                          isDark: isDark,
                                          enableBlur: enableFrosted,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal:
                                                kNavBarSearchBarHorizontalPadding,
                                            vertical: kNavBarIslandPadding,
                                          ),
                                          child: SizedBox(
                                            height: m.tabButtonHeight,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              child: SizedBox(
                                                width: m.searchContentWidth,
                                                height: m.tabButtonHeight,
                                                child: _buildScopedSearchBar(
                                                  colorScheme: colorScheme,
                                                  isDark: isDark,
                                                  hasActiveNonSearchFilters:
                                                      hasActiveNonSearchFilters,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : StandaloneFloatingActionButton(
                                          spec: contextActions[1],
                                          dockSurface: dockSurface,
                                          dockBorder: dockBorder,
                                          isDark: isDark,
                                          enableBlur: enableFrosted,
                                        ),
                                ),
                              ] else ...[
                                Positioned(
                                  key: const ValueKey(
                                    'scoped_static_filter_action',
                                  ),
                                  left: m.filterLeftNormal,
                                  top: m.actionButtonTop,
                                  width: kNavBarActionButtonSize,
                                  height: kNavBarActionButtonSize,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    opacity: _isSearchExpanded ? 0.0 : 1.0,
                                    child: IgnorePointer(
                                      ignoring: _isSearchExpanded,
                                      child: StandaloneFloatingActionButton(
                                        spec: contextActions[1],
                                        dockSurface: dockSurface,
                                        dockBorder: dockBorder,
                                        isDark: isDark,
                                        enableBlur: enableFrosted,
                                      ),
                                    ),
                                  ),
                                ),

                                AnimatedPositioned(
                                  key: const ValueKey(
                                    'scoped_morph_search_action',
                                  ),
                                  duration: kNavBarExpandDuration,
                                  curve: Curves.fastOutSlowIn,
                                  left: _isSearchExpanded
                                      ? 0.0
                                      : m.searchLeftNormal,
                                  top: _isSearchExpanded
                                      ? m.dockTop
                                      : m.actionButtonTop,
                                  width: _isSearchExpanded
                                      ? m.totalBarWidth
                                      : kNavBarActionButtonSize,
                                  height: _isSearchExpanded
                                      ? m.dockHeight
                                      : kNavBarActionButtonSize,
                                  child: _isSearchExpanded
                                      ? FrostedNavBarIsland(
                                          animate: true,
                                          animationDuration:
                                              kNavBarExpandDuration,
                                          animationCurve: Curves.fastOutSlowIn,
                                          borderRadius: m.dockRadius,
                                          surfaceColor: dockSurface,
                                          borderColor: dockBorder,
                                          isDark: isDark,
                                          enableBlur: enableFrosted,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal:
                                                kNavBarSearchBarHorizontalPadding,
                                            vertical: kNavBarIslandPadding,
                                          ),
                                          child: SizedBox(
                                            height: m.tabButtonHeight,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              child: SizedBox(
                                                width: m.searchContentWidth,
                                                height: m.tabButtonHeight,
                                                child: _buildScopedSearchBar(
                                                  colorScheme: colorScheme,
                                                  isDark: isDark,
                                                  hasActiveNonSearchFilters:
                                                      hasActiveNonSearchFilters,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : StandaloneFloatingActionButton(
                                          spec: contextActions[0],
                                          dockSurface: dockSurface,
                                          dockBorder: dockBorder,
                                          isDark: isDark,
                                          enableBlur: enableFrosted,
                                        ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openInReddit(String subreddit) async {
    final rawTrimmed = subreddit.trim();
    final isUser = SavedItem.isUserSubreddit(rawTrimmed);
    final strippedSlash = rawTrimmed.replaceFirst(RegExp(r'^/?[ru]/'), '');
    final cleanName =
        (isUser &&
            (strippedSlash.startsWith('u_') || strippedSlash.startsWith('U_')))
        ? strippedSlash.substring(2)
        : strippedSlash;
    if (cleanName.isEmpty) return;
    final pathSegment = isUser ? 'user/$cleanName' : 'r/$cleanName';
    final uri = Uri.parse('https://www.reddit.com/$pathSegment/');
    try {
      await ExternalUrlLauncher.launch(uri);
    } catch (_) {}
  }

  Future<void> _openUserInReddit(String author) async {
    final cleanUser = author.replaceAll(RegExp(r'^[ru]/'), '');
    final uri = Uri.parse('https://www.reddit.com/user/$cleanUser/');
    try {
      await ExternalUrlLauncher.launch(uri);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final enableFrosted = watchFrostedEffects(ref);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    if (_lastIsDesktop == false && isDesktop && _isSearchExpanded) {
      _isSearchExpanded = false;
    }
    _lastIsDesktop = isDesktop;
    final feedLayoutMode = ref.watch(
      settingsViewModelProvider.select((s) => s.feedLayoutMode),
    );
    final hasActiveNonSearchFilters = _scopedFilter.hasActiveNonSearchFilters;

    void focusDesktopSearch() {
      if (_searchFocusNode.canRequestFocus) {
        _searchFocusNode.requestFocus();
        _searchController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _searchController.text.length,
        );
      }
    }

    final scaffold = LayoutBuilder(
      builder: (context, outerConstraints) {
        final paneWidth = outerConstraints.maxWidth;
        final searchWidth = (paneWidth * 0.25).clamp(160.0, 300.0);
        final showFilterLabel = paneWidth >= 1080.0;

        return SnackBarTheme(
          data: theme.snackBarTheme.copyWith(
            behavior: isDesktop
                ? SnackBarBehavior.floating
                : theme.snackBarTheme.behavior,
            width: isDesktop ? kDesktopSnackBarMaxWidth : null,
            insetPadding: isDesktop
                ? const EdgeInsets.fromLTRB(16, 6, 16, 16)
                : kFloatingBarSnackBarMargin,
          ),
          child: Scaffold(
            extendBodyBehindAppBar: enableFrosted,
            appBar: AppBar(
              titleSpacing: 0,
              backgroundColor: enableFrosted ? Colors.transparent : null,
              elevation: 0,
              scrolledUnderElevation: enableFrosted ? 0 : null,
              surfaceTintColor: enableFrosted ? Colors.transparent : null,
              flexibleSpace: FrostedAppBarBackground(enableBlur: enableFrosted),
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
                      if (!widget.args.isCollection && _isScopedEntityNsfw) ...[
                        const SizedBox(width: 8),
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
                  Text(
                    _isLoading && _items.isEmpty
                        ? 'Loading...'
                        : _isTotalCountPending
                        ? '$_totalCount+ saved items'
                        : '$_totalCount saved ${_totalCount == 1 ? 'item' : 'items'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              actions: [
                if (isDesktop) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: SizedBox(
                        width: searchWidth,
                        child: DesktopInlineSearchField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          hintText: searchWidth < 210
                              ? 'Search...'
                              : 'Search in ${widget.args.title}...',
                          onChanged: _onSearchChanged,
                          onSubmitted: _onSearchSubmitted,
                          onClear: _clearDesktopSearch,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Center(
                      child: DesktopFeedLayoutSwitcher(
                        currentMode: feedLayoutMode,
                        onChanged: (mode) => ref
                            .read(settingsViewModelProvider.notifier)
                            .setFeedLayoutMode(mode),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Center(
                      child: DesktopFilterToggleButton(
                        isOpen: _isFilterExpanded,
                        hasActiveFilters: hasActiveNonSearchFilters,
                        showLabel: showFilterLabel,
                        onPressed: () {
                          setState(() {
                            _isFilterExpanded = !_isFilterExpanded;
                          });
                        },
                      ),
                    ),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.sort_rounded),
                  tooltip: 'Sort: ${_scopedFilter.sortOption.label}',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _openSortSheet(context),
                ),
                if (widget.args.isSubreddit) ...[
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded),
                    tooltip: 'Open subreddit on Reddit',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openInReddit(widget.args.subreddit!),
                  ),
                ],
                if (widget.args.isAuthor &&
                    widget.args.author != '[deleted]') ...[
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded),
                    tooltip: 'Open user on Reddit',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openUserInReddit(widget.args.author!),
                  ),
                ],
                if (widget.args.isSubreddit ||
                    (widget.args.isAuthor && widget.args.author != '[deleted]'))
                  FrostedPopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    tooltip: 'More options',
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    style: IconButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onSelected: (value) {
                      if (value == 'toggle_nsfw') {
                        unawaited(_toggleScopedEntityNsfw());
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem<String>(
                        value: 'toggle_nsfw',
                        child: Row(
                          children: [
                            Icon(
                              _isScopedEntityNsfw
                                  ? Icons.verified_user_outlined
                                  : Icons.eighteen_up_rating_outlined,
                              size: 20,
                              color: _isScopedEntityNsfw
                                  ? colorScheme.primary
                                  : colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isScopedEntityNsfw
                                  ? 'Mark as SFW'
                                  : 'Mark as NSFW',
                              style: TextStyle(
                                color: _isScopedEntityNsfw
                                    ? colorScheme.onSurface
                                    : colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 4),
              ],
            ),
            body: Builder(
              builder: (bodyContext) {
                final appBarTopOffset = MediaQuery.paddingOf(bodyContext).top;
                final feedPane = KeyedSubtree(
                  key: _feedPaneKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: _isLoading && _items.isEmpty
                            ? Padding(
                                padding: EdgeInsets.only(top: appBarTopOffset),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _errorMessage != null && _items.isEmpty
                            ? Padding(
                                padding: EdgeInsets.only(top: appBarTopOffset),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                          onPressed: () => _loadInitial(
                                            showFullScreenLoader: true,
                                          ),
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : _buildFeedList(
                                bodyContext,
                                feedLayoutMode: feedLayoutMode,
                                topPadding: appBarTopOffset,
                                isDesktop: isDesktop,
                              ),
                      ),
                    ],
                  ),
                );

                final cleanAuthor = widget.args.author?.replaceFirst(
                  RegExp(r'^[ru]/'),
                  '',
                );
                if (isDesktop) {
                  return DesktopFilterPanelHost(
                    enabled: true,
                    isOpen: _isFilterExpanded,
                    availableWidth: paneWidth,
                    topPadding: appBarTopOffset,
                    enableFrosted: enableFrosted,
                    onClose: _closeScopedFilter,
                    feedChild: feedPane,
                    filterSheetChild: FilterSheet(
                      isSidePanel: true,
                      scopedFilter: _scopedFilter,
                      onScopedFilterChanged: _onScopedFilterChanged,
                      scopedCollectionId: widget.args.collection?.id,
                      scopedSubreddit: widget.args.subreddit,
                      scopedAuthor: cleanAuthor,
                      onClose: _closeScopedFilter,
                    ),
                  );
                }

                return Stack(
                  children: [
                    feedPane,
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !_isFilterExpanded,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          opacity: _isFilterExpanded ? 1.0 : 0.0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _closeScopedFilter,
                            onVerticalDragUpdate: (details) {
                              if ((details.primaryDelta ?? 0) > 6) {
                                _closeScopedFilter();
                              }
                            },
                            child: Container(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.40 : 0.22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildScopedActionSurface(
                      bodyContext,
                      enableFrosted: enableFrosted,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    final popWrapped = _ScopedFeedInherited(
      args: widget.args,
      child: PopScope(
        canPop: isDesktop
            ? !_isFilterExpanded
            : (!_isSearchExpanded && !_isFilterExpanded),
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_isFilterExpanded) {
            _closeScopedFilter();
          } else if (_isSearchExpanded) {
            _closeScopedSearch();
          }
        },
        child: scaffold,
      ),
    );

    return CallbackShortcuts(
      bindings: isDesktop
          ? {
              const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                  focusDesktopSearch,
              const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                  focusDesktopSearch,
              const SingleActivator(
                LogicalKeyboardKey.escape,
                includeRepeats: false,
              ): () {
                final primaryFocus = FocusManager.instance.primaryFocus;
                if (_searchFocusNode.hasFocus) {
                  _searchFocusNode.unfocus();
                } else if (ResponsiveLayout.isEditableTextFocused(
                  primaryFocus,
                )) {
                  primaryFocus!.unfocus();
                } else if (_isFilterExpanded) {
                  _closeScopedFilter();
                } else if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.of(context).maybePop();
                }
              },
            }
          : const {},
      child: FocusScope(
        node: _shortcutFocusScopeNode,
        autofocus: true,
        child: popWrapped,
      ),
    );
  }

  Widget _buildPaginationFooter() {
    if (_paginationError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: TextButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Failed to load more. Tap to retry'),
            onPressed: () => _loadMore(isRetry: true),
          ),
        ),
      );
    }

    if (_isLoadingMore) {
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

  Widget _buildFeedList(
    BuildContext context, {
    required FeedLayoutMode feedLayoutMode,
    double topPadding = 0,
    bool isDesktop = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPad = isDesktop ? 28.0 : 104.0;

    if (_items.isEmpty) {
      final isSearching =
          _scopedFilter.searchQuery != null &&
          _scopedFilter.searchQuery!.isNotEmpty;
      final isFiltered = _scopedFilter.hasActiveNonSearchFilters;

      return Center(
        child: SingleChildScrollView(
          primary: false,
          padding: EdgeInsets.fromLTRB(32, topPadding + 32, 32, bottomPad),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
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
                            : (widget.args.isAuthor
                                  ? Icons.person_outline_rounded
                                  : Icons.tag_rounded)),
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
                          : (widget.args.isAuthor
                                ? 'No saved items by this user'
                                : 'No saved items in this subreddit')),
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
                          : (widget.args.isAuthor
                                ? 'Saved posts or comments by ${widget.args.title} will appear here.'
                                : 'Saved posts or comments from this subreddit will appear here.')),
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
                    _searchDebounceTimer?.cancel();
                    setState(() {
                      if (isSearching) {
                        _searchController.clear();
                      }
                      _scopedFilter = FilterCriteria(
                        sortOption: _scopedFilter.sortOption,
                        groupCommentsByPost: _scopedFilter.groupCommentsByPost,
                      );
                    });
                    _loadInitial(resetScroll: true);
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
        ),
      );
    }

    final showFooter = _hasMore || _isLoadingMore || _paginationError != null;
    final Widget scrollContent = LayoutBuilder(
      builder: (feedContext, feedConstraints) {
        final feedWidth = feedConstraints.maxWidth;
        switch (feedLayoutMode) {
          case FeedLayoutMode.card:
          case FeedLayoutMode.compact:
            final maxW = feedLayoutMode == FeedLayoutMode.compact
                ? kFeedCompactMaxWidth
                : kFeedCardMaxWidth;
            final hPad = isDesktop
                ? ResponsiveLayout.centeredHorizontalPadding(
                    feedWidth,
                    maxContentWidth: maxW,
                    minPadding: 20,
                  )
                : 0.0;
            final effectiveTop =
                topPadding +
                (isDesktop
                    ? (feedLayoutMode == FeedLayoutMode.card ? 12.0 : 8.0)
                    : 0.0);
            return CustomScrollView(
              key: const PageStorageKey<String>('scoped_feed_scroll'),
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  key: ValueKey('scoped_feed_list_$_sliverResetEpoch'),
                  padding: EdgeInsets.fromLTRB(
                    hPad,
                    effectiveTop,
                    hPad,
                    bottomPad,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index >= _items.length) {
                        return _buildPaginationFooter();
                      }
                      final item = _items[index];
                      if (feedLayoutMode == FeedLayoutMode.compact) {
                        return CompactListItem(
                          key: ValueKey(item.id),
                          item: item,
                        );
                      }
                      if (item.isComment) {
                        return CommentCard(
                          key: ValueKey(item.id),
                          item: item,
                          isDesktopCard: isDesktop,
                        );
                      }
                      return PostCard(
                        key: ValueKey(item.id),
                        item: item,
                        isDesktopCard: isDesktop,
                      );
                    }, childCount: _items.length + (showFooter ? 1 : 0)),
                  ),
                ),
              ],
            );

          case FeedLayoutMode.gallery:
            return CustomScrollView(
              key: const PageStorageKey<String>('scoped_feed_scroll'),
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  key: ValueKey('scoped_feed_grid_$_sliverResetEpoch'),
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 20 : 10,
                    topPadding + (isDesktop ? 12 : 8),
                    isDesktop ? 20 : 10,
                    bottomPad,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: isDesktop
                        ? const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: kGalleryMaxCrossAxisExtent,
                            childAspectRatio: 0.82,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          )
                        : const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.82,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = _items[index];
                      return GalleryItem(key: ValueKey(item.id), item: item);
                    }, childCount: _items.length),
                  ),
                ),
                if (showFooter)
                  SliverToBoxAdapter(child: _buildPaginationFooter()),
              ],
            );
        }
      },
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 2500) {
          _loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        edgeOffset: topPadding,
        onRefresh: _loadInitial,
        child: scrollContent,
      ),
    );
  }
}
