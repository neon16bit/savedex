import 'dart:async';

import 'package:drift/drift.dart'
    show TableUpdate, TableUpdateQuery, UpdateKind;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/database/database.dart';
import 'package:savedex/data/models/author_info.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/data/models/subreddit_info.dart';

export 'package:savedex/data/models/saved_item_model.dart'
    show SubredditSortOption;

enum CollectionSortOption {
  newest('Newest'),
  mostItems('Most Items'),
  leastItems('Least Items'),
  alphabeticalAZ('A → Z'),
  alphabeticalZA('Z → A');

  final String label;
  const CollectionSortOption(this.label);
}

final collectionsWithCountsProvider = StreamProvider<List<Collection>>((ref) {
  final repo = ref.watch(collectionRepositoryProvider);
  return repo.watchCollectionsWithCounts();
});

class CollectionSortNotifier extends Notifier<CollectionSortOption> {
  @override
  CollectionSortOption build() => CollectionSortOption.newest;

  void setSort(CollectionSortOption sort) => state = sort;
}

final collectionSortOptionProvider =
    NotifierProvider<CollectionSortNotifier, CollectionSortOption>(
      CollectionSortNotifier.new,
    );

final sortedCollectionsProvider = Provider<AsyncValue<List<Collection>>>((ref) {
  final rawAsync = ref.watch(collectionsWithCountsProvider);
  final sort = ref.watch(collectionSortOptionProvider);

  return rawAsync.whenData((collections) {
    if (collections.length <= 1) return collections;
    final lowerNames = sort == CollectionSortOption.newest
        ? null
        : <int, String>{
            for (final c in collections) c.id: c.name.toLowerCase(),
          };
    final sorted = List.of(collections);
    sorted.sort((a, b) {
      switch (sort) {
        case CollectionSortOption.newest:
          final aDate = a.createdAtUtc;
          final bDate = b.createdAtUtc;
          if (aDate != null && bDate != null) {
            final cmp = bDate.compareTo(aDate);
            if (cmp != 0) return cmp;
          }
          return b.id.compareTo(a.id);
        case CollectionSortOption.mostItems:
          final cmp = b.itemCount.compareTo(a.itemCount);
          if (cmp != 0) return cmp;
          return lowerNames![a.id]!.compareTo(lowerNames[b.id]!);
        case CollectionSortOption.leastItems:
          final cmp = a.itemCount.compareTo(b.itemCount);
          if (cmp != 0) return cmp;
          return lowerNames![a.id]!.compareTo(lowerNames[b.id]!);
        case CollectionSortOption.alphabeticalAZ:
          return lowerNames![a.id]!.compareTo(lowerNames[b.id]!);
        case CollectionSortOption.alphabeticalZA:
          return lowerNames![b.id]!.compareTo(lowerNames[a.id]!);
      }
    });
    return sorted;
  });
});

final rawSubredditsWithCountsProvider =
    StreamProvider.autoDispose<List<SubredditInfo>>((ref) {
      final repo = ref.watch(savedItemRepositoryProvider);
      return repo.watchSubredditsWithCounts();
    });

final subredditCountProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(savedItemRepositoryProvider).watchSubredditCount();
});

class SubredditSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) {
    if (state != q) state = q;
  }

  void clear() {
    if (state.isNotEmpty) state = '';
  }
}

final subredditSearchQueryProvider =
    NotifierProvider<SubredditSearchNotifier, String>(
      SubredditSearchNotifier.new,
    );

class SubredditSortNotifier extends Notifier<SubredditSortOption> {
  @override
  SubredditSortOption build() => SubredditSortOption.mostSaved;

  void setSort(SubredditSortOption sort) {
    if (state != sort) state = sort;
  }
}

final subredditSortOptionProvider =
    NotifierProvider<SubredditSortNotifier, SubredditSortOption>(
      SubredditSortNotifier.new,
    );

class DirectoryPageState<T> {
  final List<T> items;
  final FeedCursor? nextCursor;
  final bool hasMore;
  final int queryEpoch;

