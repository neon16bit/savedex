import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';

final itemDetailProvider = FutureProvider.family<SavedItem?, String>((
  ref,
  id,
) async {
  final repo = ref.watch(savedItemRepositoryProvider);
  return repo.getItemById(id);
});

final itemDetailActionsProvider = Provider((ref) => ItemDetailActions(ref));

class ItemDetailActions {
  final Ref _ref;
  ItemDetailActions(this._ref);

  Future<void> toggleStar(SavedItem item) async {
    final repo = _ref.read(savedItemRepositoryProvider);
    await repo.toggleStar(item.id, !item.isStarred);
    _ref.invalidate(itemDetailProvider(item.id));
  }

  Future<void> updateNote(String id, String? note) async {
    final repo = _ref.read(savedItemRepositoryProvider);
    await repo.updateUserNote(id, note);
    _ref.invalidate(itemDetailProvider(id));
  }

  Future<({bool success, String? error})> reEnrich(SavedItem item) async {
    final result = await _ref
        .read(enrichmentViewModelProvider.notifier)
        .enrichSingleItem(item);
    _ref.invalidate(itemDetailProvider(item.id));
    return result;
  }

  Future<void> deleteItem(String id) async {
    final repo = _ref.read(savedItemRepositoryProvider);
    await repo.deleteItem(id);
  }
}
