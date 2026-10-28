import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';
import 'package:savedex/features/saved/saved_viewmodel.dart';

final itemDetailProvider = StreamProvider.autoDispose
    .family<SavedItem?, String>((ref, id) {
      final repo = ref.watch(savedItemRepositoryProvider);
      return repo.watchItemById(id);
    });

final relatedThreadProvider = StreamProvider.autoDispose
    .family<({SavedItem? parentPost, List<SavedItem> comments}), String>((
      ref,
      id,
    ) {
      final threadKey = ref.watch(
        itemDetailProvider(id).select((a) {
          final item = a.value;
          if (item == null) return null;
          return (itemType: item.itemType, parentPostId: item.parentPostId);
        }),
      );
      if (threadKey == null) {
        return Stream.value((parentPost: null, comments: <SavedItem>[]));
      }
      final item = ref.read(itemDetailProvider(id)).value;
      if (item == null) {
        return Stream.value((parentPost: null, comments: <SavedItem>[]));
      }
      final repo = ref.watch(savedItemRepositoryProvider);
      return repo.watchRelatedThreadItems(item);
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
      await _ref.read(savedFeedPaginationProvider.notifier).toggleStar(item);
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
      await _ref
          .read(savedFeedPaginationProvider.notifier)
          .updateItemNote(id, cleanNote);
      _ref.read(itemNotesProvider.notifier).setNote(id, cleanNote);
    } finally {
      _busyItemIds.remove(id);
    }
  }

  Future<({bool success, String? error})> reEnrich(SavedItem item) async {
    final result = await _ref
        .read(enrichmentViewModelProvider.notifier)
        .enrichSingleItem(item);
    if (result.success) {
      await _ref
          .read(savedFeedPaginationProvider.notifier)
          .refreshItem(item.id);
    }
    return result;
  }

  Future<({bool success, String? error})> recoverFromArchive(
    SavedItem item,
  ) async {
    final result = await _ref
        .read(enrichmentViewModelProvider.notifier)
        .recoverSingleItemFromArchive(item);
    if (result.success) {
      await _ref
          .read(savedFeedPaginationProvider.notifier)
          .refreshItem(item.id);
    }
    return result;
  }

  Future<void> deleteItem(String id) async {
    if (!_busyItemIds.add(id)) return;
    try {
      await _ref.read(savedFeedPaginationProvider.notifier).deleteItemById(id);
    } finally {
      _busyItemIds.remove(id);
    }
  }
}
