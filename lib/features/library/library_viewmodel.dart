import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/author_info.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/data/models/subreddit_info.dart';

enum CollectionSortOption {
  newest('Newest'),
  mostItems('Most Items'),
  leastItems('Least Items'),
  alphabeticalAZ('A → Z'),
  alphabeticalZA('Z → A');

  final String label;
  const CollectionSortOption(this.label);
}

enum SubredditSortOption {
  mostSaved('Most Saved'),
  leastSaved('Least Saved'),
  alphabeticalAZ('A → Z'),
  alphabeticalZA('Z → A');

  final String label;
  const SubredditSortOption(this.label);
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
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case CollectionSortOption.leastItems:
          final cmp = a.itemCount.compareTo(b.itemCount);
          if (cmp != 0) return cmp;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case CollectionSortOption.alphabeticalAZ:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case CollectionSortOption.alphabeticalZA:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
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

final filteredSubredditsProvider =
    Provider.autoDispose<AsyncValue<List<SubredditInfo>>>((ref) {
      final rawAsync = ref.watch(rawSubredditsWithCountsProvider);
      final query = ref
          .watch(subredditSearchQueryProvider)
          .trim()
          .toLowerCase()
          .replaceFirst(RegExp(r'^/?r/'), '');
      final sort = ref.watch(subredditSortOptionProvider);

      return rawAsync.whenData((subreddits) {
        final filtered = query.isEmpty
            ? List.of(subreddits)
            : subreddits.where((s) => s.lowerName.contains(query)).toList();

        filtered.sort((a, b) {
          switch (sort) {
            case SubredditSortOption.mostSaved:
              final c = b.count.compareTo(a.count);
              return c != 0 ? c : a.lowerName.compareTo(b.lowerName);
            case SubredditSortOption.leastSaved:
              final c = a.count.compareTo(b.count);
              return c != 0 ? c : a.lowerName.compareTo(b.lowerName);
            case SubredditSortOption.alphabeticalAZ:
              return a.lowerName.compareTo(b.lowerName);
            case SubredditSortOption.alphabeticalZA:
              return b.lowerName.compareTo(a.lowerName);
          }
        });

        return filtered;
      });
    });

final rawAuthorsWithCountsProvider =
    StreamProvider.autoDispose<List<AuthorInfo>>((ref) {
      return ref.watch(savedItemRepositoryProvider).watchAuthorsWithCounts();
    });

final userSearchQueryProvider =
    NotifierProvider<SubredditSearchNotifier, String>(
      SubredditSearchNotifier.new,
    );

final userSortOptionProvider =
    NotifierProvider<SubredditSortNotifier, SubredditSortOption>(
      SubredditSortNotifier.new,
    );

final filteredAuthorsProvider =
    Provider.autoDispose<AsyncValue<List<AuthorInfo>>>((ref) {
      final rawAsync = ref.watch(rawAuthorsWithCountsProvider);
      final query = ref
          .watch(userSearchQueryProvider)
          .trim()
          .toLowerCase()
          .replaceFirst(RegExp(r'^/?u[/_]'), '');
      final sort = ref.watch(userSortOptionProvider);

      return rawAsync.whenData((authors) {
        final filtered = query.isEmpty
            ? List.of(authors)
            : authors.where((a) => a.lowerName.contains(query)).toList();

        filtered.sort((a, b) {
          switch (sort) {
            case SubredditSortOption.mostSaved:
              final c = b.count.compareTo(a.count);
              return c != 0 ? c : a.lowerName.compareTo(b.lowerName);
            case SubredditSortOption.leastSaved:
              final c = a.count.compareTo(b.count);
              return c != 0 ? c : a.lowerName.compareTo(b.lowerName);
            case SubredditSortOption.alphabeticalAZ:
              return a.lowerName.compareTo(b.lowerName);
            case SubredditSortOption.alphabeticalZA:
              return b.lowerName.compareTo(a.lowerName);
          }
        });

        return filtered;
      });
    });
