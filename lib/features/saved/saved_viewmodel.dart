import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';
import 'package:savedex/features/search/search_viewmodel.dart';

class SavedFeedState {
  final List<SavedItem> items;
  final FeedCursor? nextCursor;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? paginationError;

  const SavedFeedState({
    this.items = const [],
    this.nextCursor,
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.paginationError,
  });

  SavedFeedState copyWith({
    List<SavedItem>? items,
    FeedCursor? nextCursor,
    bool clearCursor = false,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    Object? paginationError,
    bool clearError = false,
  }) {
    return SavedFeedState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      paginationError: clearError
          ? null
          : (paginationError ?? this.paginationError),
    );
  }
}

final savedFeedPaginationProvider =
    AsyncNotifierProvider<SavedFeedPaginationNotifier, SavedFeedState>(
      SavedFeedPaginationNotifier.new,
    );

class SavedFeedPaginationNotifier extends AsyncNotifier<SavedFeedState> {
  static const int _pageSize = 100;
  int _generation = 0;
  StreamSubscription? _dbUpdatesSub;
  Timer? _debounceTimer;

  @override
  Future<SavedFeedState> build() async {
    _generation++;
    final currentGen = _generation;

    final filter = ref.watch(searchFilterViewModelProvider);
    final repo = ref.watch(savedItemRepositoryProvider);
    final db = ref.watch(databaseProvider);

    _dbUpdatesSub?.cancel();
    _debounceTimer?.cancel();

    _dbUpdatesSub = db.tableUpdates().listen((_) => _onTableUpdate());

    ref.onDispose(() {
      _dbUpdatesSub?.cancel();
      _debounceTimer?.cancel();
    });

    final results = await Future.wait([
      repo.getSavedItemsPage(filter: filter, cursor: null, limit: _pageSize),
      db.countFilteredSavedItems(filter),
    ]);

    if (currentGen != _generation) {
      return state.value ?? const SavedFeedState();
    }

    final page = results[0] as PagedRows<SavedItem>;
    final totalCount = results[1] as int;

    return SavedFeedState(
      items: page.items,
      nextCursor: page.nextCursor,
      totalCount: totalCount,
      hasMore: page.hasMore,
      isLoadingMore: false,
    );
  }

  static FeedCursor _extractCursorFromItem(SavedItem item, SortOption sort) {
    switch (sort) {
      case SortOption.savedOrderDesc:
      case SortOption.savedOrderAsc:
        return FeedCursor(sortValue: item.importOrder, id: item.id);
      case SortOption.createdDateDesc:
      case SortOption.createdDateAsc:
        return FeedCursor(
          sortValue: item.createdAtUtc?.millisecondsSinceEpoch ?? 0,
          id: item.id,
        );
      case SortOption.scoreDesc:
      case SortOption.scoreAsc:
        return FeedCursor(sortValue: item.score, id: item.id);
      case SortOption.subredditAsc:
      case SortOption.subredditDesc:
        return FeedCursor(sortValue: item.subreddit, id: item.id);
      case SortOption.authorAsc:
      case SortOption.authorDesc:
        return FeedCursor(sortValue: item.author ?? '', id: item.id);
      case SortOption.titleAsc:
        return FeedCursor(sortValue: item.title, id: item.id);
      case SortOption.commentsDesc:
        return FeedCursor(sortValue: item.numComments, id: item.id);
    }
  }