  const DirectoryPageState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = false,
    this.queryEpoch = 0,
  });

  DirectoryPageState<T> copyWith({
    List<T>? items,
    FeedCursor? nextCursor,
    bool? hasMore,
    bool clearCursor = false,
    int? queryEpoch,
  }) {
    return DirectoryPageState<T>(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      queryEpoch: queryEpoch ?? this.queryEpoch,
    );
  }
}

abstract class _PagedDirectoryNotifier<T>
    extends AsyncNotifier<DirectoryPageState<T>> {
  static const int pageSize = 100;

  int _generation = 0;
  int _reloadEpoch = 0;
  bool _isLoadingMore = false;
  Timer? _itemReloadTimer;
  Timer? _metadataRefreshTimer;
  StreamSubscription<Set<TableUpdate>>? _tableSub;
  StreamSubscription<void>? _metadataSub;
  StreamSubscription<void>? _extraItemSub;
  String _activeQuery = '';
  SubredditSortOption _activeSort = SubredditSortOption.mostSaved;

  String readQuery();
  SubredditSortOption readSort();

  Future<PagedRows<T>> fetchPage({
    required String query,
    required SubredditSortOption sort,
    FeedCursor? cursor,
    required int limit,
  });

  Stream<void> metadataChanges(AppDatabase db);
  Stream<void>? extraItemChanges(AppDatabase db) => null;
  String itemDedupeKey(T item);
  String subredditTableKeyForItem(T item);
  T? patchItemMetadata(T item, SubredditEntry? entry);

  void _disposeListeners() {
    _itemReloadTimer?.cancel();
    _itemReloadTimer = null;
    _metadataRefreshTimer?.cancel();
    _metadataRefreshTimer = null;
    _tableSub?.cancel();
    _tableSub = null;
    _metadataSub?.cancel();
    _metadataSub = null;
    _extraItemSub?.cancel();
    _extraItemSub = null;
  }

  @override
  Future<DirectoryPageState<T>> build() async {
    final gen = ++_generation;
    _isLoadingMore = false;
    _activeQuery = readQuery();
    _activeSort = readSort();
    final db = ref.watch(databaseProvider);

    _disposeListeners();
    ref.onDispose(_disposeListeners);

    _tableSub = db
        .tableUpdates(TableUpdateQuery.onAllTables([db.savedItemsTable]))
        .listen((updates) {
          if (updates.any(
            (u) =>
                u.kind == UpdateKind.insert ||
                u.kind == UpdateKind.delete ||
                u.kind == null,
          )) {
            _scheduleItemReload(gen);
          }
        });

    final extraStream = extraItemChanges(db);
    if (extraStream != null) {
      _extraItemSub = extraStream.listen((_) => _scheduleItemReload(gen));
    }
    _metadataSub = metadataChanges(db)
        .listen((_) => _scheduleMetadataRefresh(gen));

    final page = await fetchPage(
      query: _activeQuery,
      sort: _activeSort,
      cursor: null,
      limit: pageSize,
    );

    return DirectoryPageState<T>(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      queryEpoch: gen,
    );
  }

  void _scheduleItemReload(int targetGen) {
    _itemReloadTimer?.cancel();
    _itemReloadTimer = Timer(const Duration(milliseconds: 800), () async {
      if (!ref.mounted || targetGen != _generation) return;
      try {
        for (var attempt = 0; attempt < 2; attempt++) {
          final current = state.asData?.value;
          if (current == null) return;

          final targetLimit = current.items.length <= pageSize
              ? pageSize
              : current.items.length;
          final page = await fetchPage(
            query: _activeQuery,
            sort: _activeSort,
            cursor: null,
            limit: targetLimit,
          );
          if (!ref.mounted || targetGen != _generation) return;

          final latest = state.asData?.value;
          if (attempt == 0 &&
              latest != null &&
              latest.items.length > targetLimit) {
            // loadMore appended rows while this reload was in-flight; re-fetch to avoid shrinking the list.
            continue;
          }

          _reloadEpoch++;
          state = AsyncData(
            DirectoryPageState<T>(
              items: page.items,
              nextCursor: page.nextCursor,
              hasMore: page.hasMore,
              queryEpoch: (latest ?? current).queryEpoch,
            ),
          );
          return;
        }
      } catch (_) {}
    });
  }

  void _scheduleMetadataRefresh(int targetGen) {
    _metadataRefreshTimer?.cancel();
    _metadataRefreshTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!ref.mounted || targetGen != _generation) return;
      final current = state.asData?.value;
      if (current == null || current.items.isEmpty) return;

      final queriedKeys = <String>{
        for (final item in current.items) subredditTableKeyForItem(item),
      };
      if (queriedKeys.isEmpty) return;

      try {
        final entries = await ref
            .read(savedItemRepositoryProvider)
            .getSubredditsByNames(queriedKeys);
        if (!ref.mounted || targetGen != _generation) return;

        final latest = state.asData?.value;
        if (latest == null || latest.items.isEmpty) return;

        var changed = false;
        final updatedItems = [
          for (final item in latest.items)
            () {
              final key = subredditTableKeyForItem(item);
              if (!queriedKeys.contains(key)) return item;
              final patched = patchItemMetadata(item, entries[key]);
              if (patched != null) {
                changed = true;
                return patched;
              }
              return item;
            }(),
        ];

        if (changed) {
          state = AsyncData(latest.copyWith(items: updatedItems));
        }
      } catch (_) {}
    });
  }

  Future<void> loadMore() async {
    final initial = state.asData?.value;
    if (_isLoadingMore || initial == null || !initial.hasMore) return;

    final targetGen = _generation;
    final query = _activeQuery;
    final sort = _activeSort;

    _isLoadingMore = true;
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final current = state.asData?.value;
        if (!ref.mounted ||
            targetGen != _generation ||
            current == null ||
            !current.hasMore) {
          return;
        }

        final targetEpoch = _reloadEpoch;
        final page = await fetchPage(
          query: query,
          sort: sort,
          cursor: current.nextCursor,
          limit: pageSize,
        );
        if (!ref.mounted || targetGen != _generation) return;
        if (targetEpoch != _reloadEpoch) {
          // Background item reload updated base rows; retry once with the fresh cursor.
          continue;
        }

        final latest = state.asData?.value ?? current;
        final seen = <String>{
          for (final item in latest.items) itemDedupeKey(item),
        };
        final merged = [
          ...latest.items,
          for (final item in page.items)
            if (seen.add(itemDedupeKey(item))) item,
        ];

        state = AsyncData(
          DirectoryPageState<T>(
            items: merged,
            nextCursor: page.nextCursor,
            hasMore: page.hasMore,
            queryEpoch: latest.queryEpoch,
          ),
        );
        return;
      }
    } catch (_) {
    } finally {
      if (targetGen == _generation) {
        _isLoadingMore = false;
      }
    }
  }
}

