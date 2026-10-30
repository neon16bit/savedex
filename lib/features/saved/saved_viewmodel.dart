import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';
import 'package:savedex/features/search/search_viewmodel.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';

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
  static const int _pageSize = 50;
  int _generation = 0;
  int _localMutationsInProgress = 0;
  DateTime? _ignoreTableUpdatesUntil;
  final Set<String> _busyItemIds = <String>{};
  StreamSubscription? _dbUpdatesSub;
  Timer? _debounceTimer;
  final StreamController<({String itemId, SavedItem? item, bool deleted})>
  _itemMutationController =
      StreamController<
        ({String itemId, SavedItem? item, bool deleted})
      >.broadcast();

  Stream<({String itemId, SavedItem? item, bool deleted})> get itemMutations =>
      _itemMutationController.stream;

  void _suppressTableUpdates([
    Duration duration = const Duration(milliseconds: 600),
  ]) {
    _ignoreTableUpdatesUntil = DateTime.now().add(duration);
    _debounceTimer?.cancel();
  }

  bool get _shouldIgnoreTableUpdate {
    if (_localMutationsInProgress > 0) return true;
    final until = _ignoreTableUpdatesUntil;
    if (until != null && DateTime.now().isBefore(until)) return true;
    return false;
  }

  bool isItemBusy(String id) => _busyItemIds.contains(id);

  FilterCriteria _getEffectiveFilter() {
    final filter = ref.read(searchFilterViewModelProvider);
    final hideNsfw = ref.read(settingsViewModelProvider).hideNsfwInFeed;
    if (filter.isNsfw != null) {
      return filter;
    }
    if (hideNsfw) {
      return filter.copyWith(isNsfw: false);
    }
    return filter;
  }

  @override
  Future<SavedFeedState> build() async {
    _generation++;
    final currentGen = _generation;

    final filter = ref.watch(searchFilterViewModelProvider);
    final hideNsfw = ref.watch(
      settingsViewModelProvider.select((s) => s.hideNsfwInFeed),
    );
    final repo = ref.watch(savedItemRepositoryProvider);
    final db = ref.watch(databaseProvider);

    final effectiveFilter = filter.isNsfw != null
        ? filter
        : (hideNsfw ? filter.copyWith(isNsfw: false) : filter);

    _dbUpdatesSub?.cancel();
    _debounceTimer?.cancel();

    _dbUpdatesSub = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            db.savedItemsTable,
            db.collectionsTable,
            db.itemCollectionsTable,
          ]),
        )
        .listen((_) => _onTableUpdate());

    ref.onDispose(() {
      _dbUpdatesSub?.cancel();
      _debounceTimer?.cancel();
      _busyItemIds.clear();
    });

    final page = await repo.getSavedItemsPage(
      filter: effectiveFilter,
      cursor: null,
      limit: _pageSize,
    );

    if (currentGen != _generation) {
      return state.value ?? const SavedFeedState();
    }

    _loadTotalCountInBackground(effectiveFilter, currentGen);

    return SavedFeedState(
      items: page.items,
      nextCursor: page.nextCursor,
      totalCount: 0,
      hasMore: page.hasMore,
      isLoadingMore: false,
    );
  }

  void _loadTotalCountInBackground(FilterCriteria filter, int targetGen) {
    unawaited(() async {
      try {
        final db = ref.read(databaseProvider);
        final count = await db.countFilteredSavedItems(filter);
        if (targetGen != _generation) return;
        final current = state.value;
        if (current == null) return;
        state = AsyncData(
          current.copyWith(
            totalCount: count,
            hasMore: current.items.length < count,
          ),
        );
      } catch (e, st) {
        debugPrint('[SavedFeed] Background count note: $e\n$st');
      }
    }());
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
    if (f.dateRangeStart != null || f.dateRangeEnd != null) {
      final createdAt = item.createdAtUtc?.toUtc();
      if (createdAt == null) return false;
      if (f.dateRangeStart != null &&
          createdAt.isBefore(f.dateRangeStart!.toUtc())) {
        return false;
      }
      if (f.dateRangeEnd != null) {
        final end = f.dateRangeEnd!;
        final inclusiveEnd =
            (end.hour == 0 &&
                end.minute == 0 &&
                end.second == 0 &&
                end.millisecond == 0)
            ? DateTime(end.year, end.month, end.day, 23, 59, 59, 999).toUtc()
            : end.toUtc();
        if (createdAt.isAfter(inclusiveEnd)) {
          return false;
        }
      }
    }
    if (f.selectedCollectionIds.isNotEmpty) {
      final itemCollectionIds = item.collections.map((c) => c.id).toSet();
      if (!f.selectedCollectionIds.any(itemCollectionIds.contains)) {
        return false;
      }
    }
    if (f.searchQuery != null && f.searchQuery!.trim().isNotEmpty) {
      final terms = f.searchQuery!
          .trim()
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty);
      final searchableText =
          '${item.title} ${item.body ?? ''} ${item.parentPostTitle ?? ''} ${item.userNote ?? ''}'
              .toLowerCase();
      if (!terms.every(searchableText.contains)) {
        return false;
      }
    }
    return true;
  }

  void _onTableUpdate() {
    if (_shouldIgnoreTableUpdate) return;

    final isBackgroundEnriching =
        ref.read(enrichmentViewModelProvider).isRunning ||
        ref.read(archiveRecoveryStateProvider).isRunning;

    // during background enrichment, throttle feed refreshes to
    // at most once every 3 seconds instead of requerying thousands of rows after
    // every single HTTP request (~300-500ms)
    if (isBackgroundEnriching && (_debounceTimer?.isActive ?? false)) {
      return;
    }

    _debounceTimer?.cancel();
    final delay = isBackgroundEnriching
        ? const Duration(milliseconds: 3000)
        : const Duration(milliseconds: 300);

    _debounceTimer = Timer(delay, () async {
      if (_shouldIgnoreTableUpdate) return;
      final current = state.value;
      if (current == null) return;

      final repo = ref.read(savedItemRepositoryProvider);
      final filter = _getEffectiveFilter();
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

      final targetFetchCount = current.items.length <= _pageSize
          ? _pageSize
          : current.items.length;

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
    });
  }

  Future<void> retryNextPage() => fetchNextPage(isRetry: true);

  // cancel any inflight pagination fetch and trims accumulated items back to
  //  the first page when jumping back to the top from deep in the feed
  void trimToFirstPage() {
    final current = state.value;
    if (current == null) return;
    if (current.items.length <= _pageSize && !current.isLoadingMore) return;

    _generation++;
    if (current.items.length <= _pageSize) {
      state = AsyncData(
        current.copyWith(isLoadingMore: false, clearError: true),
      );
      return;
    }

    final filter = _getEffectiveFilter();
    final trimmed = current.items.sublist(0, _pageSize);
    final nextCursor = _extractItemCursor(trimmed.last, filter.sortOption);

    state = AsyncData(
      current.copyWith(
        items: trimmed,
        nextCursor: nextCursor,
        hasMore: true,
        isLoadingMore: false,
        clearError: true,
      ),
    );
  }

  static FeedCursor _extractItemCursor(SavedItem item, SortOption sort) {
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

  Future<void> fetchNextPage({bool isRetry = false}) async {
    final current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        (!isRetry && current.paginationError != null)) {
      return;
    }

    final filter = _getEffectiveFilter();
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

  Future<void> _runOptimisticMutation({
    required String? itemId,
    required SavedFeedState Function(SavedFeedState current) optimisticUpdate,
    SavedFeedState Function(SavedFeedState current)? rollback,
    required Future<void> Function() persist,
  }) async {
    if (itemId != null && !_busyItemIds.add(itemId)) {
      return;
    }
    final prev = state.value;
    if (prev != null) {
      state = AsyncData(optimisticUpdate(prev));
    }
    _localMutationsInProgress++;
    _suppressTableUpdates();
    try {
      await persist();
      _suppressTableUpdates();
    } catch (e) {
      final current = state.value;
      if (rollback != null && current != null) {
        state = AsyncData(rollback(current));
      } else if (prev != null) {
        state = AsyncData(prev);
      }
      rethrow;
    } finally {
      _localMutationsInProgress--;
      _suppressTableUpdates();
      if (itemId != null) {
        _busyItemIds.remove(itemId);
      }
    }
  }

  Future<void> toggleStar(SavedItem item) async {
    final filter = _getEffectiveFilter();
    final newStarred = !item.isStarred;
    final updated = item.copyWith(isStarred: newStarred);

    await _runOptimisticMutation(
      itemId: item.id,
      optimisticUpdate: (prev) {
        if (filter.isStarred == true && !newStarred) {
          return prev.copyWith(
            items: prev.items.where((i) => i.id != item.id).toList(),
            totalCount: prev.totalCount > 0 ? prev.totalCount - 1 : 0,
          );
        } else {
          return prev.copyWith(
            items: prev.items
                .map((i) => i.id == item.id ? updated : i)
                .toList(),
          );
        }
      },
      persist: () =>
          ref.read(savedItemRepositoryProvider).toggleStar(item.id, newStarred),
    );
    _itemMutationController.add((
      itemId: item.id,
      item: updated,
      deleted: false,
    ));
  }

  Future<void> toggleArchive(SavedItem item) async {
    final filter = _getEffectiveFilter();
    final newArchived = !item.isArchived;
    final updated = item.copyWith(isArchived: newArchived);

    await _runOptimisticMutation(
      itemId: item.id,
      optimisticUpdate: (prev) {
        if (filter.isArchived != null && filter.isArchived != newArchived) {
          return prev.copyWith(
            items: prev.items.where((i) => i.id != item.id).toList(),
            totalCount: prev.totalCount > 0 ? prev.totalCount - 1 : 0,
          );
        } else {
          return prev.copyWith(
            items: prev.items
                .map((i) => i.id == item.id ? updated : i)
                .toList(),
          );
        }
      },
      persist: () => ref
          .read(savedItemRepositoryProvider)
          .toggleArchive(item.id, newArchived),
    );
    _itemMutationController.add((
      itemId: item.id,
      item: updated,
      deleted: false,
    ));
  }

  Future<void> deleteItemById(String id) async {
    await _runOptimisticMutation(
      itemId: id,
      optimisticUpdate: (prev) {
        final hadItem = prev.items.any((i) => i.id == id);
        if (!hadItem) return prev;
        return prev.copyWith(
          items: prev.items.where((i) => i.id != id).toList(),
          totalCount: prev.totalCount > 0 ? prev.totalCount - 1 : 0,
        );
      },
      persist: () => ref.read(savedItemRepositoryProvider).deleteItem(id),
    );
    _itemMutationController.add((itemId: id, item: null, deleted: true));
  }

  Future<void> deleteItem(SavedItem item) => deleteItemById(item.id);

  Future<void> updateItemNote(String id, String? note) async {
    final cleanNote = (note == null || note.trim().isEmpty)
        ? null
        : note.trim();
    SavedItem? mutatedItem;
    await _runOptimisticMutation(
      itemId: id,
      optimisticUpdate: (prev) => prev.copyWith(
        items: prev.items.map((i) {
          if (i.id == id) {
            mutatedItem = cleanNote == null
                ? i.copyWith(clearUserNote: true)
                : i.copyWith(userNote: cleanNote);
            return mutatedItem!;
          }
          return i;
        }).toList(),
      ),
      persist: () =>
          ref.read(savedItemRepositoryProvider).updateUserNote(id, cleanNote),
    );
    if (mutatedItem != null) {
      _itemMutationController.add((
        itemId: id,
        item: mutatedItem,
        deleted: false,
      ));
    } else {
      await refreshItem(id);
    }
  }

  Future<void> setItemCollectionMembership({
    required String itemId,
    required int collectionId,
    required bool assign,
  }) async {
    _localMutationsInProgress++;
    _suppressTableUpdates();
    try {
      final collectionRepo = ref.read(collectionRepositoryProvider);
      if (assign) {
        await collectionRepo.addToCollection(itemId, collectionId);
      } else {
        await collectionRepo.removeFromCollection(itemId, collectionId);
      }
      _suppressTableUpdates();
      final updatedCollections = await collectionRepo.getCollectionsForItem(
        itemId,
      );
      ref
          .read(itemCollectionsOverrideProvider.notifier)
          .setCollections(itemId, updatedCollections);
      await refreshItem(itemId);
    } finally {
      _localMutationsInProgress--;
      _suppressTableUpdates();
    }
  }

  void updateItem(SavedItem updatedItem) {
    final prev = state.value;
    if (prev == null) return;
    final filter = _getEffectiveFilter();
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
    _suppressTableUpdates();
    final repo = ref.read(savedItemRepositoryProvider);
    final freshItem = await repo.getItemById(id);
    _suppressTableUpdates();

    if (freshItem == null) {
      _itemMutationController.add((itemId: id, item: null, deleted: true));
    } else {
      _itemMutationController.add((
        itemId: id,
        item: freshItem,
        deleted: false,
      ));
    }

    final latest = state.value;
    if (latest == null) return;
    final filter = _getEffectiveFilter();

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

    if (inList) {
      final existingIndex = latest.items.indexWhere((i) => i.id == id);
      if (existingIndex != -1 && latest.items[existingIndex] == freshItem) {
        return;
      }
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

  Future<({bool success, String? error, bool willRetry})> enrichItem(
    SavedItem item,
  ) async {
    _localMutationsInProgress++;
    _suppressTableUpdates();
    try {
      final result = await ref
          .read(enrichmentViewModelProvider.notifier)
          .enrichSingleItem(item);
      if (result.success) {
        await refreshItem(item.id);
      }
      return result;
    } finally {
      _localMutationsInProgress--;
      _suppressTableUpdates();
    }
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

final savedViewModelProvider = NotifierProvider<SavedViewModel, void>(
  SavedViewModel.new,
);

class SavedViewModel extends Notifier<void> {
  @override
  void build() {}

  SavedFeedPaginationNotifier get _feedNotifier =>
      ref.read(savedFeedPaginationProvider.notifier);

  bool isItemBusy(String id) => _feedNotifier.isItemBusy(id);

  Future<void> toggleStar(SavedItem item) => _feedNotifier.toggleStar(item);

  Future<void> toggleArchive(SavedItem item) =>
      _feedNotifier.toggleArchive(item);

  Future<void> deleteItem(SavedItem item) => _feedNotifier.deleteItem(item);

  Future<void> deleteItemById(String id) => _feedNotifier.deleteItemById(id);

  Future<void> updateItemNote(String id, String? note) =>
      _feedNotifier.updateItemNote(id, note);

  Future<({bool success, String? error, bool willRetry})> enrichItem(
    SavedItem item,
  ) => _feedNotifier.enrichItem(item);

  void clearFeed() => _feedNotifier.clearFeed();
}