  static bool _itemMatchesFilter(SavedItem item, FilterCriteria f) {
    if (f.isStarred != null && item.isStarred != f.isStarred) return false;
    if (f.isArchived != null && item.isArchived != f.isArchived) return false;
    if (f.isNsfw != null && item.isNsfw != f.isNsfw) return false;
    if (f.itemType != null && item.itemType != f.itemType) return false;
    if (f.enrichmentStatus != null &&
        item.enrichmentStatus != f.enrichmentStatus) {
      return false;
    }
    if (f.selectedSubreddits.isNotEmpty &&
        !f.selectedSubreddits.contains(item.subreddit)) {
      return false;
    }
    if (f.selectedAuthors.isNotEmpty &&
        !f.selectedAuthors.contains(item.author)) {
      return false;
    }
    if (f.selectedFlairs.isNotEmpty &&
        (item.postFlair == null ||
            !f.selectedFlairs.contains(item.postFlair))) {
      return false;
    }
    if (f.selectedMediaTypes.isNotEmpty &&
        !f.selectedMediaTypes.contains(item.mediaType)) {
      return false;
    }
    if (f.dateRangeStart != null &&
        item.createdAtUtc != null &&
        item.createdAtUtc!.isBefore(f.dateRangeStart!)) {
      return false;
    }
    if (f.dateRangeEnd != null &&
        item.createdAtUtc != null &&
        item.createdAtUtc!.isAfter(f.dateRangeEnd!)) {
      return false;
    }
    if (f.selectedTagIds.isNotEmpty) {
      final itemTagIds = item.tags.map((t) => t.id).toSet();
      if (!f.selectedTagIds.any(itemTagIds.contains)) return false;
    }
    if (f.searchQuery != null && f.searchQuery!.trim().isNotEmpty) {
      final q = f.searchQuery!.trim().toLowerCase();
      final title = item.title.toLowerCase();
      final body = item.body?.toLowerCase() ?? '';
      final parentPostTitle = item.parentPostTitle?.toLowerCase() ?? '';
      final note = item.userNote?.toLowerCase() ?? '';
      if (!title.contains(q) &&
          !body.contains(q) &&
          !parentPostTitle.contains(q) &&
          !note.contains(q)) {
        return false;
      }
    }
    return true;
  }