class SubredditsFeedNotifier extends _PagedDirectoryNotifier<SubredditInfo> {
  @override
  String readQuery() => ref.watch(subredditSearchQueryProvider);

  @override
  SubredditSortOption readSort() => ref.watch(subredditSortOptionProvider);

  @override
  Future<PagedRows<SubredditInfo>> fetchPage({
    required String query,
    required SubredditSortOption sort,
    FeedCursor? cursor,
    required int limit,
  }) {
    return ref
        .read(savedItemRepositoryProvider)
        .getSubredditsPage(
          query: query,
          sort: sort,
          cursor: cursor,
          limit: limit,
        );
  }

  @override
  Stream<void> metadataChanges(AppDatabase db) => db.subredditMetadataChanges;

  @override
  String itemDedupeKey(SubredditInfo item) => item.lowerName;

  @override
  String subredditTableKeyForItem(SubredditInfo item) =>
      SavedItem.normalizeSubredditKey(item.name);

  @override
  SubredditInfo? patchItemMetadata(SubredditInfo item, SubredditEntry? entry) {
    if (entry == null) {
      if (!item.isVerified && item.iconUrl == null) return null;
      return SubredditInfo(
        name: item.name,
        count: item.count,
        isNsfw: item.isNsfw,
        iconUrl: null,
        isVerified: false,
      );
    }
    final nextNsfw = entry.isNsfw ?? item.isNsfw;
    final nextVerified = entry.isNsfw != null || entry.lastChecked != null;
    final nextIconUrl = entry.iconUrl;
    if (nextNsfw == item.isNsfw &&
        nextVerified == item.isVerified &&
        nextIconUrl == item.iconUrl) {
      return null;
    }
    return SubredditInfo(
      name: item.name,
      count: item.count,
      isNsfw: nextNsfw,
      iconUrl: nextIconUrl,
      isVerified: nextVerified,
    );
  }
}

