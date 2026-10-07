import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';

final searchFilterViewModelProvider =
    NotifierProvider<SearchFilterViewModel, FilterCriteria>(() {
      return SearchFilterViewModel();
    });

final availableSubredditsProvider = FutureProvider<List<(String, int)>>((
  ref,
) async {
  final repo = ref.watch(savedItemRepositoryProvider);
  return repo.getSubredditsWithCounts();
});

final availableAuthorsWithCountsProvider = FutureProvider<List<(String, int)>>((
  ref,
) async {
  final repo = ref.watch(savedItemRepositoryProvider);
  return repo.getAuthorsWithCounts();
});

final availableAuthorsProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(savedItemRepositoryProvider);
  return repo.getDistinctAuthors();
});

final availableFlairsProvider = FutureProvider<List<(String, int)>>((
  ref,
) async {
  final repo = ref.watch(savedItemRepositoryProvider);
  return repo.getFlairsWithCounts();
});

final availableCollectionsProvider = StreamProvider<List<Collection>>((ref) {
  final repo = ref.watch(collectionRepositoryProvider);
  return repo.watchAllCollections();
});

class SearchFilterViewModel extends Notifier<FilterCriteria> {
  @override
  FilterCriteria build() {
    return const FilterCriteria();
  }

  void setSearchQuery(String? query) {
    if (query == null || query.trim().isEmpty) {
      state = state.copyWith(clearSearchQuery: true);
    } else {
      state = state.copyWith(searchQuery: query.trim());
    }
  }

  void toggleSubreddit(String subreddit) {
    final updated = Set<String>.from(state.selectedSubreddits);
    if (updated.contains(subreddit)) {
      updated.remove(subreddit);
    } else {
      updated.add(subreddit);
    }
    state = state.copyWith(selectedSubreddits: updated);
  }

  void toggleAuthor(String author) {
    final updated = Set<String>.from(state.selectedAuthors);
    if (updated.contains(author)) {
      updated.remove(author);
    } else {
      updated.add(author);
    }
    state = state.copyWith(selectedAuthors: updated);
  }

  void toggleFlair(String flair) {
    final updated = Set<String>.from(state.selectedFlairs);
    if (updated.contains(flair)) {
      updated.remove(flair);
    } else {
      updated.add(flair);
    }
    state = state.copyWith(selectedFlairs: updated);
  }

  void selectSingleSubreddit(String subreddit) {
    state = state.copyWith(selectedSubreddits: {subreddit});
  }

  void selectSingleAuthor(String author) {
    state = state.copyWith(selectedAuthors: {author});
  }

  void selectSingleFlair(String flair) {
    state = state.copyWith(selectedFlairs: {flair});
  }

  void setDateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) {
      state = state.copyWith(clearDateRange: true);
    } else {
      final adjustedEnd =
          (end != null &&
              end.hour == 0 &&
              end.minute == 0 &&
              end.second == 0 &&
              end.millisecond == 0)
          ? DateTime(end.year, end.month, end.day, 23, 59, 59, 999)
          : end;
      state = state.copyWith(dateRangeStart: start, dateRangeEnd: adjustedEnd);
    }
  }

  void clearDateRange() {
    state = state.copyWith(clearDateRange: true);
  }

  void toggleMediaType(MediaType type) {
    final updated = Set<MediaType>.from(state.selectedMediaTypes);
    if (updated.contains(type)) {
      updated.remove(type);
    } else {
      updated.add(type);
    }
    state = state.copyWith(selectedMediaTypes: updated);
  }

  void setItemType(ItemType? type) {
    if (type == null) {
      state = state.copyWith(clearItemType: true);
    } else {
      state = state.copyWith(itemType: type);
    }
  }

  void setNsfwFilter(bool? isNsfw) {
    if (isNsfw == null) {
      state = state.copyWith(clearNsfw: true);
    } else {
      state = state.copyWith(isNsfw: isNsfw);
    }
  }

  void toggleStarredOnly(bool starredOnly) {
    state = state.copyWith(
      isStarred: starredOnly ? true : null,
      clearStarred: !starredOnly,
    );
  }

  void toggleCollection(int collectionId) {
    final updated = Set<int>.from(state.selectedCollectionIds);
    if (updated.contains(collectionId)) {
      updated.remove(collectionId);
    } else {
      updated.add(collectionId);
    }
    state = state.copyWith(selectedCollectionIds: updated);
  }

  void setSortOption(SortOption sort) {
    state = state.copyWith(sortOption: sort);
  }

  void toggleGroupComments(bool group) {
    state = state.copyWith(groupCommentsByPost: group);
  }

  void clearAllFilters() {
    state = const FilterCriteria();
  }
}
