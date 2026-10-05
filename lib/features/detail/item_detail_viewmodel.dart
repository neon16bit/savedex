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

final relatedThreadProvider =
    FutureProvider.family<
      ({SavedItem? parentPost, List<SavedItem> comments}),
      String
    >((ref, id) async {
      final item = await ref.watch(itemDetailProvider(id).future);
      if (item == null) return (parentPost: null, comments: <SavedItem>[]);
      final repo = ref.watch(savedItemRepositoryProvider);
      return repo.getRelatedThreadItems(item);
    });

final enrichingItemsProvider =
    NotifierProvider<EnrichingItemsNotifier, Set<String>>(
      EnrichingItemsNotifier.new,
    );

class EnrichingItemsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void add(String id) => state = {...state, id};

  void remove(String id) {
    final next = Set<String>.from(state);
    next.remove(id);
    state = next;
  }

  bool isEnriching(String id) => state.contains(id);
}

final itemNotesProvider =
    NotifierProvider<ItemNotesNotifier, Map<String, String?>>(
      ItemNotesNotifier.new,
    );

class ItemNotesNotifier extends Notifier<Map<String, String?>> {
  @override
  Map<String, String?> build() => {};

  void setNote(String id, String? note) {
    state = {...state, id: note};
  }
}

final itemNoteProvider =
    Provider.family<String?, ({String id, String? initialNote})>((ref, arg) {
      final hasOverride = ref.watch(
        itemNotesProvider.select((m) => m.containsKey(arg.id)),
      );
      if (hasOverride) {
        return ref.watch(itemNotesProvider.select((m) => m[arg.id]));
      }
      return arg.initialNote;
    });

final itemDetailActionsProvider = Provider((ref) => ItemDetailActions(ref));

class ItemDetailActions {
  final Ref _ref;
  final _busyItemIds = <String>{};

  ItemDetailActions(this._ref);

  Future<void> toggleStar(SavedItem item) async {
    if (!_busyItemIds.add(item.id)) return;
    try {
      final repo = _ref.read(savedItemRepositoryProvider);
      await repo.toggleStar(item.id, !item.isStarred);
      _ref.invalidate(itemDetailProvider(item.id));
      _ref.invalidate(relatedThreadProvider);
    } finally {
      _busyItemIds.remove(item.id);
    }
  }

  Future<void> updateNote(String id, String? note) async {
    if (!_busyItemIds.add(id)) return;
    try {
      final cleanNote = (note == null || note.trim().isEmpty)
          ? null
          : note.trim();
      final repo = _ref.read(savedItemRepositoryProvider);
      await repo.updateUserNote(id, cleanNote);
      _ref.read(itemNotesProvider.notifier).setNote(id, cleanNote);
    } finally {
      _busyItemIds.remove(id);
    }
  }

  Future<({bool success, String? error})> reEnrich(SavedItem item) async {
    final result = await _ref
        .read(enrichmentViewModelProvider.notifier)
        .enrichSingleItem(item);
    _ref.invalidate(itemDetailProvider(item.id));
    _ref.invalidate(relatedThreadProvider);
    return result;
  }

  Future<void> deleteItem(String id) async {
    if (!_busyItemIds.add(id)) return;
    try {
      final repo = _ref.read(savedItemRepositoryProvider);
      await repo.deleteItem(id);
      _ref.invalidate(relatedThreadProvider);
    } finally {
      _busyItemIds.remove(id);
    }
  }
}
