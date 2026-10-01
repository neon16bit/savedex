import 'package:drift/drift.dart';
import 'package:savedex/data/database/database.dart';
import 'package:savedex/data/models/saved_item_model.dart';

class TagRepository {
  final AppDatabase _db;

  TagRepository(this._db);

  Stream<List<Tag>> watchAllTags() {
    return _db.select(_db.tagsTable).watch().map((entries) {
      return entries
          .map((e) => Tag(id: e.id, name: e.name, colorValue: e.colorValue))
          .toList();
    });
  }

  Future<List<Tag>> getAllTags() async {
    final entries = await _db.select(_db.tagsTable).get();
    return entries
        .map((e) => Tag(id: e.id, name: e.name, colorValue: e.colorValue))
        .toList();
  }

  Future<int> createTag(String name, int colorValue) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return -1;
    return await _db
        .into(_db.tagsTable)
        .insert(
          TagsTableCompanion.insert(
            name: cleanName,
            colorValue: Value(colorValue),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> updateTag(int id, String name, int colorValue) async {
    await (_db.update(_db.tagsTable)..where((t) => t.id.equals(id))).write(
      TagsTableCompanion(
        name: Value(name.trim()),
        colorValue: Value(colorValue),
      ),
    );
  }

  Future<void> deleteTag(int id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.itemTagsTable,
      )..where((t) => t.tagId.equals(id))).go();
      await (_db.delete(_db.tagsTable)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> assignTag(String itemId, int tagId) async {
    await _db
        .into(_db.itemTagsTable)
        .insert(
          ItemTagsTableCompanion.insert(itemId: itemId, tagId: tagId),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> removeTag(String itemId, int tagId) async {
    await (_db.delete(
      _db.itemTagsTable,
    )..where((t) => t.itemId.equals(itemId) & t.tagId.equals(tagId))).go();
  }

  Stream<List<Tag>> watchTagsForItem(String itemId) {
    return _db.watchTagsForItem(itemId).map((entries) {
      return entries
          .map((e) => Tag(id: e.id, name: e.name, colorValue: e.colorValue))
          .toList();
    });
  }

  Future<List<Tag>> getTagsForItem(String itemId) async {
    final entries = await _db.getTagsForItem(itemId);
    return entries
        .map((e) => Tag(id: e.id, name: e.name, colorValue: e.colorValue))
        .toList();
  }
}
