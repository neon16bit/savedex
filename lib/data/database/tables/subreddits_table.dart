import 'package:drift/drift.dart';

@DataClassName('SubredditEntry')
class SubredditsTable extends Table {
  TextColumn get name => text()();
  // null = unverified, true/false = verified.
  BoolColumn get isNsfw => boolean().nullable()();
  TextColumn get iconUrl => text().nullable()();
  DateTimeColumn get lastChecked => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {name};
}
