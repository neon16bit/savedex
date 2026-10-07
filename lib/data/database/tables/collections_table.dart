import 'package:drift/drift.dart';
import 'package:savedex/data/database/tables/saved_items_table.dart';

@DataClassName('CollectionEntry')
class CollectionsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get description => text().nullable()();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFFFF4500))();
  DateTimeColumn get createdAtUtc => dateTime().nullable()();
}

@DataClassName('ItemCollectionEntry')
class ItemCollectionsTable extends Table {
  TextColumn get itemId =>
      text().references(SavedItemsTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get collectionId => integer().references(
    CollectionsTable,
    #id,
    onDelete: KeyAction.cascade,
  )();

  @override
  Set<Column> get primaryKey => {itemId, collectionId};
}
