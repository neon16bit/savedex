import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/database/tables/collections_table.dart';
import 'package:savedex/data/database/tables/saved_items_table.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:sqlite3/sqlite3.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [SavedItemsTable, CollectionsTable, ItemCollectionsTable],
)
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
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createFts5(this);
      await _createIndexes(this);
      _ftsInitFuture = Future.value();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(savedItemsTable, savedItemsTable.postFlair);
        await m.addColumn(savedItemsTable, savedItemsTable.subredditType);
        await _rebuildFts(this);
      }
      if (from < 3) {
        await _createIndexes(this);
      }
      if (from < 4) {
        await _rebuildFts(this);
      }
      if (from < 5) {
        await _createIndexes(this);
      }
      if (from < 6) {
        await customStatement('DROP TABLE IF EXISTS item_tags_table;');
        await customStatement('DROP TABLE IF EXISTS tags_table;');
        await m.createTable(collectionsTable);
        await m.createTable(itemCollectionsTable);
      }
      if (from < 7) {
        await m.addColumn(savedItemsTable, savedItemsTable.isArchiveRecovered);
      }
      if (from < 8) {
        await m.addColumn(savedItemsTable, savedItemsTable.galleryImages);
      }
      if (from < 9) {
        await m.addColumn(
          savedItemsTable,
          savedItemsTable.galleryPreviewImages,
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _createFts5(this);
      _ftsInitFuture = Future.value();
    },
  );

  Future<void>? _ftsInitFuture;

  Future<void> ensureFtsSchema() {
    return _ftsInitFuture ??= () async {
      try {
        await _createFts5(this);
      } catch (e) {
        _ftsInitFuture = null;
        rethrow;
      }
    }();
  }

  static Future<void> _createIndexes(AppDatabase db) async {
    try {
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_order_desc ON saved_items_table (import_order DESC, id DESC);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_order_asc ON saved_items_table (import_order ASC, id ASC);
      ''');

      await db.customStatement('DROP INDEX IF EXISTS idx_saved_date_desc;');
      await db.customStatement('DROP INDEX IF EXISTS idx_saved_date_asc;');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_date_desc ON saved_items_table (COALESCE(created_at_utc, 0) DESC, id DESC);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_date_asc ON saved_items_table (COALESCE(created_at_utc, 0) ASC, id ASC);
      ''');

      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_score_desc ON saved_items_table (score DESC, id DESC);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_score_asc ON saved_items_table (score ASC, id ASC);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_sub_nocase ON saved_items_table (subreddit COLLATE NOCASE, id);
      ''');

      await db.customStatement('DROP INDEX IF EXISTS idx_saved_author_nocase;');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_author_nocase ON saved_items_table (COALESCE(author, '') COLLATE NOCASE, id);
      ''');

      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_title_nocase ON saved_items_table (title COLLATE NOCASE, id);
      ''');
      await db.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_saved_comments_desc ON saved_items_table (num_comments DESC, id DESC);
      ''');
    } catch (e, stack) {
      debugPrint('[Database] Create indexes note: $e\n$stack');
    }
  }

  static Future<void> _createFts5(AppDatabase db) async {
    try {
      bool needsRebuild = false;
      try {
        await db.customStatement(
          'SELECT parent_post_title FROM saved_items_fts LIMIT 0;',
        );
      } catch (_) {
        needsRebuild = true;
      }

      if (needsRebuild) {
        await db.customStatement('DROP TRIGGER IF EXISTS saved_items_ai');
        await db.customStatement('DROP TRIGGER IF EXISTS saved_items_ad');
        await db.customStatement('DROP TRIGGER IF EXISTS saved_items_au');
        await db.customStatement('DROP TABLE IF EXISTS saved_items_fts');
      }

      await db.customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS saved_items_fts USING fts5(
          id UNINDEXED,
          title,
          body,
          parent_post_title,
          user_note,
          tokenize = 'unicode61'
        );
      ''');

      await db.customStatement('''
        CREATE TRIGGER IF NOT EXISTS saved_items_ai AFTER INSERT ON saved_items_table BEGIN
          INSERT INTO saved_items_fts(rowid, id, title, body, parent_post_title, user_note)
          VALUES (
            new.rowid,
            new.id,
            new.title,
            coalesce(new.body, ''),
            coalesce(new.parent_post_title, ''),
            coalesce(new.user_note, '')
          );
        END;
      ''');

      await db.customStatement('''
        CREATE TRIGGER IF NOT EXISTS saved_items_ad AFTER DELETE ON saved_items_table BEGIN
          DELETE FROM saved_items_fts WHERE rowid = old.rowid;
        END;
      ''');

      await db.customStatement('''
        CREATE TRIGGER IF NOT EXISTS saved_items_au AFTER UPDATE ON saved_items_table BEGIN
          DELETE FROM saved_items_fts WHERE rowid = old.rowid;
          INSERT INTO saved_items_fts(rowid, id, title, body, parent_post_title, user_note)
          VALUES (
            new.rowid,
            new.id,
            new.title,
            coalesce(new.body, ''),
            coalesce(new.parent_post_title, ''),
            coalesce(new.user_note, '')
          );
        END;
      ''');

      if (needsRebuild) {
        await db.customStatement('''
          INSERT INTO saved_items_fts(rowid, id, title, body, parent_post_title, user_note)
          SELECT
            rowid,
            id,
            title,
            coalesce(body, ''),
            coalesce(parent_post_title, ''),
            coalesce(user_note, '')
          FROM saved_items_table;
        ''');
      }
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
      db._ftsInitFuture = null;
      await db.customStatement('DROP TRIGGER IF EXISTS saved_items_ai');
      await db.customStatement('DROP TRIGGER IF EXISTS saved_items_ad');
      await db.customStatement('DROP TRIGGER IF EXISTS saved_items_au');
      await db.customStatement('DROP TABLE IF EXISTS saved_items_fts');
      await _createFts5(db);
      db._ftsInitFuture = Future.value();
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
    Set<int> collectionIds = const {},
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
        final parentPostTitleMatch = tbl.parentPostTitle.lower().like(
          queryPattern,
        );
        final noteMatch = tbl.userNote.lower().like(queryPattern);

        predicate =
            predicate &
            (titleMatch | bodyMatch | parentPostTitleMatch | noteMatch);
      }

      return predicate;
    });

    if (collectionIds.isNotEmpty) {
      query.where((tbl) {
        final matchingItemsQuery = selectOnly(itemCollectionsTable)
          ..addColumns([itemCollectionsTable.itemId])
          ..where(itemCollectionsTable.collectionId.isIn(collectionIds));
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
              expression: coalesce([
                tbl.createdAtUtc,
                Constant(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
              ]),
              mode: OrderingMode.desc,
            );
          case SortOption.createdDateAsc:
            return OrderingTerm(
              expression: coalesce([
                tbl.createdAtUtc,
                Constant(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
              ]),
              mode: OrderingMode.asc,
            );
          case SortOption.scoreDesc:
            return OrderingTerm(expression: tbl.score, mode: OrderingMode.desc);
          case SortOption.scoreAsc:
            return OrderingTerm(expression: tbl.score, mode: OrderingMode.asc);
          case SortOption.subredditAsc:
            return OrderingTerm(
              expression: tbl.subreddit.collate(Collate.noCase),
              mode: OrderingMode.asc,
            );
          case SortOption.subredditDesc:
            return OrderingTerm(
              expression: tbl.subreddit.collate(Collate.noCase),
              mode: OrderingMode.desc,
            );
          case SortOption.authorAsc:
            return OrderingTerm(
              expression: coalesce([tbl.author, const Constant('')])
                  .collate(Collate.noCase),
              mode: OrderingMode.asc,
            );
          case SortOption.authorDesc:
            return OrderingTerm(
              expression: coalesce([tbl.author, const Constant('')])
                  .collate(Collate.noCase),
              mode: OrderingMode.desc,
            );
          case SortOption.titleAsc:
            return OrderingTerm(
              expression: tbl.title.collate(Collate.noCase),
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

  static String? _sanitizeFtsQuery(String? raw) {
    if (raw == null) return null;
    final terms = raw
        .trim()
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'["*]'), ''))
        .where((t) => t.isNotEmpty)
        .map((t) => '"$t"*')
        .join(' ');
    return terms.isEmpty ? null : terms;
  }

  static FeedCursor _extractCursor(SavedItemEntry entry, SortOption sort) {
    switch (sort) {
      case SortOption.savedOrderDesc:
      case SortOption.savedOrderAsc:
        return FeedCursor(sortValue: entry.importOrder, id: entry.id);
      case SortOption.createdDateDesc:
      case SortOption.createdDateAsc:
        return FeedCursor(
          sortValue: entry.createdAtUtc?.millisecondsSinceEpoch ?? 0,
          id: entry.id,
        );
      case SortOption.scoreDesc:
      case SortOption.scoreAsc:
        return FeedCursor(sortValue: entry.score, id: entry.id);
      case SortOption.subredditAsc:
      case SortOption.subredditDesc:
        return FeedCursor(sortValue: entry.subreddit, id: entry.id);
      case SortOption.authorAsc:
      case SortOption.authorDesc:
        return FeedCursor(sortValue: entry.author ?? '', id: entry.id);
      case SortOption.titleAsc:
        return FeedCursor(sortValue: entry.title, id: entry.id);
      case SortOption.commentsDesc:
        return FeedCursor(sortValue: entry.numComments, id: entry.id);
    }
  }

  static (String, List<Variable>) _buildKeysetRowValue(
    SortOption sort,
    FeedCursor cursor,
  ) {
    switch (sort) {
      case SortOption.savedOrderDesc:
        return (
          '(s.import_order, s.id) < (?, ?)',
          [
            Variable.withInt(cursor.sortValue as int),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.savedOrderAsc:
        return (
          '(s.import_order, s.id) > (?, ?)',
          [
            Variable.withInt(cursor.sortValue as int),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.createdDateDesc:
        return (
          '(COALESCE(s.created_at_utc, 0), s.id) < (?, ?)',
          [
            Variable.withDateTime(
              DateTime.fromMillisecondsSinceEpoch(
                cursor.sortValue as int,
                isUtc: true,
              ),
            ),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.createdDateAsc:
        return (
          '(COALESCE(s.created_at_utc, 0), s.id) > (?, ?)',
          [
            Variable.withDateTime(
              DateTime.fromMillisecondsSinceEpoch(
                cursor.sortValue as int,
                isUtc: true,
              ),
            ),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.scoreDesc:
        return (
          '(s.score, s.id) < (?, ?)',
          [
            Variable.withInt(cursor.sortValue as int),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.scoreAsc:
        return (
          '(s.score, s.id) > (?, ?)',
          [
            Variable.withInt(cursor.sortValue as int),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.subredditAsc:
        return (
          '(s.subreddit COLLATE NOCASE, s.id) > (?, ?)',
          [
            Variable.withString(cursor.sortValue as String),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.subredditDesc:
        return (
          '(s.subreddit COLLATE NOCASE, s.id) < (?, ?)',
          [
            Variable.withString(cursor.sortValue as String),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.authorAsc:
        return (
          "(COALESCE(s.author, '') COLLATE NOCASE, s.id) > (?, ?)",
          [
            Variable.withString(cursor.sortValue as String),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.authorDesc:
        return (
          "(COALESCE(s.author, '') COLLATE NOCASE, s.id) < (?, ?)",
          [
            Variable.withString(cursor.sortValue as String),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.titleAsc:
        return (
          '(s.title COLLATE NOCASE, s.id) > (?, ?)',
          [
            Variable.withString(cursor.sortValue as String),
            Variable.withString(cursor.id),
          ],
        );
      case SortOption.commentsDesc:
        return (
          '(s.num_comments, s.id) < (?, ?)',
          [
            Variable.withInt(cursor.sortValue as int),
            Variable.withString(cursor.id),
          ],
        );
    }
  }

  static String _buildOrderBySql(SortOption sort) {
    switch (sort) {
      case SortOption.savedOrderDesc:
        return 's.import_order DESC, s.id DESC';
      case SortOption.savedOrderAsc:
        return 's.import_order ASC, s.id ASC';
      case SortOption.createdDateDesc:
        return 'COALESCE(s.created_at_utc, 0) DESC, s.id DESC';
      case SortOption.createdDateAsc:
        return 'COALESCE(s.created_at_utc, 0) ASC, s.id ASC';
      case SortOption.scoreDesc:
        return 's.score DESC, s.id DESC';
      case SortOption.scoreAsc:
        return 's.score ASC, s.id ASC';
      case SortOption.subredditAsc:
        return 's.subreddit COLLATE NOCASE ASC, s.id ASC';
      case SortOption.subredditDesc:
        return 's.subreddit COLLATE NOCASE DESC, s.id DESC';
      case SortOption.authorAsc:
        return "COALESCE(s.author, '') COLLATE NOCASE ASC, s.id ASC";
      case SortOption.authorDesc:
        return "COALESCE(s.author, '') COLLATE NOCASE DESC, s.id DESC";
      case SortOption.titleAsc:
        return 's.title COLLATE NOCASE ASC, s.id ASC';
      case SortOption.commentsDesc:
        return 's.num_comments DESC, s.id DESC';
    }
  }

  (List<String>, List<Variable>) _buildFilterClauses(FilterCriteria filter) {
    final where = <String>[];
    final vars = <Variable>[];

    if (filter.isArchived != null) {
      where.add('s.is_archived = ?');
      vars.add(Variable.withBool(filter.isArchived!));
    }
    if (filter.itemType != null) {
      where.add('s.item_type = ?');
      vars.add(Variable.withInt(filter.itemType!.index));
    }
    if (filter.enrichmentStatus != null) {
      where.add('s.enrichment_status = ?');
      vars.add(Variable.withInt(filter.enrichmentStatus!.index));
    }
    if (filter.isNsfw != null) {
      where.add('s.is_nsfw = ?');
      vars.add(Variable.withBool(filter.isNsfw!));
    }
    if (filter.isStarred != null) {
      where.add('s.is_starred = ?');
      vars.add(Variable.withBool(filter.isStarred!));
    }
    if (filter.selectedSubreddits.isNotEmpty) {
      where.add(
        's.subreddit IN (${List.filled(filter.selectedSubreddits.length, '?').join(',')})',
      );
      vars.addAll(filter.selectedSubreddits.map(Variable.withString));
    }
    if (filter.selectedAuthors.isNotEmpty) {
      where.add(
        's.author IN (${List.filled(filter.selectedAuthors.length, '?').join(',')})',
      );
      vars.addAll(filter.selectedAuthors.map(Variable.withString));
    }
    if (filter.selectedFlairs.isNotEmpty) {
      where.add(
        's.post_flair IN (${List.filled(filter.selectedFlairs.length, '?').join(',')})',
      );
      vars.addAll(filter.selectedFlairs.map(Variable.withString));
    }
    if (filter.selectedMediaTypes.isNotEmpty) {
      where.add(
        's.media_type IN (${List.filled(filter.selectedMediaTypes.length, '?').join(',')})',
      );
      vars.addAll(
        filter.selectedMediaTypes.map((m) => Variable.withInt(m.index)),
      );
    }
    if (filter.dateRangeStart != null) {
      where.add('s.created_at_utc >= ?');
      vars.add(Variable.withDateTime(filter.dateRangeStart!.toUtc()));
    }
    if (filter.dateRangeEnd != null) {
      final end = filter.dateRangeEnd!;
      final inclusiveEnd =
          (end.hour == 0 &&
              end.minute == 0 &&
              end.second == 0 &&
              end.millisecond == 0)
          ? DateTime(end.year, end.month, end.day, 23, 59, 59, 999).toUtc()
          : end.toUtc();
      where.add('s.created_at_utc <= ?');
      vars.add(Variable.withDateTime(inclusiveEnd));
    }
    if (filter.selectedCollectionIds.isNotEmpty) {
      where.add(
        's.id IN (SELECT item_id FROM item_collections_table WHERE collection_id IN (${List.filled(filter.selectedCollectionIds.length, '?').join(',')}))',
      );
      vars.addAll(filter.selectedCollectionIds.map(Variable.withInt));
    }
    if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
      final ftsToken = _sanitizeFtsQuery(filter.searchQuery!);
      if (ftsToken != null) {
        where.add(
          's.id IN (SELECT id FROM saved_items_fts WHERE saved_items_fts MATCH ?)',
        );
        vars.add(Variable.withString(ftsToken));
      }
    }

    return (where, vars);
  }

  Future<PagedRows<SavedItemEntry>> getSavedItemsKeysetPage({
    required FilterCriteria filter,
    FeedCursor? cursor,
    int limit = 100,
  }) async {
    if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
      await ensureFtsSchema();
    }
    final (where, vars) = _buildFilterClauses(filter);

    if (cursor != null) {
      final (clause, cursorVars) = _buildKeysetRowValue(
        filter.sortOption,
        cursor,
      );
      where.add(clause);
      vars.addAll(cursorVars);
    }

    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final orderBy = 'ORDER BY ${_buildOrderBySql(filter.sortOption)}';

    vars.add(Variable.withInt(limit + 1));
    final sql =
        '''
      SELECT s.*
      FROM saved_items_table s
      $whereClause
      $orderBy
      LIMIT ?
    ''';

    final rows = await customSelect(
      sql,
      variables: vars,
      readsFrom: {savedItemsTable},
    ).get();

    final entries = rows.map((r) => savedItemsTable.map(r.data)).toList();
    final hasMore = entries.length > limit;
    final pageRows = hasMore ? entries.sublist(0, limit) : entries;

    FeedCursor? nextCursor;
    if (hasMore && pageRows.isNotEmpty) {
      nextCursor = _extractCursor(pageRows.last, filter.sortOption);
    }

    return PagedRows(items: pageRows, nextCursor: nextCursor, hasMore: hasMore);
  }

  Future<int> countFilteredSavedItems(FilterCriteria filter) async {
    if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
      await ensureFtsSchema();
    }
    final (where, vars) = _buildFilterClauses(filter);
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final sql = 'SELECT COUNT(*) AS c FROM saved_items_table s $whereClause';

    final row = await customSelect(
      sql,
      variables: vars,
      readsFrom: {savedItemsTable},
    ).getSingle();

    return row.read<int>('c');
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

  Stream<List<(String, int)>> watchSubredditsWithCounts() {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)
      ..addColumns([savedItemsTable.subreddit, countExp])
      ..groupBy([savedItemsTable.subreddit])
      ..orderBy([OrderingTerm(expression: countExp, mode: OrderingMode.desc)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return (row.read(savedItemsTable.subreddit)!, row.read(countExp) ?? 0);
      }).toList();
    });
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

  Stream<List<CollectionEntry>> watchCollectionsForItem(String itemId) {
    final query = select(collectionsTable).join([
      innerJoin(
        itemCollectionsTable,
        itemCollectionsTable.collectionId.equalsExp(collectionsTable.id),
      ),
    ])..where(itemCollectionsTable.itemId.equals(itemId));

    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(collectionsTable)).toList(),
    );
  }

  Future<List<CollectionEntry>> getCollectionsForItem(String itemId) {
    final query = select(collectionsTable).join([
      innerJoin(
        itemCollectionsTable,
        itemCollectionsTable.collectionId.equalsExp(collectionsTable.id),
      ),
    ])..where(itemCollectionsTable.itemId.equals(itemId));

    return query.map((r) => r.readTable(collectionsTable)).get();
  }

  Stream<List<(CollectionEntry, int)>> watchCollectionsWithCounts() {
    final countExp = itemCollectionsTable.itemId.count();
    final query =
        select(collectionsTable).join([
            leftOuterJoin(
              itemCollectionsTable,
              itemCollectionsTable.collectionId.equalsExp(collectionsTable.id),
            ),
          ])
          ..addColumns([countExp])
          ..groupBy([collectionsTable.id])
          ..orderBy([
            OrderingTerm(
              expression: collectionsTable.name,
              mode: OrderingMode.asc,
            ),
          ]);

    return query.watch().map((rows) {
      return rows.map((r) {
        return (r.readTable(collectionsTable), r.read(countExp) ?? 0);
      }).toList();
    });
  }

  Future<List<(CollectionEntry, int)>> getCollectionsWithCounts() async {
    final countExp = itemCollectionsTable.itemId.count();
    final query =
        select(collectionsTable).join([
            leftOuterJoin(
              itemCollectionsTable,
              itemCollectionsTable.collectionId.equalsExp(collectionsTable.id),
            ),
          ])
          ..addColumns([countExp])
          ..groupBy([collectionsTable.id])
          ..orderBy([
            OrderingTerm(
              expression: collectionsTable.name,
              mode: OrderingMode.asc,
            ),
          ]);

    final rows = await query.get();
    return rows.map((r) {
      return (r.readTable(collectionsTable), r.read(countExp) ?? 0);
    }).toList();
  }

  Future<List<(String, int)>> getSubredditsForCollection(
    int collectionId,
  ) async {
    final countExp = savedItemsTable.id.count();
    final query =
        selectOnly(savedItemsTable).join([
            innerJoin(
              itemCollectionsTable,
              itemCollectionsTable.itemId.equalsExp(savedItemsTable.id),
            ),
          ])
          ..addColumns([savedItemsTable.subreddit, countExp])
          ..where(itemCollectionsTable.collectionId.equals(collectionId))
          ..groupBy([savedItemsTable.subreddit])
          ..orderBy([
            OrderingTerm(expression: countExp, mode: OrderingMode.desc),
          ]);

    final rows = await query.get();
    return rows.map((row) {
      return (row.read(savedItemsTable.subreddit)!, row.read(countExp) ?? 0);
    }).toList();
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

  Future<List<SavedItemEntry>> getArchiveRecoveryItems({
    int limit = 50,
    List<String> excludeIds = const [],
  }) {
    Expression<bool> predicate =
        savedItemsTable.isArchiveRecovered.equals(false) &
        (savedItemsTable.enrichmentStatus.equals(
              EnrichmentStatus.failed.index,
            ) |
            savedItemsTable.author.isIn(['[deleted]', '[removed]']) |
            savedItemsTable.body.isIn(['[deleted]', '[removed]']) |
            savedItemsTable.title.isIn(['[deleted]', '[removed]']));
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

  Future<int> getArchiveRecoveryCount() async {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)
      ..addColumns([countExp])
      ..where(
        savedItemsTable.isArchiveRecovered.equals(false) &
            (savedItemsTable.enrichmentStatus.equals(
                  EnrichmentStatus.failed.index,
                ) |
                savedItemsTable.author.isIn(['[deleted]', '[removed]']) |
                savedItemsTable.body.isIn(['[deleted]', '[removed]']) |
                savedItemsTable.title.isIn(['[deleted]', '[removed]'])),
      );
    final row = await query.getSingleOrNull();
    return row?.read(countExp) ?? 0;
  }

  Stream<int> watchArchiveRecoveryCount() {
    final countExp = savedItemsTable.id.count();
    final query = selectOnly(savedItemsTable)
      ..addColumns([countExp])
      ..where(
        savedItemsTable.isArchiveRecovered.equals(false) &
            (savedItemsTable.enrichmentStatus.equals(
                  EnrichmentStatus.failed.index,
                ) |
                savedItemsTable.author.isIn(['[deleted]', '[removed]']) |
                savedItemsTable.body.isIn(['[deleted]', '[removed]']) |
                savedItemsTable.title.isIn(['[deleted]', '[removed]'])),
      );
    return query.watchSingle().map((row) => row.read(countExp) ?? 0);
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
    _ftsInitFuture = null;
    await transaction(() async {
      await customStatement('DROP TRIGGER IF EXISTS saved_items_ai;');
      await customStatement('DROP TRIGGER IF EXISTS saved_items_ad;');
      await customStatement('DROP TRIGGER IF EXISTS saved_items_au;');

      await delete(itemCollectionsTable).go();
      await delete(collectionsTable).go();
      await delete(savedItemsTable).go();
      try {
        await customStatement('DELETE FROM saved_items_fts;');
      } catch (e, stack) {
        debugPrint('[Database] Note: Could not clear FTS5 index: $e\n$stack');
      }

      try {
        await customStatement(
          'DELETE FROM sqlite_sequence WHERE name IN (\'collections_table\', \'saved_items_table\');',
        );
      } catch (_) {}

      await _createFts5(this);
      _ftsInitFuture = Future.value();
    });

    try {
      await customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
      await customStatement('VACUUM;');
    } catch (e) {
      debugPrint('[Database] Post-clear compaction note: $e');
    }

    notifyUpdates({
      TableUpdate.onTable(savedItemsTable, kind: UpdateKind.delete),
      TableUpdate.onTable(collectionsTable, kind: UpdateKind.delete),
      TableUpdate.onTable(itemCollectionsTable, kind: UpdateKind.delete),
    });
  }
}

extension SavedItemEntryExtension on SavedItemEntry {
  SavedItem toDomain({List<Collection> collections = const []}) {
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
      galleryImages: SavedItem.parseGalleryImagesJson(galleryImages),
      galleryPreviewImages: SavedItem.parseGalleryImagesJson(
        galleryPreviewImages,
      ),
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
      isArchiveRecovered: isArchiveRecovered,
      collections: collections,
    );
  }
}
