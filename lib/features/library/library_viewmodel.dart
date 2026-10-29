import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
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

final rawSubredditsWithCountsProvider = StreamProvider<List<SubredditInfo>>((
  ref,
) {
  final repo = ref.watch(savedItemRepositoryProvider);
  return repo.watchSubredditsWithCounts();
});

class SubredditSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
  void clear() => state = '';
}

final subredditSearchQueryProvider =
    NotifierProvider<SubredditSearchNotifier, String>(
      SubredditSearchNotifier.new,
    );

class SubredditSortNotifier extends Notifier<SubredditSortOption> {
  @override
  SubredditSortOption build() => SubredditSortOption.mostSaved;

  void setSort(SubredditSortOption sort) => state = sort;
}

final subredditSortOptionProvider =
    NotifierProvider<SubredditSortNotifier, SubredditSortOption>(
      SubredditSortNotifier.new,
    );

final filteredSubredditsProvider = Provider<AsyncValue<List<SubredditInfo>>>((
  ref,
) {
  final rawAsync = ref.watch(rawSubredditsWithCountsProvider);
  final query = ref.watch(subredditSearchQueryProvider).trim().toLowerCase();
  final sort = ref.watch(subredditSortOptionProvider);

  return rawAsync.whenData((subreddits) {
    final unverified = subreddits
        .where((s) => !s.isVerified && !SavedItem.isUserSubreddit(s.name))
        .map((s) => s.name)
        .toList();
    if (unverified.isNotEmpty) {
      Future.microtask(() {
        ref.read(savedItemRepositoryProvider).enrichSubreddits(unverified);
      });
    }

    final lowerNames = <String, String>{
      for (final sub in subreddits) sub.name: sub.name.toLowerCase(),
    };

    var filtered = subreddits;
    if (query.isNotEmpty) {
      filtered = filtered.where((sub) {
        return lowerNames[sub.name]!.contains(query);
      }).toList();
    } else {
      filtered = List.of(filtered);
    }

    filtered.sort((a, b) {
      switch (sort) {
        case SubredditSortOption.mostSaved:
          final countComp = b.count.compareTo(a.count);
          if (countComp != 0) return countComp;
          return lowerNames[a.name]!.compareTo(lowerNames[b.name]!);
        case SubredditSortOption.leastSaved:
          final countComp = a.count.compareTo(b.count);
          if (countComp != 0) return countComp;
          return lowerNames[a.name]!.compareTo(lowerNames[b.name]!);
        case SubredditSortOption.alphabeticalAZ:
          return lowerNames[a.name]!.compareTo(lowerNames[b.name]!);
        case SubredditSortOption.alphabeticalZA:
          return lowerNames[b.name]!.compareTo(lowerNames[a.name]!);
      }
    });

    return filtered;
  });
});
