import 'package:drift/drift.dart';
import 'package:savedex/data/database/database.dart';
import 'package:savedex/data/models/saved_item_model.dart';

class CollectionRepository {
  final AppDatabase _db;

  CollectionRepository(this._db);

  Stream<List<Collection>> watchAllCollections() {
    return _db.select(_db.collectionsTable).watch().map((entries) {
      return entries
          .map(
            (e) => Collection(
              id: e.id,
              name: e.name,
              description: e.description,
              colorValue: e.colorValue,
              createdAtUtc: e.createdAtUtc,
            ),
          )
          .toList();
    });
  }

  Future<List<Collection>> getAllCollections() async {
    final entries = await _db.select(_db.collectionsTable).get();
    return entries
        .map(
          (e) => Collection(
            id: e.id,
            name: e.name,
            description: e.description,
            colorValue: e.colorValue,
            createdAtUtc: e.createdAtUtc,
          ),
        )
        .toList();
  }

  Future<Collection?> getCollectionById(int id) async {
    final entry = await (_db.select(
      _db.collectionsTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entry == null) return null;
    return Collection(
      id: entry.id,
      name: entry.name,
      description: entry.description,
      colorValue: entry.colorValue,
      createdAtUtc: entry.createdAtUtc,
    );
  }

  Future<int> createCollection(
    String name,
    int colorValue, {
    String? description,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return -1;

    final existing = await (_db.select(
      _db.collectionsTable,
    )..where((t) => t.name.equals(cleanName))).getSingleOrNull();
    if (existing != null) {
      return existing.id;
    }

    return await _db
        .into(_db.collectionsTable)
        .insert(
          CollectionsTableCompanion.insert(
            name: cleanName,
            description: Value(description?.trim()),
            colorValue: Value(colorValue),
            createdAtUtc: Value(DateTime.now().toUtc()),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> updateCollection(
    int id,
    String name,
    int colorValue, {
    String? description,
  }) async {
    await (_db.update(
      _db.collectionsTable,
    )..where((t) => t.id.equals(id))).write(
      CollectionsTableCompanion(
        name: Value(name.trim()),
        description: Value(description?.trim()),
        colorValue: Value(colorValue),
      ),
    );
  }

  Future<void> deleteCollection(int id) async {
    await (_db.delete(
      _db.collectionsTable,
    )..where((t) => t.id.equals(id))).go();
  }

  Future<void> addToCollection(String itemId, int collectionId) async {
    await _db
        .into(_db.itemCollectionsTable)
        .insert(
          ItemCollectionsTableCompanion.insert(
            itemId: itemId,
            collectionId: collectionId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> removeFromCollection(String itemId, int collectionId) async {
    await (_db.delete(_db.itemCollectionsTable)..where(
          (t) => t.itemId.equals(itemId) & t.collectionId.equals(collectionId),
        ))
        .go();
  }

  Future<void> setCollectionsForItem(
    String itemId,
    List<int> collectionIds,
  ) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.itemCollectionsTable,
      )..where((t) => t.itemId.equals(itemId))).go();
      for (final collectionId in collectionIds) {
        await _db
            .into(_db.itemCollectionsTable)
            .insert(
              ItemCollectionsTableCompanion.insert(
                itemId: itemId,
                collectionId: collectionId,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  Stream<List<Collection>> watchCollectionsForItem(String itemId) {
    return _db.watchCollectionsForItem(itemId).map((entries) {
      return entries
          .map(
            (e) => Collection(
              id: e.id,
              name: e.name,
              description: e.description,
              colorValue: e.colorValue,
              createdAtUtc: e.createdAtUtc,
            ),
          )
          .toList();
    });
  }

  Future<List<Collection>> getCollectionsForItem(String itemId) async {
    final entries = await _db.getCollectionsForItem(itemId);
    return entries
        .map(
          (e) => Collection(
            id: e.id,
            name: e.name,
            description: e.description,
            colorValue: e.colorValue,
            createdAtUtc: e.createdAtUtc,
          ),
        )
        .toList();
  }

  Stream<List<Collection>> watchCollectionsWithCounts() {
    return _db.watchCollectionsWithCounts().map((rows) {
      return rows
          .map(
            (pair) => Collection(
              id: pair.$1.id,
              name: pair.$1.name,
              description: pair.$1.description,
              colorValue: pair.$1.colorValue,
              createdAtUtc: pair.$1.createdAtUtc,
              itemCount: pair.$2,
            ),
          )
          .toList();
    });
  }

  Future<List<Collection>> getCollectionsWithCounts() async {
    final rows = await _db.getCollectionsWithCounts();
    return rows
        .map(
          (pair) => Collection(
            id: pair.$1.id,
            name: pair.$1.name,
            description: pair.$1.description,
            colorValue: pair.$1.colorValue,
            createdAtUtc: pair.$1.createdAtUtc,
            itemCount: pair.$2,
          ),
        )
        .toList();
  }

  Future<List<(String, int)>> getSubredditsForCollection(int collectionId) =>
      _db.getSubredditsForCollection(collectionId);
}
