import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';

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

final rawSubredditsWithCountsProvider = StreamProvider<List<(String, int)>>((
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

final filteredSubredditsProvider = Provider<AsyncValue<List<(String, int)>>>((
  ref,
) {
  final rawAsync = ref.watch(rawSubredditsWithCountsProvider);
  final query = ref.watch(subredditSearchQueryProvider).trim().toLowerCase();
  final sort = ref.watch(subredditSortOptionProvider);

  return rawAsync.whenData((subreddits) {
    var filtered = subreddits;
    if (query.isNotEmpty) {
      filtered = filtered.where((sub) {
        final name = sub.$1.toLowerCase();
        return name.contains(query);
      }).toList();
    } else {
      filtered = List.of(filtered);
    }

    filtered.sort((a, b) {
      switch (sort) {
        case SubredditSortOption.mostSaved:
          final countComp = b.$2.compareTo(a.$2);
          if (countComp != 0) return countComp;
          return a.$1.toLowerCase().compareTo(b.$1.toLowerCase());
        case SubredditSortOption.leastSaved:
          final countComp = a.$2.compareTo(b.$2);
          if (countComp != 0) return countComp;
          return a.$1.toLowerCase().compareTo(b.$1.toLowerCase());
        case SubredditSortOption.alphabeticalAZ:
          return a.$1.toLowerCase().compareTo(b.$1.toLowerCase());
        case SubredditSortOption.alphabeticalZA:
          return b.$1.toLowerCase().compareTo(a.$1.toLowerCase());
      }
    });

    return filtered;
  });
});
