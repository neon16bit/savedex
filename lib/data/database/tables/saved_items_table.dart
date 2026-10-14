import 'package:drift/drift.dart';
import 'package:savedex/core/constants/constants.dart';

@DataClassName('SavedItemEntry')
class SavedItemsTable extends Table {
  TextColumn get id => text()();
  TextColumn get permalink => text()();
  IntColumn get itemType => intEnum<ItemType>()();
  TextColumn get parentPostId => text().nullable()();
  TextColumn get parentPostTitle => text().nullable()();
  TextColumn get title => text()();
  TextColumn get subreddit => text()();
  TextColumn get author => text().nullable()();
  TextColumn get body => text().nullable()();
  TextColumn get url => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get mediaUrl => text().nullable()();
  TextColumn get galleryImages => text().nullable()();
  TextColumn get galleryPreviewImages => text().nullable()();
  IntColumn get mediaType =>
      intEnum<MediaType>().withDefault(Constant(MediaType.text.index))();
  IntColumn get score => integer().withDefault(const Constant(0))();
  IntColumn get numComments => integer().withDefault(const Constant(0))();
  BoolColumn get isNsfw => boolean().withDefault(const Constant(false))();
  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get userNote => text().nullable()();
  TextColumn get csvSource =>
      text().withDefault(const Constant('saved_posts.csv'))();
  IntColumn get importOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAtUtc => dateTime().nullable()();
  DateTimeColumn get savedAtUtc => dateTime()();
  TextColumn get postFlair => text().nullable()();
  TextColumn get subredditType =>
      text().withDefault(const Constant('public'))();
  IntColumn get enrichmentStatus => intEnum<EnrichmentStatus>().withDefault(
    Constant(EnrichmentStatus.slugOnly.index),
  )();
  BoolColumn get isArchiveRecovered =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
