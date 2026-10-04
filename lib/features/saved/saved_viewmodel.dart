import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';
import 'package:savedex/features/search/search_viewmodel.dart';

final feedItemsStreamProvider = StreamProvider<List<SavedItem>>((ref) {
  final filter = ref.watch(searchFilterViewModelProvider);
  final repo = ref.watch(savedItemRepositoryProvider);
  return repo.watchSavedItems(filter);
});

final groupedFeedItemsProvider = Provider<List<FeedEntry>>((ref) {
  final itemsAsync = ref.watch(feedItemsStreamProvider);
  final filter = ref.watch(searchFilterViewModelProvider);

  return itemsAsync.when(
    data: (items) {
      if (!filter.groupCommentsByPost) {
        return items.map((item) => SingleFeedEntry(item)).toList();
      }

      // group multiple comments belonging to the same parent post
      final List<FeedEntry> result = [];
      final Map<String, List<SavedItem>> postCommentsMap = {};
      final Set<String> standalonePostIds = {};

      for (final item in items) {
        if (item.isComment &&
            item.parentPostId != null &&
            item.parentPostId!.isNotEmpty) {
          postCommentsMap.putIfAbsent(item.parentPostId!, () => []).add(item);
        } else {
          standalonePostIds.add(item.id);
          result.add(SingleFeedEntry(item));
        }
      }

      // grouped comments
      for (final entry in postCommentsMap.entries) {
        final parentPostId = entry.key;
        final comments = entry.value;

        if (comments.length > 1) {
          result.add(
            GroupedCommentsFeedEntry(
              parentPostId: parentPostId,
              parentTitle:
                  comments.first.parentPostTitle ?? comments.first.title,
              subreddit: comments.first.subreddit,
              comments: comments,
            ),
          );
        } else if (comments.length == 1) {
          result.add(SingleFeedEntry(comments.first));
        }
      }

      return result;
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

sealed class FeedEntry {}

class SingleFeedEntry extends FeedEntry {
  final SavedItem item;
  SingleFeedEntry(this.item);
}

class GroupedCommentsFeedEntry extends FeedEntry {
  final String parentPostId;
  final String parentTitle;
  final String subreddit;
  final List<SavedItem> comments;

  GroupedCommentsFeedEntry({
    required this.parentPostId,
    required this.parentTitle,
    required this.subreddit,
    required this.comments,
  });
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
      final repo = ref.read(savedItemRepositoryProvider);
      await repo.toggleStar(item.id, !item.isStarred);
    } finally {
      _busyItemIds.remove(item.id);
    }
  }

  Future<void> deleteItem(SavedItem item) async {
    if (!_busyItemIds.add(item.id)) return;
    try {
      final repo = ref.read(savedItemRepositoryProvider);
      await repo.deleteItem(item.id);
    } finally {
      _busyItemIds.remove(item.id);
    }
  }

  Future<void> enrichItem(SavedItem item) async {
    await ref.read(enrichmentViewModelProvider.notifier).enrichSingleItem(item);
  }
}
