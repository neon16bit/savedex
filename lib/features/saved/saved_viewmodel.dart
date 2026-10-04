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
