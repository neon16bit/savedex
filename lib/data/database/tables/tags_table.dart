import 'package:drift/drift.dart';
import 'package:savedex/data/database/tables/saved_items_table.dart';

@DataClassName('TagEntry')
class TagsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFFFF4500))();
}

@DataClassName('ItemTagEntry')
class ItemTagsTable extends Table {
  TextColumn get itemId =>
      text().references(SavedItemsTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(TagsTable, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {itemId, tagId};
}