  void _onTableUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () async {
      final current = state.value;
      if (current == null) return;

      final repo = ref.read(savedItemRepositoryProvider);
      final filter = ref.read(searchFilterViewModelProvider);
      final db = ref.read(databaseProvider);
      final gen = _generation;

      final totalCount = await db.countFilteredSavedItems(filter);
      if (gen != _generation) return;
      final latest = state.value;
      if (latest == null) return;

      if (totalCount == 0) {
        state = AsyncData(
          latest.copyWith(
            items: const [],
            nextCursor: null,
            clearCursor: true,
            totalCount: 0,
            hasMore: false,
          ),
        );
        return;
      }

      // on empty or initial pages (<= 200 items)
      final targetFetchCount = current.items.length <= _pageSize
          ? _pageSize
          : current.items.length;

      if (current.items.length <= 200) {
        final page = await repo.getSavedItemsPage(
          filter: filter,
          cursor: null,
          limit: targetFetchCount,
        );

        if (gen != _generation) return;
        final currentLatest = state.value;
        if (currentLatest == null) return;

        state = AsyncData(
          currentLatest.copyWith(
            items: page.items,
            nextCursor: page.nextCursor,
            clearCursor: page.nextCursor == null,
            totalCount: totalCount,
            hasMore: page.items.length < totalCount,
          ),
        );
        return;
      }

      final allLoadedIds = current.items.map((i) => i.id).toList();
      final freshItems = await repo.getItemsByIds(allLoadedIds);

      if (gen != _generation) return;
      final currentLatest = state.value;
      if (currentLatest == null) return;

      final freshMap = {for (final i in freshItems) i.id: i};

      final updatedList = <SavedItem>[];
      for (final item in currentLatest.items) {
        final fresh = freshMap[item.id];
        if (fresh != null && _itemMatchesFilter(fresh, filter)) {
          updatedList.add(fresh);
        }
      }

      FeedCursor? nextCursor;
      if (updatedList.isNotEmpty) {
        nextCursor = _extractCursorFromItem(
          updatedList.last,
          filter.sortOption,
        );
      }

      state = AsyncData(
        currentLatest.copyWith(
          items: updatedList,
          nextCursor: nextCursor,
          clearCursor: nextCursor == null,
          totalCount: totalCount,
          hasMore: updatedList.length < totalCount,
        ),
      );
    });
  }

  Future<void> retryNextPage() => fetchNextPage(isRetry: true);

  Future<void> fetchNextPage({bool isRetry = false}) async {
    final current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        (!isRetry && current.paginationError != null)) {
      return;
    }

    final filter = ref.read(searchFilterViewModelProvider);
    final repo = ref.read(savedItemRepositoryProvider);
    final gen = _generation;

    state = AsyncData(current.copyWith(isLoadingMore: true, clearError: true));

    try {
      final page = await repo.getSavedItemsPage(
        filter: filter,
        cursor: current.nextCursor,
        limit: _pageSize,
      );

      if (gen != _generation) return;
      final latest = state.value;
      if (latest == null) return;

      final existingIds = latest.items.map((i) => i.id).toSet();
      final newItems = page.items
          .where((i) => !existingIds.contains(i.id))
          .toList();

      state = AsyncData(
        latest.copyWith(
          items: [...latest.items, ...newItems],
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (err) {
      if (gen != _generation) return;
      final latest = state.value;
      if (latest != null) {
        state = AsyncData(
          latest.copyWith(isLoadingMore: false, paginationError: err),
        );
      }
    }
  }

  Future<void> toggleStar(SavedItem item) async {
    final prev = state.value;
    final filter = ref.read(searchFilterViewModelProvider);
    final newStarred = !item.isStarred;

    if (prev != null) {
      if (filter.isStarred == true && !newStarred) {
        state = AsyncData(
          prev.copyWith(
            items: prev.items.where((i) => i.id != item.id).toList(),
            totalCount: prev.totalCount > 0 ? prev.totalCount - 1 : 0,
          ),
        );
      } else {
        state = AsyncData(
          prev.copyWith(
            items: prev.items
                .map(
                  (i) =>
                      i.id == item.id ? i.copyWith(isStarred: newStarred) : i,
                )
                .toList(),
          ),
        );
      }
    }

    try {
      await ref
          .read(savedItemRepositoryProvider)
          .toggleStar(item.id, newStarred);
    } catch (e) {
      if (prev != null) state = AsyncData(prev);
      rethrow;
    }
  }

  Future<void> toggleArchive(SavedItem item) async {
    final prev = state.value;
    final filter = ref.read(searchFilterViewModelProvider);
    final newArchived = !item.isArchived;

    if (prev != null) {
      if (filter.isArchived != null && filter.isArchived != newArchived) {
        state = AsyncData(
          prev.copyWith(
            items: prev.items.where((i) => i.id != item.id).toList(),
            totalCount: prev.totalCount > 0 ? prev.totalCount - 1 : 0,
          ),
        );
      } else {
        state = AsyncData(
          prev.copyWith(
            items: prev.items
                .map(
                  (i) =>
                      i.id == item.id ? i.copyWith(isArchived: newArchived) : i,
                )
                .toList(),
          ),
        );
      }
    }

    try {
      await ref
          .read(savedItemRepositoryProvider)
          .toggleArchive(item.id, newArchived);
    } catch (e) {
      if (prev != null) state = AsyncData(prev);
      rethrow;
    }
  }

  Future<void> deleteItemById(String id) async {
    final prev = state.value;
    if (prev != null) {
      final hadItem = prev.items.any((i) => i.id == id);
      if (hadItem) {
        state = AsyncData(
          prev.copyWith(
            items: prev.items.where((i) => i.id != id).toList(),
            totalCount: prev.totalCount > 0 ? prev.totalCount - 1 : 0,
          ),
        );
      }
    }

    try {
      await ref.read(savedItemRepositoryProvider).deleteItem(id);
    } catch (e) {
      if (prev != null) state = AsyncData(prev);
      rethrow;
    }
  }

  Future<void> deleteItem(SavedItem item) => deleteItemById(item.id);

  Future<void> updateItemNote(String id, String? note) async {
    final prev = state.value;
    final cleanNote = (note == null || note.trim().isEmpty)
        ? null
        : note.trim();
    if (prev != null) {
      state = AsyncData(
        prev.copyWith(
          items: prev.items
              .map((i) => i.id == id ? i.copyWith(userNote: cleanNote) : i)
              .toList(),
        ),
      );
    }

    try {
      await ref.read(savedItemRepositoryProvider).updateUserNote(id, cleanNote);
    } catch (e) {
      if (prev != null) state = AsyncData(prev);
      rethrow;
    }
  }

  void updateItem(SavedItem updatedItem) {
    final prev = state.value;
    if (prev == null) return;
    final filter = ref.read(searchFilterViewModelProvider);
    final inList = prev.items.any((i) => i.id == updatedItem.id);
    final matches = _itemMatchesFilter(updatedItem, filter);

    if (inList) {
      if (matches) {
        state = AsyncData(
          prev.copyWith(
            items: prev.items
                .map((i) => i.id == updatedItem.id ? updatedItem : i)
                .toList(),
          ),
        );
      } else {
        state = AsyncData(
          prev.copyWith(
            items: prev.items.where((i) => i.id != updatedItem.id).toList(),
            totalCount: prev.totalCount > 0 ? prev.totalCount - 1 : 0,
          ),
        );
      }
    } else if (matches) {
      state = AsyncData(
        prev.copyWith(
          items: [updatedItem, ...prev.items],
          totalCount: prev.totalCount + 1,
        ),
      );
    }
  }

  Future<void> refreshItem(String id) async {
    final current = state.value;
    if (current == null) return;

    final repo = ref.read(savedItemRepositoryProvider);
    final freshItem = await repo.getItemById(id);
    final filter = ref.read(searchFilterViewModelProvider);
    final latest = state.value;
    if (latest == null) return;

    final inList = latest.items.any((i) => i.id == id);

    if (freshItem == null) {
      if (inList) {
        state = AsyncData(
          latest.copyWith(
            items: latest.items.where((i) => i.id != id).toList(),
            totalCount: latest.totalCount > 0 ? latest.totalCount - 1 : 0,
          ),
        );
      }
      return;
    }

    final matches = _itemMatchesFilter(freshItem, filter);
    if (inList) {
      if (matches) {
        state = AsyncData(
          latest.copyWith(
            items: latest.items.map((i) => i.id == id ? freshItem : i).toList(),
          ),
        );
      } else {
        state = AsyncData(
          latest.copyWith(
            items: latest.items.where((i) => i.id != id).toList(),
            totalCount: latest.totalCount > 0 ? latest.totalCount - 1 : 0,
          ),
        );
      }
    } else if (matches) {
      state = AsyncData(
        latest.copyWith(
          items: [freshItem, ...latest.items],
          totalCount: latest.totalCount + 1,
        ),
      );
    }
  }

  Future<void> enrichItem(SavedItem item) async {
    await ref.read(enrichmentViewModelProvider.notifier).enrichSingleItem(item);
  }

  void clearFeed() {
    _debounceTimer?.cancel();
    state = const AsyncData(
      SavedFeedState(
        items: [],
        nextCursor: null,
        totalCount: 0,
        hasMore: false,
        isLoadingMore: false,
      ),
    );
  }
}

final savedViewModelProvider = NotifierProvider<SavedViewModel, void>(() {
  return SavedViewModel();
});

class SavedViewModel extends Notifier<void> {
  final _busyItemIds = <String>{};

  @override
  void build() {
    _busyItemIds.clear();
  }

  Future<void> toggleStar(SavedItem item) async {
    if (!_busyItemIds.add(item.id)) return;
    try {
      await ref.read(savedFeedPaginationProvider.notifier).toggleStar(item);
    } finally {
      _busyItemIds.remove(item.id);
    }
  }

  Future<void> toggleArchive(SavedItem item) async {
    if (!_busyItemIds.add(item.id)) return;
    try {
      await ref.read(savedFeedPaginationProvider.notifier).toggleArchive(item);
    } finally {
      _busyItemIds.remove(item.id);
    }
  }

  Future<void> deleteItem(SavedItem item) => deleteItemById(item.id);

  Future<void> deleteItemById(String id) async {
    if (!_busyItemIds.add(id)) return;
    try {
      await ref.read(savedFeedPaginationProvider.notifier).deleteItemById(id);
    } finally {
      _busyItemIds.remove(id);
    }
  }

  Future<void> updateItemNote(String id, String? note) async {
    if (!_busyItemIds.add(id)) return;
    try {
      await ref
          .read(savedFeedPaginationProvider.notifier)
          .updateItemNote(id, note);
    } finally {
      _busyItemIds.remove(id);
    }
  }

  Future<void> enrichItem(SavedItem item) async {
    await ref.read(enrichmentViewModelProvider.notifier).enrichSingleItem(item);
  }

  void clearFeed() {
    ref.read(savedFeedPaginationProvider.notifier).clearFeed();
  }
}
