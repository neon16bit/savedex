import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/database/tables/saved_items_table.dart';
import 'package:savedex/data/database/tables/tags_table.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:sqlite3/sqlite3.dart';

part 'database.g.dart';

@DriftDatabase(tables: [SavedItemsTable, TagsTable, ItemTagsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase._([QueryExecutor? e]) : super(e ?? _openConnection());

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase._();

  factory AppDatabase([QueryExecutor? e]) {
    if (e != null) {
      return AppDatabase._(e);
    }
    return instance;
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbDir = await getApplicationSupportDirectory();
      final file = File(p.join(dbDir.path, 'savedex_db.sqlite'));
      final cachebase = (await getTemporaryDirectory()).path;
      sqlite3.tempDirectory = cachebase;

      return NativeDatabase.createInBackground(file);
    });
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createFts5(this);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(savedItemsTable, savedItemsTable.postFlair);
        await m.addColumn(savedItemsTable, savedItemsTable.subredditType);
        await _rebuildFts(this);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static Future<void> _createFts5(AppDatabase db) async {
    try {
      await db.customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS saved_items_fts USING fts5(
          id UNINDEXED,
          title,
          body,
          subreddit,
          author,
          user_note,
          post_flair,
          tokenize = 'unicode61'
        );
      ''');

      await db.customStatement('''
        CREATE TRIGGER IF NOT EXISTS saved_items_ai AFTER INSERT ON saved_items_table BEGIN
          INSERT INTO saved_items_fts(rowid, id, title, body, subreddit, author, user_note, post_flair)
          VALUES (new.rowid, new.id, new.title, coalesce(new.body, ''), new.subreddit, coalesce(new.author, ''), coalesce(new.user_note, ''), coalesce(new.post_flair, ''));
        END;
      ''');

      await db.customStatement('''
        CREATE TRIGGER IF NOT EXISTS saved_items_ad AFTER DELETE ON saved_items_table BEGIN
          DELETE FROM saved_items_fts WHERE id = old.id;
        END;
      ''');

      await db.customStatement('''
        CREATE TRIGGER IF NOT EXISTS saved_items_au AFTER UPDATE ON saved_items_table BEGIN
          DELETE FROM saved_items_fts WHERE id = old.id;
          INSERT INTO saved_items_fts(rowid, id, title, body, subreddit, author, user_note, post_flair)
          VALUES (new.rowid, new.id, new.title, coalesce(new.body, ''), new.subreddit, coalesce(new.author, ''), coalesce(new.user_note, ''), coalesce(new.post_flair, ''));
        END;
      ''');
    } catch (e, stack) {
      debugPrint('[Database] FTS5 initialization note: $e\n$stack');
      try {
        await db.customStatement('DROP TRIGGER IF EXISTS saved_items_ai');
        await db.customStatement('DROP TRIGGER IF EXISTS saved_items_ad');
        await db.customStatement('DROP TRIGGER IF EXISTS saved_items_au');
      } catch (_) {}
    }
  }

  static Future<void> _rebuildFts(AppDatabase db) async {
    try {
      await db.customStatement('DROP TRIGGER IF EXISTS saved_items_ai');
      await db.customStatement('DROP TRIGGER IF EXISTS saved_items_ad');
      await db.customStatement('DROP TRIGGER IF EXISTS saved_items_au');
      await db.customStatement('DROP TABLE IF EXISTS saved_items_fts');
      await _createFts5(db);
      await db.customStatement('''
        INSERT INTO saved_items_fts(rowid, id, title, body, subreddit, author, user_note, post_flair)
        SELECT rowid, id, title, coalesce(body, ''), subreddit, coalesce(author, ''), coalesce(user_note, ''), coalesce(post_flair, '')
        FROM saved_items_table;
      ''');
    } catch (e, stack) {
      debugPrint('[Database] FTS5 rebuild failed: $e\n$stack');
      rethrow;
    }
  }

  Stream<List<SavedItemEntry>> watchFilteredSavedItems({
    String? searchQuery,
    Set<String> subreddits = const {},
    Set<String> authors = const {},
    Set<String> flairs = const {},
    Set<MediaType> mediaTypes = const {},
    ItemType? itemType,
    EnrichmentStatus? enrichmentStatus,
    bool? isNsfw,
    bool? isStarred,
    bool? isArchived,
    Set<int> tagIds = const {},
    SortOption sortOption = SortOption.savedOrderDesc,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
  }) {
    final query = select(savedItemsTable);

    query.where((tbl) {
      Expression<bool> predicate = const Constant(true);

      if (isArchived != null) {
        predicate = predicate & tbl.isArchived.equals(isArchived);
      }

      if (itemType != null) {
        predicate = predicate & tbl.itemType.equals(itemType.index);
      }

      if (enrichmentStatus != null) {
        predicate =
            predicate & tbl.enrichmentStatus.equals(enrichmentStatus.index);
      }

      if (isNsfw != null) {
        predicate = predicate & tbl.isNsfw.equals(isNsfw);
      }

      if (isStarred != null) {
        predicate = predicate & tbl.isStarred.equals(isStarred);
      }

      if (subreddits.isNotEmpty) {
        predicate = predicate & tbl.subreddit.isIn(subreddits);
      }

      if (authors.isNotEmpty) {
        predicate = predicate & tbl.author.isIn(authors);
      }

      if (flairs.isNotEmpty) {
        predicate = predicate & tbl.postFlair.isIn(flairs);
      }

      if (mediaTypes.isNotEmpty) {
        predicate =
            predicate & tbl.mediaType.isIn(mediaTypes.map((m) => m.index));
      }

      if (dateRangeStart != null) {
        predicate =
            predicate &
            tbl.createdAtUtc.isBiggerOrEqualValue(dateRangeStart.toUtc());
      }

      if (dateRangeEnd != null) {
        final inclusiveEnd =
            (dateRangeEnd.hour == 0 &&
                dateRangeEnd.minute == 0 &&
                dateRangeEnd.second == 0 &&
                dateRangeEnd.millisecond == 0)
            ? DateTime(
                dateRangeEnd.year,
                dateRangeEnd.month,
                dateRangeEnd.day,
                23,
                59,
                59,
                999,
              ).toUtc()
            : dateRangeEnd.toUtc();
        predicate =
            predicate & tbl.createdAtUtc.isSmallerOrEqualValue(inclusiveEnd);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final queryPattern = '%${searchQuery.trim().toLowerCase()}%';
        final titleMatch = tbl.title.lower().like(queryPattern);
        final bodyMatch = tbl.body.lower().like(queryPattern);
        final subMatch = tbl.subreddit.lower().like(queryPattern);
        final authorMatch = tbl.author.lower().like(queryPattern);
        final noteMatch = tbl.userNote.lower().like(queryPattern);
        final flairMatch = tbl.postFlair.lower().like(queryPattern);

        predicate =
            predicate &
            (titleMatch |
                bodyMatch |
                subMatch |
                authorMatch |
                noteMatch |
                flairMatch);
      }

      return predicate;
    });

    if (tagIds.isNotEmpty) {
      query.where((tbl) {
        final matchingItemsQuery = selectOnly(itemTagsTable)
          ..addColumns([itemTagsTable.itemId])
          ..where(itemTagsTable.tagId.isIn(tagIds));
        return tbl.id.isInQuery(matchingItemsQuery);
      });
    }

    // apply sorting
    query.orderBy([
      (tbl) {
        switch (sortOption) {
          case SortOption.savedOrderDesc:
            return OrderingTerm(
              expression: tbl.importOrder,
              mode: OrderingMode.desc,
            );
          case SortOption.savedOrderAsc:
            return OrderingTerm(
              expression: tbl.importOrder,
              mode: OrderingMode.asc,
            );
          case SortOption.createdDateDesc:
            return OrderingTerm(
              expression: tbl.createdAtUtc,
              mode: OrderingMode.desc,
            );
          case SortOption.createdDateAsc:
            return OrderingTerm(
              expression: tbl.createdAtUtc,
              mode: OrderingMode.asc,
            );
          case SortOption.scoreDesc:
            return OrderingTerm(expression: tbl.score, mode: OrderingMode.desc);
          case SortOption.scoreAsc:
            return OrderingTerm(expression: tbl.score, mode: OrderingMode.asc);
          case SortOption.subredditAsc:
            return OrderingTerm(
              expression: tbl.subreddit.lower(),
              mode: OrderingMode.asc,
            );
          case SortOption.subredditDesc:
            return OrderingTerm(
              expression: tbl.subreddit.lower(),
              mode: OrderingMode.desc,
            );
          case SortOption.authorAsc:
            return OrderingTerm(
              expression: tbl.author.lower(),
              mode: OrderingMode.asc,
            );
          case SortOption.authorDesc:
            return OrderingTerm(
              expression: tbl.author.lower(),
              mode: OrderingMode.desc,
            );
          case SortOption.titleAsc:
            return OrderingTerm(
              expression: tbl.title.lower(),
              mode: OrderingMode.asc,
            );
          case SortOption.commentsDesc:
            return OrderingTerm(
              expression: tbl.numComments,
              mode: OrderingMode.desc,
            );
        }
      },
    ]);

    return query.watch();
  }

  // bulk upsert items nondestructively using ON CONFLICT DO UPDATE
  Future<void> upsertBatch(List<SavedItemsTableCompanion> entries) async {
    if (entries.isEmpty) return;
    const chunkSize = 100;
    for (var i = 0; i < entries.length; i += chunkSize) {
      final chunk = entries.sublist(
        i,
        i + chunkSize > entries.length ? entries.length : i + chunkSize,
      );
      await batch((batch) {
        batch.insertAllOnConflictUpdate(savedItemsTable, chunk);
      });
    }
  }

  Future<List<(String, int)>> getSubredditsWithCounts() async {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)
      ..addColumns([savedItemsTable.subreddit, countExp])
      ..groupBy([savedItemsTable.subreddit])
      ..orderBy([OrderingTerm(expression: countExp, mode: OrderingMode.desc)]);

    final rows = await query.get();
    return rows.map((row) {
      return (row.read(savedItemsTable.subreddit)!, row.read(countExp) ?? 0);
    }).toList();
  }

  Future<List<(String, int)>> getAuthorsWithCounts() async {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)
      ..addColumns([savedItemsTable.author, countExp])
      ..where(
        savedItemsTable.author.isNotNull() &
            savedItemsTable.author.isBiggerThanValue(''),
      )
      ..groupBy([savedItemsTable.author])
      ..orderBy([OrderingTerm(expression: countExp, mode: OrderingMode.desc)]);

    final rows = await query.get();
    return rows.map((row) {
      return (row.read(savedItemsTable.author)!, row.read(countExp) ?? 0);
    }).toList();
  }

  Future<List<(String, int)>> getFlairsWithCounts() async {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)
      ..addColumns([savedItemsTable.postFlair, countExp])
      ..where(
        savedItemsTable.postFlair.isNotNull() &
            savedItemsTable.postFlair.isBiggerThanValue(''),
      )
      ..groupBy([savedItemsTable.postFlair])
      ..orderBy([OrderingTerm(expression: countExp, mode: OrderingMode.desc)]);

    final rows = await query.get();
    return rows.map((row) {
      return (row.read(savedItemsTable.postFlair)!, row.read(countExp) ?? 0);
    }).toList();
  }

  Future<List<String>> getDistinctAuthors() async {
    final query = selectOnly(savedItemsTable, distinct: true)
      ..addColumns([savedItemsTable.author])
      ..where(savedItemsTable.author.isNotNull())
      ..orderBy([
        OrderingTerm(
          expression: savedItemsTable.author,
          mode: OrderingMode.asc,
        ),
      ]);

    final rows = await query.get();
    return rows
        .map((row) => row.read(savedItemsTable.author)!)
        .where((a) => a.isNotEmpty)
        .toList();
  }

  Stream<List<TagEntry>> watchTagsForItem(String itemId) {
    final query = select(tagsTable).join([
      innerJoin(itemTagsTable, itemTagsTable.tagId.equalsExp(tagsTable.id)),
    ])..where(itemTagsTable.itemId.equals(itemId));

    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(tagsTable)).toList(),
    );
  }

  Future<List<TagEntry>> getTagsForItem(String itemId) {
    final query = select(tagsTable).join([
      innerJoin(itemTagsTable, itemTagsTable.tagId.equalsExp(tagsTable.id)),
    ])..where(itemTagsTable.itemId.equals(itemId));

    return query.map((r) => r.readTable(tagsTable)).get();
  }

  Future<List<SavedItemEntry>> getPendingEnrichmentItems({
    int limit = 50,
    List<String> excludeIds = const [],
  }) {
    Expression<bool> predicate = savedItemsTable.enrichmentStatus.isIn([
      EnrichmentStatus.slugOnly.index,
      EnrichmentStatus.pending.index,
    ]);
    if (excludeIds.isNotEmpty) {
      predicate = predicate & savedItemsTable.id.isNotIn(excludeIds);
    }
    return (select(savedItemsTable)
          ..where((tbl) => predicate)
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.importOrder,
              mode: OrderingMode.asc,
            ),
          ])
          ..limit(limit))
        .get();
  }

  Future<int> getPendingEnrichmentCount() async {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)
      ..addColumns([countExp])
      ..where(
        savedItemsTable.enrichmentStatus.isIn([
          EnrichmentStatus.slugOnly.index,
          EnrichmentStatus.pending.index,
        ]),
      );
    final row = await query.getSingleOrNull();
    return row?.read(countExp) ?? 0;
  }

  Stream<int> watchPendingEnrichmentCount() {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)
      ..addColumns([countExp])
      ..where(
        savedItemsTable.enrichmentStatus.isIn([
          EnrichmentStatus.slugOnly.index,
          EnrichmentStatus.pending.index,
        ]),
      );
    return query.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  Future<int> getTotalCount() async {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)..addColumns([countExp]);
    final row = await query.getSingleOrNull();
    return row?.read(countExp) ?? 0;
  }

  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(itemTagsTable).go();
      await delete(tagsTable).go();
      await delete(savedItemsTable).go();
      try {
        await customStatement('DELETE FROM saved_items_fts;');
      } catch (e, stack) {
        debugPrint('[Database] Note: Could not clear FTS5 index: $e\n$stack');
      }
    });
  }
}

extension SavedItemEntryExtension on SavedItemEntry {
  SavedItem toDomain({List<Tag> tags = const []}) {
    return SavedItem(
      id: id,
      permalink: permalink,
      itemType: itemType,
      parentPostId: parentPostId,
      parentPostTitle: parentPostTitle,
      title: title,
      subreddit: subreddit,
      author: author,
      body: body,
      url: url,
      thumbnailUrl: thumbnailUrl,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      score: score,
      numComments: numComments,
      isNsfw: isNsfw,
      isStarred: isStarred,
      isArchived: isArchived,
      userNote: userNote,
      csvSource: csvSource,
      importOrder: importOrder,
      createdAtUtc: createdAtUtc,
      savedAtUtc: savedAtUtc,
      postFlair: postFlair,
      subredditType: subredditType,
      enrichmentStatus: enrichmentStatus,
      tags: tags,
    );
  }
}