final subredditsFeedProvider =
    AsyncNotifierProvider.autoDispose<
      SubredditsFeedNotifier,
      DirectoryPageState<SubredditInfo>
    >(SubredditsFeedNotifier.new);

final rawAuthorsWithCountsProvider =
    StreamProvider.autoDispose<List<AuthorInfo>>((ref) {
      return ref.watch(savedItemRepositoryProvider).watchAuthorsWithCounts();
    });

final authorCountProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(savedItemRepositoryProvider).watchAuthorCount();
});

final userSearchQueryProvider =
    NotifierProvider<SubredditSearchNotifier, String>(
      SubredditSearchNotifier.new,
    );

final userSortOptionProvider =
    NotifierProvider<SubredditSortNotifier, SubredditSortOption>(
      SubredditSortNotifier.new,
    );

class AuthorsFeedNotifier extends _PagedDirectoryNotifier<AuthorInfo> {
  @override
  String readQuery() => ref.watch(userSearchQueryProvider);

  @override
  SubredditSortOption readSort() => ref.watch(userSortOptionProvider);

  @override
  Future<PagedRows<AuthorInfo>> fetchPage({
    required String query,
    required SubredditSortOption sort,
    FeedCursor? cursor,
    required int limit,
  }) {
    return ref
        .read(savedItemRepositoryProvider)
        .getAuthorsPage(query: query, sort: sort, cursor: cursor, limit: limit);
  }

  @override
  Stream<void> metadataChanges(AppDatabase db) => db.authorMetadataChanges;

  @override
  Stream<void>? extraItemChanges(AppDatabase db) => db.authorItemsChanged;

  @override
  String itemDedupeKey(AuthorInfo item) => item.lowerName;

  @override
  String subredditTableKeyForItem(AuthorInfo item) => 'u_${item.lowerName}';

  @override
  AuthorInfo? patchItemMetadata(AuthorInfo item, SubredditEntry? entry) {
    if (entry == null) {
      if (!item.isVerified && !item.isNsfw && item.iconUrl == null) {
        return null;
      }
      return AuthorInfo(
        name: item.name,
        count: item.count,
        isNsfw: false,
        iconUrl: null,
        isVerified: false,
      );
    }
    final nextNsfw = entry.isNsfw ?? false;
    final nextVerified = entry.isNsfw != null || entry.lastChecked != null;
    final nextIconUrl = entry.iconUrl;
    if (nextNsfw == item.isNsfw &&
        nextVerified == item.isVerified &&
        nextIconUrl == item.iconUrl) {
      return null;
    }
    return AuthorInfo(
      name: item.name,
      count: item.count,
      isNsfw: nextNsfw,
      iconUrl: nextIconUrl,
      isVerified: nextVerified,
    );
  }
}

final authorsFeedProvider =
    AsyncNotifierProvider.autoDispose<
      AuthorsFeedNotifier,
      DirectoryPageState<AuthorInfo>
    >(AuthorsFeedNotifier.new);
