import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  int _localMutationsInProgress = 0;
  final Set<String> _busyItemIds = <String>{};
  StreamSubscription? _dbUpdatesSub;
  Timer? _debounceTimer;

  bool isItemBusy(String id) => _busyItemIds.contains(id);

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
      _busyItemIds.clear();
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
    if (_localMutationsInProgress > 0) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (_localMutationsInProgress > 0) return;
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

      final targetFetchCount = current.items.length <= _pageSize
          ? _pageSize
          : (current.items.length > 200 ? 200 : current.items.length);

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
    try {
      await persist();
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
      if (itemId != null) {
        _busyItemIds.remove(itemId);
      }
    }
  }

  Future<void> toggleStar(SavedItem item) async {
    final filter = ref.read(searchFilterViewModelProvider);
    final newStarred = !item.isStarred;

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
                .map(
                  (i) =>
                      i.id == item.id ? i.copyWith(isStarred: newStarred) : i,
                )
                .toList(),
          );
        }
      },
      persist: () =>
          ref.read(savedItemRepositoryProvider).toggleStar(item.id, newStarred),
    );
  }

  Future<void> toggleArchive(SavedItem item) async {
    final filter = ref.read(searchFilterViewModelProvider);
    final newArchived = !item.isArchived;

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
                .map(
                  (i) =>
                      i.id == item.id ? i.copyWith(isArchived: newArchived) : i,
                )
                .toList(),
          );
        }
      },
      persist: () => ref
          .read(savedItemRepositoryProvider)
          .toggleArchive(item.id, newArchived),
    );
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
  }

  Future<void> deleteItem(SavedItem item) => deleteItemById(item.id);

  Future<void> updateItemNote(String id, String? note) async {
    final cleanNote = (note == null || note.trim().isEmpty)
        ? null
        : note.trim();
    await _runOptimisticMutation(
      itemId: id,
      optimisticUpdate: (prev) => prev.copyWith(
        items: prev.items
            .map((i) => i.id == id ? i.copyWith(userNote: cleanNote) : i)
            .toList(),
      ),
      persist: () =>
          ref.read(savedItemRepositoryProvider).updateUserNote(id, cleanNote),
    );
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

  Future<({bool success, String? error})> enrichItem(SavedItem item) async {
    _localMutationsInProgress++;
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

  Future<({bool success, String? error})> enrichItem(SavedItem item) =>
      _feedNotifier.enrichItem(item);

  void clearFeed() => _feedNotifier.clearFeed();
}
